function serialKillerKill(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	local heroes = HeroList:GetAllHeroes()
    for i=1,#heroes do
         local hero = heroes[i]
         if hero.isMarkedForDeath then
         	hero.isMarkedForDeath = false;
         end
     end

	
	target.isMarkedForDeath = true;
	target.killer = caster;
end

function doctorHeal(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	local heroes = HeroList:GetAllHeroes()
    for i=1,#heroes do
         local hero = heroes[i]
         if hero.isHealed then
         	hero.isHealed = false;
         end
     end
	
	target.isHealed = true;
end