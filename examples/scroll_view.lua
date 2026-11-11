-- Dev view with a continuous scroll viewport, nested clipping and a native model.
return function(ctx)
    local p=ctx:create('panel',{x=500,y=150,w=500,h=400,is_scroll=true,normal_image='core\\panel.blp'})
    for i=1,20 do
        ctx:create('text',{parent=p,x=20,y=(i-1)*45,w=430,h=40,text='Row '..i,font_size=16})
    end
    local nested=ctx:create('panel',{parent=p,x=250,y=500,w=160,h=100,clip_children=true})
    ctx:create('model',{parent=nested,x=0,y=30,w=160,h=160,model='Units\\Human\\Footman\\Footman.mdx'})
    local offset=0
    ctx:loop(20,function()
        offset=(offset+0.5)%500
        p:set_scroll_y(offset)
    end)
end
