
local hook = require 'jass.hook'
local tool = require 'ui.tool.tool'
local storm = require 'jass.storm'
local jass = require 'jass.common'
local japi = require 'jass.japi'

local str2value = tool.str2value
local value2str = tool.value2str


local control_hashmap = {}

local attribute_map = {}

tool.control_hashmap = control_hashmap

tool.attribute_map = attribute_map

local init = class.ui_base.init
function class.ui_base:init()
    init(self)

    if self.name then 
        self:set_name(self.name)
    end 
end 

function class.ui_base:set_name(name)
    local old_name = self.name 
    self.name = name
    self.sync_key = name
    if old_name then 
        local old_hash = StringHash(old_name)
        local old = control_hashmap[old_hash]
        if old then 
            if old.num == self.num then 
                control_hashmap[old_hash] = nil 
            end 
        end 
    end 
    control_hashmap[StringHash(name)] = self
end



for frame_type, attr_table in pairs(tool.config_info) do 
    for index, attr_info in ipairs(attr_table) do 
        local name = attr_info[3]
        attribute_map[StringHash(name)] = attr_info
    end 
end 




--------绑定控件属性到 逆天-自定义值里--------------
local globals_map = {
    [StringHash('开发模式')] = function (path_name)
        if path_name ~= nil then
            tool.is_develop_mode = true
            require 'ui.tool.core'
        end
    end,

    [StringHash('加载界面')] = function (name)

        local file_path = (package.local_map_path or '') .. "007\\" .. name

        local str = storm.load(file_path)

        if str == nil then 
            return 
        end 
 
        if tool.is_develop_mode then 
            tool.load(str)
            return 
        end 

        local str = str:gsub('core\\\\background.blp', '')

        local data 
        pcall(function ()
            local func = load('return ' .. str)
            if func == nil then 
                return 
            end 
    
            data = func()
        end)
        if data == nil then 
            return 
        end 
        for index, info in ipairs(data) do 
            local frame_type = info.type 
            local frame = class[frame_type]:builder(info)
            
            tool.register_nil_event(frame)
        end

    end,

    [StringHash('鼠标x轴')]= function ()
        local x, y = game.get_mouse_pos()
        return x 
    end,

    [StringHash('鼠标y轴')]= function ()
        local x, y = game.get_mouse_pos()
        return y
    end,

    [StringHash('索引')]= function (self)
        return self.index
    end,

    [StringHash('父控件名字')]= function (self)
        if self.parent == nil then 
            return 
        end
        return self.parent.name
    end,
}


local globals_hash = StringHash('内置UI')
local trigger_button_hash = StringHash("触发按钮")
local real_trigger_name_hash = 0

local function set_frame_attr(name_hash, attr_type_hash, value)

    local control = control_hashmap[name_hash]
    if control == nil then 
        if name_hash == globals_hash then 
            local func = globals_map[attr_type_hash]
            if func then 
                func(value)
            end 
        end 
        return 
    end 
    local attr_info = attribute_map[attr_type_hash]
    if attr_info == nil then 
        return 
    end 

    local key, tp, name, func = table.unpack(attr_info)

    local str = tool.value2str(value, tp)
    local value = tool.str2value(str, tp)

    func(control, value)
end 

local function get_frame_attr(name_hash, attr_type_hash, value)
    local control = control_hashmap[name_hash]
    if control == nil then 
        if name_hash == globals_hash then 
            local func = globals_map[attr_type_hash]
            if func then 
                return func(value)
            end 
        end 
        return 
    end 
    local attr_info = attribute_map[attr_type_hash]
    if attr_info == nil then 
        local func = globals_map[attr_type_hash]
        if func then 
            return func(control)
        end 
        return 
    end 

    local key, tp, name, func = table.unpack(attr_info)

    local f = tool.get_attr_map[key]
    if f then 
        return f(control)
    end

    return control[key]
end 

