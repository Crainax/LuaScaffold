local M = {}
function M.run(ui, check)
    local c,japi,log=ui.class,require 'jass.japi',require 'jass.log'
    local baseline=ui.count()
    local p=c.panel:builder{x=100,y=100,w=240,h=120,is_scroll=true,not_scroll_button=true}
    local b=c.button:builder{parent=p,x=10,y=100,w=100,h=50}
    check(p._clip_children and b:point_in_rect(120,210) and not b:point_in_rect(120,230), 'viewport hit test excludes clipped region')
    p:set_scroll_y(17.25)
    local x,y=b:get_real_position()
    check(math.abs(y-182.75)<0.001, 'continuous fractional scroll position')
    check(b:point_in_rect(120,200) and not b:point_in_rect(120,230), 'scrolled hit test uses viewport')
    local nested=c.panel:builder{parent=p,x=10,y=30,w=120,h=60,clip_children=true}
    local nb=c.button:builder{parent=nested,x=5,y=50,w=50,h=30}
    local nx,ny=nb:get_real_position()
    check(nb:point_in_rect(nx+2,ny+2) and not nb:point_in_rect(nx+2,ny+15), 'nested clipping intersection')
    local model=c.model:builder{parent=p,x=10,y=150,w=80,h=80,model='Units\\Human\\Footman\\Footman.mdx'}
    p:set_scroll_y(80.5)
    check(model._id~=0, 'native model under viewport survives fractional scroll')
    local t
    p:destroy()
    local previous, first, index=0, nil, 0
    local sizes={8,16,16.5,32,64,128,256}
    local function next_size()
        index=index+1
        local size=sizes[index]
        if not size then
            log.info('[FONT_BOUNDARY] first='..first..' last='..previous..' ratio='..previous/first)
            check(t:get_text()=='Ag测试','font changes preserve Unicode text')
            t:destroy()
            check(ui.count()==baseline,'viewport/font probe releases controls')
            return
        end
        if t then t:destroy() end
        t=c.text:builder{x=400,y=50,w=1200,h=600,text='Ag测试',font_size=size}
        t:wait(50,function()
            require('scaffold.context').local_call(function()
                local width,height=t:get_width(),t:get_height()
                log.info(string.format('[FONT_PROBE] requested=%.2f width=%.4f height=%.4f',size,width,height))
                check(width>0 and height>0 and width<100000 and height<100000, 'native font metrics finite size='..size)
                if size<=128 then check(height>=previous, 'native font metrics nondecreasing size='..size) end
                first=first or height;previous=height
                next_size()
            end)
        end)
    end
    next_size()
end
return M
