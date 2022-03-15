-- Server environment

-- Getting global aliases

local PSI = PlayerStatusIcons
local Convar = PSI.Convar
local Enum = Convar.Enums

local StatusFlags = PSI.StatusFlags

local flagAdd = PSI.flagAdd
local flagRemove = PSI.flagRemove
local flagSet = PSI.flagSet
local flagGet = PSI.flagGet

-- Setting up networking

util.AddNetworkString("PlyStatusIcons_StatusUpdate") -- For receiving updates from clients and broadcasting them
util.AddNetworkString("PlyStatusIcons_RequestStatusUpdate") -- For the server to request a status update from a specific client
util.AddNetworkString("PlyStatusIcons_NetworkReady") -- For the clients to signal that they spawned in, and are ready for networking

-- Helper functions

local function isEnabled() -- Returns if the addon is currently enabled
	return Convar.sv_enabled[Enum.HANDLE]:GetBool() -- Avoiding the wrapper function (this is called pretty frequently)
end

local function isInvisible(ply)

	if ply:GetNoDraw() then -- This tries to be universal
		return true
	end

	if ULib and ply.invis then -- ULX support
		return true
	end

	-- Add other admin mods here....

	return false

end

local function initPlayerTable(ply) -- Opening a table on the player to store associated info
	if ply and not ply.PSI then
		ply.PSI = {}
		ply.PSI.Status = {invisible = isInvisible(ply), timing_out = ply:IsTimingOut()}
		ply.PSI.Net = {ready = false, rate = 0}
	end
end

-- Handling status updates, and broadcasting them to clients

local function broadcastStatus(ply_source, new_statusfield, new_last_active, ply_target) -- Reports a status update to everyone except the player who sent it (if the target is specified then only sends to the target)

	if not isEnabled() or not ply_source or ply_source.PSI and ply_source.PSI.Status.invisible then return end -- Don't switch to isInvisible, update order dependent

	new_statusfield = new_statusfield or StatusFlags.ACTIVE

	net.Start("PlyStatusIcons_StatusUpdate")
		net.WriteEntity(ply_source)
		net.WriteUInt(new_statusfield, PSI.Net.STATUS_LEN)
		if flagGet(new_statusfield, StatusFlags.AFK) then
			net.WriteFloat(new_last_active or 0)
		end

	if ply_target and ply_target:IsPlayer() then
		net.Send(ply_target)
	else
		net.SendOmit(ply_source)
	end

end

local function requestStatusUpdate(ply) -- Requests a status update from ply. The status update is then forwarded to every other player
	
	if not isEnabled() then return end

	net.Start("PlyStatusIcons_RequestStatusUpdate")
	net.Send(ply)

end

-- Handling status updates

local function ServerSideStatusDetection() -- Called in a 1 sec timer

	for _, ply in ipairs(player.GetHumans()) do

		initPlayerTable(ply)

		local Status = ply.PSI.Status

		if Status.invisible ~= isInvisible(ply) then

			if isInvisible(ply) then
				broadcastStatus(ply) -- Overwrite with 0 (make the icon disappear)
			else
				requestStatusUpdate(ply)
			end

			Status.invisible = isInvisible(ply)

		end

		if Status.timing_out ~= ply:IsTimingOut() then

			if ply:IsTimingOut() then
				-- Statusfield is completely overwritten with TIMEOUT flag - if there is no connection to the player, we have no info about what else it's doing.
				broadcastStatus(ply, StatusFlags.TIMEOUT)
			else
				requestStatusUpdate(ply)
			end

			Status.timing_out = ply:IsTimingOut()

		end

	end

end

local function NetRateReset() -- Call rate of this depends on network settings
	-- Reset rates for everyone
	for _, ply in ipairs(player.GetHumans()) do
		if ply.PSI then
			ply.PSI.Net.rate = 0
		end
	end

end

