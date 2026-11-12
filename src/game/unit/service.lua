-- Public native unit service: owns both object registry and the shared engine event bridge.
local Manager=require 'game.unit.manager'
local Context=require 'scaffold.context'
local M={}
function M.new(scheduler,native,on_fault)
    Context.assert_sync()
    native=native or require 'game.unit.native'
    local units=Manager.new(native,scheduler)
    local ok,unbind=pcall(native.bind,units,function(err)
        scheduler:stop()
        if on_fault then on_fault(err)end
    end)
    if not ok then units:stop();error(unbind,0) end
    local stop,closed=units.stop,false
    function units:stop()
        Context.assert_sync()
        if closed then return true end;closed=true
        local errors={}
        local function attempt(fn,...)
            local called,success,why=pcall(fn,...)
            if not called then errors[#errors+1]=tostring(success)
            elseif success==false then errors[#errors+1]=tostring(why) end
        end
        attempt(unbind)
        attempt(stop,self)
        unbind=nil
        if #errors>0 then return false,table.concat(errors,'\n') end
        return true
    end
    return units
end
return M
