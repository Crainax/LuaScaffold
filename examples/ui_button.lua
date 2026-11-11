-- Call after scaffold.ui.start(), once per match. Dispose through the returned function.
return function(bridge)
    local button = require('scaffold.ui').class.button:builder {
        x = 300, y = 300, w = 64, h = 64,
        normal_image = 'core\\button.blp',
        -- No sync_key: use the explicit bridge, avoiding duplicate dispatch.
    }
    function button:on_button_clicked()
        bridge:send('ping', 0, 0)
    end
    return function() button:destroy() end
end
