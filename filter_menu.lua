-- this is a simple module for creating a filter menu
-- to be shared by frames and the snooper module

local Main = ListenerAddon
local L    = Main.Locale

-------------------------------------------------------------------------------
-- Chat channel names that are ignored.
--
local IGNORED_CHANNELS = {
	xtensionxtooltip2 = true -- Common addon channel.
}

local FILTER_OPTIONS = {
	Public = { "SAY", "EMOTE", "TEXT_EMOTE", "YELL" };
	Party  = { "PARTY", "PARTY_LEADER" };
	Raid   = { "RAID", "RAID_LEADER", "RAID_WARNING" };
	Instance = { "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" };
	Guild    = { "GUILD" };
	Officer  = { "OFFICER" };
	Whisper  = { "WHISPER" };
	Rolls    = { "ROLL" };
	Channel  = "Channels"; -- Treated specially.
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
	info.checked          = checked( filters[1] )
	info.func             = function( self, a1, a2, checked )
		if onclick then onclick( filters, checked ) end
	end
	info.keepShownOnClick = true
	UIDropDownMenu_AddButton( info, level )
end

-------------------------------------------------------------------------------
-- @param level Level of the menu we're adding to.
-- @param items Items that we should add, table of "Public", "Party" etc
-- @param checked Callback function to see if an entry is checked. The only
--                argument passed is the first filter item.
-- @param oncheck Callback for when an item is clicked. function( filters, checked )
--
local function PopulateFilterMenu( level, items, checked, onclick )
	for _,item in ipairs( items ) do
		if item == "Channel" then
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
		elseif FILTER_OPTIONS[item] then
			AddFilterOption( level, L[item], FILTER_OPTIONS[item], checked, onclick )
		end
	end
	
	
	-- todo: automatically clean up channels that the player has left
end

Main.PopulateFilterMenu = PopulateFilterMenu
