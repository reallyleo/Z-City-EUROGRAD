local CLASS = player.RegClass("activeshooter")

function CLASS.Off(self)
    if CLIENT then return end
end

local masks = {
    "arctic_balaclava",
    "bandana",
}

local function ApplyShooterAccessories(ply)
    local Appearance = ply.CurAppearance or hg.Appearance.GetRandomAppearance()

    Appearance.AAttachments = {
        masks[math.random(#masks)],
        "terrorist_band",
    }

    ply:SetNetVar("Accessories", Appearance.AAttachments or "none")
    ply.CurAppearance = Appearance
end

function CLASS.On(self, data)
    if CLIENT then return end
    data = data or {}

    self:SetPlayerColor(Color(200, 40, 40):ToVector())

    if CurrentRound and CurrentRound().name == "as" then
        ApplyAppearance(self, nil, nil, nil, true)

        local mdl = data.shooterModel
        if isstring(mdl) and mdl ~= "" and util.IsValidModel(mdl) then
            self:SetModel(mdl)
            self:SetSubMaterial()
            timer.Simple(0, function()
                if not IsValid(self) then return end
                self:SetBodyGroups("00000000000")
            end)
        end

        local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
        Appearance.AAttachments = ""
        self:SetNetVar("Accessories", "")
        self.CurAppearance = Appearance
        return
    end

    ApplyAppearance(self, nil, nil, nil, true)
    timer.Simple(0.1, function()
        if not IsValid(self) then return end
        ApplyShooterAccessories(self)
    end)
end
