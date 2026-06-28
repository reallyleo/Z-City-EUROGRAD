--[[    TO-DO
    -- Добавить менюшку с прощением! |
    -- Добавить нетворкинг |
    -- Ну и все | 
--]]

hook.Add("OnNetVarSet", "Guilt",function(index, key, var)
    if key == "Karma" then
        Entity(index).Karma = var
    end
end)

hook.Add("Player Spawn", "GuiltKnown",function(ply)
    --if (ply == LocalPlayer()) and ply.Karma then
    --    ply:ChatPrint("Your current karma is "..tostring(math.Round(ply.Karma)).."")
    --end
end)

concommand.Add("hg_getkarma",function(ply)
    if not ply:IsAdmin() then return end

    net.Start("get_karma")
    net.SendToServer()
end)

net.Receive("get_karma",function(len)
    local tbl = net.ReadTable()
    local printTbl = "\nPlayers karma: \n"

    for id,karma in pairs(tbl) do
        printTbl = printTbl.."\t"..(Player(id):Name().."'s karma is "..math.Round(karma,2)).."\n"
    end

    LocalPlayer():PrintMessage(HUD_PRINTCONSOLE,printTbl)
end)

concommand.Add("hg_guilt_menu",function(ply, cmd, args)
    net.Start("open_guilt_menu")
    net.SendToServer()
end)

local OpenMenu
local forgiveMenuData = {}
local forgivePromptAvailable = false
local pendingForgiveOpen = false
local colBlue = Color(0, 100, 255, 128)
local colBlueText = Color(180, 220, 255, 255)

local function HasForgiveTargets(tbl)
    if not istable(tbl) then return false end

    for ply, harm in pairs(tbl) do
        if IsValid(ply) and harm and harm > 0.01 then
            return true
        end
    end

    return false
end

net.Receive("open_guilt_menu", function()
    local tbl = net.ReadTable()
    forgiveMenuData = tbl or {}
    forgivePromptAvailable = HasForgiveTargets(forgiveMenuData)

    if pendingForgiveOpen or IsValid(guiltMenu) then
        local forceOpen = pendingForgiveOpen
        pendingForgiveOpen = false
        OpenMenu(forgiveMenuData, forceOpen)
    end
end)

local colGray = Color(122,122,122,255)
local BlurBackground = hg.BlurBackground

local function harmdone(harm)
    if harm >= 9 then
        return "killed you."
    elseif harm >= 5 then
        return "basically killed you."
    elseif harm >= 2 then
        return "seriously injured you."
    elseif harm >= 1 then
        return "mildly injured you."
    else
        return "damaged you a bit."
    end
end

hook.Add("Player_Death","karmacheck",function(ply)
    if ply != LocalPlayer() then return end

    forgiveMenuData = {}
    forgivePromptAvailable = false
    pendingForgiveOpen = false

    timer.Simple(0, function()
        if IsValid(LocalPlayer()) and not LocalPlayer():Alive() then
            RunConsoleCommand("hg_guilt_menu")
        end
    end)
end)

hook.Add("Player Spawn", "guiltforgive_reset", function(ply)
    if ply != LocalPlayer() then return end

    forgiveMenuData = {}
    forgivePromptAvailable = false
    pendingForgiveOpen = false

    if IsValid(guiltMenu) then
        guiltMenu:Remove()
        guiltMenu = nil
    end
end)

local pressed
hook.Add("HUDPaint","shownotification",function()
    if LocalPlayer():Alive() then return end
    if forgivePromptAvailable then
        local w, h = ScrW(), ScrH()
        local x, y = w / 2, h / 25 * 24
        local txt = "Press F to open forgiveness menu."
        surface.SetFont( "HomigradFontBig" )
        surface.SetTextColor(255,255,255,255)
        local w, h = surface.GetTextSize(txt)
        surface.SetTextPos(x - w / 2, y - h / 2)
        surface.DrawText(txt)
    end

    if input.IsKeyDown(KEY_F) and not gui.IsGameUIVisible() and not IsValid(vgui.GetKeyboardFocus()) then
        if not pressed then
            pendingForgiveOpen = true
            RunConsoleCommand("hg_guilt_menu")
            pressed = true
        end
    else
        pressed = nil
    end
end)

