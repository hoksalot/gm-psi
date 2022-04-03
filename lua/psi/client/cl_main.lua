-- Client environment

-- Getting global aliases

local PSI = PlayerStatusIcons
local Convar = PSI.Convar
local Enum = Convar.Enums
local Net = PSI.Net

local StatusFlags = PSI.StatusFlags

local flagAdd = PSI.flagAdd
local flagSet = PSI.flagSet

-- Creating clientside convars

-- Enabled
Convar.cl_enabled = Convar.new("Client enabled", nil, "cl_enabled", "1", FCVAR_ARCHIVE, "Toggle the rendering of icons for yourself")

-- Privacy Mode
Convar.privacy_mode = Convar.new("Privacy mode", nil, "privacy_mode", "0", FCVAR_ARCHIVE, "Only report AFK status to other players")

-- Render Distance
Convar.render_distance = Convar.new("Render distance", nil, "render_distance", "280", FCVAR_ARCHIVE, "Set the max rendering distance of icons (source units)", 100, 800)

-- Height Offset
Convar.height_offset = Convar.new("Height offset", nil, "height_offset", "15", FCVAR_ARCHIVE, "Set the overhead offset distance of icons (source units)", 15, 30)

-- Icon settings
local iconsettings_generator = {
	{"show_afk", "AFK", StatusFlags.AFK},
	{"show_vgui", "In VGUI", StatusFlags.CURSOR},
	{"show_typing", "Typing In Chat", StatusFlags.TYPING},
	{"show_spawnmenu", "In Spawnmenu", StatusFlags.SPAWNMENU},
	{"show_mainmenu", "In Main Menu", StatusFlags.MAINMENU},
	{"show_alttab", "On Desktop", StatusFlags.ALTTAB},
	{"show_timeout", "Timing Out", StatusFlags.TIMEOUT}
}

Convar.IconSettings = {}
PSI.icon_settings_mask = 0 -- For toggling certain icons

for i, convar_data in ipairs(iconsettings_generator) do

	local name = convar_data[1] -- Prefix added in constructor
	local label = convar_data[2]
	local statusflag = convar_data[3] -- Status flag associated with the setting

	local function updateSettings(_, value_old, value_new) -- The callback to update the settings mask
		local enabled = tobool(value_new)
		if tobool(value_old) == enabled then return end -- Pointless call
		PSI.icon_settings_mask = flagSet(PSI.icon_settings_mask, statusflag, enabled)
	end

	local convar = Convar.new(label, updateSettings, name, "1", FCVAR_ARCHIVE, label)
	convar[Enum.STATUSFLAG] = statusflag

	PSI.icon_settings_mask = flagAdd(PSI.icon_settings_mask, convar:GetBool() and statusflag or 0) -- Initialize

	Convar.IconSettings[i] = convar

end

-- Creating icon mats

PSI.IconMaterials = {
	[StatusFlags.AFK] = Material("icon16/status_away.png"),
	[StatusFlags.CURSOR] = Material("icon16/application.png"),
	[StatusFlags.TYPING] = Material("icon16/comment.png"),
	[StatusFlags.SPAWNMENU] = Material("icon16/application_view_icons.png"),
	[StatusFlags.MAINMENU] = Material("icon16/application_side_list.png"),
	[StatusFlags.ALTTAB] = Material("icon16/application_cascade.png"),
	[StatusFlags.TIMEOUT] = Material("icon16/disconnect.png")
}

include("scripts/ui.lua")

-- These scripts return a function for toggling their active state
local detectionToggleHandle, sendStatus = include("scripts/status_detection.lua")
local visualizationToggleHandle = include("scripts/status_visualization.lua")

net.Receive("PlyStatusIcons_RequestStatusUpdate", function() -- Server required a status update
	sendStatus()
end)

-- Service toggles

gameevent.Listen("player_disconnect")

local visualization_active -- A safeguard for double calling the toggle function

local function visualizationToggle(active) -- Expands the toggle handle of visualization

	active = active and Convar.sv_enabled:GetBool() and Convar.cl_enabled:GetBool()

	if visualization_active == active then return end
	visualization_active = active

	if active then

		hook.Add("player_disconnect", "PlyStatusIcons_PlayerDisconnected", function(data)

			if tobool(data.bot) then return end
			local human_count = #player.GetHumans()

			if 1 == human_count then
				visualizationToggle(false)
			end

		end)

	else
		hook.Remove("player_disconnect", "PlyStatusIcons_PlayerDisconnected")
	end

	visualizationToggleHandle(active)

end

hook.Add("InitPostEntity", "PlyStatusIcons_InitPostEntity", function() -- Send startup signal to others and start up

	if Convar.sv_enabled:GetBool() then

		detectionToggleHandle(true)

		local human_count = #player.GetHumans()

		if 1 < human_count then
			visualizationToggle(true)
		end

		net.Start(Net.NETWORK_STRING) -- In case this will be used for something server side too, it's better kept here
			net.WriteUInt(Net.CLIENT_MESSAGE_TYPES.NETWORK_READY, Net.CMT_LEN)
		net.SendToServer()

	end

end)

net.Receive("PlyStatusIcons_NetworkReady", function() -- Get startup signal from others (never received if the server toggle is disabled, no need to check for that)

	local ply_source = net.ReadEntity() -- The player who started up
	sendStatus(ply_source) -- Send the current status to them (doesn't matter if the addon is disabled for them, they need to be up to date)

	local human_count = #player.GetHumans()

	if 1 < human_count then
		visualizationToggle(true)
	end

end)

-- Clientside convar toggle
cvars.AddChangeCallback(Convar.cl_enabled:GetName(), function(name, value_old, value_new)

	local enabled = tobool(value_new)
	if tobool(value_old) == enabled then return end -- Pointless call

	local human_count = #player.GetHumans()

	if 1 < human_count then
		visualizationToggle(enabled)
	end

end, "PlyStatusIcons_VisualizationToggle")

-- Serverside convar toggle
cvars.AddChangeCallback(Convar.sv_enabled:GetName(), function(name, value_old, value_new)

	local enabled = tobool(value_new)
	if tobool(value_old) == enabled then return end -- Pointless call

	detectionToggleHandle(enabled)

	local human_count = #player.GetHumans()

	if 1 < human_count then
		visualizationToggle(enabled)
	end

end, "PlyStatusIcons_SV_Toggle")