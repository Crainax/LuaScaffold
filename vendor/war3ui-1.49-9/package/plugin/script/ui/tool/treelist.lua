local tool = require 'ui.tool.tool'

local base_count = 0

class.tree_list = extends(class.button)
{
    new = function (parent, x, y, w, h)
        local list = class.tree_list:builder 
        {
            parent = parent,
            _panel_type = 'tooltip_backdrop',
            x = x, 
            y = y,
            w = w,
            h = 42,
            flag = false,
            msg = 1,
            alpha = 0.8,
            state = {
                type = 'text',
                _panel_type = 'tooltip_backdrop',
                text = '+',
                x = 0,
                y = 0,
                w = 42,
                h = 42,
                font_size = 16,
                align = 'center',
            },

            icon = {
                type = 'texture',
                x = 52,
                y = 8,
                w = 24,
                h = 24,
                normal_image = 'xx.blp',
            },

            text = {
                type = 'text',
                x = 82,

                text = '标题',
                align = 'left',
                font_size = 12,
            },
            bar = {
                type = 'panel',
                _type = 'tooltip_backdrop',
                x = 42,
                y = 42,
                h = 42,
                w = w - 42,
                is_show = false,
                is_scroll = true,
                not_scroll_button = true,
            }
        }

        --list.bar.scroll_button:destroy()
--
        --local set_parent = list.bar.set_parent
        --function list.bar:set_parent(parent)
        --    set_parent(self, parent)
        --end
        
        list:set_enable_drag(true)
      

        list:set_state(true)
        return list
    end,

    sort = function (self)
        local root = self:get_root_control()

        local max_stack = 0
        local function sort_x(object)
            for index, child in ipairs(object.bar.children) do 
                if child.msg then
                    sort_x(child)
                end
            end 

            if object.parent then 
                object:set_position(0, object.y)
            end
        end 

        local function sort_y(object, last_count, stack, this_index)
            stack = stack or 0

            if stack > max_stack then 
                max_stack = stack 
            end 

            local s = '类型'
            if tool.control_map then
                local control = tool.control_map[object.num or 0]
                if control then
                    local name = '' 
                    if control.parent then 
                        name = control.parent.name or ''
                    end 
                    s = tool.type_to_name(control.type) or control.type
                    object.icon:set_normal_image(control.normal_image)
                    control:set_name(name .. s .. '_' .. (this_index or 0))
                    control.index = this_index
                end
            end
            object.text:set_text(s .. '_' .. (this_index or 0))
            if object.parent and object.parent.parent.bar.is_show ~= true then 
                return 0
            end
           
            local count = 0
            local i = 0
            for index, child in ipairs(object.bar.children) do 
                if child.msg then
                    count = count + 1
                    i = i + 1
                    if child.bar.is_show or #child.bar.children == base_count then 
                        count = count + sort_y(child, count, stack + 1, i)
                    else 
                        sort_y(child, count, stack + 1, i)
                    end
                end
            end 

            local max_width = object.w + 42 * (max_stack - stack - 1) + 16 * (stack)
            local max_height = math.min(500, count * 42)
           
            object.bar:set_control_size(max_width, max_height)

            --local scroll = object.bar.scroll_button
            --scroll:set_position(max_width, scroll.y)
            if object.parent and last_count then 
                object:set_position(0, (last_count - 1) * 42)
            end 

            return count
        end 
        sort_x(root)
        sort_y(root)
    end,
    
    add_child_tree = function (self)
        local bar = self.bar 
        local result = bar:add(class.tree_list, 0, bar:get_child_max_y(true), self.w, self.h)

        self:set_state(true)

        return result
    end,

    set_state = function (self, show)
        self.flag = show

        local function state(object)

            local is_show = object.is_show
            object:hide()
            if object then 
                object:show()
            end
            if object.msg then 
                for index, child in ipairs(object.bar.children) do 
                    if child.msg and #child.bar.children == base_count then 
                        child.state:hide()
                        child.bar:hide()
                    else 
                        state(child)
                    end
                end 
            end
        end 

        state(self)

        if #self.bar.children > base_count then 
            self.state:show()
            if show then 
                self.state:set_text('-')
                self.bar:show()
            else 
                self.state:set_text('+')
                self.bar:hide()
            end 
        else 
            self.state:hide()
            self.bar:hide()
        end

        
        self:sort()
        
    end,


    on_button_begin_drag = function (self)
        self.clock = os.clock()
        return false
    end,

    on_button_update_drag = function (self, icon_button,x,y)

        local mx,my = game.get_mouse_pos()
        if icon_button.type ~= 'button' then 
            --icon_button:set_control_size(0,0)
            local parent = self.parent
            if parent then 
                if self.clock and os.clock() - self.clock > 0.2 then
                    local root = self:get_root_control()
                    local minx, miny, maxx, maxy = root.x, root.y, root.x + root.w, root.y + root.h
                    self:set_real_position(x,y)
                end
            elseif not self.state:point_in_rect(mx, my) then
                self:set_real_position(x, y)
            end
        end
        
        return false 
    end,

    on_button_drag_and_drop = function (self, target)
        local parent = self.parent 

        if parent and target == parent then 

            return 
        end 
        if parent and target and target.msg then 

            local bar = target.bar 
            self:set_parent(bar)

            local button = parent.parent 
            if button then 
                button:set_state(true)
            end
            target:set_state(true)
        end 
        
        self:sort()
        return false
    end,

    on_button_clicked = function (self, button)
        local x, y = game.get_mouse_pos()
        if button == nil and self.state:point_in_rect(x, y) then 
            self:set_state(not(self.flag))
            return
        end

        local num = self.num 
        if num then 
            local control = tool.control_map[num]
            if control then 
                tool.clear_select()
                tool.add_select_control(control)
            end
        end

        return false
    end,

    on_button_mouse_enter = function (self)
        local num = self.num 
        if num then 
            local control = tool.control_map[num]
            if control then 
                control.button:event_callback('on_button_mouse_enter')
            end
        end
        return false
    end,

    on_button_mouse_leave = function (self)
        local num = self.num 
        if num then 
            local control = tool.control_map[num]
            if control then 
                control.button:event_callback('on_button_mouse_leave')
            end
        end
        return false
    end,
}

local tree_list = class.tree_list.create(20, 80, 200, 42)

return tree_list
