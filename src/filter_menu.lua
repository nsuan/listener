-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- This is a simple module for creating a filter menu, to be shared by the
-- settings context menu for frames and the snooper.
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L    = Main.Locale

-------------------------------------------------------------------------------
-- Registered menus. This is populated by RegisterMenu.
-- Basically it contains the layouts of the menus, and then when you call
-- PopulateFilterMenu, the name of the registered entry is part of the
-- menuList, e.g. FILTERS_<name>_MISC
--
local g_register = {}

-------------------------------------------------------------------------------
-- Chat channel names that are ignored.
--
local IGNORED_CHANNELS = {
	xtensionxtooltip2   = true; -- Common addon channel.
	
	general             = true; -- we dont support server channels yet
	trade               = true;
	localdefense        = true;
	lookingforgroup     = true;
	bigfootworldchannel = true;
	meetingstone        = true;
}

-------------------------------------------------------------------------------
-- List of filter options that can be passed to RegisterFilterMenu.
--
local FILTER_OPTIONS = {
	Public           = { "SAY", "EMOTE", "TEXT_EMOTE", "YELL" };
	Party            = { "PARTY", "PARTY_LEADER" };
	Raid             = { "RAID", "RAID_LEADER" };
	["Raid Warning"] = { "RAID_WARNING" };
	Instance         = { "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" };
	Guild            = { "GUILD" };
	Officer          = { "OFFICER" };
	Whisper          = { "WHISPER", "WHISPER_INFORM" };
	Rolls            = { "ROLL" };
	
	-- these are treated in a specially.
	-- (see the populate code)
	Channel          = "Channels";
	Misc             = "Misc";
}

-------------------------------------------------------------------------------
-- Adds a filter option.
--
-- @param caption Text that will be displayed for the option.
-- @param filters Events that this option will control. e.g. {"RAID","RAID_LEADER"}
--
local function AddFilterOption( level, caption, filters, id )
	info = UIDropDownMenu_CreateInfo()
	info.text             = caption
	info.notCheckable     = false
	info.isNotRadio       = true
	info.checked          = g_register[id].checked( filters[1] )
	if g_register[id].onclick then
		info.func = function( self, a1, a2, checked )
			g_register[id].onclick( filters, checked )
		end
	end
	info.keepShownOnClick = true
	UIDropDownMenu_AddButton( info, level )
end

-------------------------------------------------------------------------------
-- Register a list of filters for something.
--
-- @param items   Items that we should add, table of "Public", "Party" etc
-- @param checked Callback function to see if an entry is checked. The only
--                argument passed is the first filter item.
-- @param oncheck Callback for when an item is clicked. function( filters, checked )
--
function Main.RegisterFilterMenu( name, items, checked, onclick )
	g_register[name] = {
		items = items;
		checked = checked;
		onclick = onclick;
	}
end

-------------------------------------------------------------------------------
local function GetHexCode( color )
	return string.format( "ff%2x%2x%2x", color[1]*255, color[2]*255, color[3]*255 )
end

local ENTRY_CHAT_REMAP = { ROLL = "SYSTEM", OFFLINE = "SYSTEM", ONLINE = "SYSTEM" }
function GetColorCode( event )
	local info
	if event:sub(1,1) == "#" then
		local index = GetChannelName( event:sub(2) )
		info = ChatTypeInfo[ "CHANNEL" .. index ]
		if not info then info = ChatTypeInfo.CHANNEL end
	else
		local t = ENTRY_CHAT_REMAP[event] or event
		info = ChatTypeInfo[t]
		if not info then return "" end
	end
	return "|c" .. GetHexCode( {info.r, info.g, info.b} )
end

-------------------------------------------------------------------------------
-- Populate a menu with filter settings.
-- Ideally this is called from a menu initializer. If menuList has the string
-- "FILTERS" in it, then you pass it to this function to be handled accordingly.
--
-- This function may also create FITLERS submenus.
--
function Main.PopulateFilterMenu( level, menuList )

	local id = menuList:match( "FILTERS_([^_]+)" )
	if not id then return end
	
	local submenu = menuList:match( "FILTERS_[^_]+_(%S+)" )

	if not submenu then
		for _,item in ipairs( g_register[id].items ) do
			if item == "Channel" then
				
				-- Create Channels submenu
				info = UIDropDownMenu_CreateInfo()
				info.text             = L["Channels"]
				info.notCheckable     = true
				info.hasArrow         = true
				info.keepShownOnClick = true
				info.menuList         = "FILTERS_" .. id .. "_CHANNELS"
				UIDropDownMenu_AddButton( info, level )
				
			elseif item == "Misc" then
				
				-- Create Misc submenu
				info = UIDropDownMenu_CreateInfo()
				info.text             = L["Misc"]
				info.notCheckable     = true
				info.hasArrow         = true
				info.keepShownOnClick = true
				info.menuList         = "FILTERS_" .. id .. "_MISC"
				UIDropDownMenu_AddButton( info, level )
				
			elseif FILTER_OPTIONS[item] then
				
				-- Otherwise just a simple call for this option.
				AddFilterOption( level, GetColorCode( FILTER_OPTIONS[item][1] ) .. L[item], 
				                 FILTER_OPTIONS[item], id )
			end
		end
	elseif submenu == "CHANNELS" then
	
		-- Add all channels, except for ones that are ignored.
		
		local channels = { GetChannelList() }
		for i = 1, #channels, 2 do
			local index = channels[i]
			local name = channels[i+1]
			name = name:lower()
			if not IGNORED_CHANNELS[name] then
				local event = "#" .. name:upper()
				AddFilterOption( level, GetColorCode( event ) .. "#" .. name, { event }, id )
			end
		end
	elseif submenu == "MISC" then
		
		-- Misc. filters
		AddFilterOption( level, GetColorCode( "CHANNEL" ) .. L["Joined/Left"], { "CHANNEL_JOIN", "CHANNEL_LEAVE" }, id )
		AddFilterOption( level, GetColorCode( "SYSTEM" ) .. L["Online/Offline"], { "ONLINE", "OFFLINE" }, id )
		AddFilterOption( level, GetColorCode( "GUILD_ACHIEVEMENT" ) .. L["Guild Announce"], { "GUILD_ACHIEVEMENT", "GUILD_ITEM_LOOTED" }, id )
		AddFilterOption( level, GetColorCode( "GUILD" ) .. L["Guild MOTD"], { "GUILD_MOTD" }, id )
	end
	
	-- todo: automatically clean up channels that the player has left
end
