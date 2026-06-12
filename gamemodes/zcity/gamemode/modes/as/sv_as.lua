local MODE = MODE

MODE.name = "as"
MODE.PrintName = "Active Threat Response"

MODE.LootSpawn = true
MODE.LootOnTime = true
MODE.noBoxes = true
MODE.ForBigMaps = false
MODE.Chance = 0.06
MODE.LootDivTime = 500
MODE.AdminOnly = false
MODE.GuiltDisabled = false

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
	return 1, false
end

local swatSpawned = false

local shooterPlayerModels = {
	"models/player/masked_shooter01.mdl",
	"models/player/masked_shooter02.mdl",
	"models/player/masked_shooter03.mdl",
	"models/player/masked_shooter04.mdl",
}

local shooterLoadouts = {
	{
		primary = "weapon_ar15",
		primaryAttachments = { "holo15", "grip3", "laser4" },
		primaryAmmoMul = 2,
		secondary = "weapon_m9beretta",
		secondaryAmmoMul = 2,
		items = { "weapon_bandage_sh", "weapon_melee" }
	},
	{
		primary = "weapon_mp7",
		primaryAttachments = { "holo1" },
		primaryAmmoMul = 6,
		items = { "weapon_bandage_sh", "weapon_melee" }
	},
	{
		primary = "weapon_m16a2",
		primaryAmmoMul = 2,
		secondary = "weapon_pl15",
		secondaryAmmoMul = 2,
		items = { "weapon_bandage_sh", "weapon_breachcharge", "weapon_melee" }
	},
	{
		primary = "weapon_xm1014",
		primaryAmmoMul = 4,
		secondary = "weapon_m45",
		secondaryAmmoMul = 3,
		items = { "weapon_bandage_sh", "weapon_medkit_sh", "weapon_melee" }
	},
	{
		secondary = "weapon_glock26",
		secondaryAttachments = { "ent_att_holo16", "ent_att_laser2" },
		secondaryAmmoMul = 5,
		items = { "weapon_hg_pipebomb_tpik", "weapon_bombvest", "weapon_bandage_sh", "weapon_melee" }
	},
}

local function AS_GiveShooterLoadout(ply, loadout)
	if not IsValid(ply) then return end
	loadout = loadout or table.Random(shooterLoadouts)
	if not loadout then return end

	local function giveWeapon(class, ammoMul, attachments)
		if not class or class == "" then return end
		local wep = ply:Give(class)
		if not IsValid(wep) then return end

		if attachments and hg and hg.AddAttachmentForce then
			for _, att in ipairs(attachments) do
				if att and att ~= "" then
					hg.AddAttachmentForce(ply, wep, att)
				end
			end
		end

		if ammoMul and wep.GetMaxClip1 and wep.GetPrimaryAmmoType then
			local maxClip = wep:GetMaxClip1()
			local ammoType = wep:GetPrimaryAmmoType()
			if maxClip and maxClip > 0 and ammoType and ammoType >= 0 then
				ply:GiveAmmo(maxClip * ammoMul, ammoType, true)
			end
		end

		return wep
	end

	local primary = giveWeapon(loadout.primary, loadout.primaryAmmoMul, loadout.primaryAttachments)
	giveWeapon(loadout.secondary, loadout.secondaryAmmoMul, loadout.secondaryAttachments)

	if loadout.items then
		for _, item in ipairs(loadout.items) do
			if item and item ~= "" then
				ply:Give(item)
			end
		end
	end

	if IsValid(primary) then
		ply:SelectWeapon(primary:GetClass())
	end
end

