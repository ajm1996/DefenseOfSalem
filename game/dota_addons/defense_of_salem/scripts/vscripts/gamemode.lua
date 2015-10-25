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

  if not hero:HasModifier("modifier_rooted") then
  	hero:AddNewModifier(hero, nil, "modifier_rooted", {})
  end

  PlayerResource:SetOverrideSelectionEntity(hero:GetPlayerID(), hero)

  -- This line for example will set the starting gold of every hero to 500 unreliable gold
  hero:SetGold(0, false)

end

function GameMode:OnPlayerChat(keys)
  DebugPrint("chat")
end

--[[
  This function is called once and only once when the game completely begins (about 0:00 on the clock).  At this point,
  gold will begin to go up in ticks if configured, creeps will spawn, towers will become damageable etc.  This function
  is useful for starting any game logic timers/thinkers, beginning the first round, etc.
]]
function GameMode:OnGameInProgress()
  local time_flow = 0.0020833333
  print("Time: " .. GameRules:GetTimeOfDay() * 480)
  local waitTime = 10.0
  Timers:CreateTimer(waitTime,
    function()
      print("Time: " .. GameRules:GetTimeOfDay() * 480)
      GameRules:SetTimeOfDay(GameRules:GetTimeOfDay() + ((240 - waitTime) * time_flow))
      if GameRules:IsDaytime() then
        mode:SetFogOfWarDisabled(false)
        local heroes = HeroList:GetAllHeroes()
        for i=1,#heroes do
          local hero = heroes[i]
          local abil = hero:GetAbilityByIndex(0)
          if abil then
            hero:RemoveAbility(abil:GetAbilityName())
            hero:AddAbility("SK_kill")
            hero:GetAbilityByIndex(0):SetLevel(1)
          end
          --TODO: night time init
        end
      else
        mode:SetFogOfWarDisabled(true)
        local heroes = HeroList:GetAllHeroes()
        for i=1,#heroes do
          local hero = heroes[i]
          local abil = hero:GetAbilityByIndex(0)
          if abil then
            hero:RemoveAbility(abil:GetAbilityName())
            hero:AddAbility("barebones_empty1")
          end
          --TODO: night time init
        end
        --TODO: day time init
      end
      return waitTime;
    end)
end



-- This function initializes the game mode and is called before anyone loads into the game
-- It can be used to pre-initialize any values/tables that will be needed later
function GameMode:InitGameMode()
  GameMode = self

  -- Call the internal function to set up the rules/behaviors specified in constants.lua
  -- This also sets up event hooks for all event handlers in events.lua
  -- Check out internals/gamemode to see/modify the exact code
  GameMode:_InitGameMode()

  PlayerSay:TeamChatHandler(function(playerEntity, text)
    print(playerEntity:GetPlayerID() .. ' said "' .. text .. '" to their team.')
  end)

  PlayerSay:AllChatHandler(function(playerEntity, text)
    print(playerEntity:GetPlayerID() .. ' said "' .. text .. '" to all chat.')
  end)

end