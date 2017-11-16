-- mrp name resolver

local Main = ListenerAddon
local L = Main.Locale

-------------------------------------------------------------------------------
local function TryGet( name )
	if msp.char[name] and msp.char[name].supported 
	   and mrp.DisplayChat.NA( msp.char[name].field.NA ) ~= "" then
		
		local icname = msp.char[name].field.NA
		local color  = icname:match( "^|c([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])" )
		local name   = mrp.DisplayChat.NA( msp.char[name].field.NA )
		
		return name, nil, color
	end
end
 
-------------------------------------------------------------------------------
local function Resolve( name )
	local firstname, color
	
	local fullname = name
	if not name:find( "-" ) then
		fullname = fullname .. "-" .. Main.realm
	end
	
	firstname, color = TryGet( fullname )
	if firstname then
		return firstname, nil, nil, color
	end
	
	if fullname ~= name then
		firstname, color = TryGet( name )
		if firstname then
			return firstname, nil, nil, color
		end
	end
  
	return name
end

-------------------------------------------------------------------------------
-- check again after everything loads
local function Init()
	if mrp then
		return Resolve
	end
end

table.insert( Main.name_resolvers, Init )
