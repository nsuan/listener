-- this is a simple module for creating a filter menu
-- to be shared by frames and the snooper module

local Main = ListenerAddon
local L    = Main.Locale

local g_callback_checked -- returns true if an option item is checked
local g_callback_onclick -- 
local g_items = {}

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

local FILTER_OPTIONS = {
	Public   = { "SAY", "EMOTE", "TEXT_EMOTE", "YELL" };
	Party    = { "PARTY", "PARTY_LEADER" };
	Raid     = { "RAID", "RAID_LEADER", "RAID_WARNING" };
	Instance = { "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" };
	Guild    = { "GUILD" };
	Officer  = { "OFFICER" };
	Whisper  = { "WHISPER", "WHISPER_INFORM" };
	Rolls    = { "ROLL" };
	Channel  = "Channels"; -- Treated specially.
	Misc     = "Misc"; -- treated specially.
}

-------------------------------------------------------------------------------
-- Add an option to the SHOW menu.
--
-- @param caption Text that will be displayed for the option.
-- @param filters Events that this option will control. e.g. {"RAID","RAID_LEADER"}
--
local function AddFilterOption( level, caption, filters, checked, onclick )
	info = UIDropDownMenu_CreateInfo()
	info.text             = caption
	info.notCheckable     = false
	info.isNotRadio       = true
	info.checked          = g_callback_checked( filters[1] )
	if g_callback_onclick then
		info.func = function( self, a1, a2, checked )
			g_callback_onclick( filters, checked )
		end
	end
	info.keepShownOnClick = true
	UIDropDownMenu_AddButton( info, level )
end

-------------------------------------------------------------------------------
-- @param items Items that we should add, table of "Public", "Party" etc
-- @param checked Callback function to see if an entry is checked. The only
--                argument passed is the first filter item.
-- @param oncheck Callback for when an item is clicked. function( filters, checked )
--
function Main.SetupFilterMenu( items, checked, onclick )
	g_items = items
	g_callback_checked = checked
	g_callback_onclick = onclick
end

-------------------------------------------------------------------------------
function Main.PopulateFilterSubMenu( level, menuList )

	if menuList == "FILTERS" then
		for _,item in ipairs( g_items ) do
			if item == "Channel" then
				
				info = UIDropDownMenu_CreateInfo()
				info.text             = L["Channels"]
				info.notCheckable     = true
				info.hasArrow         = true
				info.keepShownOnClick = true
				info.menuList         = "FILTERS_CHANNELS"
				UIDropDownMenu_AddButton( info, level )
				
			elseif item == "Misc" then
				
				info = UIDropDownMenu_CreateInfo()
				info.text             = L["Misc"]
				info.notCheckable     = true
				info.hasArrow         = true
				info.keepShownOnClick = true
				info.menuList         = "FILTERS_MISC"
				UIDropDownMenu_AddButton( info, level )
				
			elseif FILTER_OPTIONS[item] then
				AddFilterOption( level, L[item], FILTER_OPTIONS[item], checked, onclick )
			end
		end
	elseif menuList == "FILTERS_CHANNELS" then
		-- add all channels
		local channels = { GetChannelList() }
		for i = 1, #channels, 2 do
			local index = channels[i]
			local name = channels[i+1]
			name = name:lower()
			if not IGNORED_CHANNELS[name] then
				local event = "#" .. name:upper()
				AddFilterOption( level, "#" .. name, { event }, checked, onclick )
			end
		end
	elseif menuList == "FILTERS_MISC" then
		AddFilterOption( level, L["Joined/Left"], { "CHANNEL_JOIN", "CHANNEL_LEAVE" }, checked, onclick )
		AddFilterOption( level, L["Online/Offline"], { "ONLINE", "OFFLINE" }, checked, onclick )
		AddFilterOption( level, L["Guild Announce"], { "GUILD_ACHIEVEMENT" }, checked, onclick )
		AddFilterOption( level, L["Guild MOTD"], { "GUILD_ACHIEVEMENT" }, checked, onclick )
		
	end
	
	
	-- todo: automatically clean up channels that the player has left
end
