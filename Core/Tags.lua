local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local ElvUF = E.oUF
-- local Tags = ElvUF.Tags
local Translit = E.Libs.Translit
local translitMark = "!"

--Lua functions
local select = select
local tonumber = tonumber
local find = string.find
local floor = math.floor
local format = string.format
local gmatch = gmatch
local gsub = gsub
local match = string.match
local utf8lower = string.utf8lower
local utf8sub = string.utf8sub
--WoW API / Variables
local GetGuildInfo = GetGuildInfo
local GetInstanceInfo = GetInstanceInfo
local GetNumPartyMembers = GetNumPartyMembers
local GetPVPTimer = GetPVPTimer
local GetQuestGreenRange = GetQuestGreenRange
local GetThreatStatusColor = GetThreatStatusColor
local GetTime = GetTime
local GetUnitSpeed = GetUnitSpeed
local UnitClass = UnitClass
local UnitClassification = UnitClassification
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsAFK = UnitIsAFK
local UnitIsConnected = UnitIsConnected
local UnitIsDND = UnitIsDND
local UnitIsDead = UnitIsDead
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost
local UnitIsPVP = UnitIsPVP
local UnitIsPVPFreeForAll = UnitIsPVPFreeForAll
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitPVPName = UnitPVPName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitReaction = UnitReaction
local DEFAULT_AFK_MESSAGE = DEFAULT_AFK_MESSAGE
local SPELL_POWER_MANA = SPELL_POWER_MANA
local PVP = PVP

------------------------------------------------------------------------
--	Tags
------------------------------------------------------------------------

local function abbrev(name)
	local letters, lastWord = "", match(name, ".+%s(.+)$")
	if lastWord then
		for word in gmatch(name, ".-%s") do
			local firstLetter = utf8sub(gsub(word, "^[%s%p]*", ""), 1, 1)
			if firstLetter ~= utf8lower(firstLetter) then
				letters = format("%s%s. ", letters, firstLetter)
			end
		end
		name = format("%s%s", letters, lastWord)
	end
	return name
end

local RefreshNewTags -- will turn true at EOF
function E:AddTag(tagName, eventsOrSeconds, func, block)
	if block then return end -- easy killer for tags

	if type(eventsOrSeconds) == 'number' then
		ElvUF.Tags.OnUpdateThrottle[tagName] = eventsOrSeconds
	else

		ElvUF.Tags.Events[tagName] = (E.Retail and gsub(eventsOrSeconds, 'UNIT_HEALTH_FREQUENT', 'UNIT_HEALTH')) or gsub(eventsOrSeconds, 'UNIT_HEALTH([^_])', 'UNIT_HEALTH_FREQUENT%1')
	end

	ElvUF.Tags.Methods[tagName] = func

	if RefreshNewTags then
		ElvUF.Tags:RefreshEvents(tagName)
		ElvUF.Tags:RefreshMethods(tagName)

		RefreshNewTags = true
	end
end


ElvUF.Tags.Events["afk"] = "PLAYER_FLAGS_CHANGED"
ElvUF.Tags.Methods["afk"] = function(unit)
	local isAFK = UnitIsAFK(unit)
	if isAFK then
		return format("|cffFFFFFF[|r|cffFF0000%s|r|cFFFFFFFF]|r", DEFAULT_AFK_MESSAGE)
	else
		return nil
	end
end

do
	local faction = {
		Horde = E:TextureString(E.Media.Textures.HordeLogo, ":16:16"),
		Alliance = E:TextureString(E.Media.Textures.AllianceLogo, ":16:16"),
		Renegade = E:TextureString(E.Media.Textures.RenegadeLogo, ":16:16")
	}

	ElvUF.Tags.Events["faction:icon"] = "UNIT_FACTION"
	ElvUF.Tags.Methods["faction:icon"] = function(unit)
		return faction[UnitFactionGroup(unit)]
	end
end

ElvUF.Tags.Events["healthcolor"] = "UNIT_HEALTH UNIT_CONNECTION PLAYER_FLAGS_CHANGED"
ElvUF.Tags.Methods["healthcolor"] = function(unit)
	if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
		return Hex(0.84, 0.75, 0.65)
	else
		local r, g, b = ElvUF:ColorGradient(UnitHealth(unit), UnitHealthMax(unit), 0.69, 0.31, 0.31, 0.65, 0.63, 0.35, 0.33, 0.59, 0.33)
		return Hex(r, g, b)
	end
end

ElvUF.Tags.Events["name:abbrev"] = "UNIT_NAME_UPDATE"
ElvUF.Tags.Methods["name:abbrev"] = function(unit)
	local name = UnitName(unit)

	if name and find(name, "%s") then
		name = abbrev(name)
	end

	return name ~= nil and name or ""
end