local hook_func_table = {
'SaveInteger',
'SaveReal',
'SaveBoolean',
'SaveStr',
'SavePlayerHandle',
'SaveWidgetHandle',
'SaveDestructableHandle',
'SaveItemHandle',
'SaveUnitHandle',
'SaveAbilityHandle',
'SaveTimerHandle',
'SaveTriggerHandle',
'SaveTriggerConditionHandle',
'SaveTriggerActionHandle',
'SaveTriggerEventHandle',
'SaveForceHandle',
'SaveGroupHandle',
'SaveLocationHandle',
'SaveRectHandle',
'SaveBooleanExprHandle',
'SaveSoundHandle',
'SaveEffectHandle',
'SaveUnitPoolHandle',
'SaveItemPoolHandle',
'SaveQuestHandle',
'SaveQuestItemHandle',
'SaveDefeatConditionHandle',
'SaveTimerDialogHandle',
'SaveLeaderboardHandle',
'SaveMultiboardHandle',
'SaveMultiboardItemHandle',
'SaveTrackableHandle',
'SaveDialogHandle',
'SaveButtonHandle',
'SaveTextTagHandle',
'SaveLightningHandle',
'SaveImageHandle',
'SaveUbersplatHandle',
'SaveRegionHandle',
'SaveFogStateHandle',
'SaveFogModifierHandle',
'SaveAgentHandle',
'SaveHashtableHandle',
'LoadInteger',
'LoadReal',
'LoadBoolean',
'LoadStr',
'LoadPlayerHandle',
'LoadWidgetHandle',
'LoadDestructableHandle',
'LoadItemHandle',
'LoadUnitHandle',
'LoadAbilityHandle',
'LoadTimerHandle',
'LoadTriggerHandle',
'LoadTriggerConditionHandle',
'LoadTriggerActionHandle',
'LoadTriggerEventHandle',
'LoadForceHandle',
'LoadGroupHandle',
'LoadLocationHandle',
'LoadRectHandle',
'LoadBooleanExprHandle',
'LoadSoundHandle',
'LoadEffectHandle',
'LoadUnitPoolHandle',
'LoadItemPoolHandle',
'LoadQuestHandle',
'LoadQuestItemHandle',
'LoadDefeatConditionHandle',
'LoadTimerDialogHandle',
'LoadLeaderboardHandle',
'LoadMultiboardHandle',
'LoadMultiboardItemHandle',
'LoadTrackableHandle',
'LoadDialogHandle',
'LoadButtonHandle',
'LoadTextTagHandle',
'LoadLightningHandle',
'LoadImageHandle',
'LoadUbersplatHandle',
'LoadRegionHandle',
'LoadFogStateHandle',
'LoadFogModifierHandle',
'LoadAgentHandle',
'LoadHashtableHandle',

'HaveSavedInteger',
'HaveSavedReal',
'HaveSavedBoolean',
'HaveSavedString',
'HaveSavedHandle',
'RemoveSavedInteger',
'RemoveSavedReal',
'RemoveSavedBoolean',
'RemoveSavedString',
'RemoveSavedHandle',

}
--------------绑定控件属性 到逆天自定义值里 ---------------------------
for index, name in ipairs(hook_func_table) do 
    local head = name:sub(1, 4)
    if head == 'Save' then
        hook[name] = function (ht, index_a, index_b, value)
            if index_a == trigger_button_hash then index_a = real_trigger_name_hash end 
            set_frame_attr(index_a, index_b, value)
            _G[name](ht, index_a, index_b, value)
        end 
    elseif head == 'Load' then
        hook[name] = function (ht, index_a, index_b)
            if index_a == trigger_button_hash then index_a = real_trigger_name_hash end 
            return get_frame_attr(index_a, index_b) or _G[name](ht, index_a, index_b)
        end 
    elseif head == 'Have' then 
        hook[name] = function (ht, index_a, index_b)
            if index_a == trigger_button_hash then index_a = real_trigger_name_hash end 
            return get_frame_attr(index_a, index_b) or _G[name](ht, index_a, index_b)
        end 
    elseif head == 'Remo' then 
        hook[name] = function (ht, index_a, index_b)
            if index_a == trigger_button_hash then index_a = real_trigger_name_hash end 
            return _G[name](ht, index_a, index_b)
        end 
    end
end 

hook['FlushChildHashtable'] = function (ht, index_a, index_b)
    if index_a == trigger_button_hash then index_a = real_trigger_name_hash end 
    return FlushChildHashtable(ht, index_a, index_b)
end 



---------------绑定按钮事件 到 网易同步数据的触发事件里-----------------------
--异步事件
local frame_event_map = {}
--同步事件
local sync_event_map = {}

local trigger_player 

function hook.GetTriggerPlayer()
    return trigger_player or GetTriggerPlayer()
end 

function hook.GetTriggerPlayer()
    return trigger_player or GetTriggerPlayer()
end 

local DzGetTriggerSyncPlayer = japi.DzGetTriggerSyncPlayer
function hook.DzGetTriggerSyncPlayer()
    return trigger_player or DzGetTriggerSyncPlayer()
end 

local DzGetTriggerUIEventPlayer = japi.DzGetTriggerUIEventPlayer
function hook.DzGetTriggerSyncPlayer()
    return trigger_player or DzGetTriggerUIEventPlayer()
end 

function hook.DestroyTrigger(handle)
    for event_name, list in pairs(sync_event_map) do 
        for i = #list, 1, -1 do 
            local h = list[i]
            if h == handle then 
                table.remove(list, i)
            end 
        end 
    end 
    DestroyTrigger(handle)
end 


