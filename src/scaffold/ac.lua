-- Convenience facade, NOT the upstream ac package. Milliseconds; no global installation.
local M={}
function M.new(bridge, ui)
    local scheduler=assert(bridge.scheduler)
    local ac={}
    local function timer(ms,n,fn)
        assert(type(ms)=='number' and ms>=0 and ms<math.huge,'finite nonnegative milliseconds required')
        assert(type(n)=='number' and n>=0 and n%1==0,'nonnegative count required')
        assert(type(fn)=='function','callback required')
        local ticks=math.max(1,math.ceil(ms/10))
        local token,task={},nil
        function token:remove() task:cancel() end
        token.cancel=token.remove
        function token:pause() task:pause() end
        function token:resume() task:resume() end
        function token:get_remaining() return task:get_remaining()*10 end
        task=scheduler:after(ticks,function()
            local callback=fn
            if n==1 then token:remove() elseif n>1 then n=n-1 end
            callback(token)
        end,ticks)
        return token
    end
    function ac.wait(ms,fn) return timer(ms,1,fn) end
    function ac.loop(ms,fn) return timer(ms,0,fn) end
    ac.timer=timer
    function ac.clock() return scheduler:now()/100 end
    if ui then ac.ui={wait=ui.game.wait,loop=ui.game.loop,timer=ui.game.timer} end
    return ac
end
return M
