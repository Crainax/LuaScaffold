-- Diagnostic work is local. No measured value affects synchronized game state.
local M={}
function M.run(ui,check)
    local log=require 'jass.log'
    local sink
    local tests={}
    local function add(name,n,fn) tests[#tests+1]={name,n,fn} end
    add('empty_loop',250000,function(n) for i=1,n do sink=i end end)
    add('closure_capture',250000,function(n) for i=1,n do local x=i;sink=function() return x end end end)
    add('empty_table',250000,function(n) for _=1,n do sink={} end end)
    add('table_4_fields',250000,function(n) for i=1,n do sink={i,i+1,i+2,i+3} end end)
    add('concat_unique_short',250000,function(n) for i=1,n do sink='key:'..i end end)
    local values={};for i=1,1000 do values[i]='key:'..i end
    add('string_equal_existing',250000,function(n) for i=1,n do sink=values[i%1000+1]=='key:500' end end)
    local event=require('scaffold.events').new('local')
    local calls=0;local function listener() calls=calls+1 end
    for _=1,100 do event:on(listener) end
    add('events_100_listeners',5000,function(n) for _=1,n do event:emit() end end)
    add('scheduler_1000_idle',1000,function(n)
        local s=require('scaffold.scheduler').new('local')
        for _=1,1000 do s:after(100000,listener) end
        for _=1,n do s:step() end;s:stop()
    end)
    local text=ui.class.text:builder{x=20,y=300,w=200,h=40,text='benchmark'}
    add('native_text_update',20000,function(n) for i=1,n do text:set_text(values[i%1000+1]) end end)
    for _,test in ipairs(tests) do
        local name,n,fn=table.unpack(test)
        fn(math.min(n,100)) -- warmup
        for sample=1,5 do
            collectgarbage('collect')
            local before=collectgarbage('count')
            local start=os.clock();fn(n);local seconds=os.clock()-start
            local after=collectgarbage('count')
            log.info(string.format('[BENCH] name=%s n=%d sample=%d seconds=%.6f heap_delta_kib=%.3f gc=normal',name,n,sample,seconds,after-before))
        end
    end
    -- Bounded stopped-GC allocation probe, separate from normal-GC timings.
    for _,test in ipairs(tests) do
        if test[1]=='closure_capture' or test[1]=='empty_table' then
            collectgarbage('collect');collectgarbage('stop')
            local before=collectgarbage('count');test[3](10000)
            local delta=collectgarbage('count')-before;collectgarbage('restart')
            log.info(string.format('[ALLOC] name=%s n=10000 kib=%.3f',test[1],delta))
        end
    end
    sink=nil;event:clear();text:destroy();collectgarbage('collect')
    check(calls>0,'native runtime benchmark matrix completed')
end
return M
