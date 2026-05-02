local MODE = MODE

MODE.name = "as"
MODE.PrintName = "Active Shooter"

MODE.LootSpawn = true
MODE.LootOnTime = true
MODE.noBoxes = true
MODE.ForBigMaps = false
MODE.Chance = 0.06
MODE.LootDivTime = 500
MODE.AdminOnly = false
MODE.GuiltDisabled = true

MODE.ROUND_TIME = 1200

function MODE:GetLootTable()
	return {
		{ 15, "weapon_smallconsumable" },
		{ 12, "weapon_bigconsumable" },
		{ 8, "weapon_tourniquet" },
		{ 8, "weapon_bandage_sh" },
		{ 7, "weapon_ducttape" },
		{ 6, "weapon_painkillers" },
		{ 5, "weapon_bloodbag" },
		{ 4, "weapon_walkie_talkie" },
		{ 3, "hg_flashlight" },
		{ 3, "weapon_bigbandage_sh" },
		{ 2, "weapon_medkit_sh" },
		{ 1, "weapon_matches" },
		{ 0.2, "weapon_morphine" },
		{ 0.2, "weapon_mannitol" },
		{ 0.5, "weapon_naloxone" },
		{ 0.1, "weapon_fentanyl" },
		{ 0.9, "weapon_betablock" },
		{ 0.5, "weapon_adrenaline" }
	}
end

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
	return 1, true
end

local swatSpawned = false
local shooter_masks = {
	"arctic_balaclava",
	"bandana"
}

local russian_names = {
	"Artyom", "Boris", "Dmitry", "Evgeny", "Fedor", "Grigory", "Igor", "Ivan", "Kirill", "Leonid", "Mikhail", "Nikolai", "Oleg", "Pavel", "Ruslan", "Sergei", "Timofey", "Vasily", "Yury", "Zakhar",
	"Viktor", "Andrey", "Stanislav", "Alexey", "Konstantin", "Vladimir", "Yaroslav", "Svyatoslav", "Vyacheslav", "Gennady"
}

local russian_surnames = {
	"Ivanov", "Smirnov", "Kuznetsov", "Popov", "Vasiliev", "Petrov", "Sokolov", "Mikhailov", "Novikov", "Fedorov", "Morozov", "Volkov", "Alexeev", "Lebedev", "Semenov", "Egorov", "Pavlov", "Kozlov", "Stepanov", "Nikolaev",
	"Orlov", "Andreev", "Makarov", "Nikitin", "Zakharov", "Zaitsev", "Soloviev", "Borisov", "Yakovlev", "Vorobiev"
}

local swat_weps = {
	{ "weapon_m4a1", { "holo15", "grip3", "laser4" } },
	{ "weapon_hk416", { "holo15", "grip3", "laser4" } },
	{ "weapon_p90", {} },
	{ "weapon_mp7", { "holo14" } },
	{ "weapon_m4a1", { "optic2", "grip3", "supressor7" } }
}

local swat_otheritems = {
	"weapon_medkit_sh",
	"weapon_tourniquet",
	"weapon_walkie_talkie",
	"weapon_melee",
	"weapon_handcuffs",
	"weapon_hg_flashbang_tpik"
}

local swat_armors = {
	{ "ent_armor_vest8", "ent_armor_helmet6" }
}

function MODE:AssignTeams()
	local players = player.GetAll()
	table.Shuffle(players)

	local player_count = 0
	for _, ply in ipairs(players) do
		if ply:Team() ~= TEAM_SPECTATOR then
			player_count = player_count + 1
		end
	end

	local traitors_needed = 1
	local homicide_traitoramount = GetConVar("homicide_traitoramount")
	if homicide_traitoramount then
		traitors_needed = math.min(player_count - 1, homicide_traitoramount:GetInt())
	end
	traitors_needed = math.max(1, traitors_needed)

	for _, ply in ipairs(players) do
		if ply:Team() == TEAM_SPECTATOR then continue end

		if traitors_needed > 0 then
			traitors_needed = traitors_needed - 1
			ply:SetTeam(0)
			self.Shooter = ply
		else
			ply:SetTeam(1)
		end
	end
