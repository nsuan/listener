local Main   = ListenerAddon
local L      = Main.Locale
local Me     = Main.Frame
local Method = Me.methods

Me.menu        = nil
Me.menu_parent = nil

-------------------------------------------------------------------------------
local function SplitOptions()
	if Me.menu_parent.frame_index == 1 then return Main.db.profile.frame end
	return Main.db.char.frames[Me.menu_parent.frame_index]
end

-------------------------------------------------------------------------------
local function InclusionClicked( self, arg1, arg2, checked )
	Me.menu_parent:SetListenAll( checked )
end

-------------------------------------------------------------------------------
local function SoundClicked( self, arg1, arg2, checked )
	local index = Me.menu_parent.frame_index
	Main.db.char.frames[index].sound = checked
end

-------------------------------------------------------------------------------
local function AutoPopupClicked( self, arg1, arg2, checked )
	if Me.menu_parent.frame_index == 1 then
		Main.db.profile.frame.auto_popup = checked
	else
		Main.db.char.frames[Me.menu_parent.frame_index].auto_popup = checked
	end
end

-------------------------------------------------------------------------------
local function LockClicked( self, arg1, arg2, checked )
	SplitOptions().locked = checked
end

-------------------------------------------------------------------------------
local g_delete_frame_index
StaticPopupDialogs["LISTENER_DELETE_WINDOW"] = {
	text         = L["Are you sure you wanna do that?"];
	button1      = L["Yeah"];
	button2      = L["No..."];
	hideOnEscape = true;
	whileDead    = true;
	timeout      = 0;
	OnAccept = function( self )
	
		if Main.frames[g_delete_frame_index] then
			Main.DestroyWindow( Main.frames[g_delete_frame_index] )
		end
	end;
}

-------------------------------------------------------------------------------
local g_rename_frame_index = nil
StaticPopupDialogs["LISTENER_RENAMEFRAME"] = {
	text         = L["Enter new name."];
	button1      = L["Save"];
	button2      = L["Nevermind..."];
	hasEditBox   = true;
	hideOnEscape = true;
	whileDead    = true;
	timeout      = 0;
	OnShow = function( self )
		self.editBox:SetText( Main.db.char.frames[g_rename_frame_index].name )
	end;
	OnAccept = function( self )
		local name = self.editBox:GetText()
		if name == "" then return end
		
		local o = Main.db.char.frames[g_rename_frame_index]
		if o then
			o.name = name
		end
	end;
}

-------------------------------------------------------------------------------
local function RenameClicked( self )
	g_rename_frame_index = Me.menu_parent.frame_index
	StaticPopup_Show("LISTENER_RENAMEFRAME")
end

-------------------------------------------------------------------------------
-- Iterates through unit IDs of your party or raid, excluding the player
--
-- Note that the iterator is not valid across frames.
--
local function IteratePlayers()
	local raidparty = IsInRaid() and "raid" or "party"
	local index     = -1
	
	return function()
		
		while true do
			index = index + 1
			if index == 0 then
				return Main:FullName( 'player' )
			end
			
			local unit = raidparty .. index
			if not UnitExists( unit ) then
				return nil
			end
			
			if not UnitIsUnit( unit, "player" ) then
				return Main:FullName( unit )
			end
		end
	end
end

local g_player_list = {}

-------------------------------------------------------------------------------
local function CreatePlayerList()
	local players = {}
	for p in IteratePlayers() do
		local icname = Main.GetICName( p )
		table.insert( players, {
			name   = p;
			icname = icname;
		})
	end
	
	-- sort alphabetically
	table.sort( players, function( a, b )
		return a.icname:lower() < b.icname:lower()
	end)
	
	-- split into groups of 10
	g_player_list = {}
	local list = {}
	local count = 0
	for i = 1, #players do
		table.insert( list, players[i] )
		count = count + 1
		if count >= 10 then
			table.insert( g_player_list, list )
			list = {}
			count = 0
		end
		
	end
	table.insert( g_player_list, list )
end

