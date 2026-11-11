local tool = {}



tool.config_info = {
    ['default'] = {
        {'name', 'string', '名字', function (self, name)
            self:set_name(name)
        end, '在触发器里 可以用 文件名_控件名 来操作控件'},
        
        {'x', 'number', 'X轴', function (self, x)
            local _, y = self:get_real_position()
            self:set_real_position(x, y)
        end, 'x轴坐标 屏幕左上角0, 0 右下角 1920, 1080'},

        {'y', 'number', 'Y轴', function (self, y)
            local x = self:get_real_position()
            self:set_real_position(x, y)
        end, 'y轴坐标 屏幕左上角0, 0 右下角 1920, 1080'},

        {'w', 'number', '宽度', function (self, w)
            self:set_control_size(w, self.h)
        end},

        {'h', 'number', '高度', function (self, h)
            self:set_control_size(self.w, h)
        end},

        {'normal_image', 'string', '背景图像', function (self, normal_image)
            self:set_normal_image(normal_image)
        end},

        {'alpha', 'number', '透明通道', function (self, alpha)
            self:set_alpha(alpha)
        end, '透明通道 从 0 ~ 1 为百分比'},

        {'level', 'integer', '层级', function (self, level)
            self:set_level(level)
        end},

        {'is_show', 'boolean', '是否显示', function (self, bool)
            if bool then 
                self:show()
            else 
                self:hide()
            end 
        end, '填 true 或 false'},
    },

    ['panel'] = {
        {'is_scroll', 'boolean', '滚动条', function (self, bool)
            self.is_scroll = bool
            if bool then 
                --添加一个滚动条
                if self.scroll_button == nil then 
                    self:add_scroll_button()
                end
            else 
                if self.scroll_button then 
                    self.scroll_button:destroy()
                    self.scroll_button = nil 
                end
            end 
        end},

        {'_type', 'string', 'fdf模板', function (self, template_name)
            self.normal_image = nil
            self._type = template_name
            self:set_parent(self.parent)
        end,'填 fdf模板名字 用来做一些带边框的底图用的'},
    },

    ['text'] = {
        {'color', 'hex', '16进制颜色',function (self, color)
            self:set_color(color)
        end, '例如: ffffffff  分别是 ARGB'},


        {'text', 'string', '文本',function (self, text)
            self:set_text(text)
        end}, 

        {'align', 'integer', '对齐方式',function (self, align)
            self.align = align
            self:set_parent(self.parent)
            self:set_text(self.text)
        end, '分别是： 0 ~ 8 是 9个方向|n-1 是自动换行|n-2 是背景图自适应宽高|n-3 是背景图自适应宽|n-4 是背景图自适应高'}, 

        {'font_size', 'integer', '字体大小',function (self, font_size)
            self.font_size = font_size
            self:set_size(1)
        end, '字体的大小 填 1 ~ 20'},
    },

    ['button'] = {
        {'has_ani', 'boolean', '动态',function (self, bool)
            self.has_ani = bool
            if self.has_ani then 
                self:add_traceable_animation()
            else 
                self.on_button_mouse_enter = class.button.on_button_mouse_enter
                self.on_button_mouse_leave = class.button.on_button_mouse_leave
                self.on_button_mousedown = class.button.on_button_mousedown
                self.on_button_mouseup = class.button.on_button_mouseup
            end 
        end},

        {'is_enable', 'boolean', '是否禁用',function (self, bool)
            self:set_enable(bool)
        end, '是否禁用按钮 填  true 或者 false'},

        {'hover_image', 'string', '触碰图像', function (self, path)
            self:set_hover_image(path)
        end, '鼠标指向时的图像路径  单斜杠'}, 

        {'active_image', 'string', '点击图像', function (self, path)
            self:set_active_image(path)
        end, '鼠标按下时的图像路径 单斜杠'}, 

        {'title_str', 'string', '提示标题', function (self, str)
            self.title_str = str
        end, '鼠标指向时提示的文本标题'}, 

        {'tip_str', 'string', '提示文本', function (self, str)
            self.tip_str = str
        end, '鼠标指向时提示的文本内容'}, 
    },

    ['model'] = {
        {'model', 'string', '模型', function (self, path)
            self:set_model(path)
        end}, 

        {'size', 'number', '缩放', function (self, size)
            self:set_size(size)
        end}, 

        --{'scale_x', 'number', 'x轴缩放', function (self, size)
        --    self:set_scale(size, self.scale_y, self.scale_z)
        --end}, 
        --{'scale_y', 'number', 'y轴缩放', function (self, size)
        --    self:set_scale(self.scale_x, size, self.scale_z)
        --end}, 
        --{'scale_z', 'number', 'z轴缩放', function (self, size)
        --    self:set_scale(self.scale_x, self.scale_z, size)
        --end}, 

        {'offset_x', 'number', 'x轴偏移', function (self, value)
            self:set_model_offset(value, self.offset_y)
        end, '模型距离 控件的y偏移'}, 

        {'offset_y', 'number', 'y轴偏移', function (self, value)
            self:set_model_offset(self.offset_x, value)
        end, '模型距离 控件的y偏移'}, 
        

        {'rotate_x', 'number', 'x轴旋转', function (self, value)
            self:set_rotate_x(value)
        end}, 
        {'rotate_y', 'number', 'y轴旋转', function (self, value)
            self:set_rotate_y(value)
        end}, 
        {'rotate_z', 'number', 'z轴旋转', function (self, value)
            self:set_rotate_z(value)
        end}, 

        {'team_color', 'integer', '队伍颜色',function (self, index)
            self:set_team_color(index)
        end, '填队伍颜色 从 0 - 15 '},

        {'animation_index', 'integer', '动画索引',function (self, index)
            self:set_animation_by_index(index)
        end, '填动画的动作索引'},

        {'color', 'hex', '16进制颜色',function (self, color)
            self:set_color(color)
        end, '例如: ffffffff  分别是 ARGB'},
    },
}

