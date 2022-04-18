-- Client environment

-- Getting global aliases

local PSI = PlayerStatusIcons
local Convar = PSI.Convar
local Enum = Convar.Enums

local IconMaterials = PSI.IconMaterials

local function checkBoxIconLabel(dform, icon_material, label, convar) -- DForm is the container

	local checkbox = dform:CheckBox(label, convar)

	local icon = vgui.Create("DImage", checkbox)
	icon:SetSize(15, 15)
	icon:SetMaterial(icon_material)
	checkbox.Icon = icon

	function checkbox:PerformLayout() -- Modified source code of DCheckBoxLabel

		local x = self.m_iIndent or 0

		self.Button:SetSize(15, 15)
		self.Button:SetPos(x, math.floor((self:GetTall() - self.Button:GetTall()) / 2))

		self.Icon:SetSize(15, 15)
		self.Icon:SetPos(x + self.Button:GetWide() + 9, math.floor((self:GetTall() - self.Icon:GetTall()) / 2))

		self.Label:SizeToContents()
		self.Label:SetPos(x + self.Button:GetWide() + 9 + self.Icon:GetWide() + 9, 0)

	end

	return checkbox

end

local function MakeSettingsMenu(panel)

	panel:ClearControls()

	-- Server enabled

	local checkbox_sv_enabled = panel:CheckBox(Convar.sv_enabled[Enum.LABEL], Convar.sv_enabled:GetName())
	checkbox_sv_enabled:SetMouseInputEnabled(false)
	checkbox_sv_enabled.Button.ConVarChanged = function() end -- Dirty, but this checkbox needs to be completely sterile

	Convar.sv_enabled[Enum.PANEL] = checkbox_sv_enabled

	panel:ControlHelp("This is purely informational.")

	-- Client enabled

	local checkbox_cl_enabled = panel:CheckBox(Convar.cl_enabled[Enum.LABEL], Convar.cl_enabled:GetName())

	function checkbox_cl_enabled:OnChange(active) -- Toggle other checkboxes

		for _, convar in ipairs(Convar.IconSettings) do
			local checkbox = convar[Enum.PANEL]
			checkbox:SetEnabled(active)
		end

		Convar.height_offset[Enum.PANEL]:SetEnabled(active)

	end

	Convar.cl_enabled[Enum.PANEL] = checkbox_cl_enabled

	panel:ControlHelp("This will only toggle the rendering of icons. Your status will still be reported to other players.")

	-- Privacy mode

	local checkbox_privacy_mode = panel:CheckBox(Convar.privacy_mode[Enum.LABEL], Convar.privacy_mode:GetName())
	Convar.privacy_mode[Enum.PANEL] = checkbox_privacy_mode
	panel:ControlHelp("Only report AFK status to other players.")

	-- Auto generated settings

	panel:Help("Set which status icons you want to see.")

	for _, convar in ipairs(Convar.IconSettings) do

		local setting_cvar = convar:GetName()
		local setting_desc = convar[Enum.LABEL]
		local setting_statusflag = convar[Enum.STATUSFLAG]
		local setting_mat = IconMaterials[setting_statusflag]

		local new_checkbox = checkBoxIconLabel(panel, setting_mat, setting_desc, setting_cvar)
		new_checkbox:SetIndent(7) -- Align it with the help label
		new_checkbox.Convar = convar

		convar[Enum.PANEL] = new_checkbox

		new_checkbox.Button.Toggle = function(self) -- Make sure it can't be unchecked if it's the last checkbox

			local others_active = false -- Will store if there are any other checkboxes active

			for _, cvar in ipairs(Convar.IconSettings) do

				local checkbox = cvar[Enum.PANEL]

				if checkbox ~= self:GetParent() and checkbox:GetChecked() then
					others_active = true
					break
				end

			end

			if self:GetChecked() and not others_active then return end -- Then we don't change the value

			self:SetValue(not self:GetChecked()) -- Switch the checkbox

		end

	end

	-- Height offset

	local slider_height_offset = panel:NumSlider(Convar.height_offset[Enum.LABEL], Convar.height_offset:GetName(), Convar.height_offset:GetMin(), Convar.height_offset:GetMax(), 1)
	slider_height_offset:SetTooltip(Convar.height_offset:GetHelpText())
	Convar.height_offset[Enum.PANEL] = slider_height_offset

end

hook.Add("PopulateToolMenu", "PlyStatusIcons_PopulateToolMenu", function()
	spawnmenu.AddToolMenuOption("Utilities", "User", "PlyStatusIcons_Menu", "Player Status Icons", "", "", MakeSettingsMenu)
end)