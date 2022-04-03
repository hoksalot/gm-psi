-- Client environment

-- Getting global aliases

local PSI = PlayerStatusIcons
local Convar = PSI.Convar
local Enum = Convar.Enums

local StatusFlags = PSI.StatusFlags

local flagGet = PSI.flagGet

local IconMaterials = PSI.IconMaterials

-- Table that stores the statuses of all players
-- Not storing stuff on individual player entities because then I would have to loop over every player, including localplayer

PSI.Statuses = {}
local Statuses = PSI.Statuses

-- Render vars

local render_scale = 0.05

local icon_size = 115

local timestamp_offset = 95
local timestamp_font = "PSI_Timestamp"

surface.CreateFont(
	timestamp_font,
	{
		font = "Coolvetica",
		size = 75,
		antialiasing = true,
		weight = 100
	}
)

-- Helper functions

local function mostSignificantFlag(x) -- (previousPowerOf2) Works until up to 2^30

    x = bit.bor(x, bit.rshift(x, 1))
    x = bit.bor(x, bit.rshift(x, 2))
    x = bit.bor(x, bit.rshift(x, 4))
    x = bit.bor(x, bit.rshift(x, 8))
    x = bit.bor(x, bit.rshift(x, 16))

    return x - bit.rshift(x, 1)

end

local function determineActualStatus(statusfield) -- Determines the status to display, based on user settings - returns statusflag for indexing

	-- Masking
	statusfield = bit.band(statusfield, PSI.icon_settings_mask)

	-- Determining the actual status
	return mostSignificantFlag(statusfield)

end

local function timeFormat(seconds) -- Returns nicely formatted time string for displaying

	if seconds < 60 then
		return string.format("%02d sec", seconds)
	elseif seconds < 3600 then
		return string.format("%d min", seconds / 60)
	else
		local time = string.FormattedTime(seconds)
		return string.format("%dh %02dm", time.h, time.m)
	end

end

-- Receiving updates
local function receiveStatusUpdate() -- Receiving status update

	-- Even if the script is disabled the client has to keep up with updates (to not break re-enabling)

	local ply_source = net.ReadEntity()
	local new_statusfield = net.ReadUInt(PSI.Net.STATUS_LEN)
	local new_last_active = flagGet(new_statusfield, StatusFlags.AFK) and net.ReadFloat()

	if not ply_source:IsPlayer() then return end -- Read fail

	if new_statusfield == StatusFlags.ACTIVE then -- Pointless to store this, also less entries to loop through when rendering
		Statuses[ply_source] = nil
		return
	end


	if not Statuses[ply_source] then
		Statuses[ply_source] = {}
		-- Statuses[ply_source].statusfield = StatusFlags.ACTIVE
		-- Statuses[ply_source].last_active = nil
	end

	-- Update values

	local was_afk = flagGet(Statuses[ply_source].statusfield or StatusFlags.ACTIVE, StatusFlags.AFK)
	local is_afk = flagGet(new_statusfield, StatusFlags.AFK)

	if was_afk ~= is_afk then -- Then afk state changed (this is kiiind of pointless because there are no new updates from a player as long as they are afk, but just to be safe)
		if is_afk then
			Statuses[ply_source].last_active = new_last_active
		else
			Statuses[ply_source].last_active = nil
		end
	end

	Statuses[ply_source].statusfield = new_statusfield

end

-- Rendering stuff

local function Render(bdepth, bskybox)

	if bskybox then return end -- Current call is drawing skybox, not good for us

	for ply, statusinfo in pairs(Statuses) do

		-- Disconnect hook is not reliable
		if not IsValid(ply) then
			Statuses[ply] = nil
			goto next
		end

		local status = determineActualStatus(statusinfo.statusfield) -- This needs to be determined here, soz :f (settings can change, even though the status might not)

		-- Might seem repetitive but this is a masked value (status)
		if status == StatusFlags.ACTIVE or not ply:Alive() or ply:GetNoDraw() then goto next end -- Then there's nothing to render

		-- Render pos
		local attachment_id = ply:LookupAttachment("anim_attachment_head") or 0 -- Can't take any chances with nils here
		local attachment = ply:GetAttachment(attachment_id)

		local base_pos = Vector()

		if attachment and attachment.Pos then -- Would've been too ugly with a ternary
			base_pos = attachment.Pos
		else
			base_pos = (ply:LocalToWorld(ply:OBBCenter()) + ply:GetUp() * 24)
		end

		local render_pos = base_pos + ply:GetUp() * Convar.height_offset[Enum.HANDLE]:GetFloat()

		-- Distance fading
		local render_mindist = Convar.render_distance[Enum.HANDLE]:GetFloat()
		local render_maxdist = render_mindist + 80

		local dist = (render_pos-EyePos()):Length()
		local dist_clamped = math.Clamp(dist, render_mindist, render_maxdist)
		local dist_alpha = math.Remap(dist_clamped, render_mindist, render_maxdist, 200, 0)

		if dist_alpha == 0 then goto next end -- Nothing to render

		-- Colors
		local fade_white = Color(255, 255, 255, dist_alpha)
		local fade_black = Color(0, 0, 0, dist_alpha)

		-- Render ang
		local render_ang = EyeAngles()
		render_ang:RotateAroundAxis(render_ang:Right(),90)
		render_ang:RotateAroundAxis(-render_ang:Up(),90)

		cam.Start3D2D(render_pos, render_ang, render_scale)

			-- Icon

			render.PushFilterMag(TEXFILTER.POINT) -- Make it pixelated

			surface.SetMaterial(IconMaterials[status])
			surface.SetDrawColor(fade_white)
			surface.DrawTexturedRect(-icon_size / 2, -icon_size / 2, icon_size, icon_size)

			render.PopFilterMag()

			-- Timestamp

			local last_active = statusinfo.last_active

			if last_active then
				local afk_seconds = CurTime() - last_active
				draw.SimpleTextOutlined(timeFormat(afk_seconds), timestamp_font, 0, timestamp_offset, fade_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, fade_black)
			end

		cam.End3D2D()

		::next:: -- Using goto instead of continue, continue is not reliable

	end

end

local currently_active -- A safeguard for double calling the toggle function (bit redundant but whatevs)

local function ToggleHandle(active)

	active = active and Convar.sv_enabled:GetBool() and Convar.cl_enabled:GetBool()

	if currently_active == active then return end
	currently_active = active

	if active then
		hook.Add("PostDrawTranslucentRenderables", "PlyStatusIcons_Render", Render)
	else
		hook.Remove("PostDrawTranslucentRenderables", "PlyStatusIcons_Render")
		-- Don't clear Statuses table
	end

end

return ToggleHandle, receiveStatusUpdate