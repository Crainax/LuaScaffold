globals
// @placements:globals:begin
unit gg_unit_n001_0000 = null
rect gg_rct_training_arena = null
// @placements:globals:end
endglobals
// Minimal boot glue for classic Warcraft. Business logic stays in Lua.
// Include this function in generated war3map.j and call once from main,
// before application handles are created. Do not combine with another Lua boot.
// Fixed InnerJAPI boot; validated by the project runtime suites.
// @scaffold:boot-definition

function InitCustomPlayerSlots takes nothing returns nothing
call SetPlayerStartLocation(Player(0),0)
call ForcePlayerStartLocation(Player(0),0)
call SetPlayerColor(Player(0),ConvertPlayerColor(0))
call SetPlayerRacePreference(Player(0),RACE_PREF_HUMAN)
call SetPlayerRaceSelectable(Player(0),false)
call SetPlayerController(Player(0),MAP_CONTROL_USER)
call SetPlayerStartLocation(Player(1),1)
call ForcePlayerStartLocation(Player(1),1)
call SetPlayerColor(Player(1),ConvertPlayerColor(1))
call SetPlayerRacePreference(Player(1),RACE_PREF_HUMAN)
call SetPlayerRaceSelectable(Player(1),false)
call SetPlayerController(Player(1),MAP_CONTROL_USER)
call SetPlayerStartLocation(Player(2),2)
call ForcePlayerStartLocation(Player(2),2)
call SetPlayerColor(Player(2),ConvertPlayerColor(2))
call SetPlayerRacePreference(Player(2),RACE_PREF_HUMAN)
call SetPlayerRaceSelectable(Player(2),false)
call SetPlayerController(Player(2),MAP_CONTROL_USER)
call SetPlayerStartLocation(Player(3),3)
call ForcePlayerStartLocation(Player(3),3)
call SetPlayerColor(Player(3),ConvertPlayerColor(3))
call SetPlayerRacePreference(Player(3),RACE_PREF_HUMAN)
call SetPlayerRaceSelectable(Player(3),false)
call SetPlayerController(Player(3),MAP_CONTROL_USER)
call SetPlayerStartLocation(Player(4),4)
call ForcePlayerStartLocation(Player(4),4)
call SetPlayerColor(Player(4),ConvertPlayerColor(4))
call SetPlayerRacePreference(Player(4),RACE_PREF_HUMAN)
call SetPlayerRaceSelectable(Player(4),false)
call SetPlayerController(Player(4),MAP_CONTROL_USER)
call SetPlayerStartLocation(Player(5),5)
call ForcePlayerStartLocation(Player(5),5)
call SetPlayerColor(Player(5),ConvertPlayerColor(5))
call SetPlayerRacePreference(Player(5),RACE_PREF_HUMAN)
call SetPlayerRaceSelectable(Player(5),false)
call SetPlayerController(Player(5),MAP_CONTROL_USER)
endfunction
function InitCustomTeams takes nothing returns nothing
call SetPlayerTeam(Player(0),0)
call SetPlayerTeam(Player(1),0)
call SetPlayerTeam(Player(2),0)
call SetPlayerTeam(Player(3),0)
call SetPlayerTeam(Player(4),0)
call SetPlayerTeam(Player(5),0)
endfunction
function config takes nothing returns nothing
call SetMapName("LuaScaffold")
call SetMapDescription("InnerJAPI Lua starter")
call SetPlayers(6)
call SetTeams(1)
call SetGamePlacement(MAP_PLACEMENT_USE_MAP_SETTINGS)
call DefineStartLocation(0,0.0,0.0)
call DefineStartLocation(1,128.0,0.0)
call DefineStartLocation(2,256.0,0.0)
call DefineStartLocation(3,384.0,0.0)
call DefineStartLocation(4,512.0,0.0)
call DefineStartLocation(5,640.0,0.0)
call InitCustomPlayerSlots()
call InitCustomTeams()
endfunction
// @placements:init:begin
function CreateMapPlacements takes nothing returns nothing
set gg_unit_n001_0000 = CreateUnit(Player(15),'n001',-768.0,768.0,90.0)
set gg_rct_training_arena = Rect(-1536.0,256.0,1536.0,1536.0)
endfunction
// @placements:init:end
function main takes nothing returns nothing
call SetCameraBounds(-13568.0,-13568.0,12544.0,13056.0,-13568.0,13056.0,12544.0,-13568.0)
call InitBlizzard()
call FogEnable(false)
call FogMaskEnable(false)
call CreateMapPlacements()
call LuaScaffoldBoot()
endfunction