-------------------------------------------------------------------------------
local function PlayerMenuName( player )
	local f = Me.menu_parent.players[player.name]
	local text = player.icname
	if player.icname ~= player.name then
		text = text .. " (" .. player.name .. ")"
	end
	if f == 1 then return "|cFF1cff62" .. text end
	if f == 0 then return "|cFFff1c1c" .. text end
	return "|cFFD4D4D4" .. text
end

-------------------------------------------------------------------------------
local function PlayerMenuClicked( self, player, arg2, checked )
	local f = Me.menu_parent.players[player.name]
	local listenall = Main.db.char.frames[Me.menu_parent.frame_index].listen_all
	
	-- filter is a tristate: include,exclude,or default (listenall)
	-- change order w/ listenall: n -> 0 -> 1
	-- change order    otherwise: n -> 1 -> 0
	if not f then
		f = listenall and 0 or 1
	elseif f == 1 then
		if listenall then f = nil else f = 0 end
	elseif f == 0 then
		if listenall then f = 1 else f = nil end
	end
	Me.menu_parent.players[player.name] = f
	self:SetText( PlayerMenuName( player ) )
	Me.menu_parent:RefreshChat()
	Me.menu_parent:UpdateProbe()
end

-------------------------------------------------------------------------------
local function PopulatePlayersSubmenu( level, menuList )
	local index = tonumber(menuList:sub( 8 ))
	local list = g_player_list[index]
	
	for key, player in ipairs( list ) do
		info = UIDropDownMenu_CreateInfo()
		info.arg1             = player
		info.text             = PlayerMenuName( player )
		info.func             = PlayerMenuClicked
		info.notCheckable     = true
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton( info, level )
	end
end

