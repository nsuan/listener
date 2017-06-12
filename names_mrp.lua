-- mrp name resolver

local Main = ListenerAddon
local L = Main.Locale

-------------------------------------------------------------------------------
local function TryGet( name )
	if msp.char[name] and msp.char[name].supported 
	   and mrp.DisplayChat.NA( msp.char[name].field.NA ) ~= "" then
		
		local icname = msp.char[name].field.NA
		local color = icname:match( "^|c([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])" )
		local a = mrp.DisplayChat.NA( msp.char[name].field.NA ):gmatch( "%S+" )
		
		local name = (a() or "")
		local b = a()
		
		if name:len() < 5 and b then
			name = name .. " " .. b
		end
 
		return name, color
	end
end
 
-------------------------------------------------------------------------------
local function Resolve( name, guid )
	local firstname, lastname, color
	
	local fullname = name
	if not name:find( "-" ) then
		local n,r = UnitFullName( "player" )
		fullname = name .. "-" .. r
	end
	
	firstname, color = TryGet( fullname )
	if firstname then
		return firstname, nil, color
	end
	
	if fullname ~= name then
		firstname, color = TryGet( name )
		if firstname then
			return firstname, nil, color
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
