local Context=require 'scaffold.context'
local Catalog=require 'content.heroes.catalog'
local Arenas=require 'world.arenas'
local M={}
function M.new(units,skills,players,engine)
    local self={by_id={},by_player={}}
    for _,player in ipairs(players)do
        local party={};self.by_player[player]=party
        for index,definition in ipairs(Catalog)do
            local x,y=Arenas.hero_position(player,index)
            local unit=units:create(player,string.unpack('>I4',definition.rawcode),x,y,90)
            engine.prepare(unit)
            skills:register(unit.id,definition.skill,100)
            local hero={unit_id=unit.id,definition=definition,talent_choice=0,player=player,index=index}
            self.by_id[unit.id]=hero;party[#party+1]=hero
        end
    end
    function self:restore(player)
        Context.assert_sync()
        for _,hero in ipairs(self.by_player[player] or {})do
            local unit=units:refresh(hero.unit_id)
            if unit then
                skills:cancel(unit.id,'rest')
                local x,y=Arenas.hero_position(player,hero.index)
                engine.restore(unit,x,y);units:refresh(unit.id)
                skills:replenish(unit.id)
            end
        end
    end
    function self:alive(player)
        local n=0
        for _,hero in ipairs(self.by_player[player] or {})do
            local unit=units:refresh(hero.unit_id)
            if unit and unit.state=='alive' then n=n+1 end
        end
        return n
    end
    return self
end
return M
