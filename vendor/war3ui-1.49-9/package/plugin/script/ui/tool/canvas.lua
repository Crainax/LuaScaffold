local tool = require 'ui.tool.tool'

local canvas = class.panel:builder 
{
    x = 0,
    y = 0,
    w = 1920,
    h = 1080,

    controls = {
        type = 'panel',
        level = 1,
    },

    buttons = {
        type = 'panel',
    },
}


function canvas.buttons:on_button_mouse_enter(button)
    --button:set_alpha(1)
    button.texture:set_alpha(1) 

    tool.mouse_button = button
end

function canvas.buttons:on_button_mouse_leave(button)
    --button:set_alpha(0)
    button.texture:set_alpha(0) 
    tool.mouse_button = nil
end


return canvas