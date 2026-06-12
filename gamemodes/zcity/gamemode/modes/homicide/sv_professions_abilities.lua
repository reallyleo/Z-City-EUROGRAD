local MODE = MODE
MODE.SendFootStepEvery = 3
-- MODE.SendFootStepEvery = 1

util.AddNetworkString("HMCD_Professions_Abilities_AddFootstep")
util.AddNetworkString("HMCD_Professions_Abilities_DisplayOrganismInfo")
util.AddNetworkString("HMCD_LocksmithDoorAction")

function MODE.DisplayOrganismInfo(organism, ply)
	local text_info = ""
	text_info = text_info .. " Saturation" .. organism.o2 .. "\n"
	
	net.Start("HMCD_Professions_Abilities_DisplayOrganismInfo")
		net.WriteString(text_info)
	net.Send(ply)
end

--\\
hook.Add("HG_PlayerFootstep_Notify", "HMCD_Professions_Abilities", function(ply, pos, foot, snd, volume, filter)
	ply.ProfessionAbility_FootstepsAmt = ply.ProfessionAbility_FootstepsAmt or 0
	ply.ProfessionAbility_FootstepsAmt = ply.ProfessionAbility_FootstepsAmt + 1
	
	if(ply.ProfessionAbility_FootstepsAmt >= MODE.SendFootStepEvery)then
		ply.ProfessionAbility_FootstepsAmt = 0
		
		net.Start("HMCD_Professions_Abilities_AddFootstep")
			net.WriteVector(pos)
			net.WriteFloat(ply:EyeAngles().y)
			net.WriteBool(foot == 0)
			
			local character_color = ply:GetNWVector("PlayerColor")
			
			if(!IsColor(character_color))then
				character_color = Color(character_color[1] * 255, character_color[2] * 255, character_color[3] * 255)
			end
			
			net.WriteColor(character_color, false)
			
			local recepients = {}
			
			for _, recepient_ply in player.Iterator() do
				if(recepient_ply.Profession == "huntsman" and recepient_ply != ply)then
					recepients[#recepients+1] = recepient_ply
				end
			end
		net.Send(recepients)
	end
end)

hook.Add("PlayerPostThink", "HMCD_Professions_Abilities", function(ply)
	if(MODE.RoleChooseRoundTypes[MODE.Type])then
		if(ply:Alive())then
			if(ply.Profession == "doctor")then
				if(ply:KeyDown(IN_SPEED))then
					if(ply:KeyPressed(IN_USE))then
						local aim_ent, other_ply = MODE.GetPlayerTraceToOther(ply)
						
						if(IsValid(aim_ent))then
							if(other_ply)then
								MODE.DisplayOrganismInfo(other_ply.organism, ply)
							end
						end
					end
				end
			end
			
			if(ply.Profession == "huntsman")then
				
			end
		end
	end
end)

concommand.Add("hg_create_pipebomb", function(ply)
	if ply:Alive() and not ply.organism.otrub and ply.Profession == "engineer" then
		local have_ammo
		local have_nails

		for id, amt in pairs(ply:GetAmmo()) do
			local name = game.GetAmmoName(id)

			if name == "Nails" and amt >= 3 then
				have_nails = true
				continue
			end

			local tbl = hg.ammotypeshuy[name]
			if tbl.BulletSettings and tbl.BulletSettings.Mass * amt > 50 then
				have_ammo = {name, amt}
			end
		end

		local have_pipe = ply:HasWeapon("weapon_leadpipe")
		if have_ammo and have_pipe and have_nails then
			ply:SetAmmo(ply:GetAmmoCount("Nails") - 3, "Nails")
			ply:SetAmmo(math.Round((hg.ammotypeshuy[have_ammo[1]].BulletSettings.Mass * have_ammo[2] - 50) / hg.ammotypeshuy[have_ammo[1]].BulletSettings.Mass), have_ammo[1])
			ply:StripWeapon("weapon_leadpipe")

			ply:Give("weapon_hg_pipebomb_tpik")--crafted!
		end
    end
end)

concommand.Add("hg_create_molotov", function(ply)
	if ply:Alive() and not ply.organism.otrub and ply.Profession == "engineer" then
		local have_barrel_nearby
		local have_bandage = ply:HasWeapon("weapon_bandage_sh") or ply:HasWeapon("weapon_bigbandage_sh")
		local have_bottle = ply:HasWeapon("weapon_hg_bottle")

		for i, ent in ipairs(ents.FindInSphere(ply:GetPos(), 64)) do
			if hg.gas_models[ent:GetModel()] and !ent:GetNWBool("EmptyBarrel", false) then
				have_barrel_nearby = true
				break
			end
		end

		if have_barrel_nearby and have_bandage and have_bottle then
			if ply:HasWeapon("weapon_bandage_sh") then
				ply:StripWeapon("weapon_bandage_sh")
			else
				ply:StripWeapon("weapon_bigbandage_sh")
			end
			
			ply:StripWeapon("weapon_hg_bottle")

			ply:Give("weapon_hg_molotov_tpik")
		end
    end
end)
--//

local function isHmcdRound()
	if not zb then return false end
	return zb.CROUND_MAIN == "hmcd" or zb.CROUND == "hmcd"
end

hook.Add("Org Think", "HMCD_Chemworker_CyanideTell", function(owner, org, timeValue)
	if not isHmcdRound() then return end
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
	if owner.Profession ~= "chemworker" then return end
	if not org or not org.poison3 then return end

	if (org.poison3 + 4) < CurTime() then
		local tells = {
			"That smell... bitter almonds. That's not good..",
			"Air's contaminated.. I can smell it...",
			"Something chemical in the air..."
		}
		org.owner:Notify(tells[math.random(#tells)], true, "cyanide", 3)
	end
end)

local function patchParamedicDoubleUse()
	local function wrapHeal(stored)
		if not stored or stored.HMCD_Paramedic_HealPatched then return end
		if type(stored.Heal) ~= "function" then return end

		local oldHeal = stored.Heal

		stored.Heal = function(self, ent, mode, ...)
			local owner = self.GetOwner and self:GetOwner()
			if IsValid(owner) and owner.Profession == "paramedic" and isHmcdRound() and mode and self.modeValues and self.modeValuesdef then
				local def = self.modeValuesdef[mode]
				if istable(def) and def[2] == true then
					local wep = self
					local oldValue = wep.modeValues[mode]
					if isnumber(oldValue) then
						wep.modeValues[mode] = oldValue * 2
						local ret = oldHeal(wep, ent, mode, ...)
						if IsValid(wep) and wep.modeValues then
							wep.modeValues[mode] = (wep.modeValues[mode] or 0) / 2
						end
						return ret
					end
				end
			end

			return oldHeal(self, ent, mode, ...)
		end

		stored.HMCD_Paramedic_HealPatched = true
	end

	for _, w in ipairs(weapons.GetList()) do
		local class = w.ClassName or w
		if isstring(class) then
			wrapHeal(weapons.GetStored(class))
		end
	end
end

hook.Add("InitPostEntity", "HMCD_ParamedicDoubleUse", function()
	patchParamedicDoubleUse()
end)

timer.Simple(0, function()
	patchParamedicDoubleUse()
end)

local function isDoor(ent)
	if not IsValid(ent) then return false end
	if hgIsDoor and hgIsDoor(ent) then return true end
	return string.find(string.lower(ent:GetClass() or ""), "door", 1, true) ~= nil
end

local function setDoorLocked(ent, locked)
	if not IsValid(ent) then return end
	ent:SetNWBool("HMCD_LocksmithLocked", locked == true)
	if locked then
		ent:Fire("close")
		ent:Fire("lock")
		ent:EmitSound("doors/default_locked.wav", 70, 100, 1, CHAN_AUTO)
	else
		ent:Fire("unlock")
		ent:EmitSound("doors/latchunlocked1.wav", 70, 100, 1, CHAN_AUTO)
	end
end

local function getLocksmithDoor(ply)
	if not IsValid(ply) then return end
	local tr = ply:GetEyeTrace()
	local ent = tr and tr.Entity
	if not IsValid(ent) then return end
	if ply:EyePos():DistToSqr(tr.HitPos) > (120 * 120) then return end
	if not isDoor(ent) then return end
	return ent
end

net.Receive("HMCD_LocksmithDoorAction", function(len, ply)
	local locked = net.ReadBool()
	if not isHmcdRound() then return end
	if not IsValid(ply) or not ply:Alive() then return end
	if ply.organism and ply.organism.otrub then return end
	if ply.Profession ~= "locksmith" then return end
	if (ply.HMCD_LocksmithNextUse or 0) > CurTime() then return end
	ply.HMCD_LocksmithNextUse = CurTime() + 1

	local ent = getLocksmithDoor(ply)
	if not IsValid(ent) then return end
	setDoorLocked(ent, locked)
end)

local function applyProfessionLoadout(ply)
	if not isHmcdRound() then return end
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
	if not ply.Profession or ply.Profession == "" then return end
	if ply.HMCD_ProfessionLoadoutGiven then return end

	local function wepExists(class)
		return weapons.GetStored(class) ~= nil
	end

	local function giveIfOk(class)
		if not class then return end
		if not wepExists(class) then return end
		if ply:HasWeapon(class) then return end
		ply:Give(class)
	end
	
	local function giveWeaponWithAmmo(class, mult)
		if not class then return end
		if not wepExists(class) then return end
		if ply:HasWeapon(class) then return end
		local wep = ply:Give(class)
		if IsValid(wep) and wep.GetMaxClip1 and mult and mult > 0 then
			ply:GiveAmmo(wep:GetMaxClip1() * mult, wep:GetPrimaryAmmoType(), true)
		end
		return wep
	end

	if ply.Profession == "doctor" then
		ply.HMCD_ProfessionLoadoutGiven = true
		if math.random(100) > 15 then
			local weaponRoll = math.random(100)
			if weaponRoll <= 30 then
				giveIfOk("weapon_thaumaturgic_arm")
			elseif weaponRoll <= 60 then
				if wepExists("weapon_scalpel") then
					giveIfOk("weapon_scalpel")
				else
					giveIfOk("weapon_thaumaturgic_arm")
				end
			end

			if math.random(100) <= 60 then
				local mainRoll = math.random(100)
				if mainRoll <= 40 then
					giveIfOk("weapon_bandage_sh")
				elseif mainRoll <= 65 then
					giveIfOk("weapon_bloodbag")
				elseif mainRoll <= 80 then
					giveIfOk("weapon_tourniquet")
				elseif mainRoll <= 90 then
					giveIfOk("weapon_bigbandage_sh")
				elseif mainRoll <= 97 then
					giveIfOk("weapon_medkit_sh")
				else
					giveIfOk("weapon_needle")
				end
			end

			if math.random(100) <= 25 then
				local extraRoll = math.random(100)
				if extraRoll <= 45 then
					giveIfOk("weapon_painkillers")
				elseif extraRoll <= 65 then
					giveIfOk("weapon_naloxone")
				elseif extraRoll <= 80 then
					giveIfOk("weapon_adrenaline")
				elseif extraRoll <= 90 then
					giveIfOk("weapon_mannitol")
				else
					giveIfOk("weapon_betablock")
				end
			end
		end
	elseif ply.Profession == "paramedic" then
		ply.HMCD_ProfessionLoadoutGiven = true
		if math.random(100) > 25 then
			if wepExists("weapon_scalpel") and math.random(100) <= 50 then
				giveIfOk("weapon_scalpel")
			end

			if math.random(100) <= 50 then
				giveIfOk("weapon_bandage_sh")
			end
			if math.random(100) <= 35 then
				giveIfOk("weapon_tourniquet")
			end
			if math.random(100) <= 25 then
				giveIfOk("weapon_painkillers")
			end
			if math.random(100) <= 10 then
				giveIfOk("weapon_medkit_sh")
			end
			if math.random(100) <= 8 then
				giveIfOk("weapon_needle")
			end
		end
	elseif ply.Profession == "security" then
		ply.HMCD_ProfessionLoadoutGiven = true

		if math.random(1, 2) == 1 then
			giveIfOk("weapon_taser")
			local taser = ply:GetWeapon("weapon_taser")
			if IsValid(taser) then
				ply:GiveAmmo(taser:GetMaxClip1() * 2, taser:GetPrimaryAmmoType(), true)
			end
		else
			giveIfOk("weapon_handcuffs")
			giveIfOk("weapon_handcuffs_key")
		end
	elseif ply.Profession == "armedsecurity" then
		ply.HMCD_ProfessionLoadoutGiven = true

		if math.random(100) <= 60 then
			giveIfOk("weapon_handcuffs")
			giveIfOk("weapon_handcuffs_key")
		else
			giveIfOk("weapon_taser")
			local taser = ply:GetWeapon("weapon_taser")
			if IsValid(taser) then
				ply:GiveAmmo(taser:GetMaxClip1() * 1, taser:GetPrimaryAmmoType(), true)
			end
		end

		if math.random(100) <= 45 then
			local options = {}
			if wepExists("weapon_mp5") then options[#options + 1] = "weapon_mp5" end
			if #options > 0 then
				giveIfOk(options[math.random(#options)])
			end
		end

		if math.random(100) <= 25 then
			giveIfOk("weapon_bandage_sh")
		end
		if math.random(100) <= 15 then
			giveIfOk("weapon_tourniquet")
		end
	elseif ply.Profession == "courier" then
		ply.HMCD_ProfessionLoadoutGiven = true
		if math.random(100) <= 65 then
			giveIfOk("weapon_walkie_talkie")
		end
	elseif ply.Profession == "huntsman" then
		ply.HMCD_ProfessionLoadoutGiven = true
		if math.random(100) <= 80 then
			giveIfOk("weapon_bayonet")
		end
		if math.random(100) <= 60 then
			giveIfOk("weapon_walkie_talkie")
		end
	elseif ply.Profession == "locksmith" then
		ply.HMCD_ProfessionLoadoutGiven = true
		if math.random(100) <= 65 then
			giveIfOk("weapon_handcuffs_key")
		end
		if math.random(100) <= 25 then
			giveIfOk("weapon_walkie_talkie")
		end
	elseif ply.Profession == "chemworker" then
		ply.HMCD_ProfessionLoadoutGiven = true
		if math.random(100) <= 70 then
			hg.AddArmor(ply, "ent_armor_mask2")
		end
		if math.random(100) <= 35 then
			giveIfOk("weapon_walkie_talkie")
		end
		if math.random(100) <= 20 then
			giveIfOk("weapon_naloxone")
		end
	elseif ply.Profession == "engineer" then
		ply.HMCD_ProfessionLoadoutGiven = true
		local gaveHammer = false
		if math.random(100) <= 70 then
			giveIfOk("weapon_hammer")
			gaveHammer = ply:HasWeapon("weapon_hammer")
		end
		if gaveHammer then
			ply:GiveAmmo(math.random(8, 16), "Nails", true)
		end
		if math.random(100) <= 55 then
			giveIfOk("weapon_ducttape")
		end
		if math.random(100) <= 30 then
			giveIfOk("weapon_walkie_talkie")
		end
	elseif ply.Profession == "cook" then
		ply.HMCD_ProfessionLoadoutGiven = true
		if math.random(100) <= 85 then
			local options = {}
			if wepExists("weapon_hg_cleaver") then options[#options + 1] = "weapon_hg_cleaver" end
			if wepExists("weapon_kitchenknife") then options[#options + 1] = "weapon_kitchenknife" end
			if wepExists("weapon_pan") then options[#options + 1] = "weapon_pan" end
			if #options > 0 then
				giveIfOk(options[math.random(#options)])
			end
		end
		if math.random(100) <= 35 then
			giveIfOk("weapon_bandage_sh")
		end
		if math.random(100) <= 25 then
			giveIfOk("weapon_painkillers")
		end
	elseif ply.Profession == "builder" then
		ply.HMCD_ProfessionLoadoutGiven = true
		if math.random(100) <= 70 then
			giveIfOk("weapon_hammer")
		end
		if math.random(100) <= 60 then
			giveIfOk("weapon_ducttape")
		end
		if math.random(100) <= 20 then
			giveIfOk("weapon_walkie_talkie")
		end
	end

	if ply.Profession ~= "courier" then
		if ply.ProfessionAbility_Courier_BaseStaminaMax and ply.organism and ply.organism.stamina then
			ply.organism.stamina.max = ply.ProfessionAbility_Courier_BaseStaminaMax
			ply.organism.stamina.regen = ply.ProfessionAbility_Courier_BaseStaminaRegen or ply.organism.stamina.regen
			ply.ProfessionAbility_Courier_BaseStaminaMax = nil
			ply.ProfessionAbility_Courier_BaseStaminaRegen = nil
		end
	else
		if ply.organism then
			ply.organism.stamina = ply.organism.stamina or {}
			ply.ProfessionAbility_Courier_BaseStaminaMax = ply.ProfessionAbility_Courier_BaseStaminaMax or ply.organism.stamina.max or 140
			ply.ProfessionAbility_Courier_BaseStaminaRegen = ply.ProfessionAbility_Courier_BaseStaminaRegen or ply.organism.stamina.regen or 1

			ply.organism.stamina.max = ply.ProfessionAbility_Courier_BaseStaminaMax * 2
			ply.organism.stamina.regen = ply.ProfessionAbility_Courier_BaseStaminaRegen * 1.25
		end
	end
end

hook.Add("PlayerSpawn", "HMCD_Professions_Loadouts", function(ply)
	if not isHmcdRound() then return end
	timer.Simple(0, function()
		if IsValid(ply) then
			applyProfessionLoadout(ply)
		end
	end)
end)

hook.Add("PlayerDeath", "HMCD_Professions_Loadouts", function(ply)
	if IsValid(ply) then
		ply.HMCD_ProfessionLoadoutGiven = nil
	end
end)

hook.Add("RoundStateChange", "HMCD_Professions_Loadouts", function(old, new)
	if new == 2 then
		for _, ply in player.Iterator() do
			ply.HMCD_ProfessionLoadoutGiven = nil
		end
	end
end)
