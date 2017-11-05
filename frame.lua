
-- todo: functions to apply settings to all frames
-- for font
-- timestamps

-------------------------------------------------------------------------------
-- FRAME SCRIPTS
-------------------------------------------------------------------------------

 
-------------------------------------------------------------------------------
-- Tooltip for filter (green) button
--[[
local function Tooltip_Toggle( self )
	GameTooltip:AddLine( L["Filter"] )
	
	local r1,g1,b1 = 1,1,1
	local r2,g2,b2 = 0,1,0
	
	local target = UnitName("target")
	if target and UnitIsPlayer('target') and target ~= UnitName("player") then
		name = Main:GetICName( target, UnitGUID("target") )
		if target == UnitName("player") or Main.player_list[target] == 1 or (Main.player_list[target] ~= 0 and Main.db.char.listen_all) then
			r2, g2, b2 = 0,1,0
		else
			r2, g2, b2 = 1,0,0
		end
		
		GameTooltip:AddDoubleLine( L["Target"], name, 1,1,1, r2,g2,b2 )
		GameTooltip:AddLine( L["Click to toggle filter."] )
		GameTooltip:AddLine( " " )
	end
	
	if Main.db.char.listen_all then
		GameTooltip:AddDoubleLine( L["Default Filter"], L["Include"], 1,1,1, 0,1,0 )
	else
		GameTooltip:AddDoubleLine( L["Default Filter"], L["Exclude"], 1,1,1, 1,0,0 )
	end
	GameTooltip:AddLine( L["Shift-click to change."] )
	GameTooltip:AddLine( " " )
	
	if Main.db.char.showhidden then
		GameTooltip:AddDoubleLine( L["Show Hidden"], L["Yes"], 1, 1, 1, 0, 1, 0 )
	else
		GameTooltip:AddDoubleLine( L["Show Hidden"], L["No"], 1, 1, 1, 1, 0, 0 )
	end
	GameTooltip:AddLine( L["Right-click to toggle showing hidden players as faded text."], nil, nil, nil, true )
end]]

-------------------------------------------------------------------------------
-- Tooltip for public chat (white) button.
--[[
local function Tooltip_ShowSay( self )
	if Me.showsay then
		GameTooltip:AddDoubleLine( L["Public Chat"], L["Shown"], 1,1,1, 1,1,1 )
		GameTooltip:AddLine( L["Click to hide public emotes."] )
	else
		GameTooltip:AddDoubleLine( L["Public Chat"], L["Hidden"], 1,1,1, 0.75,0.75,0.75 )
		GameTooltip:AddLine( L["Click to show public emotes."] )
	end
end]]

-------------------------------------------------------------------------------
-- Tooltip for group chat (blue) button.
--[[
local function Tooltip_ShowParty( self )
	if Me.showparty then
		GameTooltip:AddDoubleLine( L["Group Chat"], L["Shown"], 1,1,1, 1,1,1 )
		GameTooltip:AddLine( L["Click to hide group/party chat."] )
	else
		GameTooltip:AddDoubleLine( L["Group Chat"], L["Hidden"], 1,1,1, 0.75,0.75,0.75 )
		GameTooltip:AddLine( L["Click to show group/party chat."] )
	end
end]]


-------------------------------------------------------------------------------
-- Tooltip for unread messages button.
--
--[[
local function Tooltip_Read( self )
	if g_has_unread_entries then
		GameTooltip:AddLine( L["Unread Messages"], 1,1,1 )
		GameTooltip:AddLine( L["Click to mark all messages as read."] )
	else
		GameTooltip:AddLine( L["No Unread Messages"], 0.75, 0.75, 0.75 )
	end
end]]

--[[
local function FrameMenu_Include()
	Main:SetListenAll( not Main.db.char.listen_all )
end

local function InitializeFrameMenu( self, level, menuList )
	local info
	
	if level == 1 then
		info = UIDropDownMenu_CreateInfo()
		info.text             = "Inclusion"
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = Main.db.char.listen_all
		info.func             = FrameMenu_Include
		info.keepShownOnClick = true
		info.tooltipTitle     = "Inclusion Mode"
		info.tooltipText      = "Default to include players rather than exclude them."
		info.tooltipOnButton = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = "Filter"
		info.notCheckable     = true
		info.hasArrow         = true
		info.menuList         = "SHOW"
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton( info, level )
	elseif level == 2 then
		if menuList == "SHOW" then
			info = UIDropDownMenu_CreateInfo()
			info.text             = "Party"
			info.notCheckable     = false
			info.isNotRadio       = true
			info.checked          = Me.showparty
			info.func             = FrameMenu_Show_Party
			info.keepShownOnClick = true
			UIDropDownMenu_AddButton( info, level )
			
			info = UIDropDownMenu_CreateInfo()
			info.text             = "Raid"
			info.notCheckable     = false
			info.isNotRadio       = true
			info.checked          = Me.showraid
			info.func             = FrameMenu_Show_Raid
			info.keepShownOnClick = true
			UIDropDownMenu_AddButton( info, level )
			
			info = UIDropDownMenu_CreateInfo()
			info.text             = "Guild"
			info.notCheckable     = false
			info.isNotRadio       = true
			info.checked          = Me.showguild
			info.func             = FrameMenu_Show_Guild
			info.keepShownOnClick = true
			UIDropDownMenu_AddButton( info, level )
			
			info = UIDropDownMenu_CreateInfo()
			info.text             = "Officer"
			info.notCheckable     = false
			info.isNotRadio       = true
			info.checked          = Me.showofficer
			info.func             = FrameMenu_Show_Officer
			info.keepShownOnClick = true
			UIDropDownMenu_AddButton( info, level )
		end
	end
end]]
--[[
-------------------------------------------------------------------------------
Main.AddLoadCall( function() 
--	Main:SetupTooltip( ListenerFrameBarToggle, Tooltip_Toggle )
--	Main:SetupTooltip( ListenerFrameBarShowSay, Tooltip_ShowSay )
--	Main:SetupTooltip( ListenerFrameBarShowParty, Tooltip_ShowParty )
--	Main:SetupTooltip( ListenerFrameBarRead, Tooltip_Read )
	
--	Main:ProbePlayer()
--	ListenerFrameBarShowSay:SetOn( true )
--	ListenerFrameBarShowParty:SetOn( true )
--	ListenerFrameBarRead:SetOn( false )
	
end)
]]