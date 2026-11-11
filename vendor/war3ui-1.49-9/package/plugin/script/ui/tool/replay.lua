local ui = require 'ui.client.util'
local storm = require 'jass.storm'



local function format_number(n)
    local str = ('%.10f'):format(n)
    str = str:gsub('%.?0*$', '')
    return str
end

local function is_integer(n)
    if math.type then
        return math.type(n) == 'integer'
    else
        return type(n) == 'number' and n % 1 == 0
    end
end

local is_pack_code = false

local TAB = setmetatable({}, { __index = function (self, n)
    if is_pack_code then 
        return ''
    end
    self[n] = string.rep('    ', n)
    return self[n]
end})


local RESERVED = {
    ['and']      = true,
    ['break']    = true,
    ['do']       = true,
    ['else']     = true,
    ['elseif']   = true,
    ['end']      = true,
    ['false']    = true,
    ['for']      = true,
    ['function'] = true,
    ['goto']     = true,
    ['if']       = true,
    ['in']       = true,
    ['local']    = true,
    ['nil']      = true,
    ['not']      = true,
    ['or']       = true,
    ['repeat']   = true,
    ['return']   = true,
    ['then']     = true,
    ['true']     = true,
    ['until']    = true,
    ['while']    = true,
}


local function table_encode(tbl, option)
    if not option then
        option = { }

        --if is_pack_code then 
            option['noArrayKey'] = true
        --end
    end
    if type(tbl) ~= 'table' then
        return ('%s'):format(tbl)
    end
    local lines = {}
    local mark = {}
    lines[#lines+1] = '{'
    local function unpack(tbl, tab)
        mark[tbl] = (mark[tbl] or 0) + 1
        local keys = {}
        local keymap = {}
        local integerFormat = '[%d]'
        local alignment = 0
        if #tbl >= 10 then
            local width = #tostring(#tbl)
            integerFormat = ('[%%0%dd]'):format(math.ceil(width))
        end
        for key in pairs(tbl) do
            if type(key) == 'string' then
                if not key:match('^[%a_][%w_]*$')
                or RESERVED[key]
                or option['longStringKey']
                then
                    keymap[key] = ('[%q]'):format(key)
                else
                    keymap[key] = ('%s'):format(key)
                end
            elseif is_integer(key) then
                keymap[key] = integerFormat:format(key)
            else
                keymap[key] = ('["<%s>"]'):format(tostring(key))
            end
            keys[#keys+1] = key
            if option['alignment'] then
                if #keymap[key] > alignment then
                    alignment = #keymap[key]
                end
            end
        end
        --local mt = getmetatable(tbl)
        --if not mt or not mt.__pairs then
        --    if option['sorter'] then
        --        option['sorter'](keys, keymap)
        --    else
        --        table.sort(keys, function (a, b)
        --            return keymap[a] < keymap[b]
        --        end)
        --    end
        --end
        for index, key in ipairs(keys) do
            local keyWord = keymap[key]
            if option['noArrayKey']
                and is_integer(key)
                and key <= #tbl
            then
                keyWord = ''
            else
                if #keyWord < alignment then
                    keyWord = keyWord .. (' '):rep(alignment - #keyWord) .. ' = '
                else
                    keyWord = keyWord .. ' = '
                end
            end
            local value = tbl[key]
            local tp = type(value)
            local s = ','
            if index == #keys then 
                s = ''
            end 

            if option['format'] and option['format'][key] then
                lines[#lines+1] = ('%s%s%s%s'):format(TAB[tab+1], keyWord, option['format'][key](value, unpack, tab+1), s)
            elseif tp == 'table' then
                if mark[value] and mark[value] > 0 then
                    lines[#lines+1] = ('%s%s%s%s'):format(TAB[tab+1], keyWord, option['loop'] or '"<Loop>"', s)
                else
                    lines[#lines+1] = ('%s%s{'):format(TAB[tab+1], keyWord)
                    unpack(value, tab+1)
                    lines[#lines+1] = ('%s}%s'):format(TAB[tab+1], s)
                end
            elseif tp == 'string' then
                lines[#lines+1] = ('%s%s%q%s'):format(TAB[tab+1], keyWord, value, s)
            elseif tp == 'number' then
                lines[#lines+1] = ('%s%s%s%s'):format(TAB[tab+1], keyWord, (option['number'] or format_number)(value), s)
            elseif tp == 'nil' then
            else
                lines[#lines+1] = ('%s%s%s%s'):format(TAB[tab+1], keyWord, tostring(value), s)
            end
        end
        mark[tbl] = mark[tbl] - 1
    end
    unpack(tbl, 0)
    lines[#lines+1] = '}'
    local newline = '\r\n'
    if is_pack_code then 
        newline = nil 
    end 
    return table.concat(lines, newline)
end

local save_attribute_map = {}
local save_attribute_list = {
    'type', '_type', 'x', 'y', 'w', 'h', 'alpha', 'color', 'level',
    'normal_image', 'hover_image', 'active_image',
    'align', 'font_size', 'text','keys', 'sync_key', 
    'is_scroll', 'has_ani', 'model', 'size', 'offset_x','offset_y', 
    'rotate_x','rotate_y','rotate_z','team_color','animation_index', 'name','index'
}

for k, v in ipairs(save_attribute_list) do 
    save_attribute_map[v] = true
end

save_attribute_map['_type'] = function (frame, key, value)
    if frame.type then 
        local base = class[frame.type]._type 
        if frame._type:sub(1, base:len()) ~= base then 
            return value
        end
    end
end 

local function frame_encode(frame, stack)
    local map = {}

    local function copy_frame_info(frame)
        if map[frame] then 
            return 
        end 
        if stack and stack > 0 then 
            stack = stack - 1 
            if stack < 0 then 
                return 
            end
        end
        map[frame] = true 

        local tbl = {}

        local childs = {}
        local i = 0
        if frame.children then
            for index, child in ipairs(frame.children) do 
                if (child._panel) --所有2层叠加的控件
                or (child._panel == nil and child._control == nil) then --单层的控件 
                    childs[child] = true
                    i = i + 1
                    tbl[i] = copy_frame_info(child)
                end
            end
        end

        for key, value in sortpairs(frame) do
            if type(value) ~= 'function' and key ~= '_panel' then 
                local has = save_attribute_map[key]
                if has and (type(value) ~= 'table' or value.type == nil) then 
                    if type(has) == 'function' then 
                        tbl[key] = has(frame, key, value)
                    else 
                        tbl[key] = value
                    end
                end 
            end
        end

        for index, child in ipairs(frame.children) do 
            if (child._panel) --所有2层叠加的控件
            or (child._panel == nil and child._control == nil) then --单层的控件 

                local str = copy_frame_info(child)
                if str then 
                    table.insert(tbl, str)
                end
            end
        end

        return tbl
    end


    return copy_frame_info(frame)
end

--save_ui()

return {
    frame_encode = frame_encode,
    table_encode = table_encode,
}