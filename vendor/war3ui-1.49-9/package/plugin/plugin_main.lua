
local path = ''

local bool, res = pcall(require, 'path')
console = require 'jass.console'

print = console.write 

if res then 
    --console.enable = true
    print('本地路径')

else 
    print('地图内路径')
end
print('初始化')
xpcall(function ()
    require 'script'
end, function (msg)
    --print(msg, '\n', debug.traceback())
end)

local japi = require 'jass.japi'

japi.SetOwner('问号')


