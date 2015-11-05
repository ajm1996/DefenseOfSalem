-- This is the primary barebones gamemode script and should be used to assist in initializing your game mode


-- Set this to true if you want to see a complete debug output of all events/processes done by barebones
-- You can also change the cvar 'barebones_spew' at any time to 1 or 0 for output/no output
BAREBONES_DEBUG_SPEW = false 

if GameMode == nil then
  DebugPrint( '[BAREBONES] creating barebones game mode' )
  _G.GameMode = class({})
end

-- This library allow for easily delayed/timed actions
require('libraries/timers')
-- This library can be used for advancted physics/motion/collision of units.  See PhysicsReadme.txt for more information.
require('libraries/physics')
-- This library can be used for advanced 3D projectile systems.
require('libraries/projectiles')
-- This library can be used for sending panorama notifications to the UIs of players/teams/everyone
require('libraries/notifications')
-- This library can be used for starting customized animations on units from lua
require('libraries/animations')
-- This library can be used for performing "Frankenstein" attachments on units
require('libraries/attachments')

-- These internal libraries set up barebones's events and processes.  Feel free to inspect them/change them if you need to.
require('internal/gamemode')
require('internal/events')

-- settings.lua is where you can specify many different properties for your game mode and is one of the core barebones files.
require('settings')
-- events.lua is where you can specify the actions to be taken when any event occurs and is one of the core barebones files.
require('events')


--[[
This function should be used to set up Async precache calls at the beginning of the gameplay.

In this function, place all of your PrecacheItemByNameAsync and PrecacheUnitByNameAsync.  These calls will be made
after all players have loaded in, but before they have selected their heroes. PrecacheItemByNameAsync can also
be used to precache dynamically-added datadriven abilities instead of items.  PrecacheUnitByNameAsync will 
precache the precache{} block statement of the unit and all precache{} block statements for every Ability# 
defined on the unit.

This function should only be called once.  If you want to/need to precache more items/abilities/units at a later
time, you can call the functions individually (for example if you want to precache units in a new wave of
holdout).

This function should generally only be used if the Precache() function in addon_game_mode.lua is not working.
]]
function GameMode:PostLoadPrecache()
  DebugPrint("[BAREBONES] Performing Post-Load precache")
end

--[[
This function is called once and only once as soon as the first player (almost certain to be the server in local lobbies) loads in.
It can be used to initialize state that isn't initializeable in InitGameMode() but needs to be done before everyone loads in.
]]
function GameMode:OnFirstPlayerLoaded()
  DebugPrint("[BAREBONES] First Player has loaded")
end

--[[
This function is called once and only once after all players have loaded into the game, right as the hero selection time begins.
It can be used to initialize non-hero player state or adjust the hero selection (i.e. force random etc)
]]
function GameMode:OnAllPlayersLoaded()
  DebugPrint("[BAREBONES] All Players have loaded into the game")
end

--[[
This function is called once and only once for every player when they spawn into the game for the first time.  It is also called
if the player's hero is replaced with a new hero for any reason.  This function is useful for initializing heroes, such as adding
levels, changing the starting gold, removing/adding abilities, adding physics, etc.

The hero parameter is the hero entity that just spawned in
]]
function GameMode:OnHeroInGame(hero)
  DebugPrint("[BAREBONES] Hero spawned in game for first time -- " .. hero:GetUnitName())

  PlayerSay:SendConfig(hero:GetPlayerID(), false, false)

  --add player to alive players

  self.dummy:FindAbilityByName("player_modifiers_passive"):ApplyDataDrivenModifier(self.dummy, hero, "modifier_general_player_passives", {})
  self.dummy:FindAbilityByName("player_modifiers_passive"):ApplyDataDrivenModifier(self.dummy, hero, "modifier_rooted_passive", {})

  hero:SetGold(0, false)

end

-- This function initializes the game mode and is called before anyone loads into the game
-- It can be used to pre-initialize any values/tables that will be needed later

