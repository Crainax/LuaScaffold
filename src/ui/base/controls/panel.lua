-- Adapted from the pinned official UI; see docs/UI适配记录.md.
local _ENV = require 'scaffold.ui_env'
require 'ui.base.controls.class'

local num = 0
function level_sortpairs(t)
    local mt
    local func
    local sort = {}
    for k, v in pairs(t) do
        sort[#sort+1] = {k, v}
    end
    table.sort(sort, function (a, b)
        local a_level = 0
        local b_level = 0
        if type(a[2]) == 'table' then 
            a_level = a[2].level or 0
        end 

        if type(b[2]) == 'table' then 
            b_level = b[2].level or 0
        end 
        return a_level < b_level
    end)
    local n = 1
    return function()
        local v = sort[n]
        if not v then
            return
        end
        n = n + 1
        return v[1], v[2]
    end
end

class.panel = extends(class.ui_base){
--static
    panel_map = {}, --存放所有存活的panel 对象

--public
    normal_image = '', --图像背景

    is_scroll = false, -- 是否是滚动面板

    scroll_y = 0, --滚动面板的y轴d

--private
    _type  = 'panel', --fdf 中的模板类型

    _base  = 'BACKDROP', --fdf 中的控件类型


    --构造器
    builder = function (control_class, param)
        --创建实例对象
        local control = class.ui_base.create(param.parent, param._type or control_class._type, 0, 0, 32, 32)
        control.type = control_class._type
        --设置元方法
        for name, meta_method in pairs(control_class) do 
            if name:sub(1, 2) == '__' then 
                control[name] = meta_method
            end 
        end 
        --实例对象绑定控件类
        control.__index = control_class

        for name, value in pairs(param) do 
            control[name] = value
        end 
        local parent = param.parent
        if parent then 
            if param.w == nil then  control.w = parent.w  end 
            if param.h == nil then  control.h = parent.h  end 
        end 
        
        local object = control:build()

        if object == nil then 
            return 
        end 
        if parent then 
            table.insert(parent.children, object)
        end 
    
        for name, value in level_sortpairs(param) do 
         
            if name ~= 'parent' and type(value) == 'table' and value.type then 
                local child_class = rawget(class, value.type)
                if child_class then 
                    value.parent = object
                    object[name] = child_class:builder(value)
                end 
            end 
        end 
        return object
    end,


    --构造
    build = function (self)
       
        if self.parent then 
            self.parent_id =  self.parent._id
        end 

        self._id = japi.CreateFrameByTagName( self._base, self._name, self.parent_id, self._type,0)

        if self._id == nil or self._id == 0 then 
            class.ui_base.destroy(self)
            log.error('创建背景失败')
            return 
        end
   
        self.panel_map[self._id] = self
        self:reset()
        if self.is_scroll and self.not_scroll_button == nil then 
            --添加一个滚动条
            self:add_scroll_button()
        end 
        return self
    end,

    reset = function (self)
        self.scroll_y = 0
        self:init()
        if rawget(self, 'normal_image') or self._type == class.panel._type then 
            self:update_normal_image()
        end 
    end,

    set_parent = function (self, parent, last_count, stack)

        if stack == nil then
            stack = 0
        end

        local panel = self._panel 

        local old_panel_id
        if panel then 
            local old_parent = panel.parent 
            if old_parent and old_parent ~= parent then
                for index, child in ipairs(old_parent.children) do 
                    if child == panel then 
                        table.remove(old_parent.children, index)
                        break 
                    end 
                end 
                if parent then 
                    table.insert(parent.children, panel)
                end
            end 

            local parent_id = class.ui_base.parent_id
            if parent then 
                parent_id =  parent._id
            end 
            num = num + 1
            local name = '_frame_' .. tostring(num)
            local new_id = japi.CreateFrameByTagName( panel._base, name, parent_id, panel._type, 0)
            old_panel_id = panel._id 
            panel._id = new_id
            panel._name = name
            panel.parent = parent
            local map = panel[panel.type .. '_map']
            if map then 
                map[old_panel_id] = nil 
                map[new_id] = panel 
            end 
            
            panel:reset()
        end

        local old_parent = self.parent 
        if old_parent and old_parent ~= parent then
            for index, child in ipairs(old_parent.children) do 
                if child == self then 
                    table.remove(old_parent.children, index)
                    break 
                end 
            end 
            if parent then 
                table.insert(parent.children, self)
            end
        end 

        self.parent = parent

        local parent_id = class.ui_base.parent_id
        if parent then 
            parent_id =  parent._id
        end
        num = num + 1
        local name = '_frame_' .. tostring(num)
        local new_id = japi.CreateFrameByTagName( self._base, name, panel and panel._id or parent_id, self._type, 0)
        local old_id = self._id 
        self._id = new_id
        self._name = name
        local map = self[self.type .. '_map']
        if map then 
            map[old_id] = nil 
            map[new_id] = self 
        end 

        for index, child in ipairs(self.children) do 
            if (child._panel) --所有2层叠加的控件
            or (child._panel == nil and child._control == nil) then --单层的控件 
                child:set_parent(self, index, stack + 1)
            end
        end
        self:reset()

        japi.DestroyFrame(old_id)
       
        if old_panel_id then
            japi.DestroyFrame(old_panel_id)
        end
    end,

    new = function(parent,image_path,x,y,width,height,scroll)
        local control = class.panel:builder
        {
            parent = parent,
            normal_image = image_path,
            x = x,
            y = y,
            w = width,
            h = height,
            is_scroll = scroll,
        }
        return control
    end,

    destroy = function (self)
        if self._id == nil or self._id == 0 then 
            return 
        end

        self.panel_map[self._id] = nil 

        class.ui_base.destroy(self)
    end,

    add = function (self,class,...)
        return class.add_child(self,...)
    end,

    add_effect = function (self, index)
        if self._effect then 
            return self._effect
        end 

        local w, h = self.w, self.h 

        local scale_x = 1 / 94 * w 
        local scale_y = 1 / 70 * h 

        local effect = class.model:builder {
            parent = self,
            type = 'model',
            model = index == 1 and [[UI\Buttons\HeroLevel\HeroLevel.mdx]] or [[UI\Feedback\Autocast\UI-ModalButtonOn.mdl]],
            w = w,
            h = h,
            scale_x = scale_x,
            scale_y = scale_y,
        }

        self._effect = effect
    end,

    clear_effect = function (self)
        if self._effect then 
            self._effect:destroy()
            self._effect = nil 
        end 
    end,

    update_effect_size = function (self)
        local effect = self._effect 
        if effect == nil then 
            return 
        end 

        local w, h = self.w, self.h 

        local scale_x = 1 / 94 * w 
        local scale_y = 1 / 70 * h 

        effect:set_scale(scale_x, scale_y, 1)
    end,

     --添加一个可以拖动的标题 来拖动整个界面
    add_title_button = function (self,image_path,title,x,y,width,height,font_size)
        local button = self:add_button(image_path,x,y,width,height)
        button.text = button:add_text(title,0,0,width,height,font_size,4)
        button.message_stop = true
        button:set_enable_drag(true)

        --移动
        button.on_button_update_drag = function (self,icon_button,x,y)
            icon_button:set_control_size(0,0)
            self.parent:set_position(x,y)
            return false 
        end
        return button
    end,

    --添加一个关闭按钮 点击即可关闭
    add_close_button = function (self,x,y,width,height)
        width = width or 36
        height = height or 36
        x = x or self.w - width * 1.5
        y = y or 14

        local button = self:add_button('image\\背包\\bar_CloseButton_normal.tga',x,y,width,height)

        --左键按下 修改图片
        button.on_button_mousedown = function (self)
            self:set_normal_image('image\\背包\\bar_CloseButton_Press.tga')
            return false
        end

        --左键弹起 恢复图片
        button.on_button_mouseup = function (self)
            self:set_normal_image('image\\背包\\bar_CloseButton_normal.tga')
            return false
        end

        --按钮点击关闭
        button.on_button_clicked = function (self)
            class.ui_base.remove_tooltip()
            self.parent:hide()
            return false 
        end 
        --按钮文本提示
        button.on_button_mouse_enter = function (self)
            class.ui_base.set_tooltip(self,"关闭",0,0,240,64,16) 
            return false 
        end 
        return button
    end,

    set_scroll_y = function (self,y)
        local max_y = self:get_child_max_y()
        local overflow = math.max(0, max_y - self.h)
        y = math.max(0, math.min(y, overflow))

        self.scroll_y = y
        --滚动的时候刷新UI所有子控件位置
        for key,control in pairs(self.children) do
            if not control.is_scroll_button then  
                control.parent_max_y = max_y
                control:set_position(control.x,control.y)
            end 
        end 
        local value = overflow > 0 and y / overflow or 0
        local button = self.scroll_button
        if button then 
            button:set_position( button.x,value * (self.h - button.h))
        end

    end,

    --添加一个滚动条
    add_scroll_button = function (self)

        local path = 'core\\button.blp'
        local button = self:add_button(path,self.w - 16,0,16,64)

        button.message_stop = true
        button.is_scroll_button = true 
        button._panel.is_scroll_button = true
        button:set_enable_drag(true)

        local clock = os.clock()
        --移动
        button.on_button_update_drag = function (self,icon_button,x,y)
            if os.clock() - clock < 0.03 then return false end 
            clock = os.clock()
            local px,py = self.parent:get_real_position()
            local oy = self.y
            y = y - py
            
            if y + self.h > self.parent.h then 
                y = self.parent.h - self.h
            elseif y < 0 then
                y = 0
            end 
            icon_button:set_control_size(1,1)
            self:set_position(self.x,y)


            local travel = math.max(0, self.parent.h - self.h)
            local value = travel > 0 and math.min(1, y / travel) or 0
            local sy = value * (self.parent:get_child_max_y() - self.h)
            
            self.parent:set_scroll_y(sy)
            return false 
        end
        self.scroll_button = button 
    end,

    set_control_size = function (self,width,height)
        class.ui_base.set_control_size(self,width,height)
        self:update_effect_size()
    end,


    --当鼠标滚动面板事件
    on_panel_scroll_fix = function (self)
        self:set_scroll_y(self.scroll_y)
    end,

    --[[
    --面板滚动事件 bool 
    on_panel_scroll = function (self,bool)

    end,

    ]]

    __tostring = function (self)
        local str = string.format('面板 %d',self._id or 0)
        return str
    end,

    child_builder = function (self, param)
        
        local class = class[param.type or ''] or self:get_this_class()
        if class then 
            param.parent = self 
            return class:builder(param)
        end 
    end,
}

