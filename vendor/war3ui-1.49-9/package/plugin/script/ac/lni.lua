local lni_c = require 'jass.lni'
local storm = require 'jass.storm'

local mt = {}
local marco = {}

function mt:loader(...)
	return lni_c(...)
end

function mt:searcher(name, callback)
	local searcher = marco[name .. 'Searcher']
	if searcher == '' then
		callback('')
		return
	end
	for _, path in ipairs(ac.split(searcher, ';')) do
		local fullpath = path: gsub('%$(.-)%$', function(v) return marco[v] or '' end)
		callback(fullpath)
    end
end

function mt:packager(name, loadfile)
	local result = {}
	local ok = {}


	local function package(path, default, enum)
        ok[path] = true
		local full_path = path.. name .. '.ini'

		local content = loadfile(full_path)
		if content then
			result, default, enum = lni_c(content, full_path, {result, default, enum} )
		end
		local config = loadfile(path .. '.iniconfig')
		if config then
			for _, dir in ipairs(ac.split(config, '\n')) do
				local name = dir:gsub('^%s', ''):gsub('%s$', '')
				if name ~= '' then
					local name = path .. name .. '\\'
					if not ok[name] then
						package(name, default, enum)
					end
				end
			end
		end
	end
	self:searcher('Table', package)
	return result
end

function mt:set_marco(key, value)
	marco[key] = value
end

function mt:load(name_tbl,file_path, load)

	file_path = file_path .. '\\'

    local data = {}
    mt:set_marco('TableSearcher', '$MapPath$' .. file_path)
    for _, path in ipairs(ac.split(package.path, ';')) do
        local buf = load(path:gsub('%?%.lua', file_path .. '.iniconfig'))
        if buf then
            mt:set_marco('MapPath', path:gsub('%?%.lua', ''))
            break
        end
    end
    
    --加载所有ini数据
	
    for file_name,tbl_name in pairs(name_tbl) do 
        local tbl = mt:packager(file_name, load)
		data[tbl_name] = tbl
    end 

    return data
end 


function mt:init()
	local names = {
        ['SpellData'] = 'skill',
        ['UnitData']  = 'unit', 
        ['ItemData']  = 'item',
		['BuffData']  = 'buff',
		['ModelData'] = 'model'
    }
    --读取地图数据
    ac.table = mt:load(names,'table',storm.load)

end 

mt:init()

return mt