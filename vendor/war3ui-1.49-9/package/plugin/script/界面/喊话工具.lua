local storm = require 'jass.storm'
local ui = require 'ui.client.util'
local japi = require 'jass.japi'


class.cheat_object = extends(class.panel)
{
    new = function (parent, x, y, w, h)
        local panel = class.cheat_object:builder
        {
            parent = parent,
            x = x,
            y = y,
            w = w,
            h = h,

            normal_image = '',

            button_background = {
                type = 'panel',
                _type = 'tooltip_backdrop',

                w = 128,

                button = {
                    type = 'button',
                    hide_has_event = true,
                },

                text = {
                    type = 'text',
                    text = '使用',
                    align = 'center',
                    font_size = 12,
                }

            },

            edit_background = {
                type = 'panel',
                _type = 'tooltip_backdrop',
                x = 136,
                w = w - 136,

                edit = {
                    type = 'edit',
                    text = '',
                    x = 10,
                }
            }
        }

        return panel
    end,

    on_button_mouse_enter = function (self, button)
        button:tooltip('喊话工具', '鼠标点击 或 按下键盘快捷键可以输出指令|n右边可以编辑指令。', 'top')
    end,

    on_button_clicked = function (self, button)
        local info = {
            type = 'cheat',
            func_name = 'on_input',
            params = {
                self.edit_background.edit:get_text() or ''
            }
        }
        ui.send_message(info)
    end,

    on_button_key_down = function (self, button)
        --alt 是按下状态的
        if japi.GetKeyState(0x12) then 
            local info = {
                type = 'cheat',
                func_name = 'on_input',
                params = {
                    self.edit_background.edit:get_text() or ''
                }
            }
            ui.send_message(info)
        end
    end,
}

class.cheat_panel = extends(class.panel)
{
    create = function (count)

        local panel = class.cheat_panel:builder
        {
            _type = 'tooltip_backdrop',
            x = 1920 - 500,
            y = 110,
            w = 500,
            h = 400
        }


        local list = {}

        local x, y = 20, 10
        local w = panel.w - 40
        local h = 42

        for i = 1, 10 do 
            local child = panel:add(class.cheat_object, x, y, w, h)
            local button = child.button_background.button
            local text = child.button_background.text
            button.keys = {10 - i + 1}
            text:set_text('Alt + ' .. tostring(10 - i + 1))
            y = y + h + 10
            list[i] = child
        end 
        panel.list = list

        panel:set_control_size(panel.w, y)
        return panel
    end,



    set_list = function (self, list)
        for index, str in ipairs(list) do 
            local child = self.list[index]
            if child then 
                child.edit_background.edit:set_text(str)
            end     
        end 
    end,

    get_list = function (self)
        local s = {}

        for index, child in ipairs(self.list) do 
            local str = child.edit_background.edit:get_text()
            s[index] = str or ''
        end 
        return s
    end,

    load_cheat = function (self)
        local str = storm.load("ui\\cheat.txt")
        if str == nil then 
            return 
        end 
        local list = ui.decode(str)
        self:set_list(list)
    end,

    save_cheat = function (self)
        storm.save("ui\\cheat.txt", ui.encode(self:get_list()))
    end,


    on_edit_text_changed = function (self, edit, new_str, old_str)
        self:save_cheat()
    end,
}

local panel = class.cheat_panel.create(10)
panel:load_cheat()
panel:hide()

local button = class.button:builder
{
    x = 1790,
    y = panel.y + panel.h + 10,
    w = 64,
    h = 64,
    has_ani = true,
    normal_image = [[ReplaceableTextures\CommandButtons\BTNReplay-Loop.blp]],
}

function button:on_button_clicked()
    if panel.is_show then 
        panel:hide()
        self:set_normal_image([[ReplaceableTextures\CommandButtons\BTNReplay-SpeedUp.blp]])
    else 
        panel:show()
        self:set_normal_image([[ReplaceableTextures\CommandButtons\BTNReplay-Loop.blp]])
    end
end


local on_button_mouse_enter = button.on_button_mouse_enter
function button:on_button_mouse_enter()
    if on_button_mouse_enter then 
        on_button_mouse_enter(self)
    end
    self:tooltip('喊话工具', '点击显示或隐藏喊话工具|n 正式版里不会出现', 'left', 300)
end 



ac.game:event '玩家-聊天' (function(trg, player, str, is_local)
    if is_local then 
        return 
    end 

    if player:is_self() ~= true then 
        return 
    end 


    if str:sub(1, 1) == '-' then 
 
        local list = panel:get_list()
        for index, s in ipairs(list) do 
            if s == str then 
                return 
            end
        end 
        table.insert(list, str)
        if #list > #panel.list then 
            table.remove(list, 1)
        end 
        panel:set_list(list)
        panel:save_cheat()
    end 
end)


local server = require 'ui.server.util'

local event = {
    on_input = function (str)
        local player = server.player
        japi.EXDisplayChat(player.handle, 1, str)
        player:event_notify('玩家-聊天', player, str, true)
    end,
}

server.register_event('cheat', event)