for textFormat in pairs(E.GetFormattedTextStyles) do
	local tagTextFormat = strlower(gsub(textFormat, "_", "-"))
	ElvUF.Tags.Events[format("health:%s", tagTextFormat)] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION PLAYER_FLAGS_CHANGED"
	ElvUF.Tags.Methods[format("health:%s", tagTextFormat)] = function(unit)
		local status = UnitIsDead(unit) and L["Dead"] or UnitIsGhost(unit) and L["Ghost"] or not UnitIsConnected(unit) and L["Offline"]
		if status then
			return status
		else
			return E:GetFormattedText(textFormat, UnitHealth(unit), UnitHealthMax(unit))
		end
	end

	ElvUF.Tags.Events[format("health:%s-nostatus", tagTextFormat)] = "UNIT_HEALTH UNIT_MAXHEALTH"
	ElvUF.Tags.Methods[format("health:%s-nostatus", tagTextFormat)] = function(unit)
		return E:GetFormattedText(textFormat, UnitHealth(unit), UnitHealthMax(unit))
	end

	ElvUF.Tags.Events[format("power:%s", tagTextFormat)] = "UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_MAXRUNIC_POWER UNIT_RUNIC_POWER"
	ElvUF.Tags.Methods[format("power:%s", tagTextFormat)] = function(unit)
		local pType = UnitPowerType(unit)
		local min = UnitPower(unit, pType)

		if min == 0 and tagTextFormat ~= "deficit" then
			return ""
		else
			return E:GetFormattedText(textFormat, UnitPower(unit, pType), UnitPowerMax(unit, pType))
		end
	end

	ElvUF.Tags.Events[format("mana:%s", tagTextFormat)] = "UNIT_MANA UNIT_MAXMANA"
	ElvUF.Tags.Methods[format("mana:%s", tagTextFormat)] = function(unit)
		local min = UnitPower(unit, SPELL_POWER_MANA)

		if min == 0 and tagTextFormat ~= "deficit" then
			return ""
		else
			return E:GetFormattedText(textFormat, UnitPower(unit, SPELL_POWER_MANA), UnitPowerMax(unit, SPELL_POWER_MANA))
		end
	end
end

for textFormat, length in pairs({veryshort = 5, short = 10, medium = 15, long = 20}) do
	ElvUF.Tags.Events[format("health:deficit-percent:name-%s", textFormat)] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION PLAYER_FLAGS_CHANGED"
	ElvUF.Tags.Methods[format("health:deficit-percent:name-%s", textFormat)] = function(unit)
		local cur, max = UnitHealth(unit), UnitHealthMax(unit)
		local deficit = max - cur

		if deficit > 0 and cur > 0 then
			return _TAGS["health:percent-nostatus"](unit)
		else
			return _TAGS[format("name:%s", textFormat)](unit)
		end
	end

	ElvUF.Tags.Events[format("name:abbrev:%s", textFormat)] = "UNIT_NAME_UPDATE"
	ElvUF.Tags.Methods[format("name:abbrev:%s", textFormat)] = function(unit)
		local name = UnitName(unit)

		if name and find(name, "%s") then
			name = abbrev(name)
		end

		return name ~= nil and E:ShortenString(name, length) or ""
	end

	ElvUF.Tags.Events[format("name:%s", textFormat)] = "UNIT_NAME_UPDATE"
	ElvUF.Tags.Methods[format("name:%s", textFormat)] = function(unit)
		local name = UnitName(unit)
		return name ~= nil and E:ShortenString(name, length) or nil
	end

	ElvUF.Tags.Events[format("name:%s:status", textFormat)] = "UNIT_NAME_UPDATE UNIT_CONNECTION PLAYER_FLAGS_CHANGED UNIT_HEALTH"
	ElvUF.Tags.Methods[format("name:%s:status", textFormat)] = function(unit)
		local status = UnitIsDead(unit) and L["Dead"] or UnitIsGhost(unit) and L["Ghost"] or not UnitIsConnected(unit) and L["Offline"]
		local name = UnitName(unit)
		if (status) then
			return status
		else
			return name ~= nil and E:ShortenString(name, length) or nil
		end
	end

	ElvUF.Tags.Events[format("name:%s:translit", textFormat)] = "UNIT_NAME_UPDATE"
	ElvUF.Tags.Methods[format("name:%s:translit", textFormat)] = function(unit)
		local name = Translit:Transliterate(UnitName(unit), translitMark)
		return name ~= nil and E:ShortenString(name, length) or nil
	end

	ElvUF.Tags.Events[format("target:%s", textFormat)] = "UNIT_TARGET"
	ElvUF.Tags.Methods[format("target:%s", textFormat)] = function(unit)
		local targetName = UnitName(unit.."target")
		return targetName ~= nil and E:ShortenString(targetName, length) or nil
	end

	ElvUF.Tags.Events[format("target:%s:translit", textFormat)] = "UNIT_TARGET"
	ElvUF.Tags.Methods[format("target:%s:translit", textFormat)] = function(unit)
		local targetName = Translit:Transliterate(UnitName(unit.."target"), translitMark)
		return targetName ~= nil and E:ShortenString(targetName, length) or nil
	end
end

ElvUF.Tags.Events["health:max"] = "UNIT_MAXHEALTH"
ElvUF.Tags.Methods["health:max"] = function(unit)
	local max = UnitHealthMax(unit)

	return E:GetFormattedText("CURRENT", max, max)
end

ElvUF.Tags.Events["health:deficit-percent:name"] = "UNIT_HEALTH UNIT_MAXHEALTH"
ElvUF.Tags.Methods["health:deficit-percent:name"] = function(unit)
	local currentHealth = UnitHealth(unit)
	local deficit = UnitHealthMax(unit) - currentHealth

	if deficit > 0 and currentHealth > 0 then
		return _TAGS["health:percent-nostatus"](unit)
	else
		return _TAGS.name(unit)
	end
end

ElvUF.Tags.Events["power:max"] = "UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_MAXRUNIC_POWER"
ElvUF.Tags.Methods["power:max"] = function(unit)
	local pType = UnitPowerType(unit)
	local max = UnitPowerMax(unit, pType)

	return E:GetFormattedText("CURRENT", max, max)
