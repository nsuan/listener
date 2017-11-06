local Main   = ListenerAddon
local Me     = Main.Frame
local Method = Me.methods

Me.menu        = nil
Me.menu_parent = nil

-------------------------------------------------------------------------------
-- Chat channel names that are ignored.
--
local IGNORED_CHANNELS = {
	xtensionxtooltip2 = true -- Common addon channel.
}

-------------------------------------------------------------------------------
local function InclusionClicked( self, arg1, arg2, checked )
	Me.menu_parent:SetListenAll( checked )
end

-------------------------------------------------------------------------------
local function SoundClicked( self, arg1, arg2, checked )
	local index = Me.menu_parent.frame_index
	Main.db.char.frames[index].sound = checked
end

local function FlashClicked( self, arg1, arg2, checked )
	local index = Me.menu_parent.frame_index
	Main.db.char.frames[index].flash = checked
end

-------------------------------------------------------------------------------
-- Add an option to the SHOW menu.
--
-- @param caption Text that will be displayed for the option.
-- @param filters Events that this option will control. e.g. {"RAID","RAID_LEADER"}
--
local function AddFilterOption( level, caption, filters )
	info = UIDropDownMenu_CreateInfo()
	info.text             = caption
	info.notCheckable     = false
	info.isNotRadio       = true
	info.checked          = Me.menu_parent:HasEvent( filters[1] )
	info.func             = function( self, a1, a2, checked )
		if checked then
			Me.menu_parent:AddEvents( unpack( filters ) )
		else
			Me.menu_parent:RemoveEvents( unpack( filters ) )
		end
	end
	
	info.keepShownOnClick = true
	UIDropDownMenu_AddButton( info, level )
end

-------------------------------------------------------------------------------
local function PopulateFilterMenu( level )
	AddFilterOption( level, "Public", { "SAY", "EMOTE", "TEXT_EMOTE", "YELL" } )
	AddFilterOption( level, "Party", { "PARTY", "PARTY_LEADER" } )
	AddFilterOption( level, "Raid", { "RAID", "RAID_LEADER", "RAID_WARNING" } )
	AddFilterOption( level, "Instance", { "INSTANCE", "INSTANCE_LEADER" } )
	
	local channels = { GetChannelList() }
	for i = 1, #channels, 2 do
		local index = channels[i]
		local name = channels[i+1]
		name = name:lower()
		if not IGNORED_CHANNELS[name] then
			local event = "#" .. name:upper()
			AddFilterOption( level, "#" .. name, { event } )
		end
	end
	
	-- todo: automatically clean up channels that the player has left
end

-------------------------------------------------------------------------------
local function InitializeMenu( self, level, menuList )
	local info
	if level == 1 then
	
	--[[
		info = UIDropDownMenu_CreateInfo()
		info.text             = "New"
		info.notCheckable     = true
		info.isNotRadio       = true
		info.checked          = Main.db.char.frames[Me.menu_parent.frame_index].listen_all
		info.func             = InclusionClicked
		info.keepShownOnClick = true
		info.tooltipTitle     = "New window."
		info.tooltipText      = "Create a new Listener window."
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
	]]
		info = UIDropDownMenu_CreateInfo()
		info.text             = "Inclusion"
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = Main.db.char.frames[Me.menu_parent.frame_index].listen_all
		info.func             = InclusionClicked
		info.keepShownOnClick = true
		info.tooltipTitle     = "Inclusion mode."
		info.tooltipText      = "Default to include players rather than exclude them."
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info.text             = "Notify"
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = Main.db.char.frames[Me.menu_parent.frame_index].sound
		info.func             = SoundClicked
		info.keepShownOnClick = true
		info.tooltipTitle     = "Enable notifications."
		info.tooltipText      = "Play a sound when receiving new messages."
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = "Filter"
		info.notCheckable     = true
		info.hasArrow         = true
		info.menuList         = "SHOW"
		info.tooltipTitle     = "Display filter."
		info.tooltipText      = "Selects which chat types to display."
		info.tooltipOnButton  = true
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton( info, level )
	elseif menuList == "SHOW" then
		PopulateFilterMenu( level )
	end
end

-------------------------------------------------------------------------------
function Method:ShowMenu()
	if not Me.menu then
		Me.menu = CreateFrame( "Button", "ListenerFrameMenu", UIParent, "UIDropDownMenuTemplate" )
		Me.menu.displayMode = "MENU"
	end
	
	Me.menu_parent = self
	
	UIDropDownMenu_Initialize( ListenerFrameMenu, InitializeMenu )
	UIDropDownMenu_JustifyText( ListenerFrameMenu, "LEFT" )
	
	local x,y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	ToggleDropDownMenu( 1, nil, Me.menu, "UIParent", x / scale, y / scale )
end
