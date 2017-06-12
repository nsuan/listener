-- TRP3 name resolver

local Main = ListenerAddon
local L = Main.Locale

-------------------------------------------------------------------------------
local function GetTRPCharacterInfo( name )
	
	local char, realm = TRP3_API.utils.str.unitIDToInfo( name )
	if not realm then
		realm = TRP3_API.globals.player_realm_id
	end
	name = TRP3_API.utils.str.unitInfoToID( char, realm )
	
	if name == TRP3_API.globals.player_id then
		return TRP3_API.profile.getData("player");
	elseif TRP3_API.register.isUnitIDKnown( name ) then
		return TRP3_API.register.getUnitIDCurrentProfile( name ) or {};
	end
	return {};
end

-------------------------------------------------------------------------------
local function Resolve( name )
	local firstname, lastname, title, icon, color = name, "", "", nil, nil
	
	if UnitFactionGroup( "player" ) == "Alliance" then
		icon = "Inv_Misc_Tournaments_banner_Human"
	else
		icon = "Inv_Misc_Tournaments_banner_Orc"
	end
			
	local info = GetTRPCharacterInfo( name )
	local ci = info.characteristics
	
	if ci then
		firstname = ci.FN or name
		lastname = ci.LN or ""
		title = "" -- todo?  
		
		if lastname == "" then
			local a = firstname:gmatch( "%S+" )
			firstname = a()
			lastname = a()
		end
		
		if ci.CH then 
			color = "ff" .. ci.CH
		end
		
		if ci.IC and ci.IC ~= "" then
			icon = ci.IC 
		end
		
		if firstname:len() < 5 and lastname then 
			-- lengthen it
			firstname = firstname .. " " .. lastname
			lastname = ""
		end
	end
	
	return firstname, icon, color
end

-- check again after everything loads
local function Init()
	if TRP3_API then
		return Resolve
	end
end

table.insert( Main.name_resolvers, Init )
