-- Client environment

-- Getting global aliases

local PSI = PlayerStatusIcons
local Convar = PSI.Convar
local Enum = Convar.Enums
local Net = PSI.Net

local StatusFlags = PSI.StatusFlags

local flagAdd = PSI.flagAdd
local flagRemove = PSI.flagRemove
local flagSet = PSI.flagSet
local flagGet = PSI.flagGet

-- Cointains the last unix time the player was active
local last_active = os.time() -- nil will be ignored

-- Holds the current status of the player in the form of a bitfield
local current_statusfield = StatusFlags.ACTIVE

-- This is the masked status (due to privacy mode)
local current_statusfield_masked = StatusFlags.ACTIVE
local current_statusfield_masked_last = current_statusfield_masked

-- Constants
local DETECTION_DELAY_FAST = 0.08 -- second delay
local DETECTION_DELAY_SLOW = 1 -- second delay

-- Helper functions

local function sendStatus(ply_target) -- Send status update to server (if the target is specified it will be only sent to the target, otherwise everyone)

	if #player.GetHumans() > 1 then -- Otherwise there's no one to receive (and it would hit the rate limit eventually)

		net.Start(Net.NETWORK_STRING)
			net.WriteUInt(Net.CLIENT_MESSAGE_TYPES.STATUS_UPDATE, Net.CMT_LEN)
			net.WriteUInt(current_statusfield_masked, Net.STATUS_LEN_CL)
			if flagGet(current_statusfield_masked, StatusFlags.AFK) then
				net.WriteDouble(last_active)
			end
			local write_target = ply_target and ply_target:IsPlayer()
			net.WriteBool(write_target)
			if write_target then
				net.WriteEntity(ply_target)
			end
		net.SendToServer()

	end

end

local function updateMaskedStatusField()
	current_statusfield_masked = current_statusfield
	if Convar.privacy_mode[Enum.HANDLE]:GetBool() then
		current_statusfield_masked = bit.band(current_statusfield, StatusFlags.AFK)
	end
end

local function updateLastActive()
	last_active = os.time()
end

local function isAFK()
	return last_active and (os.time() - last_active) > Convar.afk_timelimit[Enum.HANDLE]:GetFloat() * 60
end

local function isSpawnMenuOpen()
	return IsValid(g_SpawnMenu) and g_SpawnMenu:IsVisible()
end

local function isAltTabbed()
	return not system.HasFocus()
end

local function getCursorPosHash() -- Returns a little 'hash' of the current mouse position (used for detecting changes in mouse position)
	local x = gui.MouseX()
	local y = gui.MouseY()
	-- Cantor pairing
	return (x + y) * (x + y + 1) / 2 + x
end

local function isTyping()
	return IsValid(LocalPlayer()) and LocalPlayer().IsTyping and LocalPlayer():IsTyping()
end

local function isVGUIVisible() -- In case I might add some exceptions for this flag
	return vgui.CursorVisible()
end

-- Setting up vars for think

-- Cache vars for detecting change
local vgui_visible_last = isVGUIVisible()
local typing_last = isTyping() -- This is not the same as using the StartChat and FinishChat hooks.
local gameui_visible_last = gui.IsGameUIVisible()
local alttabbed_last = isAltTabbed()
local cursorpos_last = getCursorPosHash()
local eyeangles_last = EyeAngles()
local is_afk_last = false

-- Userinput detecting

local currently_active -- A safeguard for double calling the toggle function

