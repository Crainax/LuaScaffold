-- Adapted from the pinned official UI; see docs/UI适配记录.md.
local _ENV = require 'scaffold.ui_env'
require 'ui.base.controls.class'
require 'ui.base.controls.panel'
local edit_fpf = [[
    Frame "EDITBOX" "edit%d" {
        EditTextFrame "edit_text%d",
        Frame "TEXT" "edit_text%d" {
            LayerStyle "IGNORETRACKEVENTS",
            FrameFont "MasterFont", %f, "", 
        }
    }
]]

local edit_map = {}

local function load_edit(fpf,size)
    if edit_map[size] ~= nil then 
        return 
    end
    size = math.modf(size)
    edit_map[size] = 1
    local data = string.format(fpf,size,size,size,size/1000)
    load_fdf(data)
end


class.edit = extends(class.panel){

    --文本框 类型 和 基类
    _type   = 'edit',
    _base   = 'EDITBOX',

    edit_map = {},

    font_size = 18,

    text = 'edit',

    build = function (self)

        local panel = class.panel:builder 
        {
            _type = self._panel_type,
            parent = self.parent,
            w = self.w,
            h = self.h
        }

        if panel == nil then 
            log.error('文本框背景创建失败')
            return
        end
        panel._control = self
        self._panel = panel
        load_edit(edit_fpf,self.font_size)
        self._type = string.format('%s%d',self._type,self.font_size)
        self._id = japi.CreateFrameByTagName( self._base, self._name, panel._id, self._type,0)
        if self._id == nil or self._id == 0 then 
            panel:destroy()
            class.ui_base.destroy(self)
            log.error('创建文本框失败')
            return 
        end
        japi.RegisterFrameEvent(self._id)

        self.edit_map[self._id] = self
 
        self:reset()
        return self
    end,


    reset = function (self)
        self:init()
        self:set_text(self.text)
    end,

    new = function (parent, text, x, y, width, height, font_size)
        local control = class.edit:builder
        {
            parent = parent,
            text = text,
            x = x,
            y = y,
            w = width,
            h = height,
            font_size = font_size or 16, 
        }
        return control
    end,

    destroy = function (self)
        if self._id == nil or self._id == 0 then 
            return 
        end
        self._panel:destroy()

        self.edit_map[self._id] = nil 

        class.ui_base.destroy(self)
    end,

    set_text = function (self,text)
        self.text = text
        japi.FrameSetText(self._id,text)
    end,

    get_text = function (self)
        return japi.FrameGetText(self._id)
    end,

    set_focus = function(self, enabled)
        -- Native frame focus only; do not synthesize keyboard or mouse messages.
        japi.FrameSetFocus(self._id, enabled)
    end,

    set_control_size = function (self,width,height)
        class.ui_base.set_control_size(self,width,height)
        self._panel:set_control_size(width,height)
    end,

    set_position = function (self,x,y)
        class.ui_base.set_position(self,x,y)
        self._panel:set_position(x,y)
    end,

    set_level = function (self, level)
        class.panel.set_level(self,level)
        self._panel:set_level(level)
    end,


    __tostring = function (self)
        local str = string.format('文本框 %d',self._id or 0)
        return str
    end


    --[[
    on_edit_text_changed = function (self,new_str,old_str)

    end,

    ]]
    
    
}
