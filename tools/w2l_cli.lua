-- Build-host Lua 5.4, not Warcraft Lua. Invoke the pinned backend without its GUI launcher.
local root=table.remove(arg,1)
package.path=root..'/script/?.lua;'..root..'/script/?/init.lua;'..package.path
package.cpath=root..'/bin/?.dll;'..package.cpath
local fs=require 'bee.filesystem'
fs.current_path(fs.path(root)/'script')
require 'utility'
local errors,finished=0,false
local messenger={}
function messenger.raw(value) print(value) end
function messenger.text(value) print('[W2L] '..value) end
function messenger.title() end
function messenger.progress() end
function messenger.report(kind,level,content,tip)
    if level==1 then errors=errors+1 end
    print(string.format('[W2L_REPORT] type=%s level=%d %s %s',kind,level,content,tip or ''))
end
function messenger.exit(kind,value)
    finished=true
    if kind=='error' or kind=='failed' then errors=errors+1 end
    print('[W2L_EXIT] '..kind..' '..value)
end
function messenger.wait() error('Interactive w3x2lni step is unsupported') end
package.loaded['share.messager']=messenger
local ok,err=xpcall(function() require 'backend' end,debug.traceback)
if not ok then io.stderr:write(err..'\n');os.exit(1) end
if arg[1]~='version' and not finished then error('w3x2lni did not report completion') end
if errors>0 then os.exit(2) end
