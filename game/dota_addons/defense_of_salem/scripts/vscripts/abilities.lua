function SheriffInvestigate(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if caster.investigated then
        caster.investigated.investigatedBySheriff = false
    end

    target.investigatedBySheriff = true
    target.sheriff = caster
    caster.investigated = target
end

function DoctorHeal(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if caster.healed then
    	caster.healed.isHealed = false
    	caster.healed.healer = nil
    end
	
	target.isHealed = true
	target.healer = caster
	caster.healed = target
end

function InvestigatorInvestigate(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if caster.investigated then
    	caster.investigated.investigatedByInvestigator = false
    	caster.investigated.investigator = nil
    end

    target.investigatedByInvestigator = true
    target.investigator = caster
    caster.investigated = target
end

function JailorJail(keys)
	local target = keys.target
	local caster = keys.caster

	if caster == nil or target == nil then
		return
	end

	if caster.prisoner then
    	caster.prisoner.jailed = false
    	caster.prisoner.jailedBy = nil
    end

    target.jailed = true
    target.jailedBy = caster
    caster.prisoner = target
end

function JailorExecuteOn(keys)
	local caster = keys.caster
	local prisoner = caster.prisoner

	if prisoner and caster then
		prisoner.executed = true
		prisoner.executedBy = caster
		caster.executed = prisoner
	end
end

function JailorExecuteOff(keys)
	local caster = keys.caster
	local prisoner = caster.prisoner

	if prisoner and caster then
		prisoner.executed = false
		prisoner.executedBy = nil
		caster.executed = nil
	end
end

function GodfatherKill(keys)
	local target = keys.target
	local caster = keys.caster
	local mafioso

	if caster == nil or target == nil then
		return
	end

	local heroes = GameMode.alivePlayers
    for i=1,#heroes do
        local hero = heroes[i]
        if hero.isMafioso then
        	mafioso = hero
        end
    end

    if mafioso.killed then
    	mafioso.killed.isKilledByMafia = false
    	mafioso.killed.mafiaKiller = nil
    end
    if caster.killed then
    	caster.killed.isKilledByMafia = false
    	caster.killed.mafiaKiller = nil
    end

    target.isKilledByMafia = true
    if mafioso then
    	mafioso.killed = target
    	target.mafiaKiller = mafioso
    else
    	caster.killed = target
    	target.mafiaKiller = caster
    end
end

function FramerFrame(keys)
	local target = keys.target
	local caster = keys.caster

	if caster == nil or target == nil then
		return
	end

	if caster.framed then
		caster.framed.isFramed = false
		caster.framed.framer = nil
	end
	
	target.isFramed = true
	target.framer = caster
	caster.framed = target
end

function EscorterEscrot(keys)
	local target = keys.target
	local caster = keys.caster

	if caster == nil or target == nil then
		return
	end

	if caster.escorted then
		caster.escorted.isEscorted = false
		caster.escorted.escorter = nil
	end
	
	target.isEscorted = true
	target.escorter = caster
	caster.escorted = target
end

function MafiosoKill(keys)
	local target = keys.target
	local caster = keys.caster
	local godfather

	if caster == nil or target == nil then
		return
	end

	local heroes = GameMode.alivePlayers
    for i=1,#heroes do
        local hero = heroes[i]
        if hero.isGodFather then
        	godfather = hero
        end
    end

    if godfather then
    	--send message suggesting target
    else
    	if caster.killed then
    		caster.killed.isKilledByMafia = false
    		caster.killed.mafiaKiller = nil
    	end
	    hero.isKilledByMafia = true
	    hero.mafiaKiller = caster
	end
end

function LookoutWatch(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if caster.watched then
    	caster.watched.watchedByLookout = false
    	caster.watched.investigator = nil
    end

    target.watchedByLookout = true
    target.lookout = caster
    caster.watched = target
end

function SerialKillerKill(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if caster.killed then
		caster.killed.isKilledBySK = false
		caster.killed.skKiller = nil
	end
	
	target.isKilledBySK = true
	target.skKiller = caster
	caster.killed = target
end

function VeteranAlertOn(key)
	local caster = keys.caster
	caster.alert = true
end

function VeteranAlertOff(key)
	local caster = keys.caster
	caster.alert = false
end

function VigilanteShoot(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if caster.killed then
		caster.killed.isKilledByVig = false
		caster.killed.vigKiller = nil
	end
	
	target.isKilledByVig = true
	target.vigKiller = caster
	caster.killed = target
end

function JesterKill(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if caster.killed then
		caster.killed.isKilledByJester = false
		caster.killed.jesterKiller = nil
	end
	
	target.isKilledByJester = true
	target.jesterKiller = caster
	caster.killed = target
end



function VoteForTrial(keys)
	local target = keys.target
	local caster = keys.caster
	
	--allow to cancel vote and display message, show different messages for first vote and change vote
	if caster.votedFor == target then
		caster.votedFor = nil
		GameRules:SendCustomMessage("<bold><font color='#04B404'>"..GameMode:ConvertEngineName(caster:GetName()).. "</bold></font> has canceled their vote", 2, 5)
		return
	end

	if caster.votedFor then
		caster.votedFor.votes = caster.votedFor.votes - 1
		GameRules:SendCustomMessage("<bold><font color='#04B404'>"..GameMode:ConvertEngineName(caster:GetName()).. "</bold></font> has changed their vote to <bold><font color='#DF0101'>"..GameMode:ConvertEngineName(target:GetName()), 2, 5)
	else
		GameRules:SendCustomMessage("<bold><font color='#04B404'>"..GameMode:ConvertEngineName(caster:GetName()).. "</bold></font> voted for <bold><font color='#DF0101'>"..GameMode:ConvertEngineName(target:GetName()), 2, 5)
	end

	caster.votedFor = target

	target.votes = target.votes + 1
	--send message about caster voting for taret

	if target.votes > (#GameMode.alivePlayers / 2 - 6) then
		GameMode.votedPlayer = target
	end
end

function TrialVoteYes(keys)
	local caster = keys.caster
	local abil = caster:GetAbilityByIndex(1)
	if caster and abil and abil:GetName() == "trial_vote_no" and abil:GetToggleState() then
		abil:ToggleAbility()
		GameRules:SendCustomMessage("<bold><font color='#04B404'>"..GameMode:ConvertEngineName(caster:GetName()).. "</bold></font> has changed their vote", 2, 5)
	else
		GameRules:SendCustomMessage("<bold><font color='#04B404'>"..GameMode:ConvertEngineName(caster:GetName()).. "</bold></font> has voted", 2, 5)
	end
	caster.vote = "guilty"

end

function TrialVoteNo(keys)
	local caster = keys.caster
	local abil = caster:GetAbilityByIndex(0)
	if caster and abil and abil:GetName() == "trial_vote_yes" and abil:GetToggleState() then
		abil:ToggleAbility()
		GameRules:SendCustomMessage("<bold><font color='#04B404'>"..GameMode:ConvertEngineName(caster:GetName()).. "</bold></font> has changed their vote", 2, 5)
	else
		GameRules:SendCustomMessage("<bold><font color='#04B404'>"..GameMode:ConvertEngineName(caster:GetName()).. "</bold></font> has voted", 2, 5)
	end
	caster.vote = "innocent"
end

function TrialVoteOff(keys)
	local caster = keys.caster
	caster.vote = "abstain"
	GameRules:SendCustomMessage("<bold><font color='#04B404'>"..GameMode:ConvertEngineName(caster:GetName()).. "</bold></font> has canceled their vote", 2, 5)
end
