-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2016)
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L = Main.Locale

Main.MinimapButton = {}

local LDB    = LibStub:GetLibrary( "LibDataBroker-1.1" )
local DBIcon = LibStub:GetLibrary( "LibDBIcon-1.0"     )

-------------------------------------------------------------------------------
Main.AddSetup( function()
	local self = Main.MinimapButton
	
	self.data = LDB:NewDataObject( "Listener", {
		type = "data source";
		text = "Listener";
		icon = "Interface\\Icons\\SPELL_HOLY_SILENCE";
		OnClick = function(...) Main.MinimapButton:OnClick(...) end;
		OnEnter = function(...) Main.MinimapButton:OnEnter(...) end;
		OnLeave = function(...) Main.MinimapButton:OnLeave(...) end;
	})
end)

-------------------------------------------------------------------------------
function Main.MinimapButton:OnLoad() 
	DBIcon:Register( "Listener", self.data, Main.db.profile.minimapicon )
end

-------------------------------------------------------------------------------
function Main.MinimapButton:Show( show )
	if show then
		DBIcon:Show( "Listener" )
		Main.db.profile.minimapicon.hide = false
	else
		DBIcon:Hide( "Listener" )
		Main.db.profile.minimapicon.hide = true
	end
end

-------------------------------------------------------------------------------
function Main.MinimapButton:OnClick( frame, button )
	if button == "LeftButton" then
		Main:ToggleFrame()
	elseif button == "RightButton" then
		Main:OpenConfig()
		
	end
end
 
-------------------------------------------------------------------------------
local function InitializeMenu( self, level )
	local info
	
	local function AddMenuButton( text, func )
		info = UIDropDownMenu_CreateInfo()
		info.text = text
		info.func = func
		info.notCheckable = true
		UIDropDownMenu_AddButton( info, level )
	end
	
	local function AddSeparator()
		info = UIDropDownMenu_CreateInfo()
		info.notClickable = true
		info.disabled = true
		UIDropDownMenu_AddButton( info, level )
	end

	info = UIDropDownMenu_CreateInfo()
	info.text    = "Listener"
	info.isTitle = true
	info.notCheckable = true
	UIDropDownMenu_AddButton( info, level )

	AddMenuButton( L["Test"], function() end )
	
	AddSeparator()
	
	AddSeparator()
	
	AddMenuButton( L["Close"], function() end )
end

-------------------------------------------------------------------------------
function Main.MinimapButton:ShowMenu()
	if not self.menu then
		self.menu = CreateFrame( "Button", "ListenerMinimapMenu", UIParent, "UIDropDownMenuTemplate" )
		self.menu.displayMode = "MENU"
	end
	 
	UIDropDownMenu_Initialize( ListenerMinimapMenu, InitializeMenu )
	UIDropDownMenu_SetWidth( ListenerMinimapMenu, 100 )
	UIDropDownMenu_SetButtonWidth( ListenerMinimapMenu, 124 ) 
	UIDropDownMenu_JustifyText( ListenerMinimapMenu, "LEFT" )
	
	local x,y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	ToggleDropDownMenu( 1, nil, self.menu, "UIParent", x / scale, y / scale )
end

-------------------------------------------------------------------------------
function Main.MinimapButton:OnEnter( frame ) 
	-- Section the screen into 6 sextants and define the tooltip 
	-- anchor position based on which sextant the cursor is in.
	-- Code taken from WeakAuras.
	--
    local max_x = 768 * GetMonitorAspectRatio()
    local max_y = 768
    local x, y = GetCursorPosition()
	
    local horizontal = (x < (max_x/3) and "LEFT") or ((x >= (max_x/3) and x < ((max_x/3)*2)) and "") or "RIGHT"
    local tooltip_vertical = (y < (max_y/2) and "BOTTOM") or "TOP"
    local anchor_vertical = (y < (max_y/2) and "TOP") or "BOTTOM"
    GameTooltip:SetOwner( frame, "ANCHOR_NONE" )
    GameTooltip:SetPoint( tooltip_vertical..horizontal, frame, anchor_vertical..horizontal )
	
	GameTooltip:ClearLines()
	GameTooltip:AddDoubleLine("Listener", Main.version, 0, 0.7, 1, 1, 1, 1)
	GameTooltip:AddLine( " " )
	GameTooltip:AddLine( L["|cff00ff00Left-click|r to toggle window."], 1, 1, 1 )
	GameTooltip:AddLine( L["|cff00ff00Right-click|r to open configuration."], 1, 1, 1 )
	GameTooltip:Show()
end

-------------------------------------------------------------------------------
function Main.MinimapButton:OnLeave( frame ) 
	GameTooltip:Hide()
end
