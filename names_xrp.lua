-- xrp name resolver

local Main = ListenerAddon
local L = Main.Locale
 
-------------------------------------------------------------------------------
local function Resolve( name, guid )
	local color = nil
	
	local ch = xrp.characters.byGUID[ guid ]
	
	if ch and not ch.hide then
		local icname = ch.fields.NA or name
		
		-- get trp color code
		color = icname:match( "^|c([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])" )
		icname = xrp.Strip( icname )
		local a = icname:gmatch( "%S+" )
		local name = (a() or "")
		local b = a()
		if name:len() < 5 and b then
			name = name .. " " .. b
		end
		
		return name, nil, color
	end
	
	return name
end

-- check again after everything loads
local function Init()
	if xrp then
		return Resolve
	end
end

table.insert( Main.name_resolvers, Init )
 