function GameMode:InitGameMode()
  GameMode = self

  -- Call the internal function to set up the rules/behaviors specified in constants.lua
  -- This also sets up event hooks for all event handlers in events.lua
  -- Check out internals/gamemode to see/modify the exact code
  GameMode:_InitGameMode()

  PlayerSay:ChatHandler(function(playerEntity, text)
    if text ~= "" then
      local heroName = GameMode:ConvertEngineName(playerEntity:GetAssignedHero():GetName())
      local line_duration = 10.0
      Notifications:BottomToAll({hero = playerEntity:GetAssignedHero():GetName(), duration = line_duration})
      Notifications:BottomToAll({text = heroName, style={color="red",["font-size"]="20px"}, duration = line_duration, continue = true})
      Notifications:BottomToAll({text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})
    end
  end)

  self.valveTime = nil
  self.alivePlayers = {}
  self.gameState = nil
  self.dayNum = nil
  self.votedPlayer = nil
  self.dummy = CreateUnitByName("dummy_unit", Vector(0,0,0), true, nil, nil, DOTA_TEAM_GOODGUYS)
end

--[[
This function is called once and only once when the game completely begins (about 0:00 on the clock).  At this point,
gold will begin to go up in ticks if configured, creeps will spawn, towers will become damageable etc.  This function
is useful for starting any game logic timers/thinkers, beginning the first round, etc.
]]
function GameMode:OnGameInProgress()
  GameMode:StartPhase(-1)
  self.valveTime = GameRules:GetGameTime()
end