end

ElvUF.Tags.Methods["manacolor"] = function()
	local mana = PowerBarColor.MANA
	local altR, altG, altB = mana.r, mana.g, mana.b
	local color = ElvUF.colors.power.MANA
	if color then
		return Hex(color[1], color[2], color[3])
	else
		return Hex(altR, altG, altB)
	end
end

ElvUF.Tags.Events["mana:max"] = "UNIT_MAXMANA"
ElvUF.Tags.Methods["mana:max"] = function(unit)
	local max = UnitPowerMax(unit, SPELL_POWER_MANA)

	return E:GetFormattedText("CURRENT", max, max)
end

ElvUF.Tags.Events["difficultycolor"] = "UNIT_LEVEL PLAYER_LEVEL_UP"
ElvUF.Tags.Methods["difficultycolor"] = function(unit)
	local r, g, b
	local level = UnitLevel(unit)
	if level > 1 then
		local DiffColor = UnitLevel(unit) - UnitLevel("player")
		if DiffColor >= 5 then
			r, g, b = 0.69, 0.31, 0.31
		elseif DiffColor >= 3 then
			r, g, b = 0.71, 0.43, 0.27
		elseif DiffColor >= -2 then
			r, g, b = 0.84, 0.75, 0.65
		elseif -DiffColor <= GetQuestGreenRange() then
			r, g, b = 0.33, 0.59, 0.33
		else
			r, g, b = 0.55, 0.57, 0.61
		end
	end

	return Hex(r, g, b)
end

ElvUF.Tags.Events["namecolor"] = "UNIT_NAME_UPDATE UNIT_FACTION"
ElvUF.Tags.Methods["namecolor"] = function(unit)
	local unitReaction = UnitReaction(unit, "player")
	local unitPlayer = UnitIsPlayer(unit)
	if unitPlayer then
		local _, unitClass = UnitClass(unit)
		local class = ElvUF.colors.class[unitClass]
		if not class then return "" end
		return Hex(class[1], class[2], class[3])
	elseif unitReaction then
		local reaction = ElvUF.colors.reaction[unitReaction]
		return Hex(reaction[1], reaction[2], reaction[3])
	else
		return "|cFFC2C2C2"
	end
end

ElvUF.Tags.Events["smartlevel"] = "UNIT_LEVEL PLAYER_LEVEL_UP"
ElvUF.Tags.Methods["smartlevel"] = function(unit)
	local level = UnitLevel(unit)
	if level == UnitLevel("player") then
		return ""
	elseif level > 0 then
		return level
	else
		return "??"
	end
end

ElvUF.Tags.Events["realm"] = "UNIT_NAME_UPDATE"
ElvUF.Tags.Methods["realm"] = function(unit)
	local _, realm = UnitName(unit)

	if realm and realm ~= "" then
		return realm
	else
		return nil
	end
end

ElvUF.Tags.Events["realm:dash"] = "UNIT_NAME_UPDATE"
ElvUF.Tags.Methods["realm:dash"] = function(unit)
	local _, realm = UnitName(unit)

	if realm and (realm ~= "" and realm ~= E.myrealm) then
		realm = format("-%s", realm)
	elseif realm == "" then
		realm = nil
	end

	return realm
end

ElvUF.Tags.Events["realm:translit"] = "UNIT_NAME_UPDATE"
ElvUF.Tags.Methods["realm:translit"] = function(unit)
	local _, realm = Translit:Transliterate(UnitName(unit), translitMark)

	if realm and realm ~= "" then
		return realm
	else
		return nil
	end
end

ElvUF.Tags.Events["realm:dash:translit"] = "UNIT_NAME_UPDATE"
ElvUF.Tags.Methods["realm:dash:translit"] = function(unit)
	local _, realm = Translit:Transliterate(UnitName(unit), translitMark)

	if realm and (realm ~= "" and realm ~= E.myrealm) then
		realm = format("-%s", realm)
	elseif realm == "" then
		realm = nil
	end

	return realm
end

ElvUF.Tags.Events["threat:percent"] = "UNIT_THREAT_SITUATION_UPDATE UNIT_THREAT_LIST_UPDATE"
ElvUF.Tags.Methods["threat:percent"] = function(unit)
	local _, _, percent = UnitDetailedThreatSituation("player", unit)
	if percent and percent > 0 and (GetNumPartyMembers() or UnitExists("pet")) then
		return format("%.0f%%", percent)
	else
		return nil
	end
end

ElvUF.Tags.Events["threat:current"] = "UNIT_THREAT_SITUATION_UPDATE UNIT_THREAT_LIST_UPDATE"
ElvUF.Tags.Methods["threat:current"] = function(unit)
	local _, _, percent, _, threatvalue = UnitDetailedThreatSituation("player", unit)
	if percent and percent > 0 and (GetNumPartyMembers() or UnitExists("pet")) then
		return E:ShortValue(threatvalue)
	else
		return nil
	end
end

ElvUF.Tags.Events["threatcolor"] = "UNIT_THREAT_SITUATION_UPDATE UNIT_THREAT_LIST_UPDATE"
ElvUF.Tags.Methods["threatcolor"] = function(unit)
	local _, status = UnitDetailedThreatSituation("player", unit)
	if status and (GetNumPartyMembers() > 0 or UnitExists("pet")) then
		return Hex(GetThreatStatusColor(status))
	else
		return nil
	end
end

