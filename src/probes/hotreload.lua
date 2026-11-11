local M={}
function M.watch(ui,bridge,config,check)
    local Context=require 'scaffold.context'
    local j=require 'jass.common'
    local file=config.project_id..'-dev/test-'..config.build_id..'-P'..(j.GetPlayerId(j.GetLocalPlayer())+1)..'.lua'
    local baseline=ui.count()
    local code='return function(ctx) ctx.state.loads=(ctx.state.loads or 0)+1;ctx:create("text",{text="watch view",w=200,h=40}) end'
    local function write(source) require('jass.storm').save(file,source) end
    write(code)
    local watcher=require('dev.view_loader').start(ui,bridge,{dev=true,project_id=config.project_id,dev_view_file=file,dev_poll_ms=10})
    ui.game.wait(100,function() Context.local_call(function()
        local accepted,_,state=watcher.status()
        check(accepted==1 and state.loads==1,'file watcher loads initial view')
        write('syntax !!!')
    end) end)
    ui.game.wait(200,function() Context.local_call(function()
        local accepted,rejected,state=watcher.status()
        check(accepted==1 and rejected==1 and state.loads==1,'file watcher rejects syntax and preserves view')
        write(code..'\n-- second version')
    end) end)
    ui.game.wait(300,function() Context.local_call(function()
        local accepted,rejected,state=watcher.status()
        check(accepted==2 and rejected==1 and state.loads==2,'file watcher recovers on valid edit')
        watcher.stop();write('') -- embedded os.remove is unavailable; leave an empty diagnostic file
        check(ui.count()==baseline,'file watcher stop clears view')
    end) end)
end
function M.run(ui,bridge,check)
    local count,tasks,events=ui.count(),ui.game.timer_size(),ui.game.events:count()
    local manager=require('scaffold.ui_reload').new(ui,bridge,true)
    local weak=setmetatable({},{__mode='v'})
    local function factory(ctx)
        ctx.state.generation=(ctx.state.generation or 0)+1
        local payload={};weak[ctx.state.generation]=payload
        local panel=ctx:create('panel',{x=100,y=100,w=400,h=200})
        ctx:create('text',{parent=panel,x=10,y=10,w=300,h=40,text='Reload '..ctx.state.generation})
        ctx:on({on_probe=function() return payload end})
        ctx:loop(100000,function() return payload end)
    end
    for i=1,30 do
        assert(manager:reload(factory))
        assert(manager:state().generation==i)
        local before=ui.count()
        local ok=manager:reload(function(ctx)
            ctx:create('button',{x=0,y=0,w=20,h=20})
            ctx:on({on_probe=function() end});ctx:loop(50000,function() end)
            ctx.state.generation=999;error('expected mount failure')
        end)
        assert(not ok and manager:state().generation==i and ui.count()==before)
        assert(ui.game.timer_size()==tasks+1 and ui.game.events:count()==events+1)
    end
    check(manager:stop(),'view reload stops successfully')
    collectgarbage('collect');collectgarbage('collect')
    check(not next(weak),'reloaded views release closure payloads')
    check(ui.count()==count and ui.game.timer_size()==tasks and ui.game.events:count()==events,'reload success and failure return resources to baseline')
    local disabled=require('scaffold.ui_reload').new(ui,bridge,false)
    check(not pcall(function() disabled:reload(factory) end),'production reload disabled')
    if require('app.config').dev then
        local loader=require 'dev.view_loader'
        check(not loader.compile('invalid !!!') and not loader.compile('return {}'),'invalid development source rejected')
        local create=assert(loader.compile('return function(ctx) ctx:create("text",{text="compiled view",w=200,h=30}) end'))
        local loaded=require('scaffold.ui_reload').new(ui,bridge,true)
        check(loaded:reload(create),'compiled view source mounts');loaded:stop()
    end
end
return M
