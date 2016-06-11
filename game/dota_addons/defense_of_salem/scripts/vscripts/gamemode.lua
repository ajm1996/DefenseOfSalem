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

  hero.role = nil
  hero.affected = {}
  hero.effects = {}
  hero.skills = {}
  hero.desription = nil
  hero.goal = nil
  hero.isMafia = false
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

  self.valveTime = nil  -- trademark
  self.alivePlayers = {}
  self.mafia = {}
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
  
  GameMode:SetRoles()
  GameMode:ChatHandler()
  self.valveTime = GameRules:GetGameTime()

  GameMode:StartPhase(-1)
end

function GameMode:StartPhase(phase)
  if phase == -1 then     --PREGAME
    self.gameState = -1
    local timeLength = 10

    --force players to spawn with random hero?

    self.dayNum = 1
    GameRules:SetTimeOfDay((360 - timeLength) * (1/480))

    Notifications:TopToAll({text = "Day 1", style={["font-size"]="50px"}, duration = 10})
    
    self.alivePlayers = HeroList:GetAllHeroes()

    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:SetSkills(hero)
        local message = "You are "
        local first = string.sub(hero.role, 1, 1)
        if first == "A" or first == "E" or first == "I" or first == "O" or first == "U" then
          message = message .. "an "
        else
          message = message .. "a "
        end
        message = message .. hero.role

        Notifications:Top(hero:GetPlayerID(), {text = message, style={color="red", ["font-size"]="50px"}, duration = 10})
        if hero.description then
          Notifications:Top(hero:GetPlayerID(), {text = hero.description, style={["font-size"]="30px"}, duration =10})
        end
        if hero.goal then
          Notifications:Top(hero:GetPlayerID(), {text = hero.goal, style={color="yellow", ["font-size"]="30px"}, duration =10})
        end

      end
    end
    Timers:CreateTimer(0.03, function()   --wait a frame for day time to be set (to display correct time)
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

    Notifications:TopToAll({text = "Night "..self.dayNum, style={["font-size"]="50px"}, duration = 10})
    GameRules:SendCustomMessage("Day ".. self.dayNum + 1 .." starts at  <bold><font color='#DF0101'>".. GameMode:GetGameTime(timeLength) .. "</font></bold>", 2, timeLength)

    GameMode:RoleActions()
    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:SetSkills(hero)
        GameMode:CleanFlags(hero)
      end
    end
    self.votedPlayer = nil

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

    Notifications:TopToAll({text = "Day "..self.dayNum, style={["font-size"]="50px"}, duration = 10})
    GameRules:SendCustomMessage("Voting starts at  <bold><font color='#DF0101'>".. GameMode:GetGameTime(timeLength) .. "</font></bold>", 2, timeLength)


    GameMode:RoleActions()
    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
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

    if self.voteTimeRemain > 0 and self.dayNum > 4 then
      timeLength = self.voteTimeRemain
    end
    
    local start = GameRules:GetGameTime()

    Notifications:TopToAll({text = "Today's public vote and trial will now begin.", style={["font-size"]="40px"}, duration = 3})
    GameRules:SendCustomMessage("Voting ends at  <bold><font color='#DF0101'>".. GameMode:GetGameTime(timeLength) .. "</font></bold>", 2, timeLength)

    Timers:CreateTimer(4, function()
      Notifications:TopToAll({text = math.ceil(#self.alivePlayers / 2) .. " votes are needed to send someone to trial.", style={["font-size"]="40px"}, duration = 10})
    end)

    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then
        GameMode:SetSkills(hero)
      end
      if hero.role == "Executioner" then
        Notifications:Bottom(hero:GetPlayerID(), {text="Your target is ".. GameMode:ConvertEngineName(hero.target:GetName()), style={color="red", ["font-size"]="20px"}, duration = 10})
      end
    end

    local flag = false
    Timers:CreateTimer(timeLength, function()
      flag = true
    end)
    
    Timers:CreateTimer(function()
      if self.votedPlayer then
        if self.dayNum < 4 then
          self.voteTimeRemain = timeLength - (GameRules:GetGameTime() - start)
        end
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

    Notifications:TopToAll({text = "The town has decided to put ", style={["font-size"]="40px"}, duration = 10})
    Notifications:TopToAll({text = GameMode:ConvertEngineName(self.votedPlayer:GetName()).." ", style={color="red", ["font-size"]="40px"}, duration = 10, continue = true})
    Notifications:TopToAll({text = "on trial.", style={["font-size"]="40px"}, duration = 10, continue = true})
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
        
        Notifications:TopToAll({text = GameMode:ConvertEngineName(self.votedPlayer:GetName()), style={color="red", ["font-size"]="40px"}, duration = 10})
        Notifications:TopToAll({text = ", you are on trial for conspiracy against the town.", style={["font-size"]="40px"}, duration = 10, continue = true})
        Notifications:TopToAll({text = "What is your defense?", style={color="red", ["font-size"]="40px"}, duration = 10})
        
        Timers:CreateTimer(timeLength, function()
          GameMode:StartPhase(4)
        end)
      end
    end)

  elseif phase == 4 then  --JUDGEMENT
    print("judgement phase")
    self.gameState = 4
    local timeLength = 5

    Notifications:TopToAll({text = "The town may now vote on the fate of ", style={["font-size"]="40px"}, duration = 10})
    Notifications:TopToAll({text = GameMode:ConvertEngineName(self.votedPlayer:GetName()), style={color="red", ["font-size"]="40px"}, duration = 10, continue = true})
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
            GameMode:StartPhase(0)
          end
        end)
      else
        self.voteTimeRemain = 0
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

    Timers:CreateTimer(timeLength, function()
      if not self.votedPlayer.role == "Jester" then
        Notifications:TopToAll({text = "May god have mercy on your soul, ", style={["font-size"]="40px"}, duration = 3})
        Notifications:TopToAll({text = GameMode:ConvertEngineName(self.votedPlayer:GetName()), style={color="red", ["font-size"]="40px"}, duration = 3, continue = true})

        GameMode:Kill(self.votedPlayer)
      else
        Notifications:TopToAll({text = GameMode:ConvertEngineName(self.votedPlayer:GetName()), style={color="red", ["font-size"]="40px"}, duration = 5})
        Notifications:TopToAll({text = " was the Jester and is now a troubled ghost!", style={["font-size"]="40px"}, duration = 5, continue = true})
        self.votedPlayer.isGhost = true
      end

      if self.votedPlayer.isExecutionerTarget then
        self.votedPlayer.executioner.targetLynched = true
        Notifications:Bottom(hero:GetPlayerID(), {"Your target was successfully lynched", style={color="red",["font-size"]="20px"}, duration = 10})
      end

      Timers:CreateTimer(3, function()
        FindClearSpaceForUnit(self.votedPlayer, self.votedPlayer.home, false)
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
    sheriff.role = "Sheriff"
    sheriff.skills = {"sheriff_investigate"}
    sheriff.description = "#sheriff_description"
    sheriff.goal = "#sheriff_goal"
  end

  rand = math.random(#heroes)
  local doctor = table.remove(heroes, rand)
  if doctor then
    print("Doctor: " .. doctor:GetName())
    doctor.role = "Doctor"
    doctor.selfHeals = 1
    doctor.skills = {"doctor_heal"}
    doctor.description ="#doctor_description"
    doctor.goal = "#doctor_goal"
  end

  rand = math.random(#heroes)
  local investigator = table.remove(heroes, rand)
  if investigator then
    print("Investigator: " .. investigator:GetName())
    investigator.role = "Investigator"
    investigator.skills = {"investigator_investigate"}
    investigator.description ="#investigator_description"
    investigator.goal = "#investigator_goal"
  end

  rand = math.random(#heroes)
  local jailor = table.remove(heroes, rand)
  if jailor then
    print("Jailor: " .. jailor:GetName())
    jailor.role = "Jailor"
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
    medium.role = "Medium"
    medium.skills = {"medium_passive"}
    medium.daySkills = {"medium_passive"}
    medium.description ="#medium_description"
    medium.goal = "#medium_goal"
  end

  rand = math.random(#heroes)
  local godfather = table.remove(heroes, rand)
  if godfather then
    print("Godfather: " .. godfather:GetName())
    godfather.role = "Godfather"
    godfather.isMafia = true
    self.Mafia["Godfather"] = godfather
    godfather.skills = {"godfather_kill"}
    godfather.description ="#godfather_description"
    godfather.goal = "#godfather_goal"
  end

  rand = math.random(#heroes)
  local framer = table.remove(heroes, rand)
  if framer then
    print("Framer: " .. framer:GetName())
    framer.role = "Framer"
    framer.isMafia = true
    self.Mafia["Framer"] = framer
    framer.skills = {"framer_frame"}
    framer.description ="#framer_description"
    framer.goal = "#framer_goal"
  end

  rand = math.random(#heroes)
  local executioner = table.remove(heroes, rand)
  if executioner then
    print("Executioner: " .. executioner:GetName())
    executioner.role = "Executioner"
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
    escort.role = "Escort"
    escort.skills = {"escorter_escort"}
    escort.description ="#escort_description"
    escort.goal = "#escort_goal"
  end

  rand = math.random(#heroes)
  local mafioso = table.remove(heroes, rand)
  if mafioso then
    print("Mafioso: " .. mafioso:GetName())
    mafioso.role = "Mafioso"
    mafioso.isMafia = true
    self.Mafia["Mafioso"] = mafioso
    mafioso.skills = {"mafioso_kill"}
    mafioso.description ="#mafioso_description"
    mafioso.goal = "#mafioso_goal"
  end

  rand = math.random(#heroes)
  local lookout = table.remove(heroes, rand)
  if lookout then
    print("Lookout: " .. lookout:GetName())
    lookout.role = "Lookout"
    lookout.skills = {"lookout_watch"}
    lookout.description ="#lookout_description"
    lookout.goal = "#lookout_goal"
  end

  rand = math.random(#heroes)
  local serialKiller = table.remove(heroes, rand)
  if serialKiller then
    print("Serial Killer: " .. serialKiller:GetName())
    serialKiller.role = "Serial Killer"
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
      townKilling.role = "Veteran"
      townKilling.alerts = 3
      townKilling.daySkills = {"veteran_alert"}
      townKilling.description ="#veteran_description"
      townKilling.goal = "#veteran_goal"
      townKillingIsVeteran = true
    elseif rand == 2 then
      print("Vigilante (Town Killing): " .. townKilling:GetName())
      townKilling.role = "Vigilante"
      townKilling.bullets = 3
      townKilling.suicide = false
      townKilling.skills = {"vigilante_shoot"}
      townKilling.description ="#vigilante_description"
      townKilling.goal = "#vigilante_goal"
    elseif rand == 3 then
      print("Jailor (Town Killing): " .. townKilling:GetName())
      townKilling.role = "Jailor"
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
      randomTown.role = "Sheriff"
      randomTown.skills = {"sheriff_investigate"}
      randomTown.description ="#sheriff_description"
      randomTown.goal = "#sheriff_goal"
    elseif rand == 2 then
      print("Doctor (Random Town): " .. randomTown:GetName())
      randomTown.role = "Doctor"
      randomTown.selfHeals = 1
      randomTown.skills = {"doctor_heal"}
      randomTown.description ="#doctor_description"
      randomTown.goal = "#doctor_goal"
    elseif rand == 3 then
      print("Investigator (Random Town): " .. randomTown:GetName())
      randomTown.role = "Investigator"
      randomTown.skills = {"investigator_investigate"}
      randomTown.description ="#investigator_description"
      randomTown.goal = "#investigator_goal"
    elseif rand == 4 then
      print("Medium (Random Town): " .. randomTown:GetName())
      randomTown.role = "Medium"
      randomTown.skills = {"medium_passive"}
      randomTown.daySkills = {"medium_passive"}
      randomTown.description ="#medium_description"
      randomTown.goal = "#medium_goal"
    elseif rand == 5 then
      print("Escort (Random Town): " .. randomTown:GetName())
      randomTown.role = "Escort"
      randomTown.skills = {"escorter_escort"}
      randomTown.description ="#escort_description"
      randomTown.goal = "#escort_goal"
    elseif rand == 6 then
      print("Lookout (Random Town): " .. randomTown:GetName())
      randomTown.role = "Lookout"
      randomTown.skills = {"lookout_watch"}
      randomTown.description ="#lookout_description"
      randomTown.goal = "#lookout_goal"
    elseif rand == 7 then
      print("Vigilante (Random Town): " .. randomTown:GetName())
      randomTown.role = "Vigilante"
      randomTown.bullets = 3
      randomTown.suicide = false
      randomTown.skills = {"vigilante_shoot"}
      randomTown.description ="#vigilante_description"
      randomTown.goal = "#vigilante_goal"
    elseif rand == 8 then
      print("Veteran (Random Town): " .. randomTown:GetName())
      randomTown.role = "Veteran"
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
    jester.role = "Jester"
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

function GameMode:RoleActions()
  local line_duration = 10.0

  if self.gameState == 1 then
    for i=1,#self.alivePlayers do
      local hero = self.alivePlayers[i]
      if hero then

        if not hero.isEscorted and not hero.isSerialKiller or hero.isJailed then

          if hero.isSheriff then
            if hero.investigated then
              if hero.investigated.isSheriff or hero.investigated.isDoctor or hero.investigated.isInvestigator or hero.investigated.isJailor
                or hero.investigated.isMedium or hero.investigated.isGodfather or hero.investigated.isExecutioner or hero.investigated.isEscort
                or hero.investigated.isLookout or hero.investigated.isVigilante or hero.investigated.isVeteran or hero.investigated.isJester then
                
                Notifications:Bottom(hero:GetPlayerID(), {text = "Your target is not suspicious", style={color="red",["font-size"]="20px"}, duration = line_duration})
              elseif hero.investigated.isFramer or hero.investigated.isMafioso then
                Notifications:Bottom(hero:GetPlayerID(), {text = "Your target is a member of the Mafia", style={color="red",["font-size"]="20px"}, duration = line_duration})
              elseif hero.investigated.isSerialKiller then
                Notifications:Bottom(hero:GetPlayerID(), {text = "Your target is a Serial Killer", style={color="red",["font-size"]="20px"}, duration = line_duration})
              end
            else
              Notifications:Bottom(hero:GetPlayerID(), {text = "You did not choose a target to invesigate.", style={color="red",["font-size"]="20px"}, duration = line_duration})
            end

          elseif hero.isDoctor then

            if hero.healed then
              if hero.healed.isKilledByMafioso or hero.healed.isKilledByGodfather or hero.isKilledBySK or hero.isKilledByVig or hero.isKilledByVet then

              end
            else
              
            end

          elseif hero.isInvestigator then
            if hero.investigated then
              if not hero.investigated.isFramed then

                if hero.investigated.isSheriff or hero.investigated.isExecutioner then
                  Notifications:Bottom(hero:GetPlayerID(), {text = "Your target seeks justice. Therefore your target must be a Sheriff or Executioner.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                end

                if hero.investigated.isDoctor or hero.investigated.isSerialKiller then
                  Notifications:Bottom(hero:GetPlayerID(), {text = "Your target is covered in blood. They must be a Doctor or Serial Killer", style={color="red",["font-size"]="20px"}, duration = line_duration})
                end

                if hero.investigated.isInvestigator then
                  Notifications:Bottom(hero:GetPlayerID(), {text = "Your target gathers information. They must be an Investigator.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                end

                if hero.investigated.isJailor or hero.investigated.isLookout then
                  Notifications:Bottom(hero:GetPlayerID(), {text = "Your target is a protector. They must be a Jailor or a Lookout.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                end

                if hero.investigated.isMedium then
                  Notifications:Bottom(hero:GetPlayerID(), {text = "Your target works with dead bodies. They must be a Medium.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                end

                if hero.investigated.isGodfather then
                  Notifications:Bottom(hero:GetPlayerID(), {text = "Your target takes charge. They must be a Godfather.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                end

                if hero.investigated.isFramer then
                  Notifications:Bottom(hero:GetPlayerID(), {text = "Your target is good with documents. They must be a Framer.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                end

                if hero.investigated.isEscort then
                  Notifications:Bottom(hero:GetPlayerID(), {text = "Your target is a manipulative beauty. They must be an Escort.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                end

                if hero.investigated.isMafioso or hero.investigated.isVigilante or hero.investigated.isVeteran then
                  Notifications:Bottom(hero:GetPlayerID(), {text = "Your target works with weapons. They must be a Vigilante, Veteran, or Mafioso.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                end

                if hero.investigated.isJester then
                  Notifications:Bottom(hero:GetPlayerID(), {text = "Your target enjoys tricking people. They must be a Jester.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                end

              else
                Notifications:Bottom(hero:GetPlayerID(), {text = "Your target is good with documents. They must be a Framer.", style={color="red",["font-size"]="20px"}, duration = line_duration})
              end
            else
               Notifications:Bottom(hero:GetPlayerID(), {text = "You did not choose a target to invesigate.", style={color="red",["font-size"]="20px"}, duration = line_duration})
            end

          elseif hero.isJailor then
            if hero.executed then
            
              if hero.executed.isSerialKiller or hero.executed.isGodfather or hero.executed.isMafioso or hero.executed.isFramer or hero.executed.isJester or hero.executed.isExecutioner then
                hero.executes = hero.executes - 1
              else
                hero.executes = 0
              end
            
              GameMode:Kill(hero.executed)
              hero:IncrementKills(1)

              if not hero.jailed.isSerialKiller then

                Notifications:Bottom(hero:GetPlayerID(), {"You executed your target. You have ".. hero.executions .." executions left.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                Notifications:Bottom(hero.executed:GetPlayerID(), {"You were executed by the jailor last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})

              else
                GameMode:Kill(hero)
                hero.jailed:IncrementKills(1)

                Notifications:Bottom(hero:GetPlayerID(), {"Your target was the Serial Killer! They killed you over night!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                Notifications:Bottom(hero.jailed:GetPlayerID(), {"You killed the jailor who jailed you last night!", style={color="red",["font-size"]="20px"}, duration = line_duration})
              end
            else
              Notifications:Bottom(hero:GetPlayerID(), {"You spared your target. You have ".. hero.executions .." executions left.", style={color="red",["font-size"]="20px"}, duration = line_duration})
            end

            Notifications:Bottom(hero:GetPlayerID(), {"Choose a target to jail before nightfall.", style={color="red",["font-size"]="20px"}, duration = line_duration})

          elseif hero.isGodfather then

            --TODO: Godfather role actions

          elseif hero.isFramer then

            if hero.framed then
              Notifications:Bottom(hero:GetPlayerID(), {"You successfully framed your target.", style={color="red",["font-size"]="20px"}, duration = line_duration})
            else
              Notifications:Bottom(hero:GetPlayerID(), {"You did not choose a target to frame.", style={color="red",["font-size"]="20px"}, duration = line_duration})
            end

          elseif hero.isExecutioner then
            if hero.target:IsAlive() then
              Notifications:Bottom(hero:GetPlayerID(), {"Your target, ".. GameMode:ConvertEngineName(hero.target:GetName()) ..", is still alive", style={color="red",["font-size"]="20px"}, duration = line_duration})
            else
              Notifications:Bottom(hero:GetPlayerID(), {"Your target, ".. GameMode:ConvertEngineName(hero.target:GetName()) ..", has died during the night, you are now a jester", style={color="red",["font-size"]="20px"}, duration = line_duration})
              
              hero.isExecutioner = false
              hero.skills = {"executioner_passive"}
              hero.daySkills = {"executioner_passive"}

              hero.isJester = true
              hero.skills = {"jester_passive"}
              hero.daySkills = {"jester_passive"}
            end

          elseif hero.isEscort then
            if hero.escorted then
              if not hero.escorted.isSerialKiller and not hero.escorted.isVeteran then
                Notifications:Bottom(hero.escorted:GetPlayerID(), {"You were role blocked last night!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                Notifications:Bottom(hero:GetPlayerID(), {"You successfully role blocked your target.", style={color="red",["font-size"]="20px"}, duration = line_duration})
              elseif hero.escorted.isSerialKiller then
                Notifications:Bottom(hero.escorted:GetPlayerID(), {"You were role blocked and killed the roleblocker instead!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                Notifications:Bottom(hero:GetPlayerID(), {"You role blocked the Serial Killer and they killed you instead!", style={color="red",["font-size"]="20px"}, duration = line_duration})
              elseif hero.escorted.isVeteran then
                if hero.escorted.alert then
                  Notifications:Bottom(hero:GetPlayerID(), {"You role blocked the Veteran while they were on alert and you were shot!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                else
                  Notifications:Bottom(hero:GetPlayerID(), {"You successfully role blocked your target.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                end
              end
            else
              Notifications:Bottom(hero:GetPlayerID(), {"You did not choose a target to role block.", style={color="red",["font-size"]="20px"}, duration = line_duration})
            end


          elseif hero.isMafioso then

            --TODO: Mafioso role actions

          elseif hero.isLookout then
            if hero.watched then

              if hero.watched.isInvestigatedBySheriff then
                Notifications:Bottom(hero:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.sheriff:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
              
              elseif hero.watched.isHealed then
                Notifications:Bottom(hero:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.doctor:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})

              elseif hero.watched.isInvestigatedByInvestigator then
                Notifications:Bottom(hero:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.investigator:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
              
              elseif hero.watched.isJailed then
                Notifications:Bottom(hero:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.jailor:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
              
              elseif hero.watched.isKilledByMafioso then
                Notifications:Bottom(hero:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.mafiosoKiller:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
              
              elseif hero.watched.isKilledByGodfather then
                Notifications:Bottom(hero:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.godfatherKiller:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
              
              elseif hero.watched.isFramed then
                Notifications:Bottom(hero:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.framer:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
              
              elseif hero.watched.isEscorted then
                Notifications:Bottom(hero:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.escorter:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
              
              elseif hero.watched.isWatchedByLookout then
                Notifications:Bottom(hero:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.lookout:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
              
              elseif hero.watched.isKilledBySK then
                Notifications:Bottom(hero:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.skKiller:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
              
              elseif hero.watched.isKilledByVig then
                Notifications:Bottom(hero:GetPlayerID(), {"Your target was visited by ".. GameMode:ConvertEngineName(hero.vigKiller:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
              
              else
                Notifications:Bottom(hero:GetPlayerID(), {"Your target was not visited last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
              end
            
            else
              Notifications:Bottom(hero:GetPlayerID(), {"You did not choose a target to stakeout.", style={color="red",["font-size"]="20px"}, duration = line_duration})
            end

          elseif hero.isSerialKiller then

            --TODO: Serial Killer actions

          elseif hero.isVigilante then

            --TODO: Vig actions

          elseif hero.isVeteran then
            if hero.alert then

              if hero.isInvestigatedBySheriff then
                if not hero.sheriff.isHealed or not hero.sheriff.isJailed then
                  GameMode:Kill(hero.sheriff)
                  hero.sheriff.isKilledByVet = true
                  hero:IncrementKills(1)
                  Notifications:Bottom(hero:GetPlayerID(), {"You were visited by and killed ".. GameMode:ConvertEngineName(hero.sheriff:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  Notifications:Bottom(hero.sheriff:GetPlayerID(), {"You visted Veteran while they were on alert and were shot!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  hero.didKill = true
                end
              end
              
              if hero.isHealed then
                if not hero.doctor.isHealed or not hero.doctor.isJailed then
                  GameMode:Kill(hero.doctor)
                  hero.doctor.isKilledByVet = true
                  hero:IncrementKills(1)
                  Notifications:Bottom(hero:GetPlayerID(), {"You were visited by and killed ".. GameMode:ConvertEngineName(hero.doctor:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  Notifications:Bottom(hero.doctor:GetPlayerID(), {"You visted Veteran while they were on alert and were shot!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  hero.didKill = true
                end
              end

              if hero.isInvestigatedByInvestigator then
                if not hero.investigator.isHealed or not hero.investigator.isJailed then
                  GameMode:Kill(hero.investigator)
                  hero.investigator.isKilledByVet = true
                  hero:IncrementKills(1)
                  Notifications:Bottom(hero:GetPlayerID(), {"You were visited by and killed ".. GameMode:ConvertEngineName(hero.investigator:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  Notifications:Bottom(hero.investigator:GetPlayerID(), {"You visted Veteran while they were on alert and were shot!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  hero.didKill = true
                end
              end

              if hero.isJailed then
                if not hero.jailor.isHealed or not hero.jailor.isJailed then
                  GameMode:Kill(hero.jailor)
                  hero.jailor.isKilledByVet = true
                  hero:IncrementKills(1)
                  Notifications:Bottom(hero:GetPlayerID(), {"You were visited by and killed ".. GameMode:ConvertEngineName(hero.jailor:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  Notifications:Bottom(hero.jailor:GetPlayerID(), {"You visted Veteran while they were on alert and were shot!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  hero.didKill = true
                end
              end

              if hero.isKilledByMafioso then
                if not hero.mafiosoKiller.isHealed or not hero.mafiosoKiller.isJailed then
                  GameMode:Kill(hero.mafiosoKiller)
                  hero.mafiosoKiller.isKilledByVet = true
                  hero:IncrementKills(1)
                  Notifications:Bottom(hero:GetPlayerID(), {"You were visited by and killed ".. GameMode:ConvertEngineName(hero.mafiosoKiller:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  Notifications:Bottom(hero.mafiosoKiller:GetPlayerID(), {"You visted Veteran while they were on alert and were shot!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  hero.didKill = true
                end
              end

              if hero.isKilledByGodfather then
                if not hero.godfatherKiller.isHealed or not hero.godfatherKiller.isJailed then
                  GameMode:Kill(hero.godfatherKiller)
                  hero.godfatherKiller.isKilledByVet = true
                  hero:IncrementKills(1)
                  Notifications:Bottom(hero:GetPlayerID(), {"You were visited by and killed ".. GameMode:ConvertEngineName(hero.godfatherKiller:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  Notifications:Bottom(hero.godfatherKiller:GetPlayerID(), {"You visted Veteran while they were on alert and were shot!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  hero.didKill = true
                end
              end

              if hero.isFramed then
                if not hero.framer.isHealed or not hero.framer.isJailed then
                  GameMode:Kill(hero.framer)
                  hero.framer.isKilledByVet = true
                  hero:IncrementKills(1)
                  Notifications:Bottom(hero:GetPlayerID(), {"You were visited by and killed ".. GameMode:ConvertEngineName(hero.framer:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  Notifications:Bottom(hero.framer:GetPlayerID(), {"You visted Veteran while they were on alert and were shot!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  hero.didKill = true
                end
              end

              if hero.isEscorted then
                if not hero.escorter.isHealed or not hero.escorter.isJailed then
                  GameMode:Kill(hero.escorter)
                  hero.escorter.isKilledByVet = true
                  hero:IncrementKills(1)
                  Notifications:Bottom(hero:GetPlayerID(), {"You were visited by and killed ".. GameMode:ConvertEngineName(hero.escorter:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  Notifications:Bottom(hero.escorter:GetPlayerID(), {"You visted Veteran while they were on alert and were shot!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  hero.didKill = true
                end
              end

              if hero.isWatchedByLookout then
                if not hero.lookout.isHealed or not hero.lookout.isJailed then
                  GameMode:Kill(hero.lookout)
                  hero.lookout.isKilledByVet = true
                  hero:IncrementKills(1)
                  Notifications:Bottom(hero:GetPlayerID(), {"You were visited by and killed ".. GameMode:ConvertEngineName(hero.lookout:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  Notifications:Bottom(hero.lookout:GetPlayerID(), {"You visted Veteran while they were on alert and were shot!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  hero.didKill = true
                end
              end

              if hero.isKilledBySK then
                if not hero.serialKiller.isHealed or not hero.serialKiller.isJailed then
                  GameMode:Kill(hero.serialKiller)
                  hero.serialKiller.isKilledByVet = true
                  hero:IncrementKills(1)
                  Notifications:Bottom(hero:GetPlayerID(), {"You were visited by and killed ".. GameMode:ConvertEngineName(hero.serialKiller:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  Notifications:Bottom(hero.serialKiller:GetPlayerID(), {"You visted Veteran while they were on alert and were shot!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  hero.didKill = true
                end
              end

              if hero.isKilledByVig then
                if not hero.vigKiller.isHealed or not hero.vigKiller.isJailed then
                  GameMode:Kill(hero.vigKiller)
                  hero.vigKiller.isKilledByVet = true
                  hero:IncrementKills(1)
                  Notifications:Bottom(hero:GetPlayerID(), {"You were visited by and killed ".. GameMode:ConvertEngineName(hero.vigKiller:GetName()) .." last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  Notifications:Bottom(hero.vigKiller:GetPlayerID(), {"You visted Veteran while they were on alert and were shot!", style={color="red",["font-size"]="20px"}, duration = line_duration})
                  hero.didKill = true
                end
              end

              if not hero.didKill then
                Notifications:Bottom(hero:GetPlayerID(), {"You were not visited by anyone.", style={color="red",["font-size"]="20px"}, duration = line_duration})
              end
              hero.didKill = false

            else
              Notifications:Bottom(hero:GetPlayerID(), {"You did not go on alert last night.", style={color="red",["font-size"]="20px"}, duration = line_duration})
            end
          
            Notifications:Bottom(hero:GetPlayerID(), {"You have ".. hero.alerts .." alerts left", style={color="red",["font-size"]="20px"}, duration = line_duration})
            Notifications:Bottom(hero:GetPlayerID(), {"Choose if you want to go on alert by nightfall", style={color="red",["font-size"]="20px"}, duration = line_duration})

          elseif hero.isJester then

            if not hero.isGhost then
              Notifications:Bottom(hero:GetPlayerID(), {"Remember to use chat and strategy to create subtle suspicion towards yourself", style={color="red",["font-size"]="20px"}, duration = line_duration})
            end

            if hero.killed then
              Notifications:Bottom(hero.killed:GetPlayerID(), {"You were haunted by the Jester and killed", style={color="red",["font-size"]="20px"}, duration = line_duration})
              Notifications:Bottom(hero:GetPlayerID(), {"You haunted and killed your target", style={color="red",["font-size"]="20px"}, duration = line_duration})
              GameMode:Kill(hero.killed)
              GameMode:Kill(hero)
            elseif hero.isGhost then
              Notifications:Bottom(hero:GetPlayerID(), {"You did not choose a target to haunt", style={color="red",["font-size"]="20px"}, duration = line_duration})
              GameMode:Kill(hero)
            end
          end
        else
          Notifications:Bottom(hero:GetPlayerID(), {"You were role blocked last night!", style={color="red",["font-size"]="20px"}, duration = line_duration})
        end
      end
    end

  elseif self.gameState == 0 then

    if hero.isVigilante then
      Notifications:Bottom(hero:GetPlayerID(), {"You have ".. hero.bullets .." bullets left", style={color="red",["font-size"]="20px"}, duration = line_duration})
    end

    if hero.isJailor then
      Notifications:Bottom(hero:GetPlayerID(), {"You have ".. hero.executions .." executions left", style={color="red",["font-size"]="20px"}, duration = line_duration})
    end

    if hero.isJailed then
      Notifications:Bottom(hero:GetPlayerID(), {"You were jailed for the night", style={color="red",["font-size"]="20px"}, duration = line_duration})
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
  end
end

function GameMode:Kill(hero)
  hero:RemoveModifierByName("modifier_general_player_passives")
  hero:SetCustomHealthLabel(GameMode:ConvertEngineName(hero:GetName()) .. '\n"'.. hero.role ..'"', 0, 0, 0)
  for i=1, #self.alivePlayers do
    if self.alivePlayers[i] == hero then
      table.remove(self.alivePlayers, i)
    end
  end
  hero:ForceKill(false)
  hero:SetTeam(DOTA_TEAM_BADGUYS)
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
    heroName = "Natrue's Prophet"
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