OpenMenu = function(tbl, forceOpen)
    local hasTargets = HasForgiveTargets(tbl)

    if not hasTargets and not forceOpen then
        if IsValid(guiltMenu) then
            guiltMenu:Close()
        end
        return
    end

    if IsValid(guiltMenu) then
		guiltMenu:Remove()
		guiltMenu = nil
	end
    
	local sizeX,sizeY = ScrW() / 2 ,ScrH() / 3
	local posX,posY = ScrW() / 2 - sizeX / 2,ScrH() / 2 - sizeY / 2

	guiltMenu = vgui.Create("ZFrame")
	guiltMenu:SetPos(posX, posY)
	guiltMenu:SetSize(sizeX, sizeY)
    guiltMenu:SetTitle("")
    guiltMenu:MakePopup()
    guiltMenu:SetKeyboardInputEnabled(false)
    guiltMenu:ShowCloseButton(false)
    guiltMenu:SetColorBR(Color(0, 100, 255, 220))

    local button = vgui.Create("DButton", guiltMenu)
    button:SetPos(sizeX - ScreenScale(25),ScreenScale(5))
    button:SetSize(ScreenScale(20),ScreenScale(10))
    button:SetText("")

    function button:Paint(w,h)
        BlurBackground(self)

        surface.SetDrawColor(colBlue)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )

        local x, y = w / 2, h / 2
        local txt = "Exit"
        surface.SetFont("HomigradFont")
        surface.SetTextColor(255,255,255,255)
        local w, h = surface.GetTextSize(txt)
        surface.SetTextPos(x - w / 2, y - h / 2)
        surface.DrawText(txt)
    end

    function button:DoClick()
        if IsValid(guiltMenu) then
            guiltMenu:Close()
        end
    end

    local karmaPanel = vgui.Create("DPanel", guiltMenu)
    karmaPanel:SetPos(sizeX - ScreenScale(85), ScreenScale(5))
    karmaPanel:SetSize(ScreenScale(55), ScreenScale(10))
    karmaPanel.Paint = function(self, w, h)
        BlurBackground(self)

		surface.SetDrawColor(colBlue)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )

        local karma = IsValid(LocalPlayer()) and math.Round(LocalPlayer().Karma or 0, 1) or 0
        local txt = "Karma: " .. karma
        surface.SetFont("HomigradFont")
        surface.SetTextColor(colBlueText.r, colBlueText.g, colBlueText.b, 255)
        local tw, th = surface.GetTextSize(txt)
        surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
        surface.DrawText(txt)
    end

    local list = vgui.Create("DScrollPanel", guiltMenu)
    list:SetPos(ScreenScale(5), ScreenScale(20))
    list:SetSize(sizeX - ScreenScale(10), sizeY - ScreenScale(25))

    if not hasTargets then
        local empty = vgui.Create("DPanel", list)
        empty:Dock(TOP)
        empty:DockMargin(ScreenScale(5), ScreenScale(20), ScreenScale(5), ScreenScale(5))
        empty:SetTall(ScreenScaleH(22))
        empty.Paint = function(self, w, h)
            BlurBackground(self)
            surface.SetDrawColor(colBlue)
            surface.DrawOutlinedRect(0, 0, w, h, 2.5)

            local txt = "No players are available to forgive right now."
            surface.SetFont("HomigradFont")
            surface.SetTextColor(colBlueText.r, colBlueText.g, colBlueText.b, 255)
            local tw, th = surface.GetTextSize(txt)
            surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
            surface.DrawText(txt)
        end

        list:AddItem(empty)
        return
    end

    local first = true
    for ply, harm in pairs(tbl) do
        if not IsValid(ply) then continue end
        if harm <= 0.01 then continue end

        local but = vgui.Create("DButton", list)
		but:SetSize(sizeX / 2,ScreenScaleH(22))
		but:Dock(TOP)
        local mg = ScreenScale(5)
		but:DockMargin(mg, first and ScreenScale(20) or mg / 2, mg, mg / 2)
        first = false
		but:SetText("")
        but.ply = ply
        but.name = ply:Name()
        but.harm = harm
        local txt = "Forgive "..but.name.."? You will forgive him "..math.Round(but.harm,1).." karma."
        local clr = 255
        but.Paint = function(self,w,h)
            BlurBackground(self)
            clr = LerpFT(0.1, clr, self:IsHovered() and 0 or 255)
            surface.SetDrawColor(colBlue)
            surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )

            local x, y = 0, h / 2
            surface.SetFont("HomigradFont")
            surface.SetTextColor(clr, clr, 255, 255)
            local w, h = surface.GetTextSize(txt)
            surface.SetTextPos(x + ScreenScale(5), y - h / 2)
            surface.DrawText(txt)
		end

		function but:DoClick()
            net.Start("forgive_player")
            net.WriteEntity(ply)
            net.SendToServer()
            tbl[ply] = nil
            OpenMenu(tbl)
        end

		list:AddItem(but)
	end
end