local swat_weps = {
	{ "weapon_m4a1", { "holo15", "grip3", "laser4" } },
	{ "weapon_hk416", { "holo15", "grip3", "laser4" } },
	{ "weapon_p90", { "holo14" } },
	{ "weapon_mp7", { "holo14" } },
	{ "weapon_m4a1", { "holo2", "grip3", "supressor7" } }
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

	local traitors_needed = 0
	if player_count > 1 then
		traitors_needed = math.min(4, math.min(player_count - 1, math.max(1, math.ceil(player_count / 5))))
	end

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

local function AS_GetShooterSpawns()
	local spawns = {}

	for _, ent in ipairs(ents.FindByClass("as_shooter_spawn")) do
		spawns[#spawns + 1] = ent:GetPos()
	end

	if #spawns == 0 and zb and zb.GetMapPoints then
		local points = zb.GetMapPoints("AS_SHOOTER_SPAWN") or {}
		for _, p in ipairs(points) do
			if p and p.pos then
				spawns[#spawns + 1] = p.pos
			end
		end
	end

	return spawns
end

local function AS_SetupCivilian(ply)
	if not IsValid(ply) then return end
	ply:SetTeam(1)
	if hg and hg.CreateInv then
		hg.CreateInv(ply)
	end
	ply:GetRandomSpawn()
end

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
		if ply:Team() == 1 then
			ply:GetRandomSpawn()
		end
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
	self.ShooterSpawns = AS_GetShooterSpawns()
	return self.ShooterSpawns, nil
end

function MODE:GiveEquipment()
	timer.Simple(0.5, function()
		self.ShooterSpawned = false
		local shooters = {}
		for _, ply in player.Iterator() do
			if ply:Team() == TEAM_SPECTATOR then continue end
			if ply:Team() ~= 0 then continue end
			table.insert(shooters, ply)
		end
		table.sort(shooters, function(a, b)
			return a:EntIndex() < b:EntIndex()
		end)

		local loadoutPool = table.Copy(shooterLoadouts)
		table.Shuffle(loadoutPool)

		local shooterAssignments = {}
		for i, ply in ipairs(shooters) do
			local idx = ((i - 1) % #shooterPlayerModels) + 1
			shooterAssignments[ply] = {
				model = shooterPlayerModels[idx],
				loadout = loadoutPool[i] or table.Random(shooterLoadouts)
			}
		end

		for _, ply in player.Iterator() do
			if ply:Team() == TEAM_SPECTATOR then continue end

			if ply:Team() == 0 then
				local assignment = shooterAssignments[ply]
				local shooterModel = assignment and assignment.model
				local shooterLoadout = assignment and assignment.loadout
				local entIndex = ply:EntIndex()

				AS_SetShooterWaiting(ply)

				timer.Create("AS_ShooterSpawn" .. entIndex, 55, 1, function()
					if not IsValid(ply) or ply:Team() == TEAM_SPECTATOR then return end
					AS_ClearShooterWaiting(ply)

					ply:Spawn()
					ply:SetSuppressPickupNotices(true)
					ply.noSound = true
					ply:StripWeapons()
					ply:StripAmmo()

					ply:SetupTeam(0)
					ply:SetPlayerClass("activeshooter", { shooterModel = shooterModel })
					zb.GiveRole(ply, "Active Threat", Color(200, 40, 40))

					local inv = ply:GetNetVar("Inventory", {})
					inv["Weapons"] = inv["Weapons"] or {}
					inv["Weapons"]["hg_flashlight"] = true
					inv["Weapons"]["hg_sling"] = true
					ply:SetNetVar("Inventory", inv)

					local hands = ply:Give("weapon_hands_sh")

					local radio = ply:Give("weapon_walkie_talkie")
					if IsValid(radio) then
						radio:AdjustFrequency(100.2 - radio.Frequency)
						radio.isOn = true
						radio:SetIsOn(true)
					end
					AS_GiveShooterLoadout(ply, shooterLoadout)

					ply:SetSuppressPickupNotices(false)
					ply.noSound = false

					self.ShooterSpawned = true
				end)
			else
				ply:SetSuppressPickupNotices(true)
				ply.noSound = true

				AS_SetupCivilian(ply)
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
		
		local shooterSpawns = AS_GetShooterSpawns()
		local shooterBase = zb.tspawn or (shooterSpawns and shooterSpawns[1]) or zb:GetRandomSpawn()

		local startpos
		if shooterSpawns and #shooterSpawns > 0 then
			startpos = table.Random(shooterSpawns)
			if shooterBase and shooterBase:DistToSqr(startpos) < (512 * 512) then
				for _, candidate in RandomPairs(shooterSpawns) do
					if shooterBase:DistToSqr(candidate) >= (512 * 512) then
						startpos = candidate
						break
					end
				end
			end
		else
			startpos = zb:GetRandomSpawn()
		end

		local desiredSwatCount = (math.random(1, 2) == 1 and 6) or 4
		local swatCount = math.min(desiredSwatCount, #deadPlayers)

		for i = 1, swatCount do
			local ply = deadPlayers[i]

			ply:Spawn()
			ply:SetTeam(2)
			if startpos then
				if i == 1 then
					ply:SetPos(startpos)
				else
					hg.tpPlayer(startpos, ply, i, 0)
				end
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
