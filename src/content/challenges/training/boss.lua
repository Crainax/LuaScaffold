-- Boss-specific phase rule; the encounter service owns cadence and cleanup.
local M={}
function M.pulse(session,units,heroes,combat,engine)
    local boss=units:refresh(session.boss_id)
    if not boss or boss.state~='alive' then return end
    session.phase=engine.life_fraction(boss)<=0.5 and 2 or 1
    for _,hero in ipairs(heroes.by_player[session.player])do
        local target=units:refresh(hero.unit_id)
        if target and target.state=='alive' then combat.damage(boss,target,session.phase==2 and 16 or 8)end
    end
    session.pulses=session.pulses+1
end
return M
