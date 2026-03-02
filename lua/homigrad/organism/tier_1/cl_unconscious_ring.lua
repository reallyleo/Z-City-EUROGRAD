
local function DrawArc(x, y, radius, thickness, start_ang, end_ang, roughness, color)
    surface.SetDrawColor(color.r, color.g, color.b, color.a)
    draw.NoTexture()
    
    local segs = roughness
    local step = (end_ang - start_ang) / segs
    
    for i = 0, segs - 1 do
        local a1 = math.rad(start_ang + i * step)
        local a2 = math.rad(start_ang + (i + 1) * step)
        
        local cos1, sin1 = math.cos(a1), math.sin(a1)
        local cos2, sin2 = math.cos(a2), math.sin(a2)
        
        local p1 = { x = x + cos1 * (radius - thickness), y = y - sin1 * (radius - thickness) }
        local p2 = { x = x + cos1 * radius, y = y - sin1 * radius }
        local p3 = { x = x + cos2 * radius, y = y - sin2 * radius }
        local p4 = { x = x + cos2 * (radius - thickness), y = y - sin2 * (radius - thickness) }
        
        surface.DrawPoly({p1, p2, p3, p4})
    end
end

surface.CreateFont("UnconsciousDots", {
    font = "Bahnschrift",
    size = 120, -- Significantly bigger dots
    weight = 800,
    antialias = true
})

surface.CreateFont("UnconsciousHint", {
    font = "Bahnschrift",
    size = 16,
    weight = 400,
    antialias = true
})

local ringAlpha = 0
local lerpBrain = 0
local lerpShock = 0
local lerpConsciousness = 0
local peakShock = 40
local dotBeat = 0

hook.Add("HUDPaint", "DrawUnconsciousRing", function()
    local ply = lply or LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then 
        ringAlpha = 0
        peakShock = 40
        return 
    end
    
    local org = ply.organism
    if not org then 
        ringAlpha = 0
        peakShock = 40
        return 
    end
    
    local isUnconscious = org.otrub
    
    if isUnconscious then
        local currentShock = org.shock or 0
        if currentShock > peakShock then
            peakShock = currentShock
        end
        ringAlpha = math.Approach(ringAlpha, 1, FrameTime() * 2)
        dotBeat = math.floor(CurTime()) % 3
    else
        ringAlpha = math.Approach(ringAlpha, 0, FrameTime() * 3)
        -- Reset peak shock once conscious again
        if ringAlpha <= 0 then
            peakShock = 40
        end
    end
    
    if ringAlpha <= 0 then return end
    
    -- Smoothly interpolate values for real-time movement
    lerpBrain = math.Approach(lerpBrain, org.brain or 0, FrameTime() * 2)
    lerpShock = math.Approach(lerpShock, org.shock or 0, FrameTime() * 50) -- Faster interpolation for responsiveness
    lerpConsciousness = math.Approach(lerpConsciousness, org.consciousness or 0, FrameTime() * 2)
    
    local pulse = org.heartbeat or org.pulse or 70
    local brain = org.brain or 0
    local consciousness = org.consciousness or 0
    local shock = org.shock or 0
    local isCritical = (org.critical == true) or (pulse < 1 and brain >= 0.02) or (brain >= 0.34)
    
    local scrW, scrH = ScrW(), ScrH()
    local centerX, centerY = scrW / 2, scrH / 2
    
    -- Background dimming
    surface.SetDrawColor(0, 0, 0, 253 * ringAlpha)
    surface.DrawRect(0, 0, scrW, scrH)
    
    local ringColor = isCritical and Color(200, 0, 0, 255 * ringAlpha) or Color(220, 220, 220, 255 * ringAlpha)
    local dotColor = isCritical and ringColor or Color(255, 255, 255, 255 * ringAlpha)
    
    local progress = 0
    if isCritical then
        -- Red ring: drains as brain reaches 0.70 (death)
        progress = math.Clamp((0.70 - lerpBrain) / (0.70 - 0.02), 0, 1)
    else
        -- White ring: fills as you approach waking up.
        -- We scale consciousness from 0 to 0.10 (the wake-up threshold)
        -- and shock from peakShock down to 0.02 (the wake-up threshold).
        local shockProgress = math.Clamp((peakShock - lerpShock) / (peakShock - 0.02), 0, 1)
        local consciousnessProgress = math.Clamp(lerpConsciousness / 0.10, 0, 1)
        
        -- The ring fills as shock drops toward 0.02 AND consciousness rises toward 0.10.
        progress = math.min(shockProgress, consciousnessProgress)
    end
    
    local radius = 180 -- Much bigger radius like in the picture
    local thickness = 8 -- Thicker ring
    
    -- Draw background shadow ring (subtle)
    DrawArc(centerX, centerY, radius, thickness, 0, 360, 60, Color(40, 40, 40, 100 * ringAlpha))
    
    -- Draw progress ring (starting from top, clockwise)
    DrawArc(centerX, centerY, radius, thickness, 90, 90 - (progress * 360), 80, ringColor)
    
    local beat = dotBeat
    local dotText = ""

    if isCritical then
        local redDots = {".!", "..!", "...!"}
        dotText = redDots[beat + 1]
    else
        local whiteDots = {".", "..", "..."}
        dotText = whiteDots[beat + 1]
    end
    
    -- Draw text
    draw.SimpleText(dotText, "UnconsciousDots", centerX, centerY, dotColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    -- Draw the hint at the bottom
    draw.SimpleText("Type 'bind g fake' in console to get up", "UnconsciousHint", centerX, scrH - 30, Color(200, 200, 200, 100 * ringAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
