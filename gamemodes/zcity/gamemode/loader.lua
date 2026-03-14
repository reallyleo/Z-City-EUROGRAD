local function IncluderFunc(fileName)
	if (fileName:find("sv_")) then
		include(fileName)
	elseif (fileName:find("shared.lua") or fileName:find("sh_")) then
		if (SERVER) then
			AddCSLuaFile(fileName)
		end

		include(fileName)
	elseif (fileName:find("cl_")) then
		if (SERVER) then
			AddCSLuaFile(fileName)
		else
			include(fileName)
		end
	end
end

--прошу обратить внимание что файлы внутри папок загружаются первыми
local function LoadFromDir(directory)
	local files, folders = file.Find(directory .. "/*", "LUA")

	for _, v in ipairs(folders) do
		LoadFromDir(directory .. "/" .. v)
	end

	for _, v in ipairs(files) do
		IncluderFunc(directory .. "/" .. v)
	end
end

LoadFromDir("zcity/gamemode/libraries")

zb.modesHooks = {}
zb.modes = zb.modes or {}

local function InitMode()
	if table.IsEmpty(MODE) then return end

	local name = MODE.name
	local saved = zb.modes[name] and zb.modes[name].saved or {} -- saved table is used for saving data between hotloads

	if MODE.base then
		table.Inherit(MODE, zb.modes[MODE.base])

		for i, tbl in pairs(MODE) do
			if istable(MODE[i]) and istable(zb.modes[MODE.base][i]) then
				tbl2 = {}

				table.CopyFromTo(MODE[i], tbl2)

				MODE[i] = tbl2
			end
		end

		if MODE.AfterBaseInheritance then
			MODE:AfterBaseInheritance()
		end
	end

	zb.modes[name] = MODE
	zb.modes[name].saved = saved

	if SERVER then
		if MODE.SetupChances then
			MODE:SetupChances()
		else
			zb.ModesChances[name] = zb.ModesChances[name] or MODE.Chance
		end
	end

	zb.modesHooks[name] = zb.modesHooks[name] or {}

	for k, v2 in pairs(MODE) do
		if isfunction(v2) then
			zb.modesHooks[name][k] = v2
		end
	end
end

local chancesfile = "zbattle/modeschances.json"

if SERVER then
	hook.Add("ShutDown", "savechances", function()
		file.Write(chancesfile, util.TableToJSON(zb.ModesChances or {}, true))
	end)

	concommand.Add("zb_getmodeschances", function(ply, cmd, args)
		ply:zChatPrint(util.TableToJSON(zb.ModesChances, true))
	end)

	concommand.Add("zb_setmodechance", function(ply, cmd, args)
		local mode = args[1]
		local chance = tonumber(args[2])

		if !zb.ModesChances[mode] or !chance then return end

		zb.ModesChances[mode] = chance
	end)

	concommand.Add("zb_savemodeschances", function(ply, cmd, args)
		file.Write(chancesfile, util.TableToJSON(zb.ModesChances or {}, true))
	end)

	hook.Add("HG_PlayerSay", "ZB_GetModesChancesChatCommand", function(ply, txtTbl, text)
		if not IsValid(ply) or not ply:IsSuperAdmin() then return end

		local lowered = string.Trim(string.lower(text or ""))
		if lowered ~= "!zb_getmodeschances" then return end

		local chances = (zb.GetModesChances and zb.GetModesChances()) or zb.ModesChances or {}
		local total = 0
		local keys = {}

		for name, chance in pairs(chances) do
			keys[#keys + 1] = name
			if isnumber(chance) and chance > 0 then
				total = total + chance
			end
		end

		table.sort(keys)

		local function send(line)
			if ply.zChatPrint then
				ply:zChatPrint(line)
			else
				ply:ChatPrint(line)
			end
		end

		send("Mode chances:")
		for i = 1, #keys do
			local name = keys[i]
			local chance = chances[name] or 0
			local percent = (total > 0 and (chance / total * 100)) or 0
			send(name .. ": " .. tostring(chance) .. " (" .. string.format("%.2f", percent) .. "%)")
		end

		if istable(txtTbl) then
			txtTbl[1] = ""
		end
	end)
end

local function LoadModes()
	local directory = "zcity/gamemode/modes"
	local files, folders = file.Find(directory .. "/*", "LUA")

	if SERVER then
		zb.ModesChances = util.JSONToTable(file.Read(chancesfile,  "DATA") or "") or {}
	end

	for _, v in ipairs(files) do
		MODE = {}
		IncluderFunc(directory .. "/" .. v)
		InitMode()
		MODE = nil
	end

	for _, v in ipairs(folders) do
		MODE = {}
		LoadFromDir(directory .. "/" .. v)
		InitMode()
		MODE = nil
	end

	if SERVER and !file.Exists(chancesfile,  "DATA") then
		file.Write(chancesfile, util.TableToJSON(zb.ModesChances, true))
	end
end

LoadModes()

print("Z-City modes loaded!")

zb.oldHook = zb.oldHook or hook.Call
local oldHook = zb.oldHook

function hook.Call(name, gm, ...)
	local Current = zb.CROUND_MAIN or zb.CROUND or "tdm"

	local modesHooks = zb.modesHooks[Current]

	if modesHooks then -- technically an unnecessary nil check but i don't trust legacy code
		local hookFunc = modesHooks[name]
		if hookFunc then
			local ModeTable = zb.modes[Current]

			local a, b, c, d, e, f = hookFunc(ModeTable, ...)

			if (a != nil) then
				return a, b, c, d, e, f
			end
		end
	end

	return oldHook(name, gm, ...)
end