end

util.AddNetworkString("as_start")
util.AddNetworkString("as_roundend")
util.AddNetworkString("as_swat_spawn")
util.AddNetworkString("AS_SetShooterSubrole")

local function AS_ClearShooterWaiting(ply)
	if not IsValid(ply) then return end
	ply:SetNWBool("AS_WaitingShooter", false)
	if IsValid(ply.AS_WaitCam) then
		ply.AS_WaitCam:Remove()
	end
	ply.AS_WaitCam = nil
	if ply.UnSpectate then
		ply:UnSpectate()
	end
end

local function AS_SetShooterWaiting(ply)
	if not IsValid(ply) then return end
	ply:SetNWBool("AS_WaitingShooter", true)

	if IsValid(ply.AS_WaitCam) then
		ply.AS_WaitCam:Remove()
	end

	local waitCam = ents.Create("prop_physics")
	if not IsValid(waitCam) then return end
	waitCam:SetModel("models/props_junk/PopCan01a.mdl")
	waitCam:SetPos(Vector(0, 0, -16000))
	waitCam:SetAngles(angle_zero)
	waitCam:Spawn()
	waitCam:SetNoDraw(true)
	waitCam:SetNotSolid(true)
	waitCam:SetMoveType(MOVETYPE_NONE)
	waitCam:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

	ply.AS_WaitCam = waitCam
	ply:Spectate(OBS_MODE_FIXED)
	ply:SpectateEntity(waitCam)
end

net.Receive("AS_SetShooterSubrole", function(_, ply)
	local pref = net.ReadString()
	if pref ~= "overwatch" and pref ~= "old_reliable" and pref ~= "featherweight" and pref ~= "boom_or_bust" then return end
	ply.AS_ShooterSubrole = pref
end)

function MODE:CanLaunch()
	return true
end

function MODE:Intermission()
	game.CleanUpMap()

	self:AssignTeams()

	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR or ply:Team() == 0 then
			ply:KillSilent()
			continue
		end

		ply:SetupTeam(ply:Team())
	end

	net.Start("as_start")
	net.Broadcast()
end

function MODE:CheckAlivePlayers()
	local activeShooters = {}
	local civilians = {}

	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end
		if ply.organism and ply.organism.incapacitated then continue end
		if ply.organism and ply.organism.handcuffed then continue end

		if ply:Team() == 0 then
			table.insert(activeShooters, ply)
		elseif ply:Team() == 1 then
			table.insert(civilians, ply)
		end
	end

	return {activeShooters, civilians}
end

function MODE:ShouldRoundEnd()
	if zb.ROUND_START + 56 > CurTime() then return end

	local endround, winner = zb:CheckWinner(self:CheckAlivePlayers())
	return endround
end

function MODE:EndRound()
	for _, ply in player.Iterator() do
		if timer.Exists("AS_ShooterSpawn" .. ply:EntIndex()) then
			timer.Remove("AS_ShooterSpawn" .. ply:EntIndex())
		end
		AS_ClearShooterWaiting(ply)
	end

	local endround, winnerIndex = zb:CheckWinner(self:CheckAlivePlayers())

	local winningTeam = 2
	if winnerIndex == 1 then
		winningTeam = 0
	elseif winnerIndex == 2 then
		winningTeam = 1
	end

	timer.Simple(2, function()
		net.Start("as_roundend")
		net.WriteUInt(winningTeam, 8)
		net.Broadcast()
	end)
end

function MODE:RoundStart()
	swatSpawned = false

	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		ply:Freeze(false)
	end
end

function MODE:GetTeamSpawn()
	self.ShooterSpawns = self.ShooterSpawns or zb.TranslatePointsToVectors(zb.GetMapPoints("AS_SHOOTER_SPAWN"))

	local defaultSpawn = zb:GetRandomSpawn()

	return self.ShooterSpawns, {defaultSpawn}
end