function GameMode:StartPhase(phase)
  if phase == -1 then     --PREGAME
    self.gameState = -1
    local timeLength = 30

    GameRules:SetTimeOfDay((360 - timeLength) * (1/480))
    self.dayNum = 1

    Notifications:TopToAll({text = "Day 1", style={["font-size"]="50px"}, duration = 5, continue = true})

    --force heroes to spawn?
    self.alivePlayers = HeroList:GetAllHeroes()
    GameMode:SetRoles()

    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:SetSkills(hero)
        local message = "You are "
        local first = string.sub(GameMode:GetRole(hero), 1, 1)
        if first == "A" or first == "E" or first == "I" or first == "O" or first == "U" then
          message = message .. "an "
        else
          message = message .. "a "
        end
        message = message .. GameMode:GetRole(hero)
        print(hero:GetName()..": " .. message)
        ShowGenericPopupToPlayer(hero, message, "TODO: Role Description", "", "", DOTA_SHOWGENERICPOPUP_TINT_SCREEN)
      end
    end
    Timers:CreateTimer(0.03, function()
      GameRules:SendCustomMessage("Night 1 starts at  <bold><font color='#DF0101'>".. GameMode:GetGameTime(timeLength) .. "</font></bold>", 2, timeLength)
    end)

    Timers:CreateTimer(timeLength, function()
      GameMode:StartPhase(0)
    end)

  elseif phase == 0 then  --NIGHTTIME
    print("night phase")
    local timeLength = 40
    self.gameState = 0

    GameRules:SetTimeOfDay((120 - timeLength) * (1/480))
    mode:SetFogOfWarDisabled(false)

    Notifications:TopToAll({text = "Night "..self.dayNum, style={["font-size"]="50px"}, duration = 5, continue = true})
    GameRules:SendCustomMessage("Day ".. self.dayNum + 1 .." starts at  <bold><font color='#DF0101'>".. GameMode:GetGameTime(timeLength) .. "</font></bold>", 2, timeLength)

    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:RoleActions(hero)
        GameMode:SetSkills(hero)
        GameMode:SetChatPermission(hero)
        GameMode:CleanFlags(hero)
      end
    end

    Timers:CreateTimer(timeLength, function()
      GameMode:StartPhase(1)
    end)

  elseif phase == 1 then  --DAYTIME/DISCUSSION
    print("day phase")
    self.gameState = 1
    local timeLength = 45

    GameRules:SetTimeOfDay((360 - timeLength - 30) * (1/480)) --30 from vote time
    mode:SetFogOfWarDisabled(true)
    self.dayNum = self.dayNum + 1

    Notifications:TopToAll({text = "Day "..self.dayNum, style={["font-size"]="50px"}, duration = 5, continue = true})
    GameRules:SendCustomMessage("Voting starts at  <bold><font color='#DF0101'>".. GameMode:GetGameTime(timeLength) .. "</font></bold>", 2, timeLength)

    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:RoleActions(hero)
        GameMode:SetSkills(hero)
        GameMode:SetChatPermission(hero)
        GameMode:CleanFlags(hero)
      end
    end

    self.votedPlayer = nil

    Timers:CreateTimer(timeLength, function()
      GameMode:StartPhase(2)
    end)

  elseif phase == 2 then  --VOTING
    print("voting phase")
    self.gameState = 2
    local timeLength = 30

    Notifications:TopToAll({text = "Today's public vote and trial will now begin.", style={["font-size"]="40px"}, duration = 3, continue = true})
    GameRules:SendCustomMessage("Voting ends at  <bold><font color='#DF0101'>".. GameMode:GetGameTime(timeLength) .. "</font></bold>", 2, timeLength)

    Timers:CreateTimer(4, function()
      Notifications:TopToAll({text = math.ceil(#self.alivePlayers / 2) .. " votes are needed to send someone to trial.", style={["font-size"]="40px"}, duration = 5})
    end)

    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:SetSkills(hero)
      end
    end

    local flag = false
    Timers:CreateTimer(timeLength, function()
      flag = true
    end)
    
    Timers:CreateTimer(function()
      if self.votedPlayer then
        GameMode:StartPhase(3)
      elseif flag then
        GameMode:StartPhase(0)
      else
        return 0.03
      end
    end)

  elseif phase == 3 then  --DEFENSE
    print("defense phase")
    self.gameState = 3
    local timeLength = 20

    GameRules:SetTimeOfDay((360 - timeLength - 20 - 9) * (1/480)) --20 from judgement and 4.5 * 2 from walking

    Notifications:TopToAll({text = "The town has decided to put ", style={["font-size"]="40px"}, duration = 5})
    Notifications:TopToAll({text = GameMode:ConvertEngineName(self.votedPlayer:GetName()).." ", style={color="red", ["font-size"]="40px"}, duration = 5, continue = true})
    Notifications:TopToAll({text = "on trial.", style={["font-size"]="40px"}, duration = 5, continue = true})
    GameRules:SendCustomMessage("Defense ends at  <bold><font color='#DF0101'>".. GameMode:GetGameTime(timeLength) .. "</font></bold>", 2, timeLength)

    --check if day < 4 and save remaining time if true

    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:SetSkills(hero)
        GameMode:SetChatPermission(hero)
      end
    end

    self.votedPlayer.home = self.votedPlayer:GetAbsOrigin()
    if self.votedPlayer:HasModifier("modifier_rooted_passive") then
      self.votedPlayer:RemoveModifierByName("modifier_rooted_passive")
    end

    Timers:CreateTimer(0.03, function()
      self.votedPlayer:MoveToPosition(Vector(0,0,0))
      if (self.votedPlayer:GetAbsOrigin() - Vector(0, 0, 264.75)):Length() > 0.001 then
        return .03
      else
        self.dummy:FindAbilityByName("player_modifiers_passive"):ApplyDataDrivenModifier(self.dummy, self.votedPlayer, "modifier_rooted_passive", {})
        
        Notifications:TopToAll({text = GameMode:ConvertEngineName(self.votedPlayer:GetName()), style={color="red", ["font-size"]="40px"}, duration = 5})
        Notifications:TopToAll({text = ", you are on trial for conspiracy against the town.", style={["font-size"]="40px"}, duration = 5, continue = true})
        Notifications:TopToAll({text = "What is your defense?", style={color="red", ["font-size"]="40px"}, duration = 5})
        
        Timers:CreateTimer(timeLength, function()
          GameMode:StartPhase(4)
        end)
      end
    end)

  elseif phase == 4 then  --JUDGEMENT
    print("judgement phase")
    self.gameState = 4
    local timeLength = 20

    Notifications:TopToAll({text = "The town may now vote on the fate of ", style={["font-size"]="40px"}, duration = 5})
    Notifications:TopToAll({text = GameMode:ConvertEngineName(self.votedPlayer:GetName()), style={color="red", ["font-size"]="40px"}, duration = 5, continue = true})
    GameRules:SendCustomMessage("Judgement ends at  <bold><font color='#DF0101'>".. GameMode:GetGameTime(timeLength) .. "</font></bold>", 2, timeLength)

    --ask for votes

    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:SetSkills(hero)
        GameMode:SetChatPermission(hero)
      end
    end

    Timers:CreateTimer(timeLength, function()
      local guilty = 0
      local innocent = 0
      local abstain = 0

      for i=0,#self.alivePlayers do
        local hero = self.alivePlayers[i]
        if hero then
          if hero.vote == "innocent" then
            GameRules:SendCustomMessage(GameMode:ConvertEngineName(hero:GetName()).. " voted <bold><font color='#04B404'>innocent</font></bold>", 2, 5)
            innocent = innocent + 1
          elseif hero.vote == "guilty" then
            GameRules:SendCustomMessage(GameMode:ConvertEngineName(hero:GetName()).. " voted <bold><font color='#DF0101'>guilty</font></bold>", 2, 5)
            guilty = guilty + 1
          elseif hero.vote == "abstain" then
            GameRules:SendCustomMessage(GameMode:ConvertEngineName(hero:GetName()).. " <bold><font color='#0080FF'>abstained</font></bold>", 2, 5)
            abstain = abstain + 1
          end
        end
      end

      if innocent >= guilty then
        if self.votedPlayer:HasModifier("modifier_rooted_passive") then
          self.votedPlayer:RemoveModifierByName("modifier_rooted_passive")
        end
        Timers:CreateTimer(function()
          self.votedPlayer:MoveToPosition(self.votedPlayer.home)
          if (self.votedPlayer:GetAbsOrigin() - self.votedPlayer.home):Length() > 0.001 then
            return .03
          else
            self.dummy:FindAbilityByName("player_modifiers_passive"):ApplyDataDrivenModifier(self.dummy, self.votedPlayer, "modifier_rooted_passive", {})
            --check if day < 4
            GameMode:StartPhase(0)
          end
        end)
      else
        GameMode:StartPhase(5)
      end
    end)

  elseif phase == 5 then  --LAST WORDS
    print("last words phase")
    self.gameState = 5
    local timeLength = 10

    GameRules:SetTimeOfDay((360 - timeLength - 3) * (1/480))  --3 from dramatic kill delay

    Notifications:TopToAll({text = GameMode:ConvertEngineName(self.votedPlayer:GetName()), style={color="red", ["font-size"]="40px"}, duration = timeLength - 3})
    Notifications:TopToAll({text = ", do you have any last words?", style={["font-size"]="40px"}, duration = timeLength - 3, continue = true})

    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:SetSkills(hero)
        GameMode:SetChatPermission(hero)
      end
    end

    --ask for final words

    Timers:CreateTimer(timeLength - 3, function()
      Notifications:TopToAll({text = "May god have mercy on your soul, ", style={["font-size"]="40px"}, duration = 3})
      Notifications:TopToAll({text = GameMode:ConvertEngineName(self.votedPlayer:GetName()), style={color="red", ["font-size"]="40px"}, duration = 3, continue = true})

      for i=1, #self.alivePlayers do
        if self.alivePlayers[i] == self.votedPlayer then
          table.remove(self.alivePlayers, i)
        end
      end
      self.votedPlayer:ForceKill(false)
      self.votedPlayer:SetTeam(1)
      Timers:CreateTimer(3, function()
        FindClearSpaceForUnit(self.votedPlayer, self.votedPlayer.home, false)
        --check if day < 4
        GameMode:StartPhase(0)
      end)
    end)
  end
end

function GameMode:SetRoles()
  local heroes = HeroList:GetAllHeroes()

  local rand = math.random(#heroes)
  local sheriff = table.remove(heroes, rand)
  if sheriff then
    print("Sheriff: " .. sheriff:GetName())
    sheriff.isSheriff = true
    sheriff.skills = {"sheriff_investigate"}
  end

  rand = math.random(#heroes)
  local doctor = table.remove(heroes, rand)
  if doctor then
    print("Doctor: " .. doctor:GetName())
    doctor.isDoctor = true
    doctor.skills = {"doctor_heal"}
  end

  rand = math.random(#heroes)
  local investigator = table.remove(heroes, rand)
  if investigator then
    print("Investigator: " .. investigator:GetName())
    investigator.isInvestigator = true
    investigator.skills = {"investigator_investigate"}
  end

  rand = math.random(#heroes)
  local jailor = table.remove(heroes, rand)
  if jailor then
    print("Jailor: " .. jailor:GetName())
    jailor.isJailor = true
    jailor.skills = {"jailor_execute"}
    jailor.daySkills = {"jailor_jail"}
  end

  rand = math.random(#heroes)
  local medium = table.remove(heroes, rand)
  if medium then
    print("Medium: " .. medium:GetName())
    medium.isMedium = true
    medium.skills = {"medium_passive"}
    medium.daySkills = {"medium_passive"}
  end

  rand = math.random(#heroes)
  local godfather = table.remove(heroes, rand)
  if godfather then
    print("Godfather: " .. godfather:GetName())
    godfather.isGodfather = true
    godfather.isMafia = true
    godfather.skills = {"godfather_kill"}
  end

  rand = math.random(#heroes)
  local framer = table.remove(heroes, rand)
  if framer then
    print("Framer: " .. framer:GetName())
    framer.isFramer = true
    framer.isMafia = true
    framer.skills = {"framer_frame"}
  end

  rand = math.random(#heroes)
  local executioner = table.remove(heroes, rand)
  if executioner then
    print("Executioner: " .. executioner:GetName())
    executioner.isExecutioner = true
    executioner.skills = {"executioner_passive"}
    executioner.daySkills = {"executioner_passive"}
  end

  rand = math.random(#heroes)
  local escort = table.remove(heroes, rand)
  if escort then
    print("Escort: " .. escort:GetName())
    escort.isEscort = true
    escort.skills = {"escorter_escort"}
  end

  rand = math.random(#heroes)
  local mafioso = table.remove(heroes, rand)
  if mafioso then
    print("Mafioso: " .. mafioso:GetName())
    mafioso.isMafioso = true
    mafioso.isMafia = true
    mafioso.skills = {"mafioso_kill"}
  end

  rand = math.random(#heroes)
  local lookout = table.remove(heroes, rand)
  if lookout then
    print("Lookout: " .. lookout:GetName())
    lookout.isLookout = true
    lookout.skills = {"lookout_investigate"}
  end

  rand = math.random(#heroes)
  local serialKiller = table.remove(heroes, rand)
  if serialKiller then
    print("Serial Killer: " .. serialKiller:GetName())
    serialKiller.isSerialKiller = true
    serialKiller.skills = {"serial_killer_kill"}
  end

  rand = math.random(#heroes)
  local townKilling = table.remove(heroes, rand)
  local townKillingIsVeteran = false
  if townKilling then
    if math.random() > 0.5 then
      townKilling.isVeteran = true
      townKilling.daySkills = {"veteran_alert"}
      townKillingIsVeteran = true
      print("Veteran (Town Killing): " .. townKilling:GetName())
    else
      townKilling.isVigilante = true
      townKilling.skills = {"vigilante_shoot"}
      townKillingIsVeteran = false
      print("Vigilante (Town Killing): " .. townKilling:GetName())
    end
  end

  rand = math.random(#heroes)
  local randomTown = table.remove(heroes, rand)
  if randomTown then

    local town = 8
    if townKillingIsVeteran then
      town = 7
    end

    rand = math.random(town)

    if rand == 1 then
      randomTown.isSheriff = true
      randomTown.skills = {"sheriff_investigate"}
      print("Sheriff (Random Town): " .. randomTown:GetName())
    elseif rand == 2 then
      randomTown.isDoctor = true
      randomTown.skills = {"doctor_heal"}
      print("Doctor (Random Town): " .. randomTown:GetName())
    elseif rand == 3 then
      randomTown.isInvestigator = true
      randomTown.skills = {"investigator_investigate"}
      print("Investigator (Random Town): " .. randomTown:GetName())
    elseif rand == 4 then
      randomTown.medium = true
      randomTown.skills = {"medium_passive"}
      print("Medium (Random Town): " .. randomTown:GetName())
    elseif rand == 5 then
      randomTown.isEscort = true
      randomTown.skills = {"escorter_escort"}
      print("Escort (Random Town): " .. randomTown:GetName())
    elseif rand == 6 then
      randomTown.isLookout = true
      randomTown.skills = {"lookout_investigate"}
      print("Lookout (Random Town): " .. randomTown:GetName())
    elseif rand == 7 then
      randomTown.isVigilante = true
      randomTown.skills = {"vigilante_shoot"}
      print("Vigilante (Random Town): " .. randomTown:GetName())
    elseif rand == 8 then
      randomTown.isVeteran = true
      randomTown.skills = {"veteran_alert"}
      print("Veteran (Random Town): " .. randomTown:GetName())
    end
  end

  rand = math.random(#heroes)
  local jester = table.remove(heroes, rand)
  if jester then
    print("Jester: " .. jester:GetName())
    jester.isJester = true
    jester.skills = {"jester_passive"}
    jester.daySkills = {"jester_passive"}
  end

end

function GameMode:SetSkills(hero)
  if self.gameState == 0 then
    for i=1, 4 do
      local abil = hero:GetAbilityByIndex(i - 1)
      if abil then
        hero:RemoveAbility(abil:GetAbilityName())
      end
      if hero.skills and i <= #hero.skills then
        hero:AddAbility(hero.skills[i])
        hero:GetAbilityByIndex(i - 1):SetLevel(1)
      end
    end

  elseif self.gameState == -1 or self.gameState == 1 or self.gameState == 3 or self.gameState == 5 then
    for i=1, 4 do
      local abil = hero:GetAbilityByIndex(i - 1)
      if abil then
        hero:RemoveAbility(abil:GetAbilityName())
      end
      if hero.daySkills and i <= #hero.daySkills then
        hero:AddAbility(hero.daySkills[i])
        hero:GetAbilityByIndex(i - 1):SetLevel(1)
      end
    end

  elseif self.gameState == 2 then
    for i=1, 4 do
      local abil = hero:GetAbilityByIndex(i - 1)
      if abil then
        hero:RemoveAbility(abil:GetAbilityName())
      end
      if i == 1 then
        hero:AddAbility("vote_for_trial")
        hero:GetAbilityByIndex(i - 1):SetLevel(1)
      end
    end

  elseif self.gameState == 4 then
    for i=1, 4 do
      local abil = hero:GetAbilityByIndex(i - 1)
      if abil then
        hero:RemoveAbility(abil:GetAbilityName())
      end
      if i == 1 and self.votedPlayer ~= hero then
        hero:AddAbility("trial_vote_yes")
        hero:GetAbilityByIndex(i - 1):SetLevel(1)
      elseif i == 2 and self.votedPlayer ~= hero then
        hero:AddAbility("trial_vote_no")
        hero:GetAbilityByIndex(i - 1):SetLevel(1)
      end
    end
  end

end

function GameMode:SetChatPermission(hero)

end

function GameMode:RoleActions(hero)
  if self.gameState == 1 then
    if hero.isMarkedForDeath and not hero.isHealed then
      hero:RemoveModifierByName("modifier_general_player_passives")
      hero:SetCustomHealthLabel(GameMode:ConvertEngineName(hero:GetName()) .. '\n"'.. GameMode:GetRole(hero)..'"', 0, 0, 0)
      for i=1, #self.alivePlayers do
        if self.alivePlayers[i] == hero then
          table.remove(self.alivePlayers, i)
        end
      end
      hero:ForceKill(false)
      hero:SetTeam(1)
      hero.killer:IncrementKills(1)
    end
  elseif self.gameState == 2 then

  end
end
 
function GameMode:CleanFlags(hero)
  if self.gameState == 1 then
    hero.vote = "abstain"
    hero.votes = 0
    hero.votedFor = nil
    hero.isMarkedForDeath = false
    hero.isHealed = false
  end
end

function GameMode:GetGameTime(timeLength)
  local time = GameRules:GetGameTime() - self.valveTime + timeLength
  local mins = math.floor(time / 60)
  local seconds = math.floor(time % 60)
  if seconds < 10 then
    seconds = "0"..seconds
  end
  time = mins..":"..seconds
  return time
end

function GameMode:ConvertEngineName(heroEngineName)
  local heroName = string.gsub(string.gsub(string.sub(heroEngineName, 15), "_", " "), "(%l)(%w*)", function(a,b) return string.upper(a)..b end)

  if heroName == "Doom Bringer" then
    heroName = "Doom"
  elseif heroName == "Furion" then
    heroName = "Nature's Prophet"
  elseif heroName == "Keeper Of The Light" then
      heroName = "Keeper of the Light"
  elseif heroName == "Magnataur" then
    heroName = "Magnus"
  elseif heroName == "Nevermore" then
    heroName = "Shadow Fiend"
  elseif heroName == "Obsidian Destroyer" then
    heroName = "Outworld Devourer"
  elseif heroName == "Queenofpain" then
    heroName = "Queen of Pain"
  elseif heroName == "Rattletrap" then
    heroName = "Clockwork"
  elseif heroName == "Shredder" then
    heroName = "Timbersaw"
  elseif heroName == "Skeleton King" then
    heroName = "Wraith King"
  elseif heroName == "Rattletrap" then
    heroName = "Clockwork"
  elseif heroName == "Vengefulspirit" then
    heroName = "Vengeful Spirit"
  elseif heroName == "Windrunner" then
    heroName = "Windranger"
  elseif heroName == "Zuus" then
    heroName = "Zues"
  end
  return heroName
end

function GameMode:GetRole(hero)
  if hero.isSheriff then
    return "Sheriff"
  elseif hero.isDoctor then
    return "Doctor"
  elseif hero.isInvestigator then
    return "Investigator"
  elseif hero.isJailor then
    return "Jailor"
  elseif hero.isMedium then
    return "Medium"
  elseif hero.isGodfather then
    return "Godfather"
  elseif hero.isFramer then
    return "Framer"
  elseif hero.isExecutioner then
    return "Executioner"
  elseif hero.isEscort then
    return "Escort"
  elseif hero.isMafioso then
    return "Mafioso"
  elseif hero.isLookout then
    return "Lookout"
  elseif hero.isSerialKiller then
    return "Serial Killer"
  elseif hero.isVeteran then
    return "Veteran"
  elseif hero.isVigilante then
    return "Vigilante"
  elseif hero.isJester then
    return "Jester"
  else
    return "No Role"
  end
end