local unitStatus = {}
ElvUF.Tags.OnUpdateThrottle["statustimer"] = 1
ElvUF.Tags.Methods["statustimer"] = function(unit)
	if not UnitIsPlayer(unit) then return end
	local guid = UnitGUID(unit)
	if UnitIsAFK(unit) then
		if not unitStatus[guid] or unitStatus[guid] and unitStatus[guid][1] ~= "AFK" then
			unitStatus[guid] = {"AFK", GetTime()}
		end
	elseif UnitIsDND(unit) then
		if not unitStatus[guid] or unitStatus[guid] and unitStatus[guid][1] ~= "DND" then
			unitStatus[guid] = {"DND", GetTime()}
		end
	elseif UnitIsDead(unit) or UnitIsGhost(unit) then
		if not unitStatus[guid] or unitStatus[guid] and unitStatus[guid][1] ~= "Dead" then
			unitStatus[guid] = {"Dead", GetTime()}
		end
	elseif not UnitIsConnected(unit) then
		if not unitStatus[guid] or unitStatus[guid] and unitStatus[guid][1] ~= "Offline" then
			unitStatus[guid] = {"Offline", GetTime()}
		end
	else
		unitStatus[guid] = nil
	end

	if unitStatus[guid] ~= nil then
		local status = unitStatus[guid][1]
		local timer = GetTime() - unitStatus[guid][2]
		local mins = floor(timer / 60)
		local secs = floor(timer - (mins * 60))
		return format("%s (%01.f:%02.f)", status, mins, secs)
	else
		return nil
	end
end

ElvUF.Tags.OnUpdateThrottle["pvptimer"] = 1
ElvUF.Tags.Methods["pvptimer"] = function(unit)
	if UnitIsPVPFreeForAll(unit) or UnitIsPVP(unit) then
		local timer = GetPVPTimer()

		if timer ~= 301000 and timer ~= -1 then
			local mins = floor((timer / 1000) / 60)
			local secs = floor((timer / 1000) - (mins * 60))
			return format("%s (%01.f:%02.f)", PVP, mins, secs)
		else
			return PVP
		end
	else
		return nil
	end
end

local baseSpeed = 7
local speedText = SPEED

ElvUF.Tags.OnUpdateThrottle["speed:percent"] = 0.1
ElvUF.Tags.Methods["speed:percent"] = function(unit)
	local currentSpeedInYards = GetUnitSpeed(unit)
	local currentSpeedInPercent = (currentSpeedInYards / baseSpeed) * 100

	return format("%s: %d%%", speedText, currentSpeedInPercent)
end

ElvUF.Tags.OnUpdateThrottle["speed:percent-moving"] = 0.1
ElvUF.Tags.Methods["speed:percent-moving"] = function(unit)
	local currentSpeedInYards = GetUnitSpeed(unit)
	local currentSpeedInPercent = currentSpeedInYards > 0 and ((currentSpeedInYards / baseSpeed) * 100)

	if currentSpeedInPercent then
		currentSpeedInPercent = format("%s: %d%%", speedText, currentSpeedInPercent)
	end

	return currentSpeedInPercent or nil
end

ElvUF.Tags.OnUpdateThrottle["speed:percent-raw"] = 0.1
ElvUF.Tags.Methods["speed:percent-raw"] = function(unit)
	local currentSpeedInYards = GetUnitSpeed(unit)
	local currentSpeedInPercent = (currentSpeedInYards / baseSpeed) * 100

	return format("%d%%", currentSpeedInPercent)
end

ElvUF.Tags.OnUpdateThrottle["speed:percent-moving-raw"] = 0.1
ElvUF.Tags.Methods["speed:percent-moving-raw"] = function(unit)
	local currentSpeedInYards = GetUnitSpeed(unit)
	local currentSpeedInPercent = currentSpeedInYards > 0 and ((currentSpeedInYards / baseSpeed) * 100)

	if currentSpeedInPercent then
		currentSpeedInPercent = format("%d%%", currentSpeedInPercent)
	end

	return currentSpeedInPercent or nil
end

ElvUF.Tags.OnUpdateThrottle["speed:yardspersec"] = 0.1
ElvUF.Tags.Methods["speed:yardspersec"] = function(unit)
	local currentSpeedInYards = GetUnitSpeed(unit)

	return format("%s: %.1f", speedText, currentSpeedInYards)
end

ElvUF.Tags.OnUpdateThrottle["speed:yardspersec-moving"] = 0.1
ElvUF.Tags.Methods["speed:yardspersec-moving"] = function(unit)
	local currentSpeedInYards = GetUnitSpeed(unit)

	return currentSpeedInYards > 0 and format("%s: %.1f", speedText, currentSpeedInYards) or nil
end

ElvUF.Tags.OnUpdateThrottle["speed:yardspersec-raw"] = 0.1
ElvUF.Tags.Methods["speed:yardspersec-raw"] = function(unit)
	local currentSpeedInYards = GetUnitSpeed(unit)
	return format("%.1f", currentSpeedInYards)
end

ElvUF.Tags.OnUpdateThrottle["speed:yardspersec-moving-raw"] = 0.1
ElvUF.Tags.Methods["speed:yardspersec-moving-raw"] = function(unit)
	local currentSpeedInYards = GetUnitSpeed(unit)

	return currentSpeedInYards > 0 and format("%.1f", currentSpeedInYards) or nil
end

