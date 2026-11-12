-- Application composition and teardown. Gameplay composition lives in world/session.
local M = {}
local bridge
local ui
local dev_view
local world,game_view
local initialized=false
local config = require 'app.config'
function M.start()
    require('scaffold.context').assert_sync()
    assert(not initialized,'application initialization is once per match')
    initialized=true
    local log = require 'jass.log'
    local jass = require 'jass.common'
    local counts = {}
    local handlers = {
        ping = function(sender)
            counts[sender] = (counts[sender] or 0) + 1
            log.info('[LuaScaffold] COMMAND ping', sender, counts[sender])
        end,
    }
    local test
    local gameplay=not config.runtime_test or config.suite=='gameplay' or config.suite=='campaign_soak' or config.suite=='business_resource' or config.suite=='resource_matrix'
    if config.runtime_test then
        test = require 'app.runtime_test'
        test.handlers(handlers)
    end
    if gameplay then
        for _,verb in ipairs{'cast','talent','challenge','leave'}do
            handlers[verb]=function(sender,cmd)return world:command(sender,cmd)end
        end
    end
    bridge = require('scaffold.innerjapi').start(handlers, function(sender, cmd)
        local allowed = cmd.verb == 'ping' and cmd.entity == 0 and cmd.value == 0
        if gameplay then allowed=allowed or cmd.verb=='cast' or cmd.verb=='talent' or cmd.verb=='challenge' or cmd.verb=='leave' end
        if test then allowed = allowed or test.authorize(sender, cmd) end
        return allowed
            and jass.GetPlayerController(jass.Player(sender)) == jass.MAP_CONTROL_USER
            and jass.GetPlayerSlotState(jass.Player(sender)) == jass.PLAYER_SLOT_STATE_PLAYING
    end)
    local started,why=pcall(function()
    if gameplay then
        local players={}
        for i=0,11 do
            if jass.GetPlayerController(jass.Player(i))==jass.MAP_CONTROL_USER and jass.GetPlayerSlotState(jass.Player(i))==jass.PLAYER_SLOT_STATE_PLAYING then players[#players+1]=i end
        end
        world=require('world.session').start(bridge.scheduler,players,config.runtime_test,function(err)bridge:abort(err)end)
        M.world=world
    end
    if config.ui then
        ui = require 'scaffold.ui'
        ui.start()
        bridge.scheduler:after(1, function() ui.step() end, 1)
        if config.runtime_test then require('app.view').start(ui, bridge)end
        if world then game_view=require('scaffold.context').local_call(function()return require('presentation.challenge_view').start(ui,bridge,world)end);M.game_view=game_view end
        if config.dev and not config.runtime_test then dev_view=require('dev.view_loader').start(ui,bridge,config) end
    end
    log.info('[LuaScaffold] BOOT', _VERSION, require('jass.runtime').version)
    if test then test.start(bridge, ui, counts, config, world, game_view) end
    end)
    if not started then
        local clean,detail=M.stop()
        error(tostring(why)..(clean and '' or '\ncleanup: '..tostring(detail)),0)
    end
    return bridge
end
function M.stop()
    require('scaffold.context').assert_sync()
    if not bridge then return true end
    local old,old_dev,old_view,old_world,old_ui=bridge,dev_view,game_view,world,ui
    bridge,dev_view,game_view,world,ui=nil,nil,nil,nil,nil
    M.world,M.game_view=nil,nil
    local errors={}
    local function attempt(fn,...)
        local called,ok,err=pcall(fn,...)
        if not called then errors[#errors+1]=tostring(ok)
        elseif ok==false then errors[#errors+1]=tostring(err)end
    end
    if old_dev then attempt(old_dev.stop)end
    if old_view then attempt(old_view.stop,old_view)end
    if old_world then attempt(old_world.stop,old_world)end
    if old_ui then attempt(old_ui.stop)end
    attempt(old.stop,old)
    if #errors>0 then return false,table.concat(errors,'\n')end
    return true
end
return M
