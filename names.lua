-- interface for getting IC names

local Main = ListenerAddon
local L = Main.Locale

Main.name_resolvers = {}

local g_func

-------------------------------------------------------------------------------
function Main:SetNameResolver( func )
	if g_func then return end -- already have resolver
	g_func = func
end

-------------------------------------------------------------------------------
local function GetCharacterClassColor( guid )
	if not guid then
		return nil -- unknown player guid
	end
	
	local _, cls = GetPlayerInfoByGUID( guid )
	if cls and RAID_CLASS_COLORS[cls] then
		local c = RAID_CLASS_COLORS[cls]
		return ("ff%.2x%.2x%.2x"):format(c.r*255, c.g*255, c.b*255)
	end
end

local function FindResolver()
	if g_func then return g_func end
	for k,v in ipairs( Main.name_resolvers ) do
		g_func = v()
		if g_func then return g_func end
	end
	
	return g_func
end

Main.GetCharacterClassColor = GetCharacterClassColor

-------------------------------------------------------------------------------
function Main:GetICName( name, guid )

	if not g_func then
		if not FindResolver() then
		
			return name, nil, GetCharacterClassColor( guid )
		end
	end
	
	local firstname, icon, color = g_func( name, guid )
	if color == nil then
		color = GetCharacterClassColor( guid )
	end
	
	return firstname, icon, color
end
