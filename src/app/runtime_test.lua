-- Runs entirely in-game. No desktop input. All gameplay is driven on every peer.
local M = {}
local j = require 'jass.common'
local log = require 'jass.log'
local Context = require 'scaffold.context'
local snapshots, expected = {}, {}
local assertions, ui_cycles, rng_calls, checksum = 0, 0, 0, 17
local function check(ok, name)
    assert(ok, 'runtime assertion: ' .. name)
    assertions = assertions + 1
    log.info('PASS: ' .. name)
end
function M.handlers(handlers)
    handlers.snapshot = function(sender, cmd)
        snapshots[cmd.entity] = snapshots[cmd.entity] or {}
        snapshots[cmd.entity][sender] = cmd.value
    end
end
function M.authorize(_, cmd)
    return cmd.verb == 'snapshot' and cmd.entity >= 1 and cmd.entity <= 10000
end
function M.start(bridge, ui, counts, config)
    local scheduler, class = bridge.scheduler, ui.class
    local local_id = j.GetPlayerId(j.GetLocalPlayer())
    local Registry = require 'scaffold.entity_registry'
    local registry, entities, humans = Registry.new(), {}, {}
    local baseline_ui = ui.count()
    local weak = setmetatable({}, {__mode = 'v'})
    for i = 0, 11 do
        if j.GetPlayerController(j.Player(i)) == j.MAP_CONTROL_USER and j.GetPlayerSlotState(j.Player(i)) == j.PLAYER_SLOT_STATE_PLAYING then
            humans[#humans + 1] = i
        end
    end
    local function create_entity()
        local unit = j.CreateUnit(j.Player(0), string.unpack('>I4', 'hfoo'), 0, 0, 0)
        j.PauseUnit(unit, true)
        j.SetUnitInvulnerable(unit, true)
        local record = registry:register(unit)
        entities[#entities + 1] = record
        return record
    end
    for i = 1, 6 do create_entity() end
    local group = j.CreateGroup()
    local function state_hash()
        local h = checksum
        for _, e in ipairs(entities) do
            h = (h * 31 + e.id * 7 + math.floor(j.GetUnitState(e.handle, j.UNIT_STATE_LIFE))) % 2147483647
            h = (h * 31 + math.floor(j.GetUnitX(e.handle) * 16)) % 2147483647
            h = (h * 31 + math.floor(j.GetUnitY(e.handle) * 16)) % 2147483647
        end
        for _, p in ipairs(humans) do h = (h * 31 + (counts[p] or 0)) % 2147483647 end
        return h
    end
    local native_weak = setmetatable({}, {__mode = 'v'})
    local pending_native = {}
    local function make_native_probe(i)
        local marker = {i}
        native_weak[i] = marker
        local fn = function() return marker end
        local t = j.CreateTimer()
        j.TimerStart(t, 1000, false, fn)
        pending_native[#pending_native + 1] = t
    end
    for i = 1, 8 do make_native_probe(i) end
    scheduler:after(50, function()
        for _, t in ipairs(pending_native) do j.PauseTimer(t); j.DestroyTimer(t) end
        pending_native = nil
    end)
    scheduler:after(100, function()
        check(#humans == config.clients, 'expected active humans=' .. config.clients)
        check(type(ui.class.button) == 'table' and baseline_ui > 0, 'official UI controls initialized')
        check(_G.class == nil and math.abs(math.sin(math.pi / 2) - 1) < 1e-9, 'UI globals and standard math isolated')
        check(not package.loaded['ui.client.util'] and not package.loaded['ac'], 'legacy sync and gameplay entry absent')
        local view = require 'app.view'
        check(require('jass.japi').FrameGetWidth(view.button._id) > 0, 'native button has positive width')
        check(view.text:get_text():find('LuaScaffold', 1, true) ~= nil, 'native text round trip')
        local rejected = not pcall(function()
            Context.local_call(function() registry:register(999) end)
        end)
        check(rejected, 'local UI cannot register gameplay entities')
        local Command = require 'scaffold.command'
        check(not Command.decode('print"probe"') and not Command.decode(string.rep('x',129)), 'unsafe and oversized input rejected')
        local model = class.model:builder {x=20,y=400,w=80,h=80,model='Units\\Human\\Footman\\Footman.mdx'}
        check(model and model._id ~= 0, 'native model created')
        model:destroy()
        local model2 = class.model2:builder {x=120,y=400,w=80,h=80,model='Units\\Human\\Footman\\Footman.mdx'}
        check(model2 and model2._id ~= 0, 'native model2 created')
        model2:destroy()
        baseline_ui = ui.count() -- model2 has one shared match-long backdrop
        local scroll = class.panel:builder {x=200,y=400,w=150,h=100,is_scroll=true}
        scroll:set_scroll_y(0) -- empty content must not divide by zero
        local child = class.button:builder {parent=scroll,x=0,y=180,w=40,h=40}
        check(scroll._id ~= nil and child._id ~= nil, 'native scroll panel created')
        scroll:destroy()
        local progress = class.progress.new(nil, 'Units\\Human\\Footman\\Footman.mdx', 10, 500, 150, 30, 12, 'center')
        progress:set_value(50,100); progress:set_value(0,0)
        check(progress._id ~= nil and progress.rate == 0, 'progress handles zero denominator')
        progress:destroy()
        check(ui.count() == baseline_ui, 'models and scroll disposal return to baseline')
        -- Exercise the actual Lua UI dispatch path. This is not an OS mouse click.
        view.button:event_notify('on_button_clicked')
    end)
    scheduler:after(120, function()
        require('jass.japi').SendCustomMessage('LS1|1|ping|0|0')
    end)
    local function ui_cycle()
        Context.local_call(function()
            local p = class.panel:builder {x=30,y=40,w=240,h=180,normal_image='core\\panel.blp'}
            local b = class.button:builder {parent=p,x=5,y=5,w=32,h=32,normal_image='core\\button.blp'}
            local t = class.text:builder {parent=p,x=45,y=5,w=140,h=30,text='Lua test',font_size=16}
            local edit = class.edit:builder {parent=p,x=5,y=60,w=150,h=30,text='edit test',font_size=16}
            assert(t:get_text() == 'Lua test' and edit:get_text() == 'edit test', 'text/edit native round trip')
            local marker = {}; weak[1] = marker
            local function capture(value)
                b:loop(100000, function() return value end)
            end
            capture(marker)
            p:destroy(); p:destroy()
            assert(ui.count() == baseline_ui, 'UI registry did not return to baseline')
            ui_cycles = ui_cycles + 1
        end)
    end
    scheduler:after(150, function()
        for i = 1, 20 + local_id * 10 do ui_cycle() end
        collectgarbage('collect'); collectgarbage('collect')
        check(weak[1] == nil, 'destroyed UI releases cancelled closure captures')
        local remaining = 0
        for _ in pairs(native_weak) do remaining = remaining + 1 end
        log.info('[NATIVE_CALLBACK_GC] retained=' .. remaining .. '/8')
        -- The project uses a bounded match-long bridge even if native VM caches codes.
        check(ui.count() == baseline_ui, 'nested UI destroy is idempotent')
    end)
    local stress = scheduler:after(200, function()
        for i = 1, 1 + local_id do ui_cycle() end
        if local_id == 0 then collectgarbage('collect') end
    end, 25)
    local gameplay = scheduler:after(200, function()
        j.GroupClear(group)
        j.GroupEnumUnitsInRange(group, 0, 0, 1000, nil)
        local candidates = {}
        while true do
            local unit = j.FirstOfGroup(group)
            if unit == nil or unit == 0 then break end
            j.GroupRemoveUnit(group, unit)
            local record = registry:find(unit)
            if record then candidates[#candidates + 1] = record end
        end
        table.sort(candidates, function(a,b) return a.id < b.id end)
        assert(#candidates == 6, 'stable candidate count')
        local index = j.GetRandomInt(1, #candidates)
        rng_calls = rng_calls + 1
        local e = candidates[index]
        j.SetUnitState(e.handle, j.UNIT_STATE_LIFE, 100 + rng_calls % 100)
        checksum = (checksum * 31 + e.id * 7 + index) % 2147483647
        if rng_calls % 10 == 0 then
            local old = table.remove(entities, 1)
            local handle, id = old.handle, old.id
            registry:remove(id); j.RemoveUnit(handle)
            local new = create_entity()
            assert(new.id > id and not registry:get(id), 'stale entity survived reuse')
        end
    end, 50)
    local phase = 0
    local snapshot_job = scheduler:after(600, function()
        phase = phase + 1
        expected[phase] = state_hash()
        bridge:send('snapshot', phase, expected[phase])
        local current = phase
        scheduler:after(250, function()
            for _, p in ipairs(humans) do
                assert(snapshots[current] and snapshots[current][p] == expected[current], 'peer state mismatch or missing peer phase=' .. current .. ' player=' .. p)
            end
            log.info('[STATE_MATCH] phase=' .. current .. ' hash=' .. expected[current] .. ' rng=' .. rng_calls)
        end)
    end, 500)
    if config.oos_control then
        scheduler:after(1000, function()
            if local_id == 0 then j.SetRandomSeed(123); j.GetRandomInt(0, 1000000) end
            log.info('[CONTROL] deliberate RNG divergence injected')
        end)
    end
    scheduler:after(config.duration_ticks, function()
        stress:cancel(); gameplay:cancel(); snapshot_job:cancel()
        check(ui_cycles >= 100, 'UI lifecycle stress cycles=' .. ui_cycles)
        check(rng_calls > 20 and phase >= 3, 'gameplay RNG and peer snapshots exercised')
        for _, p in ipairs(humans) do check(counts[p] == 1, 'UI command exactly once player=' .. p) end
        check(not bridge:is_faulted(), 'bridge has no fault')
        for _, e in ipairs(entities) do
            local h=e.handle; registry:remove(e.id); j.RemoveUnit(h)
        end
        j.DestroyGroup(group)
        ui.stop()
        check(ui.count() == 0, 'UI shutdown clears all controls')
        scheduler:after(300, function()
            log.info('[METRICS] ui_cycles=' .. ui_cycles .. ' rng_calls=' .. rng_calls .. ' phases=' .. phase .. ' assertions=' .. assertions)
            log.info('[UT_DONE] LuaScaffold ' .. config.build_id .. ' P' .. (local_id+1))
        end)
    end)
end
return M
