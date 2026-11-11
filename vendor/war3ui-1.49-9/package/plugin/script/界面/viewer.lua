local slk = require 'jass.slk'
local japi = require 'jass.japi'

class.viewer = extends(class.panel)
{
    new = function ()


        local panel = class.viewer:builder
        {
            _type = 'tooltip_backdrop',
            x = 350,
            y = 100,
            w = 1200,
            h = 690,

            bar = { --左侧图标栏
                type = 'panel',
                _type = 'tooltip_backdrop',
                x = 10,
                y = 10,
                w = 250,
                h = 670,
                is_scroll = true, --支持滚动
                --每次滚动的间距
                scroll_interval_y = 30, 
            },

            --中间的模型控件
            model = {
                type = 'model2',
                x = 260,
                y = 10,
                w = 1200 - 270,
                h = 670,
                model = [[]]
            },
        }

        panel.bar:set_view_port(true)
        panel.list = {}
        return panel 
    end,

    add_unit = function (self, id)
        local data = slk.unit[id]
        if data == nil then 
            return 
        end 

        local index = #self.list

        local icon = class.button:builder 
        {
            parent = self.bar,
            x = 10 + 120 * (index % 2),
            y = 10 + 110 * (math.floor(index / 2)),
            w = 100,
            h = 100,
            normal_image = data['Art'],
        }
        icon.index = index + 1
        icon.id = id 
        icon.data = data
        table.insert(self.list, icon)
    end,


    --当鼠标点击头像的时候
    on_button_clicked = function (self, icon)
        local data = icon.data 
        if data == nil then 
            return 
        end 

        local color_id = os.time() % 15
        local path = data['File']
        
        local ext = path:sub(-4):lower()
        if ext ~= '.mdl' and ext ~= '.mdx' then 
            path = path .. '.mdx'
        end 

  
        local model = self.model 

        --设置人物模型
        model:set_model(path, color_id)

        if model.timer then 
            model.timer:remove()
        end 

        model.timer = ac.loop(33, function ()
            model:set_rotate_z(2)
        end)
     
        model:set_model_position(0, 0, -100)
        model:set_camera_source(200, 0, 100)
        model:set_camera_target(0, 0, 0)
        local time = model:play_animation('attack', '')



        local effect = model:add_effect("overhead", [[Abilities\Spells\Human\InnerFire\InnerFireTarget.mdl]])

        ac.wait(2 * 1000, function ()
            model:remove_effect(effect)
        end)
    
        local effect2 = model:add_effect("left hand", [[Abilities\Spells\Human\InnerFire\InnerFireTarget.mdl]])
    
        ac.wait(4 * 1000, function ()
            model:remove_effect(effect2)
        end)
    
        local effect3 = model:add_effect("right hand", [[Abilities\Spells\Human\InnerFire\InnerFireTarget.mdl]])
    
        ac.wait(6 * 1000, function ()
            model:remove_effect(effect3)
        end)
        
  
    end,
}




local viewer = class.viewer.new()
for id, data in pairs(slk.unit) do
    viewer:add_unit(id)
end 