ElvUF.Tags.Events["classificationcolor"] = "UNIT_CLASSIFICATION_CHANGED"
ElvUF.Tags.Methods["classificationcolor"] = function(unit)
	local c = UnitClassification(unit)
	if c == "rare" or c == "elite" then
		return Hex(1, 0.5, 0.25) -- Orange
	elseif c == "rareelite" or c == "worldboss" then
		return Hex(1, 0, 0) -- Red
	end
end

ElvUF.Tags.SharedEvents.PLAYER_GUILD_UPDATE = true

ElvUF.Tags.Events["guild"] = "UNIT_NAME_UPDATE PLAYER_GUILD_UPDATE"
ElvUF.Tags.Methods["guild"] = function(unit)
	if (UnitIsPlayer(unit)) then
		return GetGuildInfo(unit) or nil
	end
end

ElvUF.Tags.Events["guild:brackets"] = "PLAYER_GUILD_UPDATE"
ElvUF.Tags.Methods["guild:brackets"] = function(unit)
	local guildName = GetGuildInfo(unit)

	return guildName and format("<%s>", guildName) or nil
end

ElvUF.Tags.Events["guild:translit"] = "UNIT_NAME_UPDATE PLAYER_GUILD_UPDATE"
ElvUF.Tags.Methods["guild:translit"] = function(unit)
	if UnitIsPlayer(unit) then
		return Translit:Transliterate(GetGuildInfo(unit), translitMark) or nil
	end
end

ElvUF.Tags.Events["guild:brackets:translit"] = "PLAYER_GUILD_UPDATE"
ElvUF.Tags.Methods["guild:brackets:translit"] = function(unit)
	local guildName = Translit:Transliterate(GetGuildInfo(unit), translitMark)

	return guildName and format("<%s>", guildName) or nil
end

ElvUF.Tags.Events["target"] = "UNIT_TARGET"
ElvUF.Tags.Methods["target"] = function(unit)
	local targetName = UnitName(unit.."target")
	return targetName or nil
end

ElvUF.Tags.Events["target:translit"] = "UNIT_TARGET"
ElvUF.Tags.Methods["target:translit"] = function(unit)
	local targetName = Translit:Transliterate(UnitName(unit.."target"), translitMark)
	return targetName or nil
end

ElvUF.Tags.Events["guild:rank"] = "UNIT_NAME_UPDATE"
ElvUF.Tags.Methods["guild:rank"] = function(unit)
	if (UnitIsPlayer(unit)) then
		return select(2, GetGuildInfo(unit)) or ""
	end
end

ElvUF.Tags.Events["arena:number"] = "UNIT_NAME_UPDATE"
ElvUF.Tags.Methods["arena:number"] = function(unit)
	local _, instanceType = GetInstanceInfo()
	if instanceType == "arena" then
		for i = 1, 5 do
			if UnitIsUnit(unit, "arena"..i) then
				return i
			end
		end
	end
end

ElvUF.Tags.Events["class"] = "UNIT_NAME_UPDATE"
ElvUF.Tags.Methods["class"] = function(unit)
	return UnitClass(unit)
end

ElvUF.Tags.Events["specialization"] = "UNIT_NAME_UPDATE ACTIVE_TALENT_GROUP_CHANGED PLAYER_TALENT_UPDATE INSPECT_TALENT_READY UNIT_PORTRAIT_UPDATE"
ElvUF.Tags.Methods["specialization"] = function(unit)
	if (UnitIsPlayer(unit)) then
		local _, specName
		local GUID = UnitGUID(unit)

		if GUID == E.myguid then
			_, specName = E:GetTalentSpecInfo()
		else
			if CanInspect(unit) then
				_, specName = E:GetTalentSpecInfo(true)
			end
		end

		return specName
	end
end


ElvUF.Tags.Events["group"] = "PARTY_MEMBERS_CHANGED RAID_ROSTER_UPDATE"
ElvUF.Tags.Methods["group"] = function(unit)
	local name, server = UnitName(unit)
	if(server and server ~= '') then
		name = format('%s-%s', name, server)
	end
	for i=1, GetNumRaidMembers() do
		local raidName, _, group = GetRaidRosterInfo(i)
		if(raidName == name) then
			return group
		end
	end
end

ElvUF.Tags.Events["leader"] = "PARTY_LEADER_CHANGED"
ElvUF.Tags.Methods["leader"] =function(u)
	if(UnitIsPartyLeader(u)) then
		return 'L'
	end
end

ElvUF.Tags.Events["leaderlong"] = "PARTY_LEADER_CHANGED"
ElvUF.Tags.Methods["leaderlong"] =function(u)
	if(UnitIsPartyLeader(u)) then
		return 'Leader'
	end
end


ElvUF.Tags.Events["name:title"] = "UNIT_NAME_UPDATE"
ElvUF.Tags.Methods["name:title"] = function(unit)
	if UnitIsPlayer(unit) then
		return UnitPVPName(unit)
	end
end

do
	local highestVersion = E.version
	E:AddTag('ElvUI-Users', 20, function(unit)
		if E.UserList and next(E.UserList) then
			local name = UnitName(unit)
			if name then
				-- local nameRealm = (realm and realm ~= '' and format('%s-%s', name, realm)) or name
				local userVersion =  E.UserList[name]
				if userVersion then
					if highestVersion < userVersion then
						highestVersion = userVersion
					end
					return (userVersion < highestVersion) and '|cffFF3333E|r' or '|cff3366ffE|r'
				end
			end
		end
	end)
end

local SA = LibStub("SpecializedAbsorbs-1.0")
local HealComm = LibStub("LibHealComm-4.0")
-- Tags
ElvUF.Tags.Methods["absorbs"] = function(tagUnit)
	local abs = SA.UnitTotal(UnitGUID(tagUnit))
	if abs > 0 then
		return E:ShortValue(abs)
	end
