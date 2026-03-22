MODE.name = "as"

local MODE = MODE

local teams = {
	[0] = {
		objective = "Find and Eliminate as many civilians as possible.",
		name = "the Active Shooter",
		color1 = Color(200, 40, 40),
		color2 = Color(200, 40, 40)
	},
	[1] = {
		objective = "Survive and avoid the shooter. Help others stay alive.",
		name = "a Civilian",
		color1 = Color(40, 160, 40),
		color2 = Color(40, 160, 40)
	},
}

local song
local songfade = 0
local swatSirensPlayed = false

surface.CreateFont("UnconsciousHint", {
	font = "Bahnschrift",
	size = 16,
	weight = 400,
	antialias = true
})

net.Receive("as_start", function()
	surface.PlaySound("zbattle/criresp.mp3")
	zb.RemoveFade()

	timer.Simple(3, function()
		sound.PlayFile("sound/zbattle/criresp/criepmission.mp3", "mono noblock", function(station)
			if IsValid(station) then
				station:Play()
				song = station
				songfade = 1
			end
		end)
	end)
end)

net.Receive("as_swat_spawn", function()
	if not swatSirensPlayed then
		surface.PlaySound("snd_jack_hmcd_policesiren.wav")
		swatSirensPlayed = true
	end
end)

function MODE:RenderScreenspaceEffects()
	if zb.ROUND_START + 7.5 < CurTime() then return end
	local fade = math.Clamp(zb.ROUND_START + 7.5 - CurTime(), 0, 1)

	surface.SetDrawColor(0, 0, 0, 255 * fade)
	surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
end

local posadd = 0
local posaddSWAT = 0
local shooterWaitHintAlpha = 0
local CreateEndMenu
net.Receive("as_roundend", function()
	local winner = net.ReadUInt(8)
	CreateEndMenu(winner)
end)

local colGray = Color(85, 85, 85, 255)
local colRed = Color(130, 10, 10)
local colRedUp = Color(160, 30, 30)
local colBlue = Color(10, 10, 160)
local colBlueUp = Color(40, 40, 160)
local col = Color(255, 255, 255, 255)
local colSpect1 = Color(75, 75, 75, 255)
local colSpect2 = Color(255, 255, 255)
local colorBG = Color(55, 55, 55, 255)
local colorBGBlacky = Color(40, 40, 40, 255)
local blurMat = Material("pp/blurscreen")
local Dynamic = 0
BlurBackground = BlurBackground or hg.DrawBlur

if IsValid(hmcdEndMenu) then
	hmcdEndMenu:Remove()
	hmcdEndMenu = nil
end

CreateEndMenu = function(winner)
	if IsValid(hmcdEndMenu) then
		hmcdEndMenu:Remove()
		hmcdEndMenu = nil
	end

	Dynamic = 0
	hmcdEndMenu = vgui.Create("ZFrame")

	local soundPath
	if winner == 0 then
		soundPath = "ambient/alarms/warningbell1.wav"
	else
		soundPath = "ambient/alarms/warningbell1.wav"
	end

	surface.PlaySound(soundPath)

	local sizeX, sizeY = ScrW() / 2.5, ScrH() / 1.2
	local posX, posY = ScrW() / 1.3 - sizeX / 2, ScrH() / 2 - sizeY / 2
	hmcdEndMenu:SetPos(posX, posY)
	hmcdEndMenu:SetSize(sizeX, sizeY)
	hmcdEndMenu:MakePopup()
	hmcdEndMenu:SetKeyboardInputEnabled(false)
	hmcdEndMenu:ShowCloseButton(false)

	local closebutton = vgui.Create("DButton", hmcdEndMenu)
	closebutton:SetPos(5, 5)
	closebutton:SetSize(ScrW() / 20, ScrH() / 30)
	closebutton:SetText("")
	closebutton.DoClick = function()
		if IsValid(hmcdEndMenu) then
			hmcdEndMenu:Close()
			hmcdEndMenu = nil
		end
	end

	closebutton.Paint = function(self, w, h)
		surface.SetDrawColor(122, 122, 122, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 2.5)
		surface.SetFont("ZB_InterfaceMedium")
		surface.SetTextColor(col.r, col.g, col.b, col.a)
		local lengthX, lengthY = surface.GetTextSize("Close")
		surface.SetTextPos(lengthX - lengthX / 1.1, 4)
		surface.DrawText("Close")
	end

	hmcdEndMenu.PaintOver = function(self, w, h)
		surface.SetFont("ZB_InterfaceMediumLarge")
		surface.SetTextColor(col.r, col.g, col.b, col.a)

		local title
		if winner == 0 then
			title = "Active Shooter Wins"
		elseif winner == 1 then
			title = "Civilians Win"
		else
			title = "Round Over"
		end

		local lengthX, lengthY = surface.GetTextSize(title)
		surface.SetTextPos(w / 2 - lengthX / 2, 20)
		surface.DrawText(title)
	end

	local DScrollPanel = vgui.Create("DScrollPanel", hmcdEndMenu)
	DScrollPanel:SetPos(10, 80)
	DScrollPanel:SetSize(sizeX - 20, sizeY - 90)

	for i, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end

		local row = vgui.Create("DButton", DScrollPanel)
		row:SetSize(100, 50)
		row:Dock(TOP)
		row:DockMargin(8, 6, 8, -1)
		row:SetText("")

		row.Paint = function(self, w, h)
			local isWinner = ply:Team() == winner
			local alive = ply:Alive()

			local col1 = isWinner and colBlue or colRed
			local col2 = isWinner and colBlueUp or colRedUp

			if not alive then
				col1 = colGray
				col2 = colSpect1
			end

			surface.SetDrawColor(col1.r, col1.g, col1.b, col1.a)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(col2.r, col2.g, col2.b, col2.a)
			surface.DrawRect(0, h / 2, w, h / 2)

			local nameColor = ply:GetPlayerColor():ToColor()
			surface.SetFont("ZB_InterfaceMediumLarge")

			local nameText = ply:GetPlayerName() or "Disconnected"
			local lengthX, lengthY = surface.GetTextSize(nameText)
			surface.SetTextColor(0, 0, 0, 255)
			surface.SetTextPos(w / 2 + 1, h / 2 - lengthY / 2 + 1)
			surface.DrawText(nameText)

			surface.SetTextColor(nameColor.r, nameColor.g, nameColor.b, nameColor.a)
			surface.SetTextPos(w / 2, h / 2 - lengthY / 2)
			surface.DrawText(nameText)

			local statusColor = colSpect2
			surface.SetFont("ZB_InterfaceMediumLarge")
			surface.SetTextColor(statusColor.r, statusColor.g, statusColor.b, statusColor.a)

			local status
			if not alive then
				status = " - dead"
			elseif isWinner then
				status = " - survived"
			else
				status = ""
			end

			local statusLenX, statusLenY = surface.GetTextSize(nameText .. status)
			surface.SetTextPos(15, h / 2 - statusLenY / 2)
			surface.DrawText(ply:Name() .. status)
		end
	end

	timer.Simple(10, function()
		if IsValid(hmcdEndMenu) then
			hmcdEndMenu:Close()
			hmcdEndMenu = nil
		end
	end)
