
ac.loop(30 * 1000, function()
	collectgarbage("collect")
    local lua_memory = collectgarbage 'count'
    
    print(('定期清理内存[%.3fk]'):format(lua_memory))
end)