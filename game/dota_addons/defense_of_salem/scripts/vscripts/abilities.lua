function SheriffInvestigate(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if caster.investigated then
		if caster.investigated == target then
			caster.investigated.isInvestigatedBySheriff = false
        	caster.investigated = nil
			return
		end
        caster.investigated.isInvestigatedBySheriff = false
        caster.investigated = nil
    end

    target.isInvestigatedBySheriff = true
    target.sheriff = caster
    caster.investigated = target

    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = "You have decided to investigate "..targetName, style={color="red",["font-size"]="20px"}, duration = 10})
end

function DoctorHeal(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if caster.healed then
		if caster.healed == target then
    		caster.healed.healed = false
    		caster.healed.healer = nil
    		return
    	end
    	caster.healed.healed = false
    	caster.healed.healer = nil
    end
	
	target.isHealed = true
	target.doctor = caster
	caster.healed = target

    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = "You have decided to heal "..targetName, style={color="red",["font-size"]="20px"}, duration = 10})
end

function InvestigatorInvestigate(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if caster.investigated then
		if caster.investigated == target then
			caster.investigated.isInvestigatedByInvestigator = false
    		caster.investigated.investigator = nil
    		return
    	end
    	caster.investigated.isInvestigatedByInvestigator = false
    	caster.investigated.investigator = nil
    end

    target.isInvestigatedByInvestigator = true
    target.investigator = caster
    caster.investigated = target

    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = "You have decided to investigate "..targetName, style={color="red",["font-size"]="20px"}, duration = 10})
end

function JailorJail(keys)
	local target = keys.target
	local caster = keys.caster

	if caster == nil or target == nil then
		return
	end

	if caster.prisoner then
		if caster.prisoner == target then
			caster.prisoner.isJailed = false
    		caster.prisoner.jailor = nil
			return
		end
    	caster.prisoner.isJailed = false
    	caster.prisoner.jailor = nil
    end

    target.isJailed = true
    target.jailor = caster
    caster.jailed = target

    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = "You have decided to jail "..targetName, style={color="red",["font-size"]="20px"}, duration = 10})
end

function JailorExecuteOn(keys)
	local caster = keys.caster
	local prisoner = caster.prisoner

	if prisoner and caster then
		prisoner.isExecuted = true
		prisoner.executor = caster
		caster.executed = prisoner
	end

    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = "You have decided to execute "..targetName, style={color="red",["font-size"]="20px"}, duration = 10})
    Notifications:Bottom(prisoner:GetPlayerID(), {text = "Jailor has decided to execute you", style={color="red",["font-size"]="20px"}, duration = 10})
end

function JailorExecuteOff(keys)
	local caster = keys.caster
	local prisoner = caster.prisoner

	if prisoner and caster then
		prisoner.isExecuted = false
		prisoner.executor = nil
		caster.executed = nil
	end

	local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = "You have decided not to execute "..targetName, style={color="red",["font-size"]="20px"}, duration = 10})
    Notifications:Bottom(prisoner:GetPlayerID(), {text = "Jailor has decided not to execute you", style={color="red",["font-size"]="20px"}, duration = 10})
end

function GodfatherOrderToKill(keys)
	local target = keys.target
	local caster = keys.caster

	if caster == nil or target == nil then
		return
	end

	if not caster.mafioso or not caster.framer then

		local heroes = GameMode.alivePlayers
	    for i=1,#heroes do
	        local hero = heroes[i]
	        if hero.isMafioso then
	        	caster.mafioso = hero
	        elseif hero.isFramer then
	        	caster.framer = hero
	        end
	    end
	end

    if caster.mafioso.killed then
    	if caster.mafioso.killed == target then
    		caster.mafioso.killed.isKilledByMafioso = false
    		caster.mafioso.killed.mafiosoKiller= nil
    		return
    	end
    	caster.mafioso.killed.isKilledByMafioso = false
    	caster.mafioso.killed.mafiosoKiller= nil
    end

    target.isKilledByMafioso = true
    target.mafiosoKiller = caster.mafioso
    caster.mafioso.killed = target

    local casterName = GameMode:ConvertEngineName(caster:GetName())
    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = casterName.." has decided to kill "..targetName, style={color="red",["font-size"]="20px"}, duration = line_duration})

    Notifications:Bottom(caster.mafioso:GetPlayerID(), {text = casterName.." has decided to kill "..targetName, style={color="red",["font-size"]="20px"}, duration = line_duration, continue = true})

    Notifications:Bottom(caster.framer:GetPlayerID(), {text = casterName.." has decided to kill "..targetName, style={color="red",["font-size"]="20px"}, duration = line_duration, continue = true})
end

function GodfatherKill(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if not caster.framer then
		local heroes = GameMode.alivePlayers
	    for i=1,#heroes do
	        local hero = heroes[i]
	        if hero.isFramer then
	        	caster.framer = hero
	        end
	    end
	end

	if caster.killed then
		if caster.killed == target then
			caster.killed.isKilledByGodfather = false
			caster.killed.godfatherKiller = nil
			return
		end
		caster.killed.isKilledByGodfather = false
		caster.killed.godfatherKiller = nil
	end
	
	target.isKilledByGodfather = true
	target.godfatherKiller = caster
	caster.killed = target

    local casterName = GameMode:ConvertEngineName(caster:GetName())
    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = casterName.." has decided to kill "..targetName, style={color="red",["font-size"]="20px"}, duration = line_duration})

    Notifications:Bottom(caster.framer:GetPlayerID(), {text = casterName.." has decided to kill "..targetName, style={color="red",["font-size"]="20px"}, duration = line_duration, continue = true})
end

