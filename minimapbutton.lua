-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2016)
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L = Main.Locale

Main.MinimapButton = {}
local Me = Main.MinimapButton

local LDB    = LibStub:GetLibrary( "LibDataBroker-1.1" )
local DBIcon = LibStub:GetLibrary( "LibDBIcon-1.0"     )

-------------------------------------------------------------------------------
Main.AddSetup( function()
	
	Me.data = LDB:NewDataObject( "Listener", {
		type = "data source";
		text = "Listener";
		icon = "Interface\\Icons\\SPELL_HOLY_SILENCE";
		OnClick = Me.OnClick;
		OnEnter = Me.OnEnter;
		OnLeave = Me.OnLeave;
	})
end)

-------------------------------------------------------------------------------
function Me.OnLoad()
	DBIcon:Register( "Listener", Me.data, Main.db.profile.minimapicon )
end

-------------------------------------------------------------------------------
function Me.Show( show )
	if show then
		DBIcon:Show( "Listener" )
		Main.db.profile.minimapicon.hide = false
	else
		DBIcon:Hide( "Listener" )
		Main.db.profile.minimapicon.hide = true
	end
end

-------------------------------------------------------------------------------
function Me.OnClick( frame, button )
	if button == "LeftButton" then
	
		local wc = 0
		for _,_ in pairs( Main.frames ) do
			wc = wc + 1
		end
		
		if wc == 1 or IsShiftKeyDown() then
			Main.frames[1]:Toggle()
		else
			Me.ShowMenu( "FRAMES" )
		end
		
	elseif button == "RightButton" then
		Me.ShowMenu( "OPTIONS" )
	end
end

-------------------------------------------------------------------------------
local function FramesMenuAction_OpenAll()
	for _,f in pairs( Main.frames ) do
		f:Open()
	end
end

-------------------------------------------------------------------------------
local function FramesMenuAction_CloseAll()
	for _,f in pairs( Main.frames ) do
		f:Close()
	end
end

-------------------------------------------------------------------------------
local function InitializeFramesMenu( self, level, menuList )
	
	if level == 1 then
		local info
		info = UIDropDownMenu_CreateInfo()
		info.text    = "Windows"
		info.isTitle = true
		info.notCheckable = true
		UIDropDownMenu_AddButton( info, level )
		--[[
		info = UIDropDownMenu_CreateInfo()
		info.text = "Open All"
		info.func = FramesMenuAction_OpenAll
		info.notCheckable = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text = "Close All"
		info.func = FramesMenuAction_CloseAll
		info.notCheckable = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.notClickable = true
		info.disabled = true
		UIDropDownMenu_AddButton( info, level )
		]]
		local frames = {}
		
		-- populate with everything but first frame
		for _, f in pairs( Main.frames ) do
			if f ~= Main.frames[1] then
				table.insert( frames, f )
			end
		end
		
		table.sort( frames, function( a, b )
			local an, bn = Main.db.char.frames[a.frame_index].name or "", Main.db.char.frames[b.frame_index].name or ""
			return an < bn
		end)
		
		table.insert( frames, 1, Main.frames[1] )
		
		for _, f in ipairs( frames ) do
			local name = Main.db.char.frames[f.frame_index].name
			if f.frame_index == 1 then name = "Main" end
			
			info = UIDropDownMenu_CreateInfo()
			info.text = name
			info.func = function()
				f:Toggle()
			end
			info.notCheckable = false
			info.isNotRadio   = true
			info.checked = f:IsShown()
			info.keepShownOnClick = true
			UIDropDownMenu_AddButton( info, level )
		end
	end
end

-------------------------------------------------------------------------------
local function InitializeOptionsMenu( self, level, menuList )
	if level == 1 then
		local info
		info = UIDropDownMenu_CreateInfo()
		info.text         = "Listener"
		info.isTitle      = true
		info.notCheckable = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = "Snooper Filter"
		info.notCheckable     = true
		info.hasArrow         = true
		info.menuList         = "SNOOPER"
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text = "Open Configuraton"
		info.func = function()
			Main.OpenConfig()
		end
		info.notCheckable = true
		UIDropDownMenu_AddButton( info, level )
	elseif level == 2 and menuList == "SNOOPER" then
		Main.Snoop.PopulateFilterMenu( level )
	end
end

-------------------------------------------------------------------------------
function Me.ShowMenu( menu )
	if not Me.menu then
		Me.menu = CreateFrame( "Button", "ListenerMinimapMenu", UIParent, "UIDropDownMenuTemplate" )
		Me.menu.displayMode = "MENU"
	end
	
	local menus = {
		FRAMES  = InitializeFramesMenu;
		OPTIONS = InitializeOptionsMenu;
	}
	 
	UIDropDownMenu_Initialize( ListenerMinimapMenu, menus[menu] )
	UIDropDownMenu_JustifyText( ListenerMinimapMenu, "LEFT" )
	
	local x,y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	ToggleDropDownMenu( 1, nil, Me.menu, "UIParent", x / scale, y / scale )
end

-------------------------------------------------------------------------------
function Me.OnEnter( frame ) 
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
	
	local window_count = 0
	for _,_ in pairs( Main.frames ) do
		window_count = window_count + 1
	end
	
	if window_count == 1 then
		GameTooltip:AddLine( L["|cff00ff00Left-click|r to toggle window."], 1, 1, 1 )
	else
		GameTooltip:AddLine( L["|cff00ff00Left-click|r to toggle windows."], 1, 1, 1 )
	end
	
	GameTooltip:AddLine( L["|cff00ff00Right-click|r to open menu."], 1, 1, 1 )
	GameTooltip:Show()
end

-------------------------------------------------------------------------------
function Main.MinimapButton:OnLeave( frame ) 
	GameTooltip:Hide()
end
