-- Client environment

-- TODO: Privacy mode (Only handle AFK and Timeout status?)

-- Getting global aliases

local PSI = PlayerStatusIcons
local Convar = PSI.Convar
local Enum = Convar.Enums

local StatusFlags = PSI.StatusFlags

local flagAdd = PSI.flagAdd
local flagRemove = PSI.flagRemove
local flagSet = PSI.flagSet
local flagGet = PSI.flagGet

-- Cycle variable to detect if there was user input
local userinput = false
-- Cointains the last servertime (CurTime()) the player was active
local last_active = CurTime() -- 0 is the 'safe default' state, basically it will be ignored

-- Holds the current status of the player in the form of a bitfield
local current_statusfield = StatusFlags.ACTIVE
local current_statusfield_last = current_statusfield

-- Helper functions

local function sendStatus(ply_target) -- Send status update to server (if the target is specified it will be only sent to the target, otherwise everyone)

	if #player.GetHumans() > 1 then -- Otherwise there's no one to receive (and it would hit the rate limit eventually)

		if Convar.privacy_mode:GetBool() then
			current_statusfield = bit.band(current_statusfield, StatusFlags.AFK) -- Mask it to AFK only
		end

		net.Start("PlyStatusIcons_StatusUpdate")
			net.WriteUInt(current_statusfield, PSI.Net.STATUS_LEN)
			if flagGet(current_statusfield, StatusFlags.AFK) then
				net.WriteFloat(last_active)
			end
			local write_target = ply_target and ply_target:IsPlayer()
			net.WriteBool(write_target)
			if write_target then
				net.WriteEntity(ply_target) 
			end
		net.SendToServer()

	end

end

function isSpawnMenuOpen()
	return IsValid(g_SpawnMenu) and g_SpawnMenu:IsVisible()
end

local function isAltTabbed()
	return not system.HasFocus()
end

local function getCursorPosHash() -- Returns a little 'hash' of the current mouse position (used for detecting changes in mouse position)
	return gui.MouseX() * gui.MouseY() + gui.MouseX() + gui.MouseY()
end

local function isTyping()
	return LocalPlayer():IsValid() and LocalPlayer().IsTyping and LocalPlayer():IsTyping()
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
		current_statusfield_last = current_statusfield
		
		-- TIMEOUT is detected serverside
		
		sendStatus()

		-- Status detection

		timer.Create("PlyStatusIcons_StatusDetection", 0.04, 0, function() -- 40 ms

			-- This could probably be made less copy-pasty, but it's easier to see what's happening this way imo

			-- VGUI

			if vgui_visible_last ~= isVGUIVisible() then -- If changed then

				current_statusfield = flagSet(current_statusfield, StatusFlags.CURSOR, isVGUIVisible())
				vgui_visible_last = isVGUIVisible()
				userinput = true

			end

			-- Typing

			if typing_last ~= isTyping() then
				
				current_statusfield = flagSet(current_statusfield, StatusFlags.TYPING, isTyping())
				typing_last = isTyping()
				userinput = true

			end

			-- Main menu

			if gameui_visible_last ~= gui.IsGameUIVisible() then 

				current_statusfield = flagSet(current_statusfield, StatusFlags.MAINMENU, gui.IsGameUIVisible())
				gameui_visible_last = gui.IsGameUIVisible()
				userinput = true

			end

			-- Alt tabbed

			if alttabbed_last ~= isAltTabbed() then 

				current_statusfield = flagSet(current_statusfield, StatusFlags.ALTTAB, isAltTabbed())
				alttabbed_last = isAltTabbed()
				userinput = true

			end

			-- Catching status change

			if current_statusfield_last ~= current_statusfield then -- Then the status changed somewhere

				if userinput then -- This is so that the AFK flag instantly disappears for the other clients
					current_statusfield = flagRemove(current_statusfield, StatusFlags.AFK)
				end

				sendStatus()
				current_statusfield_last = current_statusfield
			end

			-- Mouse movement detection

			if cursorpos_last ~= getCursorPosHash() then
				userinput = true
				cursorpos_last = getCursorPosHash()
			end

			if eyeangles_last ~= EyeAngles() then
				userinput = true
				eyeangles_last = EyeAngles()
			end

		end)

		-- hook.Add("PreDrawTranslucentRenderables", "PlyStatusIcons_FixEyeAngles", EyeAngles) -- This is to fix EyeAngles() inside Think

		hook.Add("OnSpawnMenuOpen", "PlyStatusIcons_OnSpawnMenuOpen", function()
			current_statusfield = flagAdd(current_statusfield, StatusFlags.SPAWNMENU)
		end)

		hook.Add("OnSpawnMenuClose", "PlyStatusIcons_OnSpawnMenuClose", function()
			current_statusfield = flagRemove(current_statusfield, StatusFlags.SPAWNMENU)
		end)

		-- Input detection

		hook.Add("KeyPress", "PlyStatusIcons_KeyPress", function()
			userinput = true
		end)

		timer.Create("PlyStatusIcons_InputDetection", 1, 0, function()

			-- One second has passed,
			if userinput then -- Player is still here, nothing to do
				userinput = false -- Reset, so that we can detect in next cycle
				last_active = CurTime() -- Save last time the player was active
			end

			local is_afk = last_active ~= 0 and CurTime() - last_active > Convar.afk_timelimit[Enum.HANDLE]:GetFloat() * 60
			current_statusfield = flagSet(current_statusfield, StatusFlags.AFK, is_afk)

		end)

	else

		timer.Remove("PlyStatusIcons_StatusDetection")
		hook.Remove("PreDrawTranslucentRenderables", "PlyStatusIcons_FixEyeAngles")
		hook.Remove("OnSpawnMenuOpen", "PlyStatusIcons_OnSpawnMenuOpen")
		hook.Remove("OnSpawnMenuClose", "PlyStatusIcons_OnSpawnMenuClose")
		hook.Remove("KeyPress", "PlyStatusIcons_KeyPress")
		timer.Remove("PlyStatusIcons_InputDetection")

		last_active = 0
		userinput = true -- So that it gets updated when it's started
		current_statusfield = StatusFlags.ACTIVE

	end

end

return ToggleHandle, sendStatus