function FramerFrame(keys)
	local target = keys.target
	local caster = keys.caster

	if caster == nil or target == nil then
		return
	end

	if not caster.godfather then
		local heroes = GameMode.alivePlayers
	    for i=1,#heroes do
	        local hero = heroes[i]
	        if hero.isGodfather then
	        	caster.godfather = hero
	        end
	    end
	end

	if caster.framed then
		if caster.framed == target then
			caster.framed.isFramed = false
			caster.framed.framer = nil
			return
		end
		caster.framed.isFramed = false
		caster.framed.framer = nil
	end
	
	target.isFramed = true
	target.framer = caster
	caster.framed = target

    local casterName = GameMode:ConvertEngineName(caster:GetName())
    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = casterName.." has decided to frame "..targetName, style={color="red",["font-size"]="20px"}, duration = line_duration})

    Notifications:Bottom(caster.godfather:GetPlayerID(), {text = casterName.." has decided to frame "..targetName, style={color="red",["font-size"]="20px"}, duration = line_duration, continue = true})

    Notifications:Bottom(caster.godfather.mafioso:GetPlayerID(), {text = casterName.." has decided to frame "..targetName, style={color="red",["font-size"]="20px"}, duration = line_duration, continue = true})
end

function EscorterEscrot(keys)
	local target = keys.target
	local caster = keys.caster

	if caster == nil or target == nil then
		return
	end

	if caster.escorted then
		if caster.escorted == target then
			caster.escorted.isEscorted = false
			caster.escorted.escorter = nil
			return
		end
		caster.escorted.isEscorted = false
		caster.escorted.escorter = nil
	end
	
	target.isEscorted = true
	target.escorter = caster
	caster.escorted = target

    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = "You have decided to escort "..targetName, style={color="red",["font-size"]="20px"}, duration = 10})
end

function MafiosoKill(keys)
	local target = keys.target
	local caster = keys.caster

	if caster == nil or target == nil then
		return
	end

	if not caster.godfather then
		local heroes = GameMode.alivePlayers
	    for i=1,#heroes do
	        local hero = heroes[i]
	        if hero.isGodfather then
	        	caster.godfather = hero
	        end
	    end
	end

	if caster.suggested then
		if caster.suggested == target then
			caster.suggested.isSuggestedByMafioso = false
			caster.suggested.mafiosoSuggestor = nil
			return
		end
		caster.suggested.isSuggestedByMafioso = false
		caster.suggested.mafiosoSuggestor = nil
	end

    target.isSuggestedByMafioso = true
    target.mafiosoSuggestor = caster
    caster.suggested = target

    local casterName = GameMode:ConvertEngineName(caster:GetName())
    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = casterName.." suggests to kill "..targetName, style={color="red",["font-size"]="20px"}, duration = line_duration})

    Notifications:Bottom(caster.godfather:GetPlayerID(), {text = casterName.." suggests to kill "..targetName, style={color="red",["font-size"]="20px"}, duration = line_duration, continue = true})

    Notifications:Bottom(caster.godfather.framer:GetPlayerID(), {text = casterName.." suggests to kill "..targetName, style={color="red",["font-size"]="20px"}, duration = line_duration, continue = true})

end

function LookoutWatch(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if caster.watched then
		if caster.watched == target then
			caster.watched.isWatchedByLookout = false
    		caster.watched.lookout = nil
    		return
    	end
    	caster.watched.isWatchedByLookout = false
    	caster.watched.lookout = nil
    end

    target.isWatchedByLookout = true
    target.lookout = caster
    caster.watched = target

    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = "You have decided to watch "..targetName.."'s home", style={color="red",["font-size"]="20px"}, duration = 10})
end

function SerialKillerKill(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if caster.killed then
		if caster.killed == target then
			caster.killed.isKilledBySK = false
			caster.killed.skKiller = nil
			return
		end
		caster.killed.isKilledBySK = false
		caster.killed.skKiller = nil
	end
	
	target.isKilledBySK = true
	target.skKiller = caster
	caster.killed = target

    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = "You have decided to kill "..targetName, style={color="red",["font-size"]="20px"}, duration = 10})
end

function VeteranAlertOn(keys)
	local caster = keys.caster
	caster.alert = true

    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = "You have decided to go on alert tonight", style={color="red",["font-size"]="20px"}, duration = 10})
end

function VeteranAlertOff(keys)
	local caster = keys.caster
	caster.alert = false

    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = "You have decided to not go on alert tonight", style={color="red",["font-size"]="20px"}, duration = 10})
end

function VigilanteShoot(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if caster.killed then
		if caster.killed == target then
			caster.killed.isKilledByVig = false
			caster.killed.vigKiller = nil
			return
		end
		caster.killed.isKilledByVig = false
		caster.killed.vigKiller = nil
	end
	
	target.isKilledByVig = true
	target.vigKiller = caster
	caster.killed = target

    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = "You have decided to shoot "..targetName, style={color="red",["font-size"]="20px"}, duration = 10})
end

function JesterKill(keys)
	local target = keys.target
	local caster = keys.caster
	
	if caster == nil or target == nil then
		return
	end

	if caster.killed then
		if caster.killed == target then
			caster.killed.isKilledByJester = false
			caster.killed.jesterKiller = nil
			return
		end
		caster.killed.isKilledByJester = false
		caster.killed.jesterKiller = nil
	end
	
	target.isKilledByJester = true
	target.jesterKiller = caster
	caster.killed = target

    local targetName = GameMode:ConvertEngineName(target:GetName())
    Notifications:Bottom(caster:GetPlayerID(), {text = "You have decided to haunt and kill "..targetName, style={color="red",["font-size"]="20px"}, duration = 10})
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
