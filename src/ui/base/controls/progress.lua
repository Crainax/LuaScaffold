-- Adapted from the pinned official UI; see docs/UI适配记录.md.
local _ENV = require 'scaffold.ui_env'
require 'ui.base.controls.model'



class.progress = extends(class.model){

    offset_x = 0,

    offset_y = 0,
    
    build = function (self)
        class.model.build(self)

        self._texture = self:add_texture(self.background, self.offset_x, self.offset_y, self.w, self.h)
        self._text = self:add_text('', self.offset_x, self.offset_y, self.w, self.h, self.font_size, self.font_alien)
        self:set_animation(0,true)

        self.rate = 0
        self:clear()
        return self
    end,

    new = function (parent,path,x,y,width,height,font_size,font_alien,background)
        local param
        if type(path) == 'table' then 
            param = path 
            path = param.path 
        else 
            param = {}
        end 
        local control = class.progress:builder
        {
            parent = parent,
            model = path,
            x = x or param.x or 0,
            y = y or param.y or 0,
            w = width or param.w or 0,
            h = height or param.h or 0,
            font_size = font_size or param.font_size or 10,
            font_alien = font_alien or param.font_alien or 'center',
            background = background or param.background or 'core\\black_icon.tga',
        }

        return control 
    end,

    destroy = function (self)
        if self._id == nil or self._id == 0 then 
            return 
        end

        self._texture:destroy()
        self._text:destroy()
        class.model.destroy(self)
    end,

    set_value = function (self,value,max_value)
        local rate
        if max_value == 0 then 
            rate = 0 
        else 
            rate = value / max_value 
        end 
		local str = string.format('%.0f / %.0f (%.0f%%)',value,max_value, rate * 100 )
        self._text:set_text(str)
        self.rate = rate 
        if rate >= 1 then rate = 0.9999 end 
        if rate <= 0 then 
            rate = 0.0001
        end 

        local width = self.w * rate
        self._texture:set_position(width + self.offset_x,self.offset_y)
		self._texture:set_control_size(self.w - width ,self.h)
    end,

    clear = function (self)
        self._text:set_text('')
        self._texture:set_position(self.offset_x,self.offset_y)
		self._texture:set_control_size(self.w,self.h)
    end,

    __tostring = function (self)
        local str = string.format('进度条 %d',self._id or 0)
        return str
    end
}