end

function MODE:HUDPaint()
	local sw, sh = ScrW(), ScrH()
	local startTime = zb.ROUND_START or CurTime()
	local shooterSpawnTime = startTime + 55
	local swatArrivalTime = (zb.ROUND_START or startTime) + 240

	local ply = LocalPlayer()
	local waitingShooter = IsValid(ply) and ply:GetNWBool("AS_WaitingShooter", false)
	if waitingShooter then
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(0, 0, sw, sh)
	end

	local hintTarget = (waitingShooter and CurTime() >= startTime + 8.5) and 1 or 0
	shooterWaitHintAlpha = math.Approach(shooterWaitHintAlpha, hintTarget, FrameTime() * 2)
	if shooterWaitHintAlpha > 0 then
		local a = 160 * shooterWaitHintAlpha
		draw.SimpleText("You will spawn in after the countdown.", "UnconsciousHint", sw / 2, sh / 2 - 10, Color(200, 200, 200, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("Drink water while you wait.", "UnconsciousHint", sw / 2, sh / 2 + 10, Color(200, 200, 200, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if shooterSpawnTime > CurTime() then
		posadd = Lerp(FrameTime() * 5, posadd or 0, startTime + 7.3 < CurTime() and 0 or -sw * 0.4)

		local timeLeft = shooterSpawnTime - CurTime()
		local text = "The Shooter will arrive in: " .. string.FormattedTime(timeLeft, "%02i:%02i")

		draw.SimpleText(text, "ZB_HomicideMedium", sw * 0.02 + posadd, sh * 0.95, Color(0, 0, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local pulse = (math.sin(CurTime() * 3) + 1) / 2
		local col = Color(255 * pulse, 0, 0)
		draw.SimpleText(text, "ZB_HomicideMedium", (sw * 0.02) - 2 + posadd, (sh * 0.95) - 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	if IsValid(song) then
		if CurTime() >= shooterSpawnTime then
			songfade = Lerp(0.01, songfade, 0)
			song:SetVolume(songfade)

			if songfade <= 0.01 then
				song:Stop()
				song = nil
			end
		else
			song:SetVolume(songfade)
		end
	end

	local timeBeforeSWAT = swatArrivalTime - CurTime()
	if timeBeforeSWAT > 0 and CurTime() >= shooterSpawnTime then
		posaddSWAT = Lerp(FrameTime() * 5, posaddSWAT or -sw * 0.4, shooterSpawnTime + 0.5 < CurTime() and 0 or -sw * 0.4)

		local text = "The SWAT Team will arrive in: " .. string.FormattedTime(timeBeforeSWAT, "%02i:%02i")
		local s = math.sin(CurTime() * 3)
		local col = Color(255 * -s, 25, 255 * s)

		draw.SimpleText(text, "ZB_HomicideMedium", sw * 0.02 + posaddSWAT, sh * 0.95, Color(0, 0, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(text, "ZB_HomicideMedium", (sw * 0.02) - 2 + posaddSWAT, (sh * 0.95) - 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	if not IsValid(ply) then return end

	local isShooter = ply:Team() == 0
	if not ply:Alive() and not isShooter then return end

	local showStartIntro = CurTime() < startTime + 8.5

	if showStartIntro then
		zb.RemoveFade()

		local fade = math.Clamp(startTime + 8 - CurTime(), 0, 1)
		local teamId = ply:Team()
		local teamData = teams[teamId]
		if teamData then
			draw.SimpleText("ZBattle | Active Shooter", "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.1, Color(0, 162, 255, 255 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local roleColor = teamData.color1
			roleColor.a = 255 * fade
			draw.SimpleText("You are " .. teamData.name, "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.5, roleColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local objColor = teamData.color2
			objColor.a = 255 * fade
			draw.SimpleText(teamData.objective, "ZB_HomicideMedium", sw * 0.5, sh * 0.9, objColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

end
