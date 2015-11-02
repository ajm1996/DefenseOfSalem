function serialKillerKill(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	local heroes = GameMode.alivePlayers
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

	local heroes = GameMode.alivePlayers
    for i=1,#heroes do
         local hero = heroes[i]
         if hero.isHealed then
         	hero.isHealed = false;
         end
     end
	
	target.isHealed = true;
end

function VoteForTrial(keys)
	local target = keys.target
	local caster = keys.caster
	print("voted for " .. target:GetName())

	if caster.votedFor then
		caster.votedFor.votes = caster.votedFor.votes - 1
	end

	caster.votedFor = target

	target.votes = target.votes + 1
	--send message about caster voting for taret

	if target.votes > (#GameMode.alivePlayers / 2) then
		GameMode.votedPlayer = target
	end
end

function TrialVoteYes(keys)
	local caster = keys.caster
	local abil = caster:GetAbilityByIndex(1)
	if caster and abil and abil:GetName() == "trial_vote_no" and abil:GetToggleState() then
		abil:ToggleAbility()
	end
	caster.vote = "guilty"
end

function TrialVoteNo(keys)
	local caster = keys.caster
	local abil = caster:GetAbilityByIndex(0)
	if caster and abil and abil:GetName() == "trial_vote_yes" and abil:GetToggleState() then
		abil:ToggleAbility()
	end
	caster.vote = "innocent"
end

function TrialVoteOff(keys)
	local caster = target.caster
	caster.vote = "abstain"
end
