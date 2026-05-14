-- Система точек, спавны и так далее, все для чего нужны какие либо координаты на карте.
zb = zb or {}

zb.Points = zb.Points or {}

zb.Points.Example = zb.Points.Example or {}

function zb.CreateMapDir()
    local map = game.GetMap()
    if not file.Exists( "zbattle", "DATA" ) then file.CreateDir( "zbattle/mappoints" ) end
    if not file.Exists( "zbattle/mappoints/" .. map, "DATA" ) then file.CreateDir( "zbattle/mappoints/" .. map ) end
    if file.Exists( "zbattle/mappoints/" .. map, "DATA" ) then return true end
end

function zb.GetMapPoints( pointGroup, forceupdatepoints ) -- Загрузить точки в память игры... На клиенте будет примерно такая же функция.
    if not zb.CreateMapDir() then PrintMessage( HUD_PRINTTALK, "sv_points.lua: map folder dosen't exist?" ) return false end
    if not zb.Points[pointGroup] then PrintMessage( HUD_PRINTTALK, "sv_points.lua: point group " .. "\"" .. pointGroup .. "\"" .. " doesn't exist." ) return false end

    forceupdatepoints = forceupdatepoints or false
    if (not forceupdatepoints) and zb.Points[pointGroup].Points then
        local newTbl = {}
        table.CopyFromTo(zb.Points[pointGroup].Points,newTbl)
        return newTbl
    end

    local map = game.GetMap()

    zb.Points[pointGroup].Points = util.JSONToTable( file.Read( "zbattle/mappoints/" .. map .. "/"..pointGroup..".json", "DATA" ) or "" ) 
    
    local newTbl = {}
    if zb.Points[pointGroup].Points then
        table.CopyFromTo(zb.Points[pointGroup].Points,newTbl)
    end

    return newTbl
end--undebiled this function no need to thank me

-- pointsData = zb.Points[pointGroup].Points  // Таблица пойнтов
function zb.SaveMapPoints( pointGroup, pointsData ) -- Сохранаяет все точки в группе
    if not zb.CreateMapDir() then PrintMessage( HUD_PRINTTALK, "sv_points.lua: map folder dosen't exists?" ) return false end
    if not zb.Points[pointGroup] then PrintMessage( HUD_PRINTTALK, "sv_points.lua: point group " .. "\"" .. pointGroup .. "\"" .. " doesn't exist." ) return false end

    local map = game.GetMap()

    file.Write( "zbattle/mappoints/" .. map .. "/" .. pointGroup .. ".json", util.TableToJSON( pointsData, true ) )
end

