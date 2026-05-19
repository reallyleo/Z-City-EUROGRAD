hg = hg or {}

local NET = "hg_giveup"

if SERVER then
	util.AddNetworkString(NET)

	net.Receive(NET, function(_, ply)
		if not IsValid(ply) or not ply:Alive() then return end

		local org = ply.organism
		if not org or not org.otrub then return end

		ply.hg_giveup_next = ply.hg_giveup_next or 0
		if ply.hg_giveup_next > CurTime() then return end
		ply.hg_giveup_next = CurTime() + 1

		org.brain = 0.70
	end)

	return
end

surface.CreateFont("GiveUpCountdown", {
	font = "Bahnschrift",
	size = 72,
	weight = 700,
	antialias = true
})

local otrubStart = nil
local lastOtrub = false
local holdAccum = 0
local holdLastUpdate = nil
local usedThisOtrub = false
local countdownAlpha = 0
local wasHolding = false

hook.Add("HUDPaint", "hg_giveup_countdown", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local org = ply.organism
	local otrub = (ply:Alive() and org and org.otrub) and true or false

	if otrub and not lastOtrub then
		otrubStart = CurTime()
		usedThisOtrub = false
		holdAccum = 0
		holdLastUpdate = nil
		wasHolding = false
	elseif not otrub then
		otrubStart = nil
		usedThisOtrub = false
		holdAccum = 0
		holdLastUpdate = nil
		wasHolding = false
	end
	lastOtrub = otrub

	if not otrub or usedThisOtrub then
		countdownAlpha = math.Approach(countdownAlpha, 0, FrameTime() * 6)
		holdAccum = 0
		holdLastUpdate = nil
		wasHolding = false
		if countdownAlpha <= 0 then return end
	end

	local holding = ply:KeyDown(IN_USE)
	if holding and otrub and not usedThisOtrub then
		if not wasHolding then
			holdAccum = 0
			holdLastUpdate = CurTime()
		end
		holdLastUpdate = holdLastUpdate or CurTime()
		holdAccum = math.min(2, holdAccum + (CurTime() - holdLastUpdate))
		holdLastUpdate = CurTime()
		countdownAlpha = math.Approach(countdownAlpha, 1, FrameTime() * 6)
	else
		holdLastUpdate = nil
		countdownAlpha = math.Approach(countdownAlpha, 0, FrameTime() * 6)
	end
	wasHolding = holding

	if countdownAlpha <= 0 then return end

	local remaining = math.max(0, 2 - holdAccum)
	local p = math.Clamp(holdAccum / 2, 0, 1)

	local a = 255 * p * countdownAlpha
	local gb = Lerp(p, 255, 0)
	local col = Color(255, gb, gb, a)

	draw.SimpleText(string.format("%.1fs", remaining), "GiveUpCountdown", ScrW() / 2, ScrH() / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if otrub and not usedThisOtrub and holdAccum >= 2 then
		usedThisOtrub = true
		holdAccum = 0
		holdLastUpdate = nil
		wasHolding = false
		net.Start(NET)
		net.SendToServer()
	end
end)
