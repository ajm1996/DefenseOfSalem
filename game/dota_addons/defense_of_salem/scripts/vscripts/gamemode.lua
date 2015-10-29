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
--PrecacheItemByNameAsync("item_example_item", function(...) end)
--PrecacheItemByNameAsync("example_ability", function(...) end)

--PrecacheUnitByNameAsync("npc_dota_hero_viper", function(...) end)
--PrecacheUnitByNameAsync("npc_dota_hero_enigma", function(...) end)
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

  dummy:FindAbilityByName("player_modifiers_passive"):ApplyDataDrivenModifier(dummy, hero, "modifier_general_player_passives", {})
  dummy:FindAbilityByName("player_modifiers_passive"):ApplyDataDrivenModifier(dummy, hero, "modifier_rooted_passive", {})
  

  hero:SetGold(0, false)

end

<<<<<<< HEAD
=======
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
      if GameRules:IsDaytime() then
        local heroName = GameMode:ConvertEngineName(playerEntity)
        local line_duration = 10.0
        Notifications:BottomToAll({hero = playerEntity:GetAssignedHero():GetName(), duration = line_duration})
        Notifications:BottomToAll({text = " "..heroName, style={color="blue",["font-size"]="20px"}, duration = line_duration, continue = true})
        Notifications:BottomToAll({text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})
      end
    end
  end)
end


function GameMode:ConvertEngineName(playerEntity)
  local heroEngineName = playerEntity:GetAssignedHero():GetName()
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

--[[
This function is called once and only once when the game completely begins (about 0:00 on the clock).  At this point,
gold will begin to go up in ticks if configured, creeps will spawn, towers will become damageable etc.  This function
is useful for starting any game logic timers/thinkers, beginning the first round, etc.
]]
function GameMode:OnGameInProgress()
  GameMode:SetRoles()
  
  local waitTime = 45
  GameRules:SetTimeOfDay((360 - waitTime) * (1/480))

  Timers:CreateTimer(waitTime, function()

    if GameRules:IsDaytime() then
      waitTime = 30
    else
      waitTime = 45
    end
    GameRules:SetTimeOfDay(GameRules:GetTimeOfDay() + ((240 - waitTime) * (1/480)))
    Timers:CreateTimer(0.03, function()
      if GameRules:IsDaytime() then
        --DAYTIME
        mode:SetFogOfWarDisabled(true)

        local heroes = HeroList:GetAllHeroes()
        for i=1,#heroes do
          local hero = heroes[i]
          if hero then
            GameMode:SetSkills(hero)
            GameMode:RoleActions(hero)
            GameMode:CleanFlags(hero)
          end
        end
      else
        --NIGHTTIME
        mode:SetFogOfWarDisabled(false)

        local heroes = HeroList:GetAllHeroes()
        for i=1,#heroes do
          local hero = heroes[i]
          if hero then
            GameMode:SetSkills(hero)
          end
        end
      end
    end)
    return waitTime
  end)
end

function GameMode:SetRoles()
  local heroes = HeroList:GetAllHeroes()

  local rand = math.random(#heroes)
  local serialKiller = table.remove(heroes, rand)
  if serialKiller then
    print("SK: " .. serialKiller:GetName())
    serialKiller.isSerialKill = true;
  end

  rand = math.random(#heroes)
  local doctor = table.remove(heroes, rand)
  if doctor then
    print("Doctor: " .. doctor:GetName())
    doctor.isDoctor = true;
  end
end

function GameMode:SetSkills(hero)
  if GameRules:IsDaytime() then
    local abil = hero:GetAbilityByIndex(0)
    if abil then
      hero:RemoveAbility(abil:GetAbilityName())
      hero:AddAbility("barebones_empty1")
    end
  else
    if hero.isSerialKill then
      local abil = hero:GetAbilityByIndex(0)
      if abil then
        hero:RemoveAbility(abil:GetAbilityName())
        hero:AddAbility("SK_kill")
        hero:GetAbilityByIndex(0):SetLevel(1)
      end
    elseif hero.isDoctor then
      local abil = hero:GetAbilityByIndex(0)
      if abil then
        hero:RemoveAbility(abil:GetAbilityName())
        hero:AddAbility("doctor_heal")
        hero:GetAbilityByIndex(0):SetLevel(1)
      end
    end
  end
end

function GameMode:RoleActions(hero)
  if hero.isMarkedForDeath and not hero.isHealed then
    hero:ForceKill(false)
    hero.killer:IncrementKills(1)
  end
end

function GameMode:CleanFlags(hero)
  if hero.isMarkedForDeath then
    hero.isMarkedForDeath = false;
  elseif hero.isHealed then
    hero.isHealed = false;
  end
<<<<<<< HEAD
end

function GameMode:PlayerTrial()
  local hero = HeroList:GetHero(0)
  local home = hero:GetAbsOrigin()

  if hero:HasModifier("modifier_rooted_passive") then
    hero:RemoveModifierByName("modifier_rooted_passive")
  end

  Timers:CreateTimer(0.03, function()
    hero:MoveToPosition(Vector(0,0,0))
    print(hero:GetAbsOrigin())
    if (hero:GetAbsOrigin() - Vector(0, 0, 264.75)):Length() > 0 then
      return .03
    else
      dummy:FindAbilityByName("player_modifiers_passive"):ApplyDataDrivenModifier(dummy, hero, "modifier_rooted_passive", {})

      print("proc1")

      Timers:CreateTimer(5, function()
        print("proc1.5")
        if hero:HasModifier("modifier_rooted_passive") then
          hero:RemoveModifierByName("modifier_rooted_passive")
        end
        hero:MoveToPosition(home)
        if (hero:GetAbsOrigin() - home):Length() > 0 then
          return .03
        else
          print("proc2")
          dummy:FindAbilityByName("player_modifiers_passive"):ApplyDataDrivenModifier(dummy, hero, "modifier_rooted_passive", {})
        end
      end)
    end
  end)
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
      Notifications:BottomToAll({text = heroName, style={color="blue",["font-size"]="20px"}, duration = line_duration, continue = true})
      Notifications:BottomToAll({text = ": " .. text, style = {["font-size"] = "20px"}, duration = line_duration, continue = true})
    end
  end)

  Convars:RegisterCommand( "vote_trial_player", Dynamic_Wrap(GameMode, 'PlayerTrial'), "A console command example", FCVAR_CHEAT )
  Convars:RegisterCommand( "remove_root", Dynamic_Wrap(GameMode, 'RemoveRoot'), "A console command example", FCVAR_CHEAT )

  dummy = CreateUnitByName("dummy_unit", Vector(0,0,0), true, nil, nil, DOTA_TEAM_GOODGUYS)

end

function GameMode:RemoveRoot()
  hero = HeroList:GetHero(0)
  if hero:HasModifier("modifier_rooted_passive") then
    hero:RemoveModifierByName("modifier_rooted_passive")
  end
end