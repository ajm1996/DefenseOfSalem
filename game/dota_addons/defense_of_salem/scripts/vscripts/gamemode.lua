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
  PlayerResource:SetCustomPlayerColor(hero:GetPlayerID(), 255, 255, 255)
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
    local heroName = GameMode:ConvertEngineName(playerEntity:GetAssignedHero():GetName())
    local line_duration = 10.0
    Notifications:BottomToAll({hero = playerEntity:GetAssignedHero():GetName(), duration = line_duration})
    Notifications:BottomToAll({text = heroName, style={color="red",["font-size"]="20px"}, duration = line_duration, continue = true})
    Notifications:BottomToAll({text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})
  end)
  UTIL_ResetMessageTextAll()

  self.valveTime = nil
  self.alivePlayers = {}
  self.gameState = nil
  self.dayNum = nil
  self.votedPlayer = nil
  self.dummy = CreateUnitByName("dummy_unit", Vector(0,0,0), true, nil, nil, DOTA_TEAM_BADGUYS)
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
    local timeLength = 10

    GameRules:SetTimeOfDay((360 - timeLength) * (1/480))
    self.dayNum = 1

    Notifications:TopToAll({text = "Day 1", style={["font-size"]="50px"}, duration = 5})

    --force heroes to spawn?
    self.alivePlayers = HeroList:GetAllHeroes()
    GameMode:SetRoles()
    GameMode:ChatHandler()

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

        Notifications:Top(hero:GetPlayerID(), {text = message, style={color="red", ["font-size"]="50px"}, duration = 10})
        if hero.description then
          Notifications:Top(hero:GetPlayerID(), {text = hero.description, style={["font-size"]="30px"}, duration =10})
        end
        if hero.goal then
          Notifications:Top(hero:GetPlayerID(), {text = hero.goal, style={color="yellow", ["font-size"]="30px"}, duration =10})
        end

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
    local timeLength = 10
    self.gameState = 0

    GameRules:SetTimeOfDay((120 - timeLength) * (1/480))
    mode:SetFogOfWarDisabled(false)

    Notifications:TopToAll({text = "Night "..self.dayNum, style={["font-size"]="50px"}, duration = 5})
    GameRules:SendCustomMessage("Day ".. self.dayNum + 1 .." starts at  <bold><font color='#DF0101'>".. GameMode:GetGameTime(timeLength) .. "</font></bold>", 2, timeLength)

    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:RoleActions(hero)
        GameMode:SetSkills(hero)
        GameMode:CleanFlags(hero)
      end
    end

    Timers:CreateTimer(timeLength, function()
      GameMode:StartPhase(1)
    end)

  elseif phase == 1 then  --DAYTIME/DISCUSSION
    print("day phase")
    self.gameState = 1
    local timeLength = 5

    GameRules:SetTimeOfDay((360 - timeLength - 15) * (1/480)) --30 from vote time
    mode:SetFogOfWarDisabled(true)
    self.dayNum = self.dayNum + 1

    Notifications:TopToAll({text = "Day "..self.dayNum, style={["font-size"]="50px"}, duration = 5})
    GameRules:SendCustomMessage("Voting starts at  <bold><font color='#DF0101'>".. GameMode:GetGameTime(timeLength) .. "</font></bold>", 2, timeLength)


    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:RoleActions(hero)
        GameMode:SetSkills(hero)
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
    local timeLength = 15

    Notifications:TopToAll({text = "Today's public vote and trial will now begin.", style={["font-size"]="40px"}, duration = 3})
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
    local timeLength = 5

    GameRules:SetTimeOfDay((360 - timeLength - 5 - 9) * (1/480)) --20 from judgement and 4.5 * 2 from walking

    Notifications:TopToAll({text = "The town has decided to put ", style={["font-size"]="40px"}, duration = 5})
    Notifications:TopToAll({text = GameMode:ConvertEngineName(self.votedPlayer:GetName()).." ", style={color="red", ["font-size"]="40px"}, duration = 5, continue = true})
    Notifications:TopToAll({text = "on trial.", style={["font-size"]="40px"}, duration = 5, continue = true})
    GameRules:SendCustomMessage("Defense ends at  <bold><font color='#DF0101'>".. GameMode:GetGameTime(timeLength) .. "</font></bold>", 2, timeLength)

    --check if day < 4 and save remaining time if true

    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:SetSkills(hero)
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
    local timeLength = 5

    Notifications:TopToAll({text = "The town may now vote on the fate of ", style={["font-size"]="40px"}, duration = 5})
    Notifications:TopToAll({text = GameMode:ConvertEngineName(self.votedPlayer:GetName()), style={color="red", ["font-size"]="40px"}, duration = 5, continue = true})
    GameRules:SendCustomMessage("Judgement ends at  <bold><font color='#DF0101'>".. GameMode:GetGameTime(timeLength) .. "</font></bold>", 2, timeLength)

    --ask for votes

    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:SetSkills(hero)
      end
    end

    Timers:CreateTimer(timeLength, function()
      local guilty = 0
      local innocent = 0
      local abstain = 0

      for i=0,#self.alivePlayers do
        local hero = self.alivePlayers[i]
        if hero and hero ~= self.votedPlayer then
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
    local timeLength = 5

    GameRules:SetTimeOfDay((360 - timeLength - 3) * (1/480))  --3 from kill delay

    Notifications:TopToAll({text = GameMode:ConvertEngineName(self.votedPlayer:GetName()), style={color="red", ["font-size"]="40px"}, duration = timeLength})
    Notifications:TopToAll({text = ", do you have any last words?", style={["font-size"]="40px"}, duration = timeLength, continue = true})

    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:SetSkills(hero)
      end
    end

    --ask for final words

    Timers:CreateTimer(timeLength, function()
      Notifications:TopToAll({text = "May god have mercy on your soul, ", style={["font-size"]="40px"}, duration = 3})
      Notifications:TopToAll({text = GameMode:ConvertEngineName(self.votedPlayer:GetName()), style={color="red", ["font-size"]="40px"}, duration = 3, continue = true})

      for i=1, #self.alivePlayers do
        if self.alivePlayers[i] == self.votedPlayer then
          table.remove(self.alivePlayers, i)
        end
      end
      self.votedPlayer:ForceKill(false)
      self.votedPlayer:SetTeam(DOTA_TEAM_BADGUYS)

      if self.votedPlayer.isExecutionerTarget then
        self.votedPlayer.executioner.targetLynched = true
        Notifications:Bottom(hero:GetPlayerID(), {"Your target was successfully lynched", style={color="red",["font-size"]="20px"}, duration = 5})
      end

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
    sheriff.description = "#sheriff_description"
    sheriff.goal = "#sheriff_goal"
  end

  rand = math.random(#heroes)
  local doctor = table.remove(heroes, rand)
  if doctor then
    print("Doctor: " .. doctor:GetName())
    doctor.isDoctor = true
    doctor.selfHeals = 1
    doctor.skills = {"doctor_heal"}
    doctor.description ="#doctor_description"
    doctor.goal = "#doctor_goal"
  end

  rand = math.random(#heroes)
  local investigator = table.remove(heroes, rand)
  if investigator then
    print("Investigator: " .. investigator:GetName())
    investigator.isInvestigator = true
    investigator.skills = {"investigator_investigate"}
    investigator.description ="#investigator_description"
    investigator.goal = "#investigator_goal"
  end

  rand = math.random(#heroes)
  local jailor = table.remove(heroes, rand)
  if jailor then
    print("Jailor: " .. jailor:GetName())
    jailor.isJailor = true
    jailor.executions = 3
    jailor.skills = {"jailor_execute"}
    jailor.daySkills = {"jailor_jail"}
    jailor.description ="#jailor_description"
    jailor.goal = "#jailor_goal"
  end

  rand = math.random(#heroes)
  local medium = table.remove(heroes, rand)
  if medium then
    print("Medium: " .. medium:GetName())
    medium.isMedium = true
    medium.skills = {"medium_passive"}
    medium.daySkills = {"medium_passive"}
    medium.description ="#medium_description"
    medium.goal = "#medium_goal"
  end

  rand = math.random(#heroes)
  local godfather = table.remove(heroes, rand)
  if godfather then
    print("Godfather: " .. godfather:GetName())
    godfather.isGodfather = true
    godfather.isMafia = true
    godfather.skills = {"godfather_kill"}
    godfather.description ="#godfather_description"
    godfather.goal = "#godfather_goal"
  end

  rand = math.random(#heroes)
  local framer = table.remove(heroes, rand)
  if framer then
    print("Framer: " .. framer:GetName())
    framer.isFramer = true
    framer.isMafia = true
    framer.skills = {"framer_frame"}
    framer.description ="#framer_description"
    framer.goal = "#framer_goal"
  end

  rand = math.random(#heroes)
  local executioner = table.remove(heroes, rand)
  if executioner then
    print("Executioner: " .. executioner:GetName())
    executioner.isExecutioner = true
    executioner.targetLynched = false
    executioner.target = HeroList:GetHero(math.random(#HeroList:GetAllHeroes()))
    executioner.target.isExecutionerTarget = true
    executioner.target.executioner = executioner
    executioner.skills = {"executioner_passive"}
    executioner.daySkills = {"executioner_passive"}
    executioner.description ="#executioner_description"
    executioner.goal = "#executioner_goal"
  end

  rand = math.random(#heroes)
  local escort = table.remove(heroes, rand)
  if escort then
    print("Escort: " .. escort:GetName())
    escort.isEscort = true
    escort.skills = {"escorter_escort"}
    escort.description ="#escort_description"
    escort.goal = "#escort_goal"
  end

  rand = math.random(#heroes)
  local mafioso = table.remove(heroes, rand)
  if mafioso then
    print("Mafioso: " .. mafioso:GetName())
    mafioso.isMafioso = true
    mafioso.isMafia = true
    mafioso.skills = {"mafioso_kill"}
    mafioso.description ="#mafioso_description"
    mafioso.goal = "#mafioso_goal"
  end

  rand = math.random(#heroes)
  local lookout = table.remove(heroes, rand)
  if lookout then
    print("Lookout: " .. lookout:GetName())
    lookout.isLookout = true
    lookout.skills = {"lookout_watch"}
    lookout.description ="#lookout_description"
    lookout.goal = "#lookout_goal"
  end

  rand = math.random(#heroes)
  local serialKiller = table.remove(heroes, rand)
  if serialKiller then
    print("Serial Killer: " .. serialKiller:GetName())
    serialKiller.isSerialKiller = true
    serialKiller.skills = {"serial_killer_kill"}
    serialKiller.description ="#serial_killer_description"
    serialKiller.goal = "#serial_killer_goal"
  end

  rand = math.random(#heroes)
  local townKilling = table.remove(heroes, rand)
  local townKillingIsVeteran = false
  if townKilling then
    rand = math.random(3)
    if rand == 1 then
      print("Veteran (Town Killing): " .. townKilling:GetName())
      townKilling.isVeteran = true
      townKilling.alerts = 3
      townKilling.daySkills = {"veteran_alert"}
      townKilling.description ="#veteran_description"
      townKilling.goal = "#veteran_goal"
    elseif rand == 2 then
      print("Vigilante (Town Killing): " .. townKilling:GetName())
      townKilling.isVigilante = true
      townKilling.bullets = 3
      townKilling.suicide = false
      townKilling.skills = {"vigilante_shoot"}
      townKillingIsVeteran = false
      townKilling.description ="#vigilante_description"
      townKilling.goal = "#vigilante_goal"
    elseif rand == 3 then
      print("Jailor (Town Killing): " .. townKilling:GetName())
      townKilling.isJailor = true
      townKilling.executions = 3
      townKilling.skills = {"jailor_execute"}
      townKilling.daySkills = {"jailor_jail"}
      townKilling.description ="#jailor_description"
      townKilling.goal = "#jailor_goal"
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
      print("Sheriff (Random Town): " .. randomTown:GetName())
      randomTown.isSheriff = true
      randomTown.skills = {"sheriff_investigate"}
      randomTown.description ="#sheriff_description"
      randomTown.goal = "#sheriff_goal"
    elseif rand == 2 then
      print("Doctor (Random Town): " .. randomTown:GetName())
      randomTown.isDoctor = true
      randomTown.selfHeals = 1
      randomTown.skills = {"doctor_heal"}
      randomTown.description ="#doctor_description"
      randomTown.goal = "#doctor_goal"
    elseif rand == 3 then
      print("Investigator (Random Town): " .. randomTown:GetName())
      randomTown.isInvestigator = true
      randomTown.skills = {"investigator_investigate"}
      randomTown.description ="#investigator_description"
      randomTown.goal = "#investigator_goal"
    elseif rand == 4 then
      print("Medium (Random Town): " .. randomTown:GetName())
      randomTown.medium = true
      randomTown.skills = {"medium_passive"}
      randomTown.daySkills = {"medium_passive"}
      randomTown.description ="#medium_description"
      randomTown.goal = "#medium_goal"
    elseif rand == 5 then
      print("Escort (Random Town): " .. randomTown:GetName())
      randomTown.isEscort = true
      randomTown.skills = {"escorter_escort"}
      randomTown.description ="#escort_description"
      randomTown.goal = "#escort_goal"
    elseif rand == 6 then
      print("Lookout (Random Town): " .. randomTown:GetName())
      randomTown.isLookout = true
      randomTown.skills = {"lookout_watch"}
      randomTown.description ="#lookout_description"
      randomTown.goal = "#lookout_goal"
    elseif rand == 7 then
      print("Vigilante (Random Town): " .. randomTown:GetName())
      randomTown.isVigilante = true
      randomTown.bullets = 3
      randomTown.suicide = false
      randomTown.skills = {"vigilante_shoot"}
      randomTown.description ="#vigilante_description"
      randomTown.goal = "#vigilante_goal"
    elseif rand == 8 then
      print("Veteran (Random Town): " .. randomTown:GetName())
      randomTown.isVeteran = true
      randomTown.alerts = 3
      randomTown.skills = {"veteran_alert"}
      randomTown.description ="#veteran_description"
      randomTown.goal = "#veteran_goal"
    end
  end

  rand = math.random(#heroes)
  local jester = table.remove(heroes, rand)
  if jester then
    print("Jester: " .. jester:GetName())
    jester.isJester = true
    jester.skills = {"jester_passive"}
    jester.daySkills = {"jester_passive"}
    jester.description ="#jester_description"
    jester.goal = "#jester_goal"
  end

end

function GameMode:SetSkills(hero)
  if self.gameState == 0 and not hero.isJailed then
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
        hero:AddAbility("trial_vote_no")
        hero:GetAbilityByIndex(i - 1):SetLevel(1)
      elseif i == 2 and self.votedPlayer ~= hero then
        hero:AddAbility("trial_vote_yes")
        hero:GetAbilityByIndex(i - 1):SetLevel(1)
      end
    end
  end

end

function GameMode:ChatHandler()
  PlayerSay:ChatHandler(function(playerEntity, text)

    if text == "" or not playerEntity:GetAssignedHero() then
      return
    end

    local heroName = GameMode:ConvertEngineName(playerEntity:GetAssignedHero():GetName())
    local line_duration = 10.0

    if playerEntity:GetAssignedHero():GetTeam() == 3 then

      local heroes = HeroList:GetAllHeroes()
      for i=1,#heroes do
        local hero = heroes[i]
        if not hero:IsAlive() then
          Notifications:Bottom(hero:GetPlayerID(), {hero = playerEntity:GetAssignedHero():GetName(), duration = line_duration})
          Notifications:Bottom(hero:GetPlayerID(), {text = heroName, style={color="grey",["font-size"]="20px"}, duration = line_duration, continue = true})
          Notifications:Bottom(hero:GetPlayerID(), {text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})
        end
      end

      if self.gameState == 0 then
        for i=1,#self.alivePlayers do
          local hero = self.alivePlayers[i]
          if hero.isMedium and not hero.isJailed then
            Notifications:Bottom(hero:GetPlayerID(), {hero = playerEntity:GetAssignedHero():GetName(), duration = line_duration})
            Notifications:Bottom(hero:GetPlayerID(), {text = heroName, style={color="grey",["font-size"]="20px"}, duration = line_duration, continue = true})
            Notifications:Bottom(hero:GetPlayerID(), {text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})
          end
        end
      end


    elseif self.gameState == -1 or self.gameState == 1 or self.gameState == 4 then

      Notifications:BottomToAll({hero = playerEntity:GetAssignedHero():GetName(), duration = line_duration})
      Notifications:BottomToAll({text = heroName, style={color="red",["font-size"]="20px"}, duration = line_duration, continue = true})
      Notifications:BottomToAll({text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})


    elseif self.gameState == 0 then

      if playerEntity:GetAssignedHero().isMafia then
        for i=1,#self.alivePlayers do
          local hero = self.alivePlayers[i]
          if hero.isMafia then
            Notifications:Bottom(hero:GetPlayerID(), {hero = playerEntity:GetAssignedHero():GetName(), duration = line_duration})
            Notifications:Bottom(hero:GetPlayerID(), {text = "(Mafia) "..heroName, style={color="red",["font-size"]="20px"}, duration = line_duration, continue = true})
            Notifications:Bottom(hero:GetPlayerID(), {text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})
          end
        end

      elseif playerEntity:GetAssignedHero().isJailor then
        Notifications:Bottom(playerEntity:GetPlayerID(), {text = "Jailor", style={color="red",["font-size"]="20px"}, duration = line_duration})
        Notifications:Bottom(playerEntity:GetPlayerID(), {text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})

        Notifications:Bottom(playerEntity:GetAssignedHero().prisoner:GetPlayerID(), {text = "Jailor", style={color="red",["font-size"]="20px"}, duration = line_duration})
        Notifications:Bottom(playerEntity:GetAssignedHero().prisoner:GetPlayerID(), {text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})
      
      elseif playerEntity:GetAssignedHero().jailed then
        Notifications:Bottom(playerEntity:GetPlayerID(), {hero = playerEntity:GetAssignedHero():GetName(), duration = line_duration})
        Notifications:Bottom(playerEntity:GetPlayerID(), {text = heroName, style={color="red",["font-size"]="20px"}, duration = line_duration})
        Notifications:Bottom(playerEntity:GetPlayerID(), {text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})

        Notifications:Bottom(playerEntity:GetAssignedHero().prisoner:GetPlayerID(), {hero = playerEntity:GetAssignedHero():GetName(), duration = line_duration})
        Notifications:Bottom(playerEntity:GetAssignedHero().prisoner:GetPlayerID(), {text = heroName, style={color="red",["font-size"]="20px"}, duration = line_duration})
        Notifications:Bottom(playerEntity:GetAssignedHero().prisoner:GetPlayerID(), {text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})

      elseif playerEntity:GetAssignedHero().isMedium then
        Notifications:Bottom(playerEntity:GetPlayerID(), {hero = playerEntity:GetAssignedHero():GetName(), duration = line_duration})
        Notifications:Bottom(playerEntity:GetPlayerID(), {text = "Medium", style={color="yellow",["font-size"]="20px"}, duration = line_duration})
        Notifications:Bottom(playerEntity:GetPlayerID(), {text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})

        local heroes = HeroList:GetAllHeroes()
        for i=1,#heroes do
          local hero = heroes[i]
          if not hero:IsAlive() then
            Notifications:Bottom(hero:GetPlayerID(), {hero = playerEntity:GetAssignedHero():GetName(), duration = line_duration})
            Notifications:Bottom(hero:GetPlayerID(), {text = "Medium", style={color="grey",["font-size"]="20px"}, duration = line_duration, continue = true})
            Notifications:Bottom(hero:GetPlayerID(), {text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})
          end
        end

      else
        Notifications:Bottom(playerEntity:GetPlayerID(), {text = "No one can hear you", style={color="red",["font-size"]="20px"}, duration = line_duration / 2})
      end


    elseif self.gameState == 3 or self.gameState == 5 then
      if playerEntity:GetAssignedHero() == self.votedPlayer then
        Notifications:BottomToAll({hero = playerEntity:GetAssignedHero():GetName(), duration = line_duration})
        Notifications:BottomToAll({text = heroName, style={color="red",["font-size"]="20px"}, duration = line_duration, continue = true})
        Notifications:BottomToAll({text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})

      else
        Notifications:Bottom(playerEntity:GetPlayerID(), {text = "No one can hear you", style={color="red",["font-size"]="20px"}, duration = line_duration / 2})
      end
    end
  end)
end

function GameMode:RoleActions(hero)
  if self.gameState == 1 then

    if hero.isVeteran then
      Notifications:Bottom(hero:GetPlayerID(), {"You have ".. hero.alerts .." alerts left", style={color="red",["font-size"]="20px"}, duration = 5})
    end
    
    if hero.isInvestigatedBySheriff and not hero.sheriff.isEscorted then
      if hero.isSheriff or hero.isDoctor or hero.isInvestigator or hero.isJailor or hero.isMedium or hero.isGodfather or hero.isExecutioner or hero.isEscort or hero.isLookout or hero.isVigilante or hero.isVeteran or hero.isJester then
        Notifications:Bottom(hero.sheriff:GetPlayerID(), {text = "Your target is not suspicious", style={["font-size"]="20px"}, duration = 5})
      elseif hero.isFramer or hero.isMafioso then
        Notifications:Bottom(hero.sheriff:GetPlayerID(), {text = "Your target is a member of the Mafia", style={["font-size"]="20px"}, duration = 5})
      elseif hero.isSerialKiller then
        Notifications:Bottom(hero.sheriff:GetPlayerID(), {text = "Your target is a Serial Killer", style={["font-size"]="20px"}, duration = 5})
      end
    end

    if hero.isInvestigatedByInvestigator and not hero.investigator.isEscorted then
      if not hero.isFramed then

        if hero.isSheriff or hero.isExecutioner then
          Notifications:Bottom(hero.investigator:GetPlayerID(), {text = "Your target seeks justice. Therefore your target must be a Sheriff or Executioner.", style={["font-size"]="20px"}, duration = 5})
        end

        if hero.isDoctor or hero.isSerialKiller then
          Notifications:Bottom(hero.investigator:GetPlayerID(), {text = "Your target is covered in blood. They must be a Doctor or Serial Killer", style={["font-size"]="20px"}, duration = 5})
        end

        if hero.isInvestigator then
          Notifications:Bottom(hero.investigator:GetPlayerID(), {text = "Your target gathers information. They must be an Investigator.", style={["font-size"]="20px"}, duration = 5})
        end

        if hero.isJailor or hero.isLookout then
          Notifications:Bottom(hero.investigator:GetPlayerID(), {text = "Your target is a protector. They must be a Jailor or a Lookout.", style={["font-size"]="20px"}, duration = 5})
        end

        if hero.isMedium then
          Notifications:Bottom(hero.investigator:GetPlayerID(), {text = "Your target works with dead bodies. They must be a Medium.", style={["font-size"]="20px"}, duration = 5})
        end

        if hero.isGodfather then
          Notifications:Bottom(hero.investigator:GetPlayerID(), {text = "Your target takes charge. They must be a Godfather.", style={["font-size"]="20px"}, duration = 5})
        end

        if hero.isFramer then
          Notifications:Bottom(hero.investigator:GetPlayerID(), {text = "Your target is good with documents. They must be a Framer.", style={["font-size"]="20px"}, duration = 5})
        end

        if hero.isEscort then
          Notifications:Bottom(hero.investigator:GetPlayerID(), {text = "Your target is a manipulative beauty. They must be an Escort.", style={["font-size"]="20px"}, duration = 5})
        end

        if hero.isMafioso or hero.isVigilante or hero.isVeteran then
          Notifications:Bottom(hero.investigator:GetPlayerID(), {text = "Your target works with weapons. They must be a Vigilante, Veteran, or Mafioso.", style={["font-size"]="20px"}, duration = 5})
        end

        if hero.isJester then
          Notifications:Bottom(hero.investigator:GetPlayerID(), {text = "Your target enjoys tricking people. They must be a Jester.", style={["font-size"]="20px"}, duration = 5})
        end

      else 
        Notifications:Bottom(hero.investigator:GetPlayerID(), {text = "Your target is good with documents. They must be a Framer.", style={["font-size"]="20px"}, duration = 5})
      end
    end


    if hero.isExecuted and not hero.jailor.isEscorted then
      
      if hero.isSerialKiller or hero.isGodfather or hero.isMafioso or hero.isFramer or hero.isJester or hero.isExecutioner then
        hero.executor.executes = hero.executor.executes - 1
      else
        hero.executor.executes = 0
      end
      
      hero:RemoveModifierByName("modifier_general_player_passives")
      hero:SetCustomHealthLabel(GameMode:ConvertEngineName(hero:GetName()) .. '\n"'.. GameMode:GetRole(hero)..'"', 0, 0, 0)
      for i=1, #self.alivePlayers do
        if self.alivePlayers[i] == hero then
          table.remove(self.alivePlayers, i)
        end
      end
      hero:ForceKill(false)
      hero:SetTeam(DOTA_TEAM_BADGUYS)
      hero.killer:IncrementKills(1)

      Notifications:Bottom(hero.jailor:GetPlayerID(), {"You executed ".. GameMode:ConvertEngineName(hero.prisoner:GetName()) .." last night", style={color="red",["font-size"]="20px"}, duration = 5})
      Notifications:Bottom(hero:GetPlayerID(), {"You were executed by the jailor last night", style={color="red",["font-size"]="20px"}, duration = 5})
    end

    if hero.isJailed and hero.isSerialKiller and not hero.isExecuted then
      hero.jailor:RemoveModifierByName("modifier_general_player_passives")
      hero.jailor:SetCustomHealthLabel(GameMode:ConvertEngineName(hero:GetName()) .. '\n"'.. GameMode:GetRole(hero)..'"', 0, 0, 0)
      for i=1, #self.alivePlayers do
        if self.alivePlayers[i] == hero.jailor then
          table.remove(self.alivePlayers, i)
        end
      end
      hero:ForceKill(false)
      hero:SetTeam(DOTA_TEAM_BADGUYS)
      hero.killer:IncrementKills(1)

      Notifications:Bottom(hero.jailor:GetPlayerID(), {"You were attacked by the Serial Killer you jailed!", style={color="red",["font-size"]="20px"}, duration = 5})
      Notifications:Bottom(hero:GetPlayerID(), {"You killed the jailor who jailed you last night!", style={color="red",["font-size"]="20px"}, duration = 5})
    end


    --mafia here


    if hero.isEscorted then
      if not hero.isSerialKiller then
        Notifications:Bottom(hero:GetPlayerID(), {"You were role blocked last night!", style={color="red",["font-size"]="20px"}, duration = 5})
        Notifications:Bottom(hero.escorter:GetPlayerID(), {"You escorted ".. GameMode:ConvertEngineName(hero:GetName()) .." last night", style={color="red",["font-size"]="20px"}, duration = 5})
      else
        Notifications:Bottom(hero:GetPlayerID(), {"You were role blocked and killed the roleblocker instead!", style={color="red",["font-size"]="20px"}, duration = 5})
        Notifications:Bottom(hero:GetPlayerID(), {"You role blocked the Serial Killer and they killed you instead!", style={color="red",["font-size"]="20px"}, duration = 5})
      end
    end

    if hero.isWatchedByLookout and not hero.lookout.isEscorted then

      if hero.isInvestigatedBySheriff then
        Notifications:Bottom(hero.lookout:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.sheriff:GetName()) .." last night", style={color="red",["font-size"]="20px"}, duration = 5})
      end

      if hero.isHealed then
        Notifications:Bottom(hero.lookout:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.doctor:GetName()) .." last night", style={color="red",["font-size"]="20px"}, duration = 5})
      end

      if hero.isInvestigatedByInvestigator then
        Notifications:Bottom(hero.lookout:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.investigator:GetName()) .." last night", style={color="red",["font-size"]="20px"}, duration = 5})
      end

      if hero.isJailed then
        Notifications:Bottom(hero.lookout:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.jailor:GetName()) .." last night", style={color="red",["font-size"]="20px"}, duration = 5})
      end

      if hero.isKilledByMafioso then
        Notifications:Bottom(hero.lookout:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.mafiosoKiller:GetName()) .." last night", style={color="red",["font-size"]="20px"}, duration = 5})
      end

      if hero.isKilledByGodfather then
        Notifications:Bottom(hero.lookout:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.godfatherKiller:GetName()) .." last night", style={color="red",["font-size"]="20px"}, duration = 5})
      end

      if hero.isFramed then
        Notifications:Bottom(hero.lookout:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.framer:GetName()) .." last night", style={color="red",["font-size"]="20px"}, duration = 5})
      end

      if hero.isEscorted then
        Notifications:Bottom(hero.lookout:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.escorter:GetName()) .." last night", style={color="red",["font-size"]="20px"}, duration = 5})
      end

      if hero.isWatchedByLookout then
        Notifications:Bottom(hero.lookout:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.lookout:GetName()) .." last night", style={color="red",["font-size"]="20px"}, duration = 5})
      end

      if hero.isKilledBySK then
        Notifications:Bottom(hero.lookout:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.skKiller:GetName()) .." last night", style={color="red",["font-size"]="20px"}, duration = 5})
      end

      if hero.isKilledByVig then
        Notifications:Bottom(hero.lookout:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.vigKiller:GetName()) .." last night", style={color="red",["font-size"]="20px"}, duration = 5})
      end
    end



    --[[if hero.isMarkedForDeath and not hero.isHealed then
      hero:RemoveModifierByName("modifier_general_player_passives")
      hero:SetCustomHealthLabel(GameMode:ConvertEngineName(hero:GetName()) .. '\n"'.. GameMode:GetRole(hero)..'"', 0, 0, 0)
      for i=1, #self.alivePlayers do
        if self.alivePlayers[i] == hero then
          table.remove(self.alivePlayers, i)
        end
      end
      hero:ForceKill(false)
      hero:SetTeam(DOTA_TEAM_BADGUYS)
      hero.killer:IncrementKills(1)
    end
    ]]

    if hero.isExecutioner then
      if hero.target:IsAlive() then
        Notifications:Bottom(hero:GetPlayerID(), {"Your target, ".. GameMode:ConvertEngineName(hero.target:GetName()) ..", is still alive", style={color="red",["font-size"]="20px"}, duration = 5})
      else
        Notifications:Bottom(hero:GetPlayerID(), {"Your target, ".. GameMode:ConvertEngineName(hero.target:GetName()) ..", has died during the night, you are now a jester", style={color="red",["font-size"]="20px"}, duration = 5})
        
        hero.isExecutioner = false
        hero.skills = {"executioner_passive"}
        hero.daySkills = {"executioner_passive"}

        hero.isJester = true
        hero.skills = {"jester_passive"}
        hero.daySkills = {"jester_passive"}
      end
    end

  elseif self.gameState == 0 then

    if hero.isVigilante then
      Notifications:Bottom(hero:GetPlayerID(), {"You have ".. hero.bullets .." bullets left", style={color="red",["font-size"]="20px"}, duration = 5})
    end

    if hero.isJailor then
      Notifications:Bottom(hero:GetPlayerID(), {"You have ".. hero.executions .." executions left", style={color="red",["font-size"]="20px"}, duration = 5})
    end

    if hero.isJailed then
      Notifications:Bottom(hero:GetPlayerID(), {"You were jailed for the night", style={color="red",["font-size"]="20px"}, duration = 5})
    end

  end
