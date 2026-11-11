local M = {}
function M.start(ui, bridge)
    local class = ui.class
    local panel = class.panel:builder {x = 320, y = 180, w = 460, h = 160,
        normal_image = 'core\\panel.blp'}
    local text = class.text:builder {parent = panel, x = 20, y = 15, w = 420, h = 50,
        text = 'LuaScaffold / InnerJAPI', font_size = 18}
    local button = class.button:builder {parent = panel, x = 25, y = 80, w = 60, h = 50,
        normal_image = 'core\\button.blp'}
    local test_mode, sent = require('app.config').runtime_test, false
    function button:on_button_clicked()
        if test_mode and sent then return end
        local ok = bridge:send('ping', 0, 0)
        if ok then sent = true end
    end
    M.panel, M.button, M.text = panel, button, text
    return panel
end
return M