net.Receive("PlyStatusIcons_StatusUpdate", function(len, ply_source) -- The client is only expected to send a status update when there is a CHANGE in the status or it is requested

	-- Security measures

	if not isEnabled() or not IsValid(ply_source) then return end

	initPlayerTable(ply_source)
	if ply_source.PSI.Net.rate >= PSI.Net.RATE_LIMIT then return end

	ply_source.PSI.Net.rate = ply_source.PSI.Net.rate + 1 -- This resets after a given time window

	-- Reading net

	local new_statusfield = net.ReadUInt(PSI.Net.STATUS_LEN)
	local new_last_active = flagGet(new_statusfield, StatusFlags.AFK) and net.ReadFloat() or 0
	local read_target = net.ReadBool()
	local ply_target = read_target and net.ReadEntity() or NULL -- broadcastStatus will know if it's invalid

	-- Sending update

	broadcastStatus(ply_source, new_statusfield, new_last_active, ply_target)

	-- A bit of support for server devs, you can use this to add a custom script to kick AFKs or whatever
	hook.Run("PlyStatusIcons_Hook_StatusUpdate", ply_source, new_statusfield, new_last_active, ply_target) 
	-- ent ply_source: player where the status update came from
	-- unsigned int new_statusfield: the new status... (also check out helper functions for handling this (init file))
	-- float new_last_active: the last time there was input from the player (curtime) only used when afk, otherwise 0
	-- ent ply_target: only a player entity if there is a specific player to send the update to, otherwise it is sent to everyone

end)

net.Receive("PlyStatusIcons_NetworkReady", function(len, ply_source) -- Forward that the newly spawned in player is ready

	if not isEnabled() or not IsValid(ply_source) then return end

	initPlayerTable(ply_source)
	if ply_source.PSI.Net.ready then return end -- This is a security measure to protect other players from getting flooded
	ply_source.PSI.Net.ready = true

	-- Forwarding

	net.Start("PlyStatusIcons_NetworkReady")
		net.WriteEntity(ply_source)
	net.SendOmit(ply_source)

end)

-- Handling the activation / deactivation

local currently_active -- A safeguard for double calling the toggle function

local function toggleServerService(active) -- Toggles the detection and broadcasting of statusflags detected serverside (only serverside - status updates received from clients are independent)
	
	if currently_active == active then return end
	currently_active = active

	if active then

		timer.Create("PlyStatusIcons_ServerSideStatusDetection", 1, 0, ServerSideStatusDetection)
		timer.Create("PlyStatusIcons_NetRateReset", PSI.Net.RATE_WINDOW, 0, NetRateReset)

		hook.Add("PlayerDisconnected", "PlyStatusIcons_PlayerDisconnected", function(ply) -- Handles shutdown

			if ply:IsBot() then return end -- I trust that this doesnt callback with an invalid player entity

			local human_count = #player.GetHumans() - 1 -- The table hasn't updated yet when this hook is called

			if 1 >= human_count then
				toggleServerService(false)
			end

		end)
		
		hook.Remove("PlayerInitialSpawn", "PlyStatusIcons_PlayerInitialSpawn")

	else

		timer.Remove("PlyStatusIcons_ServerSideStatusDetection")
		timer.Remove("PlyStatusIcons_NetRateReset")
		
		hook.Add("PlayerInitialSpawn", "PlyStatusIcons_PlayerInitialSpawn", function() -- Player spawned in

			if not isEnabled() then return end

			local human_count = #player.GetHumans()

			if 1 < human_count then
				toggleServerService(true) -- Safeguarded
			end

		end)

		hook.Remove("PlayerDisconnected", "PlyStatusIcons_PlayerDisconnected")

	end

end

toggleServerService(false) -- Initialize server side

cvars.AddChangeCallback(Convar.sv_enabled:GetName(), function(name, value_old, value_new)
	
	local enabled = tobool(value_new)
	if tobool(value_old) == enabled then return end -- Pointless call

	local human_count = #player.GetHumans()

	if 1 < human_count then
		toggleServerService(enabled)
	end

end, "PlyStatusIcons_SV_Toggle")