end
 
function GameMode:CleanFlags(hero)
  if self.gameState == 1 then
    hero.isInvestigatedBySheriff = false
    hero.sheriff = nil
    hero.investigated = nil

    hero.isHealed = false
    hero.doctor = nil
    hero.healed = nil

    hero.isInvestigatedByInvestigator = false
    hero.investigator = nil
    hero.investigated = nil

    hero.isJailed = false
    hero.jailor = nil
    hero.jailed = nil

    hero.isExecuted = false
    hero.executor = nil
    hero.executed = nil

    hero.isKilledByMafioso = false
    hero.mafiosoKiller = nil

    hero.isKilledByGodfather = false
    hero.godfatherKiller = nil
    hero.killed = nil

    hero.isFramed = false
    hero.framer = nil
    hero.framed = nil

    hero.isEscorted = false
    hero.escorter = nil
    hero.escorted = nil

    hero.isSuggestedByMafioso = false
    hero.mafiosoSuggestor = nil
    hero.suggested = nil

    hero.isWatchedByLookout = false
    hero.lookout = nil
    hero.watched = nil

    hero.isKilledBySK = false
    hero.skKiller = nil
    hero.killed = nil

    hero.alert = false

    hero.isKilledByVig = false
    hero.vigKiller = nil
    hero.killed = nil

    hero.isKilledByJester = false
    hero.jesterKiller = nil
    hero.killed = nil

  elseif self.gameState == 0 then
    hero.votedFor = nil
    hero.votes = 0
    hero.vote = "abstain"
    self.votedPlayer = nil
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
    heroName = "Zeus"
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