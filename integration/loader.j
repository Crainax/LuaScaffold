// Minimal boot glue for classic Warcraft. Business logic stays in Lua.
// Include this function in generated war3map.j and call once from main,
// before application handles are created. Do not combine with another Lua boot.
// Fixed InnerJAPI boot; validated by the project runtime suites.
function LuaScaffoldBoot takes nothing returns nothing
    call ExecuteFunc("DoNothing")
    call StartCampaignAI(Player(PLAYER_NEUTRAL_AGGRESSIVE), "callback")
    call ExecuteFunc("DoNothing")
    call AbilityId("exec-lua:plugin_main")
endfunction
