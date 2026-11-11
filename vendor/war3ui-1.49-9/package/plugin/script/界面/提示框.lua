
local japi = require 'jass.japi'

local tool = class.panel:builder
{
    _type = 'tooltip_backdrop',
    x = 1390,
    y = 400,
    w = 530,
    h = 400,
    level = 5,
    is_show = false,
    alpha = 0.9,

    icon = {
        type = 'texture',
        x = 15,
        y = 40,
        w = 18,
        h = 18,
        normal_image = 'xxx.blp',
        text = {
            type = 'text',
            x = 25,
            y = -2,
            w = 100,
            h = 24,
            font_size = 11,
            align = 'left',
            text = ''
        },
    },

    title = {
        type = 'text',
        x = 8,
        y = 6,
        text = '测试标题',
        align = 'topleft',
        font_size = 16,
    },

    tip = {
        type = 'text',
        x = 8,
        y = 60,
        align = 'auto_height',
        font_size = 12,
    }
}

local text_tool = class.panel:builder
{
    _type = 'tooltip_backdrop',
    x = 1390,
    y = 400,
    w = 530,
    h = 400,
    level = 5,
    is_show = false,
    alpha = 0.9,

    tip = {
        type = 'text',
        x = 8,
        y = 6,
        align = 'auto_height',
        font_size = 10,
    }
}

--隐藏时 将原生提示框恢复
function tool:hide()
    if self.timer then 
        self.timer:remove()
        self.timerr = nil
    end 
    class.panel.hide(self)
end 


local tools = {

    only_tip = function (self, tip, anchor, width)
        text_tool.tip:set_width(width or 530)
        text_tool.tip:set_text(tip)
        if anchor then 
            self:set_tooltip_follow(text_tool, anchor)
        else 
            local x, y = 1390, 780 - text_tool.h 
            text_tool:set_position(x, y)
        end 
        text_tool:show()
    end,

    tooltip = function (self, title, tip, anchor, width)

        tool.tip:set_width(width or 530)
        
        tool.icon:hide()
        tool.title:set_text(title)
        tool.tip:set_text(tip)
        if anchor then 
            self:set_tooltip_follow(tool, anchor)
        else 
            local x, y = 1390, 780 - tool.h 
            tool:set_position(x, y)
        end 
        tool:show()
    end,

    remove_tooltip = function ()
        text_tool:hide()
        tool:hide()
    end,
}

for name, func in pairs(tools) do 
    class.ui_base[name] = func
end 
