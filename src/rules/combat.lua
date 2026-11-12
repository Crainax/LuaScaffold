-- Map-owned formula. Public game/skill does not know this map's talents or coefficients.
local M={}
function M.with_talent(base,talent)
    local out={}
    -- Copying independent named fields has no order-sensitive side effects.
    for key,value in pairs(base)do out[key]=value end
    out.key=base.key..':'..talent.key
    out.damage=math.floor((base.damage+(talent.damage_flat or 0))*(100+(talent.damage_percent or 0))/100)
    out.range=base.range+(talent.range_bonus or 0)
    out.hits=base.hits+(talent.hit_bonus or 0)
    return out
end
return M