function MODE:GiveEquipment()
	timer.Simple(0.5, function()
		self.ShooterSpawned = false

		for _, ply in player.Iterator() do
			if ply:Team() == TEAM_SPECTATOR then continue end

			if ply:Team() == 0 then
				local entIndex = ply:EntIndex()

				AS_SetShooterWaiting(ply)

				timer.Create("AS_ShooterSpawn" .. entIndex, 55, 1, function()
					if not IsValid(ply) or ply:Team() == TEAM_SPECTATOR then return end
					AS_ClearShooterWaiting(ply)

					ply:Spawn()
					ply:SetSuppressPickupNotices(true)
					ply.noSound = true

					ply:SetupTeam(0)
					ply:SetPlayerClass("activeshooter")
					zb.GiveRole(ply, "Active Shooter", Color(200, 40, 40))

					local russianName = table.Random(russian_names) .. " " .. table.Random(russian_surnames)
					ply:SetNWString("RussianName", russianName)
					ply:SetNetVar("RussianName", russianName)
					ply:SetNWString("PlayerName", russianName)

					timer.Simple(0, function()
						if not IsValid(ply) then return end
						ApplyAppearance(ply, nil, nil, nil, true)
						local Appearance = ply.CurAppearance or hg.Appearance.GetRandomAppearance()
						Appearance.AAttachments = { shooter_masks[math.random(#shooter_masks)], "terrorist_band" }
						ply:SetNetVar("Accessories", Appearance.AAttachments or "none")
						ply.CurAppearance = Appearance
						ply:SetNWString("PlayerName", russianName)
					end)

					local inv = ply:GetNetVar("Inventory", {})
					inv["Weapons"] = inv["Weapons"] or {}
					inv["Weapons"]["hg_flashlight"] = true
					inv["Weapons"]["hg_sling"] = true
					ply:SetNetVar("Inventory", inv)

					local hands = ply:Give("weapon_hands_sh")

					local subrole = table.Random({ "overwatch", "old_reliable", "featherweight", "boom_or_bust" })
					ply.AS_ShooterSubrole = subrole

					local radio = ply:Give("weapon_walkie_talkie")
					if IsValid(radio) then
						radio:AdjustFrequency(100.2 - radio.Frequency)
						radio.isOn = true
						radio:SetIsOn(true)
					end

					if subrole == "overwatch" then
						ply.organism.stamina.range = 150
						hg.AddArmor(ply, "ent_armor_vest16")
						hg.AddArmor(ply, "ent_armor_helmet3")

						local primary = ply:Give("weapon_rpk")
						if IsValid(primary) and primary.GetMaxClip1 then
							ply:GiveAmmo(primary:GetMaxClip1() * 2, primary:GetPrimaryAmmoType(), true)
							ply:SelectWeapon(primary:GetClass())
						end

						local pistol = ply:Give("weapon_makarov")
						if IsValid(pistol) and pistol.GetMaxClip1 then
							ply:GiveAmmo(pistol:GetMaxClip1() * 2, pistol:GetPrimaryAmmoType(), true)
						end

						ply:Give("weapon_bandage_sh")
						ply:Give("weapon_melee")
					elseif subrole == "featherweight" then
						ply.organism.stamina.range = 280

						local pistol = ply:Give("weapon_glock18c")
						if IsValid(pistol) and pistol.GetMaxClip1 then
							hg.AddAttachmentForce(ply, pistol, { "laser2", "supressor4" })
							ply:GiveAmmo(pistol:GetMaxClip1() * 6, pistol:GetPrimaryAmmoType(), true)
						end

						ply:Give("weapon_bandage_sh")
						ply:Give("weapon_melee")
					elseif subrole == "boom_or_bust" then
						ply.organism.stamina.range = 175
						hg.AddArmor(ply, "ent_armor_vest18")

						local pistol = ply:Give("weapon_glock18c")
						if IsValid(pistol) and pistol.GetMaxClip1 then
							ply:GiveAmmo(pistol:GetMaxClip1() * 3, pistol:GetPrimaryAmmoType(), true)
							ply:SelectWeapon(pistol:GetClass())
						else
							ply:SelectWeapon("weapon_hands_sh")
						end

						ply:Give("weapon_claymore")
						ply:Give("weapon_hg_slam")
						ply:Give("weapon_hg_pipebomb_tpik")
						ply:Give("weapon_bandage_sh")
						ply:Give("weapon_breachcharge")
						ply:Give("weapon_bayonet")
					else
						ply.organism.stamina.range = 220
						hg.AddArmor(ply, "ent_armor_vest4")
						hg.AddArmor(ply, "ent_armor_helmet12")

						local pistol = ply:Give("weapon_m1911")
						if IsValid(pistol) and pistol.GetMaxClip1 then
							ply:GiveAmmo(pistol:GetMaxClip1() * 3, pistol:GetPrimaryAmmoType(), true)
						end

						local shotgun = ply:Give("weapon_saiga12")
						if IsValid(shotgun) and shotgun.GetMaxClip1 then
							ply:GiveAmmo(shotgun:GetMaxClip1() * 4, shotgun:GetPrimaryAmmoType(), true)
							ply:SelectWeapon(shotgun:GetClass())
						else
							ply:SelectWeapon("weapon_hands_sh")
						end

						ply:Give("weapon_hg_pipebomb_tpik")
						ply:Give("weapon_bandage_sh")
						ply:Give("weapon_medkit_sh")
						ply:Give("weapon_melee")
					end

					ply:SetSuppressPickupNotices(false)
					ply.noSound = false

					self.ShooterSpawned = true
				end)
			else
				ply:SetSuppressPickupNotices(true)
				ply.noSound = true

				ply:SetupTeam(1)
				zb.GiveRole(ply, "Civilian", Color(40, 160, 40))

				local hands = ply:Give("weapon_hands_sh")
				ply:SelectWeapon("weapon_hands_sh")

				ply:SetSuppressPickupNotices(false)
				ply.noSound = false
			end

			timer.Simple(0.5, function()
				if IsValid(ply) then
					ply.noSound = false
					ply:SetSuppressPickupNotices(false)
				end
			end)
		end
	end)
end

function MODE:RoundThink()
	if not swatSpawned and (CurTime() - (zb.ROUND_BEGIN or CurTime())) >= 300 then
		local deadPlayers = {}

		for _, ply in player.Iterator() do
			if not ply:Alive() and ply:Team() ~= TEAM_SPECTATOR then
				table.insert(deadPlayers, ply)
			end
		end

		local spawnVectors = self.ShooterSpawns or zb.TranslatePointsToVectors(zb.GetMapPoints("AS_SHOOTER_SPAWN"))
		local startpos = (spawnVectors and spawnVectors[1]) or zb:GetRandomSpawn()

		for i = 1, math.min(4, #deadPlayers) do
			local ply = deadPlayers[i]

			ply:Spawn()
			ply:SetTeam(2)

			if not startpos then
				startpos = ply:GetPos()
			else
				hg.tpPlayer(startpos, ply, i, 0)
			end

			ply:SetPlayerClass("swat")

			local inv = ply:GetNetVar("Inventory") or {}
			inv["Weapons"] = inv["Weapons"] or {}
			inv["Weapons"]["hg_sling"] = true
			ply:SetNetVar("Inventory", inv)

			local armor = swat_armors[math.random(#swat_armors)]
			hg.AddArmor(ply, armor)

			zb.GiveRole(ply, "SWAT", Color(0, 0, 190))

			local wep = swat_weps[math.random(#swat_weps)]
			local gun = ply:Give(wep[1])
			if IsValid(gun) and gun.GetMaxClip1 then
				hg.AddAttachmentForce(ply, gun, wep[2])
				ply:GiveAmmo(gun:GetMaxClip1() * 3, gun:GetPrimaryAmmoType(), true)
			end

			local pistol = ply:Give("weapon_glock17")
			if IsValid(pistol) and pistol.GetMaxClip1 then
				ply:GiveAmmo(pistol:GetMaxClip1() * 3, pistol:GetPrimaryAmmoType(), true)
			end

			for _, item in ipairs(swat_otheritems) do
				ply:Give(item)
			end

			local hands = ply:Give("weapon_hands_sh")
			ply:SelectWeapon("weapon_hands_sh")
		end

		net.Start("as_swat_spawn")
		net.Broadcast()

		swatSpawned = true
	end
end