end
ElvUF.Tags.Methods["absorbs()"] = function(tagUnit)
	local abs = SA.UnitTotal(UnitGUID(tagUnit))
	if abs > 0 then
		return "(" .. E:ShortValue(abs) .. ")"
	end
end
ElvUF.Tags.Methods["incomingheals:personal"] = function(tagUnit)
	local incHealP = (HealComm:GetHealAmount(UnitGUID(tagUnit), HealComm.ALL_HEALS, nil--[[GetTime() + (element.lookAhead or 5)]], UnitGUID("player")) or 0) * ((HealComm:GetHealModifier(UnitGUID(tagUnit)) or 1) or 0)
	if incHealP > 0 then
		return E:ShortValue(incHealP)
	end
end
ElvUF.Tags.Methods["incomingheals:others"] = function(tagUnit)
	local incHealO = (HealComm:GetOthersHealAmount(UnitGUID(tagUnit), HealComm.ALL_HEALS, nil--[[GetTime() + (element.lookAhead or 5)]]) or 0) * ((HealComm:GetHealModifier(UnitGUID(tagUnit)) or 1) or 0)
	if incHealO > 0 then
		return E:ShortValue(incHealO)
	end
end
ElvUF.Tags.Methods["incomingheals"] = function(tagUnit)
	local incHeal = (HealComm:GetHealAmount(UnitGUID(tagUnit), HealComm.ALL_HEALS, nil--[[GetTime() + (element.lookAhead or 5)]]) or 0) * ((HealComm:GetHealModifier(UnitGUID(tagUnit)) or 1) or 0)
	if incHeal > 0 then
		return E:ShortValue(incHeal)
	end
end


