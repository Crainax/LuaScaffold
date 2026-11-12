local Refs=require 'scaffold.handle_refs'
-- Synchronized engine adapter. Map coefficients live in rules/, not here.
local Context=require 'scaffold.context'
local M={}
function M.new(units)
    local j,dbg=require 'jass.common',require 'jass.debug'
    local self={effects=0,effects_created=0,damage_calls=0}
    function self.is_enemy(a,b)return j.IsUnitEnemy(b.handle,j.Player(a.owner))end
    function self.in_range(a,b,radius)
        local x,y=j.GetUnitX(a.handle)-j.GetUnitX(b.handle),j.GetUnitY(a.handle)-j.GetUnitY(b.handle)
        return x*x+y*y<=radius*radius
    end
    function self.damage(a,b,amount)
        Context.assert_sync()
        self.damage_calls=self.damage_calls+1
        local result=j.UnitDamageTarget(a.handle,b.handle,amount,false,false,j.ATTACK_TYPE_NORMAL,j.DAMAGE_TYPE_MAGIC,j.WEAPON_TYPE_WHOKNOWS)
        units:refresh(b.id)
        return result
    end
    function self.effect(definition,_,target)
        Context.assert_sync()
        local spec=definition.effect
        if not spec then return function()end end
        local handle=j.AddSpecialEffectTarget(spec.model,target.handle,spec.attachment)
        assert(handle and handle~=0,'skill native effect creation failed')
        Refs.ref('effect',handle);self.effects=self.effects+1;self.effects_created=self.effects_created+1
        local active=true
        return function()
            Context.assert_sync();if not active then return end;active=false
            j.DestroyEffect(handle);Refs.unref('effect',handle)
            self.effects=self.effects-1;handle=nil
        end
    end
    return self
end
return M
