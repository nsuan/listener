-- xrp name resolver

local Main = ListenerAddon
local L = Main.Locale
 
-------------------------------------------------------------------------------
local function Resolve( name )

	local color = nil
	local ch = xrp.characters.byName[ name ]
	
	if ch and not ch.hide then
		local icname = ch.fields.NA or name
		
		-- get trp color code
		color = icname:match( "^|c([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])" )
		icname = xrp.Strip( icname )
		
		return icname, nil, color
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
 