-- Copy to GAME/LuaScaffold-dev/view.lua after building with --dev.
-- Each edit builds a new view. Only ctx.state (plain data) survives a successful replacement.
return function(ctx)
    ctx.state.loads=(ctx.state.loads or 0)+1
    local panel=ctx:create('panel',{x=500,y=200,w=500,h=250,normal_image='core\\panel.blp',clip_children=true})
    ctx:create('text',{parent=panel,x=20,y=20,w=450,h=50,text='Development view '..ctx.state.loads,font_size=16})
    local button=ctx:create('button',{parent=panel,x=20,y=90,w=120,h=40,normal_image='core\\button.blp'})
    function button:on_button_clicked() ctx:send('ping',0,0) end
end