-- pointData = { pos = Vector(), ang = Angle() } // Таблица пойнта
function zb.CreateMapPoint( pointGroup, pointData, needsave ) -- Создать точку на карте, и сохранить ли ее?
    if not zb.CreateMapDir() then PrintMessage( HUD_PRINTTALK, "sv_points.lua: map folder dosen't exists?" ) return false end
    if not zb.Points[pointGroup] then PrintMessage( HUD_PRINTTALK, "sv_points.lua: point group " .. "\"" .. pointGroup .. "\"" .. " doesn't exist." ) return false end

    zb.Points[pointGroup].Points = zb.Points[pointGroup].Points or zb.GetMapPoints( pointGroup )

    zb.Points[pointGroup].Points[ #zb.Points[pointGroup].Points + 1 ] = pointData
    needsave = needsave or true
    if needsave then
        zb.SaveMapPoints( pointGroup, zb.Points[pointGroup].Points )
    end
end

function zb.RemoveMapPoint( pointGroup, pointNum, needsave, removeall ) -- Создать точку на карте, и сохранить ли ее?
    if not zb.CreateMapDir() then PrintMessage( HUD_PRINTTALK, "sv_points.lua: map folder dosen't exists?" ) return false end
    if not zb.Points[pointGroup] then PrintMessage( HUD_PRINTTALK, "sv_points.lua: point group " .. "\"" .. pointGroup .. "\"" .. " doesn't exist." ) return false end

    zb.Points[pointGroup].Points = zb.Points[pointGroup].Points or zb.GetMapPoints( pointGroup )
    --zb.Points[pointGroup].Points[ math.Clamp(pointNum, 1, #zb.Points[pointGroup].Points) ]
    removeall = removeall or false
    if removeall then zb.Points[pointGroup].Points = {} else
        if not zb.Points[pointGroup].Points[ math.Clamp(pointNum or 0, 1, #zb.Points[pointGroup].Points) ] then PrintMessage( HUD_PRINTTALK, "sv_points.lua: point dosen't exist." ) return false end
        table.remove( zb.Points[pointGroup].Points, math.Clamp(pointNum or 0, 1, #zb.Points[pointGroup].Points) )
    end
    
    needsave = needsave or true
    if needsave then
        zb.SaveMapPoints( pointGroup, zb.Points[pointGroup].Points )
    end
    return true
end

function zb.SetMapPoint( pointGroup, pointNum, pointData, needsave ) -- Создать точку на карте, и сохранить ли ее?
    if not zb.CreateMapDir() then PrintMessage( HUD_PRINTTALK, "sv_points.lua: map folder couldn't be created." ) return false end
    if not zb.Points[pointGroup] then PrintMessage( HUD_PRINTTALK, "sv_points.lua: point group " .. "\"" .. pointGroup .. "\"" .. " doesn't exist." ) return false end

    zb.Points[pointGroup].Points = zb.Points[pointGroup].Points or zb.GetMapPoints( pointGroup )
    if not zb.Points[pointGroup].Points[ math.Clamp(pointNum, 1, #zb.Points[pointGroup].Points) ] then PrintMessage( HUD_PRINTTALK, "sv_points.lua: point dosen't exist." ) return false end

    zb.Points[pointGroup].Points[ math.Clamp(pointNum, 1, #zb.Points[pointGroup].Points) ] = pointData

    if needsave then
        zb.SaveMapPoints( pointGroup, zb.Points[pointGroup].Points )
    end
    return true
end

function zb.GetAllPoints(forceupdate)
    forceupdate = forceupdate or true--ALWAYS TRUE LMAOOOOOO
    allpoints = {}
    for k, pointGroup in pairs(zb.Points) do
        pointgroups = zb.GetMapPoints( k, forceupdate ) 
        if not pointgroups then continue end
        allpoints[k] = pointgroups
    end

    hook.Run("ZB_AfterAllPoints",zb.Points)
    
    return allpoints
end

hook.Add("InitPostEntity", "inithuyOwOs", function()
    zb.GetAllPoints(true)
end)

//zb.GetAllPoints()

hook.Add( "Initialize", "LoadMapPoints", zb.CreateMapDir )
--PrintTable(zb.Points.Example.Points)
-- pointData = { pos = Vector(), ang = Angle() } // Таблица пойнта
COMMANDS.pointnew = {function(ply,args)
    if not args[1] then
        ply:ChatPrint("Usage: !pointnew <pointGroup>")
        return
    end
    local ang = ply:EyeAngles()
    ang.x = 0
    local pointData = {
        pos = ply:GetPos(),
        ang = ang
    }

    zb.CreateMapPoint( args[1], pointData )

    ply:ConCommand("zb_pointsupdate")

end,1,"Creates a new point on the map\nArgs - pointGroup"}

COMMANDS.pointset = {function(ply,args)
    if not args[1] or not args[2] then
        ply:ChatPrint("Usage: !pointset <pointGroup> <pointNumber>")
        return
    end

    zb.SetMapPoint( args[1], args[2], args[3] )

    ply:ConCommand("zb_pointsupdate")

end,1,"Sets a point on the map\nArgs - pointGroup, pointNumber"}

COMMANDS.pointremove = {function(ply,args)
    if not args[1] then
        ply:ChatPrint("Usage: !pointremove <pointGroup> <pointNumber|*>\nUse * to remove all points")
        return
    end

    zb.RemoveMapPoint( args[1], args[2], true, args[2] == "*" )

    ply:ConCommand("zb_pointsupdate")

end,1,"Remove point (points) on the map\nArgs - pointGroup, pointNumber ( * - allpoints )"}

-- Передача клиенту точек

function zb.SendPointsToPly(ply, shouldprint)
    net.Start("zb_getallpoints")
        net.WriteTable(zb.GetAllPoints())
    net.Send(ply)

    if shouldprint then
        ply:ChatPrint("Points: Points transferred")
    end
end

function zb.SendPoints()
    local rf = RecipientFilter()
    
    for k, v in player.Iterator() do
        rf:AddPlayer(v)
    end

    net.Start("zb_getallpoints")
        net.WriteTable(zb.GetAllPoints())
    net.Send(rf)
end

function zb.SendSpecificPointsToPly(ply, pointGroup, shouldprint)
    net.Start("zb_getspecificpoints")
        net.WriteString(pointGroup)
        net.WriteTable(zb.GetAllPoints()[pointGroup])
    if IsValid(ply) then    
        net.Send(ply)
        
        if shouldprint then
            ply:ChatPrint("Points: Points transferred")
        end
    else
        net.Broadcast()
    end
end

local angZero = Angle(0,0,0)

function zb.TranslateVectorsToPoints(tbl)
	local newtbl = {}
	for i,val in pairs(tbl) do
		if istable(val) then
			if val.pos and val.ang and isvector(val.pos) and isangle(val.ang) then table.insert(newtbl,val) end
		end
		if isvector(val) then table.insert(newtbl,{pos = val,ang = angZero}) end
	end
	return newtbl
end

function zb.TranslatePointsToVectors(tbl)
	local newtbl = {}
    
	for i,val in pairs(tbl) do
		if istable(val) then
			if val.pos and val.ang and isvector(val.pos) and isangle(val.ang) then
                table.insert(newtbl,val.pos)
            end
		end

		if isvector(val) then table.insert(newtbl, val) end
	end

	return newtbl
end

net.Receive("zb_getallpoints",function(len,ply)
    if not ply:IsAdmin() then ply:ChatPrint("Points: Access denied") return end

    zb.SendPointsToPly(ply, true)
end)

function zb.tdm_checkpoints()
    local pT = zb.Points.HMCD_TDM_T and zb.Points.HMCD_TDM_T.Points
    local pCT = zb.Points.HMCD_TDM_CT and zb.Points.HMCD_TDM_CT.Points
    local pA = zb.Points.BOMB_ZONE_A and zb.Points.BOMB_ZONE_A.Points
    local pB = zb.Points.BOMB_ZONE_B and zb.Points.BOMB_ZONE_B.Points
    local pH = zb.Points.HOSTAGE_DELIVERY_ZONE and zb.Points.HOSTAGE_DELIVERY_ZONE.Points

    if istable(pT) and #pT > 0
        and istable(pCT) and #pCT > 0
        and istable(pA) and #pA > 0
        and istable(pB) and #pB > 0
        and istable(pH) and #pH > 0 then
        return
    end

    local vecs = {}
    local points = zb.GetMapPoints( "HMCD_TDM_T" )
    if #points == 0 then
        for i,ent in pairs(ents.FindByClass("info_player_terrorist")) do
            vecs[#vecs + 1] = ent:GetPos()
        end

        points = zb.TranslateVectorsToPoints(vecs)

        zb.SaveMapPoints("HMCD_TDM_T", points)
        if #zb.GetMapPoints("RIOT_TDM_RIOTERS") == 0 then
            zb.SaveMapPoints("RIOT_TDM_RIOTERS", points)
        end
        if #zb.GetMapPoints("HMCD_CRI_T") == 0 then
            zb.SaveMapPoints("HMCD_CRI_T", points)
        end
    end
    
    --||

    local vecs = {}
    local points = zb.GetMapPoints( "HMCD_TDM_CT" )
    if #points == 0 then
        for i, ent in pairs(ents.FindByClass("info_player_counterterrorist")) do
            vecs[#vecs + 1] = ent:GetPos()
        end

        points = zb.TranslateVectorsToPoints(vecs)

        zb.SaveMapPoints("HMCD_TDM_CT", points)
        if #zb.GetMapPoints("HMCD_CRI_CT") == 0 then
            zb.SaveMapPoints("HMCD_CRI_CT", points)
        end
        if #zb.GetMapPoints("RIOT_TDM_LAW") == 0 then
            zb.SaveMapPoints("RIOT_TDM_LAW", points)
        end
    end

    --||

    local foundA
    local foundB
    if #zb.GetMapPoints("BOMB_ZONE_A") == 0 or #zb.GetMapPoints("BOMB_ZONE_B") == 0 then
        for i, ent in ipairs(ents.FindByClass("func_bomb_target")) do
            local vecs = {}
            local min, max = ent:WorldSpaceAABB()

            vecs[1] = min
            vecs[2] = max

            if not foundB and #zb.GetMapPoints("BOMB_ZONE_B") == 0 then
                local points = zb.TranslateVectorsToPoints(vecs)
                zb.SaveMapPoints("BOMB_ZONE_B", points)
                foundB = true
                continue
            end

            if not foundA and #zb.GetMapPoints("BOMB_ZONE_A") == 0 then
                local points = zb.TranslateVectorsToPoints(vecs)
                zb.SaveMapPoints("BOMB_ZONE_A", points)
                foundA = true
                continue
            end
        end
    end

    local points = {}
    if #zb.GetMapPoints("HOSTAGE_DELIVERY_ZONE") == 0 then
        for i, ent in pairs(ents.FindByClass("func_hostage_rescue")) do
            local min, max = ent:WorldSpaceAABB()

            points[#points + 1] = min
            points[#points + 1] = max
        end

        points = zb.TranslateVectorsToPoints(points)
        zb.SaveMapPoints("HOSTAGE_DELIVERY_ZONE", points)
    end
end

--[[for i,ent in pairs(ents.FindInSphere(Entity(1):GetPos(),60)) do
    local enta = ents.Create("prop_physics")
	enta:SetModel("models/props_c17/lampShade001a.mdl")
	enta:SetPos(ent:GetPos())
	enta:Spawn()
	enta:SetSolidFlags(FSOLID_NOT_SOLID)
	enta:GetPhysicsObject():EnableMotion(false)
    print(ent)
end--]]


hook.Add("PostCleanupMap","no_t_ct_spawns",function()
    if zb._tdmPointsReady then return end
    zb.tdm_checkpoints()
    local pT = zb.Points.HMCD_TDM_T and zb.Points.HMCD_TDM_T.Points
    local pCT = zb.Points.HMCD_TDM_CT and zb.Points.HMCD_TDM_CT.Points
    if istable(pT) and #pT > 0 and istable(pCT) and #pCT > 0 then
        zb._tdmPointsReady = true
    end
end)
