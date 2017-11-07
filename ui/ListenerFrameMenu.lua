local Main   = ListenerAddon
local L      = Main.Locale
local Me     = Main.Frame
local Method = Me.methods

Me.menu        = nil
Me.menu_parent = nil


-------------------------------------------------------------------------------
local function InclusionClicked( self, arg1, arg2, checked )
	Me.menu_parent:SetListenAll( checked )
end

-------------------------------------------------------------------------------
local function SoundClicked( self, arg1, arg2, checked )
	local index = Me.menu_parent.frame_index
	Main.db.char.frames[index].sound = checked
end

local g_delete_frame_index
StaticPopupDialogs["LISTENER_DELETE_WINDOW"] = {
	text    = L["Are you sure you wanna do that?"];
	button1 = L["Yeah"];
	button2 = L["No..."];
	OnAccept = function( self )
	
		if Main.frames[g_delete_frame_index] then
			Main.DestroyWindow( Main.frames[g_delete_frame_index] )
		end
	end;
}

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
		
		info = UIDropDownMenu_CreateInfo()
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
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = "Settings"
		info.notCheckable     = true
		info.func             = function()
			Me.menu_parent:OpenConfig()
		end
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = "New Window"
		info.notCheckable     = true
		info.tooltipTitle     = "New window."
		info.tooltipText      = "Creates a new Listener window."
		info.func             = function()
			Main.UserCreateWindow()
		end
		UIDropDownMenu_AddButton( info, level )
		
		if Me.menu_parent.frame_index ~= 1 then
			info = UIDropDownMenu_CreateInfo()
			info.text             = "Delete Window"
			info.notCheckable     = true
			info.tooltipTitle     = "Delete window."
			info.tooltipText      = "Closes and deletes this menu."
			info.func             = function()
				g_delete_frame_index = Me.menu_parent.frame_index
				StaticPopup_Show("LISTENER_DELETE_WINDOW")
			end
			UIDropDownMenu_AddButton( info, level )
		end
	
	elseif menuList == "SHOW" then
		
		Main.PopulateFilterMenu( level, 
			{ "Public", "Party", "Raid", "Instance", "Guild", "Officer", "Channel" }, 
			function( filter )
				return Me.menu_parent:HasEvent( filter )
			end,
			function( filters, checked )
				if checked then
					Me.menu_parent:AddEvents( unpack( filters ))
				else
					Me.menu_parent:RemoveEvents( unpack( filters ))
				end
			end)
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
