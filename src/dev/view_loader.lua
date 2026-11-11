-- Trusted developer file only. This environment reduces accidental coupling, not a security sandbox.
local M={}
function M.compile(source)
    if type(source)~='string' or #source>131072 then return nil,'view source exceeds 128 KiB' end
    local env={assert=assert,error=error,ipairs=ipairs,pairs=pairs,next=next,type=type,
        tonumber=tonumber,tostring=tostring,select=select,math=math,string=string,table=table}
    local chunk,err=load(source,'@dev/view.lua','t',env)
    if not chunk then return nil,err end
    local ok,factory=pcall(chunk)
    if not ok then return nil,factory end
    if type(factory)~='function' then return nil,'view file must return a factory' end
    return factory
end
function M.start(ui,bridge,config)
    assert(config.dev,'development build required')
    local manager=require('scaffold.ui_reload').new(ui,bridge,true)
    local last,accepted,rejected=nil,0,0
    local token=ui.game.loop(config.dev_poll_ms or 500,function()
        local file=io.open(config.dev_view_file or config.project_id..'-dev/view.lua','rb')
        if not file then return end
        local source=file:read(131073);file:close()
        if source==last then return end
        last=source
        local factory,err=M.compile(source)
        local ok=false
        if factory then ok,err=manager:reload(factory) end
        if ok then accepted=accepted+1 else rejected=rejected+1 end
        require('jass.log').info(ok and '[DEV_VIEW] replaced' or '[DEV_VIEW_REJECTED] '..tostring(err))
    end)
    return {stop=function() token:remove();return manager:stop() end,
        status=function() return accepted,rejected,manager:state() end}
end
return M
