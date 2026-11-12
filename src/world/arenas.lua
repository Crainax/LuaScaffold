-- Deterministic map-owned positions; no local camera or mouse input.
local M={}
function M.for_player(player)return {x=-4000+player*1400,y=4000}end
function M.hero_position(player,index)local p=M.for_player(player);return p.x+(index-2)*160,p.y end
return M
