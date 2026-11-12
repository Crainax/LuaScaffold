-- One permanent choice per hero in this sample; changing heroes does not reset it.
local Context=require 'scaffold.context'
local Formula=require 'rules.combat'
local M={}
function M.choose(hero,choice,sender,units,skills)
    Context.assert_sync()
    if not hero then return false,'unknown hero' end
    local unit=units:refresh(hero.unit_id)
    if not unit or unit.state~='alive' or unit.owner~=sender then return false,'hero unavailable' end
    if hero.talent_choice~=0 then return false,'already chosen' end
    local talent=hero.definition.talents[choice]
    if not talent then return false,'unknown talent' end
    local skill=skills:get(hero.unit_id)
    if not skill or skill.cast then return false,'skill busy' end
    skills:set_definition(hero.unit_id,Formula.with_talent(hero.definition.skill,talent))
    hero.talent_choice=choice
    return true
end
return M
