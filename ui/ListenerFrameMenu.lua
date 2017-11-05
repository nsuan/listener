local Main   = ListenerAddon
local Me     = Main.Frame
local Method = Me.methods

Me.menu        = nil
Me.menu_parent = nil

local function InclusionClicked( self, arg1, arg2, checked )
	Me.menu_parent:SetListenAll( checked )
end

local function InitializeMenu( self, level, menuList )
	local info
	if level == 1 then
		info = UIDropDownMenu_CreateInfo()
		info.text             = "Inclusion"
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = Main.db.char.listen_all
		info.func             = FrameMenu_Include
		info.keepShownOnClick = true
		info.tooltipTitle     = "Inclusion mode."
		info.tooltipText      = "Default to include players rather than exclude them."
		info.tooltipOnButton = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = "Filter"
		info.notCheckable     = true
		info.hasArrow         = true
		info.menuList         = "SHOW"
		info.tooltipTitle     = "Display filter."
		info.tooltipText      = "Selects which chat types to display."
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton( info, level )
	end
end

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
	ToggleDropDownMenu( 1, nil, Main.frame_menu, "UIParent", x / scale, y / scale )
end