-------------------------------------------------------------------------------
local function PopulatePlayersMenu( level )
	if #g_player_list == 1 then
		-- if there's just one list (of max 10) then 
		-- we populate that menu here directly.
		PopulatePlayersSubmenu( level, "PLAYERS1" )
	else
		for key, list in ipairs( g_player_list ) do
		
			-- take first letter of first and last entries
			-- e.g. "A..F"
			local letter1, letter2 = list[1].icname:match( "^[%z\1-\127\194-\244][\128-\191]*" ):upper(),
			                         list[#list].icname:match( "^[%z\1-\127\194-\244][\128-\191]*" ):upper()
			local name
			if letter1 == letter2 then
				name = letter1
			else
				name = letter1 .. ".." .. letter2
			end
			
			info = UIDropDownMenu_CreateInfo()
			info.text             = name
			info.notCheckable     = true
			info.hasArrow         = true
			info.menuList         = "PLAYERS" .. key
			info.keepShownOnClick = true
			UIDropDownMenu_AddButton( info, level )
		end
	end
end

-------------------------------------------------------------------------------
local function GroupMenuName( group )
	local f = Me.menu_parent.groups[group]
	local text = L( "Group {1}", group )
	if f == 1 then return "|cFF1cff62" .. text end
	if f == 0 then return "|cFFff1c1c" .. text end
	return "|cFFD4D4D4" .. text
end

-------------------------------------------------------------------------------
local function RaidGroupClicked( self, group )
	local f = Me.menu_parent.groups[group]
	local listenall = Main.db.char.frames[Me.menu_parent.frame_index].listen_all
	
	if not f then
		f = listenall and 0 or 1
	elseif f == 1 then
		if listenall then f = nil else f = 0 end
	elseif f == 0 then
		if listenall then f = 1 else f = nil end
	end
	
	Me.menu_parent.groups[group] = f
	self:SetText( GroupMenuName( group ) )
	Me.menu_parent:RefreshChat()
	Me.menu_parent:UpdateProbe()
end

-------------------------------------------------------------------------------
local function PopulateRaidGroupsMenu( level )
	for i = 1, 8 do
		info = UIDropDownMenu_CreateInfo()
		info.text             = GroupMenuName( i )
		info.arg1             = i
		info.notCheckable     = true
		info.func             = RaidGroupClicked
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton( info, level )
	end
end

-------------------------------------------------------------------------------
local function InitializeMenu( self, level, menuList )
	local info
	if level == 1 then
	
		if Me.menu_parent.frame_index ~= 1 then
			
			info = UIDropDownMenu_CreateInfo()
			info.text             = "|cFFECCD35" .. Main.db.char.frames[Me.menu_parent.frame_index].name
			info.notCheckable     = true
			info.tooltipTitle     = Main.db.char.frames[Me.menu_parent.frame_index].name
			info.tooltipText      = L["Click to rename this window."]
			info.tooltipOnButton  = true
			info.func             = RenameClicked
			UIDropDownMenu_AddButton( info, level )
		end
	
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Inclusion"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = Main.db.char.frames[Me.menu_parent.frame_index].listen_all
		info.func             = InclusionClicked
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Inclusion mode."]
		info.tooltipText      = L["Default to include players rather than exclude them."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Notify"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = Main.db.char.frames[Me.menu_parent.frame_index].sound
		info.func             = SoundClicked
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Enable notifications."]
		info.tooltipText      = L["Play a sound when receiving new messages."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Auto-Popup"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = SplitOptions().auto_popup
		info.func             = AutoPopupClicked
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Auto-Popup."]
		info.tooltipText      = L["Reopen window automatically upon receiving new messages."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Lock"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = SplitOptions().locked
		info.func             = LockClicked
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Lock Window."]
		info.tooltipText      = L["Disables dragging via the menu bar."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		Main.SetupFilterMenu(
			{ "Public", "Party", "Raid", "Whisper", "Instance", "Guild", "Officer", "Rolls", "Channel", "Misc" }, 
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
			
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Filter"]
		info.notCheckable     = true
		info.hasArrow         = true
		info.menuList         = "FILTERS"
		info.tooltipTitle     = L["Display filter."]
		info.tooltipText      = L["Selects which chat types to display."]
		info.tooltipOnButton  = true
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton( info, level )
		
		if IsInGroup( LE_PARTY_CATEGORY_HOME ) then
			CreatePlayerList()
			info = UIDropDownMenu_CreateInfo()
			info.text             = L["Players"]
			info.notCheckable     = true
			info.hasArrow         = true
			info.menuList         = "PLAYERS"
			info.tooltipTitle     = L["Player filter."]
			info.tooltipText      = L["Adjusts filter for players in your group."]
			info.tooltipOnButton  = true
			info.keepShownOnClick = true
			UIDropDownMenu_AddButton( info, level )
			
			if IsInRaid() then
				
				info = UIDropDownMenu_CreateInfo()
				info.text             = L["Raid Groups"]
				info.notCheckable     = true
				info.hasArrow         = true
				info.menuList         = "RAID"
				info.tooltipTitle     = L["Raid group filters."]
				info.tooltipText      = L["Adjusts filter for groups in your raid."]
				info.tooltipOnButton  = true
				info.keepShownOnClick = true
				UIDropDownMenu_AddButton( info, level )
			end
		end
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Settings"]
		info.notCheckable     = true
		info.func             = function()
			Me.menu_parent:OpenConfig()
		end
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["New Window"]
		info.notCheckable     = true
		info.tooltipTitle     = L["New window."]
		info.tooltipText      = L["Creates a new Listener window."]
		info.tooltipOnButton  = true
		info.func             = function()
			Main.UserCreateWindow()
		end
		UIDropDownMenu_AddButton( info, level )
		
		if Me.menu_parent.frame_index ~= 1 then
			info = UIDropDownMenu_CreateInfo()
			info.text             = L["Delete Window"]
			info.notCheckable     = true
			info.tooltipTitle     = L["Delete window."]
			info.tooltipText      = L["Closes and deletes this menu."]
			info.tooltipOnButton  = true
			info.func             = function()
				g_delete_frame_index = Me.menu_parent.frame_index
				StaticPopup_Show("LISTENER_DELETE_WINDOW")
			end
			UIDropDownMenu_AddButton( info, level )
		end
	
	elseif menuList and menuList:find( "FILTERS" ) then
		
		Main.PopulateFilterSubMenu( level, menuList )
		
	elseif menuList == "PLAYERS" then
		PopulatePlayersMenu( level )
	elseif menuList == "RAID" then
		PopulateRaidGroupsMenu( level )
	elseif menuList and menuList:sub( 1,7 ) == "PLAYERS" then
		PopulatePlayersSubmenu( level, menuList )
	
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
