--[[

	Player Status Icons by Haaax is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
	Copyright (c) 2020 Haaax <http://steamcommunity.com/profiles/76561198073542810> (STEAM_0:0:56638541)
	https://creativecommons.org/licenses/by-nc-nd/4.0/

	Coding style info:

	Function names:
	Helper functions / methods: camelCase
	Event functions (hooks, net, etc): PascalCase

	Var names:
	snake_case (camelCase if it gets too long)
	
	Constants:
	UPPER_SNAKE_CASE

	Tables:
	PascalCase

	Mark running environment in the top of the file

	For everything else, follow lua style guidelines
	
]]--

-- Shared environment (file automatically sent to clients)

if game.SinglePlayer() then return end -- This addon is pointless in singleplayer

-- Base class

PlayerStatusIcons = {}
PlayerStatusIcons.Convar = {}
PlayerStatusIcons.Convar.Enums = {}
PlayerStatusIcons.Net = {}

local PSI = PlayerStatusIcons
local Convar = PSI.Convar
local Enum = Convar.Enums
local Net = PSI.Net

-- Small OOP for convars

-- Enums for referencing the convar tables (objects)

Enum.HANDLE = 1
Enum.HANDLE_META = 2
Enum.LABEL = 3
Enum.STATUSFLAG = 4
Enum.PANEL = 5

Convar.PREFIX = "psi_"

Convar.__index = Convar

function Convar:new(label, change_callback, ...) -- Constructor - Safely (no duplicate) creates a new convar, and stores some extra data with it
	-- Not the prettiest thing, also probably bad for performance but I kinda wanted to try some OOP with LUA

	local new_convar = {
		[Enum.LABEL] = label or "", -- Label seen in UI
	}

	local args = {...}
	args[1] = Convar.PREFIX..args[1] -- Adding prefix to name
	local name = args[1]

	local convar_handle = GetConVar(name) -- Get it if it exists

	if not convar_handle then -- Create if it doesn't

		convar_handle = CreateConVar(unpack(args))

		if change_callback then
			cvars.AddChangeCallback(name, change_callback, name)
		end

	end

	new_convar[Enum.HANDLE] = convar_handle

	-- This is just passing function calls back to the ConVar (Bad performance, use only for convenience where it is called rarely)

	new_convar[Enum.HANDLE_META] = {}

	local convar_meta = getmetatable(convar_handle)

	new_convar[Enum.HANDLE_META].__index = function(self, key)

		local convar_func_ref = convar_meta[key]

		if isfunction(convar_func_ref) then
			return function (self, ...)
				return convar_func_ref(self[Enum.HANDLE], ...)
			end
		end

		return nil

	end

	setmetatable(new_convar, new_convar[Enum.HANDLE_META])

	return new_convar

end

-- Networking constants
Net.STATUS_LEN = 7 -- bits
Net.RATE_LIMIT = 20 -- Number of updates a client can send over a given time window
Net.RATE_WINDOW = 1 -- sec -- Period after which the rate counter resets for clients

-- Status flags (enums), in hierarchical order

PSI.StatusFlags = {
	ACTIVE = 0,
	AFK = 1,
	CURSOR = 2, -- Cursor is active (in vgui)
	TYPING = 4,
	SPAWNMENU = 8,
	MAINMENU = 16,
	ALTTAB = 32, -- Game not in focus
	TIMEOUT = 64 -- The player is timing out, detected server side
}

-- Global helper functions

PSI.flagAdd = function(field, flag)
	return bit.bor(field, flag)
end
local flagAdd = PSI.flagAdd

PSI.flagRemove = function(field, flag)
	return bit.band(field, bit.bnot(flag))
end
local flagRemove = PSI.flagRemove

PSI.flagSet = function(field, flag, flag_active) -- A shorthand to make the code a bit cleaner (set flag based on flagActive)
	if flag_active then
		return flagAdd(field, flag)
	else
		return flagRemove(field, flag)
	end
end

PSI.flagGet = function(field, flag) -- Returns whether the given flag is active 
	return tobool(bit.band(field, flag))
end

-- Enabled
Convar.sv_enabled = Convar:new("Server enabled", nil, "sv_enabled", "1", bit.bor(SERVER and FCVAR_ARCHIVE or 0, FCVAR_REPLICATED), "Toggles the addon globally") -- FCVAR_ARCHIVE must be serverside only as of now (game bug)

-- AFK Timelimit
Convar.afk_timelimit = Convar:new(nil, nil, "afk_timelimit", "3", bit.bor(SERVER and FCVAR_ARCHIVE or 0, FCVAR_REPLICATED), "Sets the timelimit for the timestamp to appear, and for afk flag activation (minutes)", 1)

-- Loading script

if SERVER then
	
	AddCSLuaFile("psi/client/cl_main.lua")
	
	AddCSLuaFile("psi/client/scripts/ui.lua")
	AddCSLuaFile("psi/client/scripts/status_detection.lua")
	AddCSLuaFile("psi/client/scripts/status_visualization.lua")

	include("psi/server/status_broadcast_service.lua")

else -- Client
	include("psi/client/cl_main.lua")
end