local function ToggleHandle(active) -- Activates / deactivates this script

	active = active and Convar.sv_enabled:GetBool()

	if currently_active == active then return end
	currently_active = active

	if active then

		-- Sending status in the moment of activation
		current_statusfield = flagSet(current_statusfield, StatusFlags.CURSOR, isVGUIVisible()) -- VGUI
		current_statusfield = flagSet(current_statusfield, StatusFlags.TYPING, isTyping()) -- Typing
		current_statusfield = flagSet(current_statusfield, StatusFlags.SPAWNMENU, isSpawnMenuOpen()) -- Spawn menu
		current_statusfield = flagSet(current_statusfield, StatusFlags.MAINMENU, gui.IsGameUIVisible()) -- Main menu
		current_statusfield = flagSet(current_statusfield, StatusFlags.ALTTAB, isAltTabbed()) -- Alt tab
		current_statusfield = flagRemove(current_statusfield, StatusFlags.AFK) -- AFK
		updateMaskedStatusField()
		current_statusfield_masked_last = current_statusfield_masked

		updateLastActive()

		-- TIMEOUT is detected serverside

		sendStatus()

		-- Status detection
		timer.Create("PlyStatusIcons_StatusDetection", DETECTION_DELAY_FAST, 0, function() -- 40 ms

			-- This could probably be made less copy-pasty, but it's easier to see what's happening this way imo

			-- VGUI
			if vgui_visible_last ~= isVGUIVisible() then -- If changed then

				current_statusfield = flagSet(current_statusfield, StatusFlags.CURSOR, isVGUIVisible())
				vgui_visible_last = isVGUIVisible()
				updateLastActive()

			end

			-- Typing
			if typing_last ~= isTyping() then

				current_statusfield = flagSet(current_statusfield, StatusFlags.TYPING, isTyping())
				typing_last = isTyping()
				updateLastActive()

			end

			-- Main menu
			if gameui_visible_last ~= gui.IsGameUIVisible() then

				current_statusfield = flagSet(current_statusfield, StatusFlags.MAINMENU, gui.IsGameUIVisible())
				gameui_visible_last = gui.IsGameUIVisible()
				updateLastActive()

			end

			-- Alt tabbed
			if alttabbed_last ~= isAltTabbed() then

				current_statusfield = flagSet(current_statusfield, StatusFlags.ALTTAB, isAltTabbed())
				alttabbed_last = isAltTabbed()
				updateLastActive()

			end

			-- Mouse movement detection
			if cursorpos_last ~= getCursorPosHash() then
				updateLastActive()
				cursorpos_last = getCursorPosHash()
			end

			if eyeangles_last ~= EyeAngles() then
				updateLastActive()
				eyeangles_last = EyeAngles()
			end

			-- AFK
			if is_afk_last ~= isAFK() then

				current_statusfield = flagSet(current_statusfield, StatusFlags.AFK, isAFK())

				-- Dynamic update rate
				local delay = isAFK() and DETECTION_DELAY_SLOW or DETECTION_DELAY_FAST
				timer.Adjust("PlyStatusIcons_StatusDetection", delay)

				is_afk_last = isAFK()

			end

			-- Mask status for privacy mode
			updateMaskedStatusField()

			-- Catching status change
			if current_statusfield_masked_last ~= current_statusfield_masked then -- Then the status changed somewhere
				sendStatus()
				current_statusfield_masked_last = current_statusfield_masked
			end

		end)

		hook.Add("PreDrawTranslucentRenderables", "PlyStatusIcons_FixEyeAngles", EyeAngles) -- This is to fix EyeAngles() inside Think

		-- Last active is handled by the KeyPress hook for these
		hook.Add("OnSpawnMenuOpen", "PlyStatusIcons_OnSpawnMenuOpen", function()
			current_statusfield = flagAdd(current_statusfield, StatusFlags.SPAWNMENU)
		end)

		hook.Add("OnSpawnMenuClose", "PlyStatusIcons_OnSpawnMenuClose", function()
			current_statusfield = flagRemove(current_statusfield, StatusFlags.SPAWNMENU)
		end)

		-- Input detection
		hook.Add("KeyPress", "PlyStatusIcons_KeyPress", function()
			updateLastActive()
		end)

	else

		timer.Remove("PlyStatusIcons_StatusDetection")
		hook.Remove("PreDrawTranslucentRenderables", "PlyStatusIcons_FixEyeAngles")
		hook.Remove("OnSpawnMenuOpen", "PlyStatusIcons_OnSpawnMenuOpen")
		hook.Remove("OnSpawnMenuClose", "PlyStatusIcons_OnSpawnMenuClose")
		hook.Remove("KeyPress", "PlyStatusIcons_KeyPress")

		last_active = nil
		current_statusfield = StatusFlags.ACTIVE

	end

end

return ToggleHandle, sendStatus