E.TagInfo = {
	--Colors
	["namecolor"] = {category = L["Colors"], description = L["Colors names by player class or NPC reaction"]},
	["powercolor"] = {category = L["Colors"], description = L["Colors the power text based upon its type"]},
	["difficultycolor"] = {category = L["Colors"], description = L["Colors the following tags by difficulty, red for impossible, orange for hard, green for easy"]},
	["healthcolor"] = {category = L["Colors"], description = L["Changes color of health text, depending on the unit's current health"]},
	["threatcolor"] = {category = L["Colors"], description = L["Changes color of health, depending on the unit's threat situation"]},
	["classificationcolor"] = {category = L["Colors"], description = L["Changes color of health, depending on the unit's classification"]},
	--Classification
	["Classification"] = {category = L["Classification"], description = L["Displays the unit's classification (e.g. 'ELITE' and 'RARE')"]},
	["shortclassification"] = {category = L["Classification"], description = L["Displays the unit's classification in short form (e.g. '+' for ELITE and 'R' for RARE)"]},
	["rare"] = {category = L["Classification"], description = L["Displays 'Rare' when the unit is a rare or rareelite"]},
	--Guild
	["guild"] = {category = L["Guild"], description = L["Displays the guild name"]},
	["guild:brackets"] = {category = L["Guild"], description = L["Displays the guild name with < > brackets (e.g. <GUILD>)"]},
	["guild:brackets:translit"] = {category = L["Guild"], description = L["Displays the guild name with < > and transliteration (e.g. <GUILD>)"]},
	["guild:rank"] = {category = L["Guild"], description = L["Displays the guild rank"]},
	["guild:translit"] = {category = L["Guild"], description = L["Displays the guild name with transliteration for cyrillic letters"]},
	--Health
	["curhp"] = {category = L["Health"], description = L["Displays the current HP without decimals"]},
	["perhp"] = {category = L["Health"], description = L["Displays percentage HP without decimals"]},
	["maxhp"] = {category = L["Health"], description = L["Displays max HP without decimals"]},
	["deficit:name"] = {category = L["Health"], description = L["Displays the health as a deficit and the name at full health"]},
	["health:current"] = {category = L["Health"], description = L["Displays the current health of the unit"]},
	["health:current-max"] = {category = L["Health"], description = L["Displays the current and maximum health of the unit, separated by a dash"]},
	["health:current-max-nostatus"] = {category = L["Health"], description = L["Displays the current and maximum health of the unit, separated by a dash, without status"]},
	["health:current-max-percent"] = {category = L["Health"], description = L["Displays the current and max hp of the unit, separated by a dash (% when not full hp)"]},
	["health:current-max-percent-nostatus"] = {category = L["Health"], description = L["Displays the current and max hp of the unit, separated by a dash (% when not full hp), without status"]},
	["health:current-nostatus"] = {category = L["Health"], description = L["Displays the current health of the unit, without status"]},
	["health:current-percent"] = {category = L["Health"], description = L["Displays the current hp of the unit (% when not full hp)"]},
	["health:current-percent-nostatus"] = {category = L["Health"], description = L["Displays the current hp of the unit (% when not full hp), without status"]},
	["health:deficit"] = {category = L["Health"], description = L["Displays the health of the unit as a deficit (Total Health - Current Health = -Deficit)"]},
	["health:deficit-nostatus"] = {category = L["Health"], description = L["Displays the health of the unit as a deficit, without status"]},
	["health:deficit-percent:name"] = {category = L["Health"], description = L["Displays the health deficit as a percentage and the full name of the unit"]},
	["health:deficit-percent:name-long"] = {category = L["Health"], description = L["Displays the health deficit as a percentage and the name of the unit (limited to 20 letters)"]},
	["health:deficit-percent:name-medium"] = {category = L["Health"], description = L["Displays the health deficit as a percentage and the name of the unit (limited to 15 letters)"]},
	["health:deficit-percent:name-short"] = {category = L["Health"], description = L["Displays the health deficit as a percentage and the name of the unit (limited to 10 letters)"]},
	["health:deficit-percent:name-veryshort"] = {category = L["Health"], description = L["Displays the health deficit as a percentage and the name of the unit (limited to 5 letters)"]},
	["health:max"] = {category = L["Health"], description = L["Displays the maximum health of the unit"]},
	["health:percent"] = {category = L["Health"], description = L["Displays the current health of the unit as a percentage"]},
	["health:percent-nostatus"] = {category = L["Health"], description = L["Displays the unit's current health as a percentage, without status"]},
	["missinghp"] = {category = L["Health"], description = L["Displays the missing health of the unit in whole numbers, when not at full health"]},
	--Level
	["smartlevel"] = {category = L["Level"], description = L["Only display the unit's level if it is not the same as yours"]},
	["level"] = {category = L["Level"], description = L["Displays the level of the unit"]},
	--Mana
	["mana:current"] = {category = L["Mana"], description = L["Displays the unit's current amount of mana (e.g. 97200)"]},
	["mana:current-percent"] = {category = L["Mana"], description = L["Displays the current amount of mana as a whole number and a percentage, separated by a dash"]},
	["mana:current-max"] = {category = L["Mana"], description = L["Displays the current mana and max mana, separated by a dash"]},
	["mana:current-max-percent"] = {category = L["Mana"], description = L["Displays the current mana and max mana, separated by a dash (% when not full power)"]},
	["mana:percent"] = {category = L["Mana"], description = L["Displays the mana of the unit as a percentage value"]},
	["mana:max"] = {category = L["Mana"], description = L["Displays the unit's maximum mana"]},
	["mana:deficit"] = {category = L["Mana"], description = L["Displays the mana deficit (Total Mana - Current Mana = -Deficit)"]},
	["curmana"] = {category = L["Mana"], description = L["Displays the current mana without decimals"]},
	["maxmana"] = {category = L["Mana"], description = L["Displays the max amount of mana the unit can have"]},
	--Names
	["name"] = {category = L["Names"], description = L["Displays the full name of the unit without any letter limitation"]},
	["name:veryshort"] = {category = L["Names"], description = L["Displays the name of the unit (limited to 5 letters)"]},
	["name:short"] = {category = L["Names"], description = L["Displays the name of the unit (limited to 10 letters)"]},
	["name:medium"] = {category = L["Names"], description = L["Displays the name of the unit (limited to 15 letters)"]},
	["name:long"] = {category = L["Names"], description = L["Displays the name of the unit (limited to 20 letters)"]},
	["name:veryshort:translit"] = {category = L["Names"], description = L["Displays the name of the unit with transliteration for cyrillic letters (limited to 5 letters)"]},
	["name:short:translit"] = {category = L["Names"], description = L["Displays the name of the unit with transliteration for cyrillic letters (limited to 10 letters)"]},
	["name:medium:translit"] = {category = L["Names"], description = L["Displays the name of the unit with transliteration for cyrillic letters (limited to 15 letters)"]},
	["name:long:translit"] = {category = L["Names"], description = L["Displays the name of the unit with transliteration for cyrillic letters (limited to 20 letters)"]},
	["name:abbrev"] = {category = L["Names"], description = L["Displays the name of the unit with abbreviation (e.g. 'Shadowfury Witch Doctor' becomes 'S. W. Doctor')"]},
	["name:abbrev:veryshort"] = {category = L["Names"], description = L["Displays the name of the unit with abbreviation (limited to 5 letters)"]},
	["name:abbrev:short"] = {category = L["Names"], description = L["Displays the name of the unit with abbreviation (limited to 10 letters)"]},
	["name:abbrev:medium"] = {category = L["Names"], description = L["Displays the name of the unit with abbreviation (limited to 15 letters)"]},
	["name:abbrev:long"] = {category = L["Names"], description = L["Displays the name of the unit with abbreviation (limited to 20 letters)"]},
	["name:veryshort:status"] = {category = L["Names"], description = L["Replace the name of the unit with 'DEAD' or 'OFFLINE' if applicable (limited to 5 letters)"]},
	["name:short:status"] = {category = L["Names"], description = L["Replace the name of the unit with 'DEAD' or 'OFFLINE' if applicable (limited to 10 letters)"]},
	["name:medium:status"] = {category = L["Names"], description = L["Replace the name of the unit with 'DEAD' or 'OFFLINE' if applicable (limited to 15 letters)"]},
	["name:long:status"] = {category = L["Names"], description = L["Replace the name of the unit with 'DEAD' or 'OFFLINE' if applicable (limited to 20 letters)"]},
	["name:title"] = {category = L["Names"], description = L["Displays player name and title"]},
	--Party and Raid
	["group"] = {category = L["Party and Raid"], description = L["Displays the group number the unit is in ('1' - '8')"]},
	["leader"] = {category = L["Party and Raid"], description = L["Displays 'L' if the unit is the group/raid leader"]},
	["leaderlong"] = {category = L["Party and Raid"], description = L["Displays 'Leader' if the unit is the group/raid leader"]},
	--Power
	["power:current"] = {category = L["Power"], description = L["Displays the unit's current amount of power"]},
	["power:current-percent"] = {category = L["Power"], description = L["Displays the current power and power as a percentage, separated by a dash"]},
	["power:current-max"] = {category = L["Power"], description = L["Displays the current power and max power, separated by a dash"]},
	["power:current-max-percent"] = {category = L["Power"], description = L["Displays the current power and max power, separated by a dash (% when not full power)"]},
	["power:percent"] = {category = L["Power"], description = L["Displays the unit's power as a percentage"]},
	["power:max"] = {category = L["Power"], description = L["Displays the unit's maximum power"]},
	["power:deficit"] = {category = L["Power"], description = L["Displays the power as a deficit (Total Power - Current Power = -Deficit)"]},
	["curpp"] = {category = L["Power"], description = L["Displays the unit's current power without decimals"]},
	["perpp"] = {category = L["Power"], description = L["Displays the unit's percentage power without decimals "]},
	["maxpp"] = {category = L["Power"], description = L["Displays the max amount of power of the unit in whole numbers without decimals"]},
	["missingpp"] = {category = L["Power"], description = L["Displays the missing power of the unit in whole numbers when not at full power"]},
	--Realm
	["realm"] = {category = L["Realm"], description = L["Displays the server name"]},
	["realm:translit"] = {category = L["Realm"], description = L["Displays the server name with transliteration for cyrillic letters"]},
	["realm:dash"] = {category = L["Realm"], description = L["Displays the server name with a dash in front (e.g. -Realm)"]},
	["realm:dash:translit"] = {category = L["Realm"], description = L["Displays the server name with transliteration for cyrillic letters and a dash in front"]},
	--Status
	["status"] = {category = L["Status"], description = L["Displays zzz, dead, ghost, offline"]},
	["statustimer"] = {category = L["Status"], description = L["Displays a timer for how long a unit has had the status (e.g 'DEAD - 0:34')"]},
	["afk"] = {category = L["Status"], description = L["Displays <AFK> if the Unit is afk"]},
	["dead"] = {category = L["Status"], description = L["Displays <DEAD> if the unit is dead"]},
	["resting"] = {category = L["Status"], description = L["Displays zzz if the unit is dead"]},
	["pvp"] = {category = L["Status"], description = L["Displays 'PvP' if the unit is pvp flagged"]},
	['ElvUI-Users'] = { category = L["Status"], description = "Displays current ElvUI users" },
	["offline"] = {category = L["Status"], description = L["Displays 'OFFLINE' if the unit is disconnected"]},
	--Target
	["target"] = {category = L["Target"], description = L["Displays the current target of the unit"]},
	["target:veryshort"] = {category = L["Target"], description = L["Displays the current target of the unit (limited to 5 letters)"]},
	["target:short"] = {category = L["Target"], description = L["Displays the current target of the unit (limited to 10 letters)"]},
	["target:medium"] = {category = L["Target"], description = L["Displays the current target of the unit (limited to 15 letters)"]},
	["target:long"] = {category = L["Target"], description = L["Displays the current target of the unit (limited to 20 letters)"]},
	["target:translit"] = {category = L["Target"], description = L["Displays the current target of the unit with transliteration for cyrillic letters"]},
	["target:veryshort:translit"] = {category = L["Target"], description = L["Displays the current target of the unit with transliteration for cyrillic letters (limited to 5 letters)"]},
	["target:short:translit"] = {category = L["Target"], description = L["Displays the current target of the unit with transliteration for cyrillic letters (limited to 10 letters)"]},
	["target:medium:translit"] = {category = L["Target"], description = L["Displays the current target of the unit with transliteration for cyrillic letters (limited to 15 letters)"]},
	["target:long:translit"] = {category = L["Target"], description = L["Displays the current target of the unit with transliteration for cyrillic letters (limited to 20 letters)"]},
	--Threat
	["threat"] = {category = L["Threat"], description = L["Displays the current threat"]},
	["threat:percent"] = {category = L["Threat"], description = L["Displays the current threat as a percent"]},
	["threat:current"] = {category = L["Threat"], description = L["Displays the current threat as a value"]},
	--Miscellaneous
	["smartclass"] = {category = L["Miscellaneous"], description = L["Displays the player's class or creature's type"]},
	["specialization"] = {category = L["Miscellaneous"], description = L["Displays your current specialization as text"]},
	["class"] = {category = L["Miscellaneous"], description = L["Displays the class of the unit, if that unit is a player"]},
	["difficulty"] = {category = L["Miscellaneous"], description = L["Changes color of the next tag based on how difficult the unit is compared to the players level"]},
	["faction"] = {category = L["Miscellaneous"], description = L["Displays 'Alliance' or 'Horde' or 'Renegade'"]},
	["faction:icon"] = {category = L["Miscellaneous"], description = L["Displays faction icon"]},
	["plus"] = {category = L["Miscellaneous"], description = L["Displays the character '+' if the unit is an elite or rare-elite"]},
	["arena:number"] = {category = L["Miscellaneous"], description = L["Displays the arena number 1-5"]},
}

function E:AddTagInfo(tagName, category, description, order, hidden)
	if order then order = tonumber(order) + 10 end

	E.TagInfo[tagName] = E.TagInfo[tagName] or {}
	E.TagInfo[tagName].category = category or "Разное"
	E.TagInfo[tagName].description = description or ""
	E.TagInfo[tagName].order = order or nil
	E.TagInfo[tagName].hidden = hidden or nil
	return E.TagInfo[tagName]
end

RefreshNewTags = true
