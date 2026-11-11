load_fdf [[
IncludeFile "UI\FrameDef\Glue\StandardTemplates.fdf",
IncludeFile "UI\FrameDef\Glue\BattleNetTemplates.fdf",

Frame "TEXTBUTTON" "ChooBlankButtonTemplatetA" {
    ControlStyle "AUTOTRACK",
}

//背景模板
Frame "BACKDROP" "panel" {
	BackdropBackground  "core\Transparent.tga",
	//BackdropBlendAll,
}
//背景模板
Frame "BACKDROP" "texture" {
	BackdropBackground  "core\Transparent.tga",
	//BackdropBlendAll,
}

//按钮模板
Frame "GLUETEXTBUTTON" "buttonAAA" {
  SetAllPoints,
}
//字
Frame "TEXT" "text" {
    LayerStyle "IGNORETRACKEVENTS",
    FrameFont "fonts.TTF", 10, "", 
}


Frame "SPRITE" "model" {
    LayerStyle "IGNORETRACKEVENTS",
    BackgroundArt "HeroShadowHunter2.mdx",
    //SetAllPoints,
}

Frame "TEXT" "old_text" {
    LayerStyle "IGNORETRACKEVENTS",
    FrameFont "MasterFont", 1, "", 
    FontJustificationH JUSTIFYCENTER,
    FontJustificationV JUSTIFYMIDDLE,
}


Frame "BACKDROP" "tooltip_backdrop" {
    UseActiveContext,
    BackdropTileBackground,
    BackdropBackground  "UI\Widgets\ToolTips\Human\human-tooltip-background.blp",
    BackdropCornerFlags "UL|UR|BL|BR|T|L|B|R",
    BackdropCornerSize  0.01,
    BackdropBackgroundInsets 0.001f 0.001f 0.001f 0.001f,
    BackdropEdgeFile  "UI\Widgets\ToolTips\Human\human-tooltip-border.blp",
}


Frame "BACKDROP" "tooltip_backdrop2" {
    BackdropTileBackground,
    BackdropBackgroundInsets 0.002 0.002 0.002 0.002,
    BackdropBackground "UI\Widgets\ToolTips\Human\human-tooltip-background.blp",
    BackdropCornerFlags "UL|UR|BL|BR|T|L|B|R",
    BackdropCornerSize  0.01,
    BackdropEdgeFile "UI\Widgets\BattleNet\bnet-dialoguebox-border.blp",
    BackdropBlendAll,
}

]]