local DzTriggerRegisterSyncData = japi.DzTriggerRegisterSyncData

function hook.DzTriggerRegisterSyncData(trg, str, bool)
    local list = sync_event_map[str]
    if list == nil then 
        list = {}
        sync_event_map[str] = list 
    end 
    table.insert(list, trg)
    return DzTriggerRegisterSyncData(trg, str, bool)
end 


local DzFrameSetScriptByCode = japi.DzFrameSetScriptByCode
function hook.DzFrameSetScriptByCode(frame, event_id, code, sync)
    if frame == 0 then 
        if sync == false then 
            local list = frame_event_map[event_id]
            if list == nil then 
                list = {}
                frame_event_map[event_id] = list 
            end 
            table.insert(list, japi.get_code_name(code))
        end 
        return 
    end 
    DzFrameSetScriptByCode(frame, event_id, code, sync)
end 



local sync_event_name_map = {
    ['当左键点击按钮'] = 'on_sync_button_clicked',
    --['当左键按下按钮'] = 'on_sync_button_mousedown',
    --['当左键弹起按钮'] = 'on_sync_button_mouseup',

    ['当右键点击按钮'] = 'on_sync_button_right_clicked',
    --['当右键按下按钮'] = 'on_sync_button_right_mousedown',
    --['当右键弹起按钮'] = 'on_sync_button_right_mouseup',

    --['当按钮进入'] = 'on_sync_button_mouse_enter',
    --['当按钮离开'] = 'on_sync_button_mouse_leave',
 
}


for name, func_name in pairs(sync_event_name_map) do 
    
    ac.game:event('ui:' .. func_name)(function (_, player, button)
        
        local trg_list = sync_event_map[name]
        if trg_list == nil then 
            return 
        end 
        trigger_player = player.handle 

        real_trigger_name_hash = StringHash(button.name)
        for index, trg_handle in ipairs(trg_list) do 
            ConditionalTriggerExecute(trg_handle)
        end 

        trigger_player = nil
        real_trigger_name_hash = 0
    end)
end 



    --[[
PRESSED = 1,
MOUSE_ENTER = 2,
FOCUS_ENTER = 2,
FOCUS_LEAVE = 3,
MOUSE_LEAVE = 3,
MOUSE_UP = 4,
MOUSE_DOWN = 5,
MOUSE_WHEEL = 6,
CHECKBOX_CHECKED = 7,
CHECKBOX_UNCHECKED = 8,
EDITBOX_TEXT_CHANGED = 9,
POPUPMENU_ITEM_CHANGE_START = 10,
POPUPMENU_ITEM_CHANGED = 11,
MOUSE_DOUBLECLICK = 12,
SPRITE_ANIM_UPDATE = 13,
]]
local frame_sync_event_name_map = {
    ['on_button_clicked'] = 1,
    ['on_button_mouseup'] = 4,
    ['on_button_mousedown'] = 5,
    ['on_button_double_clicked'] = 12,
    ['on_button_right_clicked'] = 1,
    ['on_button_right_mouseup'] = 4,
    ['on_button_right_mousedown'] = 5,
    ['on_button_mouse_enter'] = 2,
    ['on_button_mouse_leave'] = 3,
}

local function frame_callback(frame, frame_event_name)
    local id = frame_sync_event_name_map[frame_event_name]
    if id == nil then 
        return 
    end 

    local list = frame_event_map[id]
    if list == nil then 
        return 
    end 

    trigger_player = ac.player.self.handle

    real_trigger_name_hash = StringHash(frame.name)
    for index, code_name in ipairs(list) do 
        japi.ExExecuteFunc(code_name)
    end 
    trigger_player = nil
    real_trigger_name_hash = 0
end 

--注册空事件
tool.register_nil_event = function (frame)
    for name, func_name in pairs(sync_event_name_map) do 
        frame[func_name] = function (self, ...)
        end
    end 
    for frame_event_name in pairs(frame_sync_event_name_map) do 
        local old = frame[frame_event_name]
        frame[frame_event_name] = function (self, button)
            button = button or self
            frame_callback(button, frame_event_name)
            if old then 
                old(self, button)
            end
        end
    end 
    

    local old_on_button_mouse_enter = frame[frame_event_name]

    function frame:on_button_mouse_enter(button)
        button = button or self
        local title = button.title_str 
        local tip = button.tip_str 
        if title and tip and title:len() > 0 and tip:len() > 0 then 
            button:tooltip(title, tip, 'top')
        elseif title and title:len() > 0 then 
            button:only_tip(title)
        elseif tip and tip:len() > 0 then 
            button:only_tip(tip)
        end 
        frame_callback(button, 'on_button_mouse_enter')
        if old_on_button_mouse_enter then 
            old_on_button_mouse_enter(self, button)
        end
    end
end 