tool.get_attr_map = {
    ['x'] = function (self)
        local x, y = self:get_real_position()

        return x
    end,

    ['y'] = function (self)
        local x, y = self:get_real_position()

        return y
    end,
}


tool.frame_tip_map = {
    ['panel'] = {'面板', '用来作为底板，可以在底板上面置放其他子控件。'},
    ['texture'] = {'图片', '用来显示图像用的控件，基本跟面板一样。'},
    ['text'] = {'文本', '用来显示静态文本的控件。'},
    ['edit'] = {'可编辑文本', '用来获取用户输入的文本的控件。'},
    ['button'] = {'按钮', '用来捕获鼠标相关事件的控件。'},
    ['model']  = {'模型', '用来显示一些mdlx的模型控件， 比如进度条 cd模型之类的。'},
}

tool.type_to_name = function (type)
    local info = tool.frame_tip_map[type]
    if info == nil then 
        return 
    end 

    return info[1]
end 



tool.str2value = function(str, tp)
    local value = str 

    if tp == 'number' then 
        value = tonumber(string.format('%.6f', tonumber(str) or 0))
    elseif tp == 'boolean' then 
        value = str == 'true'
    elseif tp == 'integer' then 
        value = math.floor(tonumber(str) or 0)
    elseif tp == 'hex' then 
        value = tonumber(str, 16)
    end 

    return value
end

tool.value2str = function(value, tp)
    local str = ''
    if tp == 'number' then 
        
        str = tostring(value)
    elseif tp == 'hex' then 
        local v = value 
        if type(v) == 'table' then 
            v = 255 * 0x1000000 + v.r * 0x10000 + v.g * 0x100 + v.b
        end 
        str = string.format("%x", v or 0)
    elseif tp == 'boolean' then 
        str = tostring(value == true)
    else 
        str = tostring(value or '') or ''
    end 

    return str
end



return tool