-- need to rewrite this shit, make cool gui, also rewrite serverside -- who will make cool gui :-(

-- items what player hides better, they take longer to find
hg.TraitorLoot = {
	["weapon_sogknife"] = 10,
	["weapon_buck200knife"] = 10,
	["weapon_hg_shuriken"] = 9,
	["weapon_p22"] = 9,
	["weapon_traitor_ied"] = 8,
	["weapon_traitor_poison1"] = 7,
	["weapon_traitor_poison2"] = 6,
	["weapon_traitor_poison3"] = 5,
	["weapon_hg_smokenade_tpik"] = 4,
	["weapon_hg_rgd_tpik"] = 3,
	["weapon_walkie_talkie"] = 2,
	["weapon_adrenaline"] = 1,
	["hg_flashlight"] = 1,
}

if SERVER then return end

--\\ Loot menu, server side is in sv_inventory.lua
    local Tabs = {"Weapons", "Ammo", "Attachments", "Armor", "Equipment"}

    local plyMenu
    local cooldown = 0
    local clr_text = Color(255, 255, 255, 45)
    local clr_search = Color(255, 255, 255, 15)

    hook.Add("Player_Death", "foundloot", function(ply)
        if IsValid(ply.FakeRagdoll) then ply.FakeRagdoll.foundloot = table.Copy(ply.foundloot) end
        ply.foundloot = {}
    end)

    --\\ Item info
        local function GetName(tab, key, thing)
            if tab == "Ammo" then return game.GetAmmoName(key) or tostring(key) end
            if tab == "Armor" or tab == "Attachments" then return language.GetPhrase(thing) end

            if tab == "Equipment" then
                local Equip = Entity(thing)
                return IsValid(Equip) and language.GetPhrase(Equip.PrintName) or ""
            end

            local stored = weapons.Get(key) or scripted_ents.Get(key)
            return language.GetPhrase(stored and stored.PrintName or key)
        end

        -- Icon, bOverride (Icon is texture id), bQuad
        local function GetIcon(tab, key, thing)
            if tab == "Weapons" then
                local stored = weapons.Get(key)
                if !stored then return end

                return stored.WepSelectIcon2 or stored.WepSelectIcon, stored.WepSelectIcon2 == nil, stored.WepSelectIcon2box
            end

            if tab == "Equipment" then
                local Equip = Entity(thing)
                local Icon = IsValid(Equip) and Equip.IconOverride
                if !isstring(Icon) or Icon == "" then return end

                return Icon, false, true
            end

            if tab == "Attachments" then return hg.attachmentsIcons[thing], false, true end
            if tab == "Armor" then return hg.armorIcons[thing], false, true end
        end

        local function CanSee(ent, tab, key, thing)
            if tab == "Armor" then
                local armorData = hg.armor[key] and hg.armor[key][thing]
                return !(armorData and armorData.nodrop)
            end

            if tab == "Weapons" and ent:IsPlayer() then
                local wep = ent:GetActiveWeapon()
                return !(IsValid(wep) and wep:GetClass() == key)
            end

            return true
        end

        local function CanTake(tab, key)
            if tab == "Armor" then return !LocalPlayer():GetNetVar("Armor", {})[key] end

            return true
        end
    --//

    local function TakeItem(tab, key, ent)
        net.Start("ply_take_item")
            net.WriteString(tab)
            net.WriteString(tostring(key))
            net.WriteEntity(ent)
        net.SendToServer()
    end

    local function OpenInv(ent)
        if IsValid(plyMenu) then plyMenu:Remove() end
        if !IsValid(ent) then return end

        local inv = ent:GetNetVar("Inventory")
        if !inv then return end

        -- don't write in inv, it's a netvar table
        local Items = {
            ["Weapons"] = inv.Weapons,
            ["Ammo"] = inv.Ammo,
            ["Attachments"] = inv.Attachments,
            ["Armor"] = ent:GetNetVar("Armor"),
            ["Equipment"] = ent:GetEquipments(),
        }

        local isPlayer = ent:IsPlayer()
        local isBody = isPlayer or ent:IsRagdoll()

        ent.foundloot = ent.foundloot or {}

        --\\ Search time, not found items take time
            local searchTime = 0
            for _, tab in ipairs(Tabs) do
                if !istable(Items[tab]) then continue end

                for key in pairs(Items[tab]) do
                    if ent.foundloot[key] then continue end

                    searchTime = searchTime + (isBody and ((isPlayer and hg.TraitorLoot[key]) and 2 or 0.5) or 1)
                end
            end
        --//

        local name = isBody and (ent:GetPlayerName() or string.NiceName(ent:GetClass())) .. "'s inventory" or "Container"
        local sizeX, sizeY = ScrW() / 3, ScrH() / 2.5

        --\\ Frame
            plyMenu = vgui.Create("ZFrame")
            plyMenu.ent = ent
            plyMenu:SetTitle("")
            plyMenu:SetSize(sizeX, sizeY)
            plyMenu:Center()
            plyMenu:MakePopup()
            plyMenu:SetKeyBoardInputEnabled(false)
            plyMenu:ShowCloseButton(true)
            plyMenu:SetVisible(true)
            plyMenu.Created = CurTime()

            function plyMenu:PaintOver(w, h)
                draw.DrawText(name, "HomigradFontSmall", w / 2, 10, color_white, TEXT_ALIGN_CENTER)
                draw.DrawText("R - Close | LMB - Take | RMB - Item menu", "HomigradFontSmall", w / 2, h - h * 0.055, clr_text, TEXT_ALIGN_CENTER)
            end

            function plyMenu:Think()
                local lply = LocalPlayer()
                local ent = self.ent

                if !IsValid(ent) then self:Close() return end
                if !lply:Alive() or (lply.organism and lply.organism.otrub) then self:Remove() return end
                if (ent:GetPos() - lply:GetPos()):LengthSqr() > 125 ^ 2 then self:Remove() return end
                if ent:IsPlayer() and !IsValid(ent.FakeRagdoll) then self:Remove() return end
                if input.IsKeyDown(KEY_R) then self:Close() end
            end

            local DScrollPanel = vgui.Create("DScrollPanel", plyMenu)
            DScrollPanel:Dock(FILL)
            DScrollPanel:DockMargin(2, 8, 2, 20)

            local time = CurTime() + 3
            function DScrollPanel:Paint(w, h)
                if plyMenu.Created + searchTime + 3 < CurTime() then return end
                if time < CurTime() then time = CurTime() + 3 end

                draw.DrawText("Searching" .. string.rep(".", 3 - math.Round(time - CurTime())), "ZCity_Small", w / 2, h / 2.8, clr_search, TEXT_ALIGN_CENTER)
            end

            local grid = vgui.Create("DGrid", DScrollPanel)
            grid:Dock(FILL)
            grid:DockMargin(12, 10, 0, 0)
            grid:SetCols(5)
            grid:SetColWide(sizeX / 5 - sizeX / 16 / 9)
            grid:SetRowHeight(sizeY / 6.5 + sizeY / 32)
        --//

        local function TryTake(tab, key)
            if cooldown > CurTime() then return false end
            cooldown = CurTime() + 0.5

            if !CanTake(tab, key) then
                local OptionsMenu = DermaMenu()
                OptionsMenu:AddOption("You have item like this", function() end)
                OptionsMenu:Open()
                return false
            end

            surface.PlaySound("arc9_eft_shared/generic_mag_pouch_in" .. math.random(7) .. ".ogg")
            grid.SoundKD = CurTime() + 0.2

            return true
        end

        --\\ Item buttons, found items first, not found appear one by one
            local delay = 0
            for _, tab in ipairs(Tabs) do
                local things = Items[tab]
                if !istable(things) then continue end

                local keys = table.GetKeys(things)
                table.sort(keys, function(a, b)
                    return (ent.foundloot[a] and 1 or 0) > (ent.foundloot[b] and 1 or 0)
                end)

                for _, key in ipairs(keys) do
                    local thing = things[key]
                    if !CanSee(ent, tab, key, thing) then continue end

                    local found = ent.foundloot[key]
                    if !found then delay = delay + 1 end

                    local Icon, Override, Quad = GetIcon(tab, key, thing)
                    if isstring(Icon) then Icon = Material(Icon) end

                    local Text = GetName(tab, key, thing)
                    local TextDiv = Icon and (#utf8.sub(Text, 17) > 0 and 1.65 or 1.3) or 3
                    Text = utf8.sub(Text, 1, 17) .. "\n" .. utf8.sub(Text, 18)

				local button = vgui.Create("DButton", plyMenu)
				button:SetText("")
				button:DockMargin(5, 0, 2, 0)
				button:SetSize(0,0)
				--button:SetSize(sizeX / 5.8, sizeY / 5.8)
				button.Created = CurTime() + (!ent.foundloot[i] and 2 or 0) + count2
				button.Think = function(self)
					if self.Created and (self.Created < CurTime()) then
						self:SetSize(sizeX / 5.8, sizeY / 5.8)
						self:SetAlpha(0)
						surface.PlaySound("arc9_eft_shared/generic_mag_pouch_in" .. math.random(7) .. ".ogg")
						self:AlphaTo(255,0.3,0)
						ent.foundloot[i] = true
						self.Created = nil
					end
				end
				
				button.DoClick = function()
					if cooldown > CurTime() then return end

					cooldown = CurTime() + 0.5
					
					if not functions[tab](ply, ent, i, unpack(thing1)) then
						local OptionsMenu = DermaMenu() 
							OptionsMenu:AddOption( "You have item like this", function() end )
						OptionsMenu:Open()
						return
					end
					if istable(thing) then
						thing["render"] = {}
					end
					
					surface.PlaySound("arc9_eft_shared/generic_mag_pouch_in" .. math.random(7) .. ".ogg")
					grid.SoundKD = CurTime() + 0.2
					button:Remove()
					TakeItem(tab, i, thing, ent)
					--timer.Simple(0.5 * math.max(ply:Ping() / 50,1),function()
					--	--OpenInv(ent)
					--end)
				end

				button.DoRightClick = function()
					if cooldown > CurTime() then return end

					cooldown = CurTime() + 0.5

					
					if not functions[tab](ply, ent, i, unpack(thing1)) then
						local OptionsMenu = DermaMenu() 
							OptionsMenu:AddOption( "You have item like this", function() end )
						OptionsMenu:Open()
						return
					end
					if istable(thing) then
						thing["render"] = {}
					end
					
					surface.PlaySound("arc9_eft_shared/generic_mag_pouch_in" .. math.random(7) .. ".ogg")
					grid.SoundKD = CurTime() + 0.2
					--button:Remove()
					local OptionsMenu = DermaMenu() 
						OptionsMenu:AddOption( "Take", function() button:Remove() TakeItem(tab, i, thing, ent) end )
					OptionsMenu:Open()
					--timer.Simple(0.5 * math.max(ply:Ping() / 50,1),function()
					--	--OpenInv(ent)
					--end)
				end

				local name = nameThings(i, thing)
				button.col1 = 100
				button.Paint = function(self, w, h)
					button.col1 = Lerp(0.1, button.col1, button:IsHovered() and 255 or 100)
					if button:IsHovered() then
						button.SoundKD = button.SoundKD or 0
						if (grid.SoundKD or 0) < CurTime() and button.SoundKD < CurTime() then surface.PlaySound("arc9_eft_shared/generic_mag_pouch_out" .. math.random(7) .. ".ogg") end
						button.SoundKD = CurTime() + 0.1
					end

					surface.SetDrawColor(button.col1, 0, 0, 15)
					surface.DrawRect(0, 0, w, h)
					local Icon, HaveIcon, Overide, Quad = getIconThing(i, thing, tab)
					if Icon then
						button.Icon = button.Icon or (isstring(Icon) and Material(Icon)) or Icon -- Ну тут так, без выбора если что материал будет
					end

					if HaveIcon then
						if Overide and isnumber( Icon ) then
							surface.SetTexture(button.Icon)
						else
							surface.SetMaterial(button.Icon)
						end

                            surface.SetDrawColor(255, 255, 255)
                            surface.DrawTexturedRect(Quad and w / 5 + 5 or -5, 5, Quad and (w / 2 + 2.5) or (w + 10), Quad and h / 1.3 or h - 10)
                        end

					surface.SetDrawColor(button.col1,0,0,button.col1)
					surface.DrawOutlinedRect(0, 0, w, h, 1)
					local Text = (tab == "Ammo" and game.GetAmmoName(name)) or language.GetPhrase(name)
					local SubText = utf8.sub(Text, 17)
					Text = utf8.sub(Text, 1, 17) .. "\n" .. utf8.sub(Text, 18)
					draw.DrawText(Text, "ZCity_VerySuperTiny", w / 2, (HaveIcon and h / ((#SubText > 0 and 1.65) or 1.3)) or h / 3, color_white, TEXT_ALIGN_CENTER)
				end
				grid:AddItem(button)
			end
		end
	--plyMenu:SlideDown(0.5)
	end
end