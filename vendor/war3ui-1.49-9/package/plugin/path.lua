local storm = require 'jass.storm'
local is_local = storm.load("war3map.wtg") ~= nil
if is_local then 
    package.path = package.path .. ";"
    .. "D:\\map\\war3ui\\war3UI1.49-3\\war3UI\\package\\plugin\\" .. "?\\init.lua;"
    .. "D:\\map\\war3ui\\war3UI1.49-3\\war3UI\\package\\plugin\\" .. "script\\?.lua;"
    .. "D:\\map\\war3ui\\war3UI1.49-3\\war3UI\\package\\plugin\\" .. "script\\?\\init.lua;"
    .. "D:\\map\\war3ui\\war3UI1.49-3\\war3UI\\package\\plugin\\" .. "script\\core\\?.lua;"
    .. "D:\\map\\war3ui\\war3UI1.49-3\\war3UI\\package\\plugin\\" .. "script\\core\\?\\init.lua;"
    package.local_map_path = "D:\\map\\war3ui\\war3UI1.49-3\\war3UI\\package\\plugin\\" 
else 
    package.path = package.path .. ";"
        .. "?\\init.lua;"
        .. "script\\?.lua;"
        .. "script\\?\\init.lua;"
        .. "script\\core\\?.lua;"
        .. "script\\core\\?\\init.lua;"
end
return is_local
