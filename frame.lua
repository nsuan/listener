-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2016)
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L = Main.Locale
local SharedMedia = LibStub("LibSharedMedia-3.0")
 
-- ordered list of chat history entries that should appear in the frame
Main.chat_buffer = {}
local g_chat_buffer_size = 300
local g_old_time = 60*10 -- time until messages are old

local g_has_unread_entries = false
local g_top_unread_id      = nil
local g_mouseover_highlight 

-- when a new messages is added, this saves the time
-- if the user clicks on the frame at the moment a message is added, its ignore to prevent error
local g_clickblock = 0

-- for the probe function
local g_probe_target = nil -- the name of the unit we're currently probing
local g_probe_target_time = 0 -- the time of the last successful target found

local Me = {
	hl_texes = {};
	
	-- the current chatid
	chatid   = 0;
	showsay = true;
	showparty    = true;
}

Main.Frame = Me

local function MixCol( a, b )
	
	local c = {
		a[1] + b[1];
		a[2] + b[2];
		a[3] + b[3];
	}
	
	local m = math.max( c[1], c[2] )
	m = math.max( m, c[3] )
	if m > 1.0 then
		c[1] = c[1] / m
		c[2] = c[2] / m
		c[3] = c[3] / m
	end
	
	c[1] = math.max( c[1], 0 )
	c[2] = math.max( c[2], 0 )
	c[3] = math.max( c[3], 0 )
	
	return c
end
   
function Main:HasUnreadEntries()
	return g_has_unread_entries
end
 
function Main:SetClickBlock()
	g_clickblock = GetTime()
end

function Main:OnChatboxScroll( delta )
	
	local reps = IsShiftKeyDown() and 5 or 1
	if delta > 0 then
		if IsAltKeyDown() then
			ListenerFrameChat:ScrollToTop()
		elseif IsControlKeyDown() then
			-- todo: increase font size
			Main:SetFontSize( Main.db.profile.frame.font.size + 1 )
		else
			for i = 1,reps do ListenerFrameChat:ScrollUp() end
		end
	else
		if IsAltKeyDown() then
			ListenerFrameChat:ScrollToBottom()
		elseif IsControlKeyDown() then
			-- todo: decrease font size
			Main:SetFontSize( Main.db.profile.frame.font.size - 1 )
		else
			for i = 1,reps do ListenerFrameChat:ScrollDown() end
		end
	end
	
	--Main:UpdateHighlight() -- this is called when the chat refreshes
end

function Main:OnChatboxHyperlinkClick( link, text, button )
	if GetTime() - g_clickblock < 0.4 then
		-- block clicks when scroll changes
		return
	end	
	 
	if ( strsub(link, 1, 6) == "player" ) then
		local namelink, isGMLink;
		if ( strsub(link, 7, 8) == "GM" ) then
			namelink = strsub(link, 10);
			isGMLink = true;
		else
			namelink = strsub(link, 8);
		end
		
		local name, lineid, chatType, chatTarget = strsplit(":", namelink);
		
		if IsShiftKeyDown() and button == "RightButton" then
			Main:TogglePlayer( name )
			return
		end
	end
	
	SetItemRef( link, text, button, DEFAULT_CHAT_FRAME );

end

-------------------------------------------------------------------------------
function Main:FlagUnreadEntries()
	ListenerFrameBarRead:SetOn( true )
	ListenerFrameBarRead:RefreshTooltip()
	g_has_unread_entries = true
end

-------------------------------------------------------------------------------
function Main:UnflagUnreadEntries()
	ListenerFrameBarRead:SetOn( false )
	ListenerFrameBarRead:RefreshTooltip()
	g_has_unread_entries = false
end

-------------------------------------------------------------------------------
function Main:TogglePlayerClicked( button )

	if button == "LeftButton" then 
		if UnitExists( "target" ) then 
			if UnitIsPlayer( "target" ) and UnitIsFriend( "target", "player" ) then
				if UnitGUID("target") == UnitGUID( "player" ) then return end
				
				self:TogglePlayer( UnitName( "target" ), true )
			end
		end
	elseif button == "RightButton" then
		Main:ShowFrameMenu()
	end
end

-------------------------------------------------------------------------------
function Main:ProbePlayer( force )
	if force then g_probe_target = nil end
	
	local unit, unitname
	if UnitExists( "target" ) then 
		unit = "target"
	elseif UnitExists( "mouseover" ) then
		unit = "mouseover"
	end
	
	if unit and UnitGUID( unit ) == UnitGUID("player") then unit = nil end
	if not UnitIsPlayer( unit ) then unit = nil end
	if unit then unitname = UnitName( unit ) end

	if unitname then
		-- reset the timer if we have a valid unit
		g_probe_target_time = GetTime()
	end
	
	if not unitname then
		if GetTime() < g_probe_target_time + 1.5 then
			unitname = g_probe_target
		end
	end
	
	
	if g_probe_target == unitname then 
		return -- already a match
	end
	
	g_probe_target = unitname
	
	local on = false
	
	local title = "—"
	
	if unitname then
		
		on = self.player_list[unitname] == 1 or (Main.db.char.listen_all and self.player_list[unitname] ~= 0)
		local name, icon, color = self:GetICName( unitname, UnitGUID(unit) )
		title = " " .. name
		
	end
	
	ListenerFrame.bar2.title:SetText( title )
	
	if on then
		ListenerFrame.bar2.toggle_button:Show()
	else
		ListenerFrame.bar2.toggle_button:Hide()
	end
end

-------------------------------------------------------------------------------
function Main:HighlightMouseover( name )

	if Main.db.profile.highlight_mouseover then
	
		if g_mouseover_highlight == name then return end
		g_mouseover_highlight = name
		Main:UpdateHighlight()
		
	end
end

-------------------------------------------------------------------------------
-- This is for when the configuration panel disables highlighting.
--
function Main:ResetHighlightMouseover()
	g_mouseover_highlight = nil
	Main:UpdateHighlight()
end

-------------------------------------------------------------------------------
function Main:ToggleSay()
	Me.showsay = not Me.showsay
	ListenerFrameBarShowSay:SetOn( Me.showsay )
	ListenerFrameBarShowSay:RefreshTooltip()
	Main:RefreshChat()
	
	Main:Snoop_DoUpdate()
end

-------------------------------------------------------------------------------
function Main:ToggleParty()
	Me.showparty = not Me.showparty
	ListenerFrameBarShowParty:SetOn( Me.showparty )
	ListenerFrameBarShowParty:RefreshTooltip()
	Main:RefreshChat()
	
	Main:Snoop_DoUpdate()
end

-------------------------------------------------------------------------------
function Main:ClipFramePosition()
	-- todo
end
 
-------------------------------------------------------------------------------
function Main:LoadFrameSettings()
 
	if Main.db.profile.frame.width < 50 then
		Main.db.profile.frame.width = 50
	end
	
	if Main.db.profile.frame.height < 50 then
		Main.db.profile.frame.height = 50
	end
	
	ListenerFrame:ClearAllPoints()
	local point = Main.db.profile.frame.point
	if #point == 0 then
		ListenerFrame:SetPoint( "LEFT", 50, 0 )
	else
		ListenerFrame:SetPoint( point[1], UIParent, point[2], point[3], point[4] )
	end
	
	ListenerFrame:SetSize( Main.db.profile.frame.width, Main.db.profile.frame.height )
	
	ListenerFrame.bg:SetColorTexture( unpack( Main.db.profile.frame.color_bg ) )
		
	for k,v in pairs( ListenerFrame.edges ) do
		v:SetColorTexture( unpack( Main.db.profile.frame.color_edge ) )
	end
	
	if Main.db.char.showhidden then
		ListenerFrame.bar2.hidden_button:SetOn( true )
	else
		ListenerFrame.bar2.hidden_button:SetOn( false )
	end
	
	Main:LoadFrameBarSettings()
	
	Main:LoadChatFont()
	
	if Main.db.profile.frame.hidden then
		ListenerFrame:Hide()
	else
		ListenerFrame:Show()
	end
end

function Main:LoadFrameBarSettings()

	ListenerFrame.bar2.bg:SetColorTexture( unpack( Main.db.profile.frame.color_bar ) )
	
	local font = SharedMedia:Fetch( "font", Main.db.profile.frame.barfont.face )
	ListenerBarFont:SetFont( font, Main.db.profile.frame.barfont.size )
end

-------------------------------------------------------------------------------
function Main:LoadChatFont()
	local outline = nil
	if Main.db.profile.frame.font.outline == 2 then
		outline = "OUTLINE"
	elseif Main.db.profile.frame.font.outline == 3 then
		outline = "THICKOUTLINE"
	end
	local font = SharedMedia:Fetch( "font", Main.db.profile.frame.font.face )
	ListenerFrameChat:SetFont( font, Main.db.profile.frame.font.size, outline )
	
	if Main.db.profile.frame.font.shadow then 
		ListenerFrameChat:SetShadowColor( 0, 0, 0, 0.8 )
		ListenerFrameChat:SetShadowOffset( 1,-1 )
	else
		
		ListenerFrameChat:SetShadowColor( 0, 0, 0, 0 )
	end
end

-------------------------------------------------------------------------------
function Main:ToggleFrame()
	self.db.profile.frame.hidden = not self.db.profile.frame.hidden
	if self.db.profile.frame.hidden then
		ListenerFrame:Hide()
	else
		ListenerFrame:Show()
	end
end

-------------------------------------------------------------------------------
function Main:HideFrame( dontsave )
	ListenerFrame:Hide()
	if not dontsave then
		self.db.profile.frame.hidden = true
	end
end

-------------------------------------------------------------------------------
function Main:ShowFrame( dontsave )
	ListenerFrame:Show()
	if not dontsave then
		self.db.profile.frame.hidden = false
	end
end

-------------------------------------------------------------------------------
function Main:SaveFramePosition()

	local point, _, point2, x, y = ListenerFrame:GetPoint(1)
	self.db.profile.frame.point = { point, point2, x, y }
	self.db.profile.frame.width = ListenerFrame:GetWidth()
	self.db.profile.frame.height = ListenerFrame:GetHeight()
end

-------------------------------------------------------------------------------
local SAY_EVENTS = { SAY=true, EMOTE=true, TEXT_EMOTE=true, YELL=true }

-------------------------------------------------------------------------------
local function EntryFilter( entry )
	if SAY_EVENTS[entry.e] then
		return Me.showsay
	elseif Me.showparty then
		return true
	end
end

local function GetEntryColor( e )
	
	local color = Main.db.profile.colors[e.e]
	 
--	if e.p then
--		-- player message
--		color = Main.db.profile.colors[ "P_" .. e.e ]
--	end 
	
	return color
end

local g_msgtypes = { 
	SAY=1, PARTY=1, PARTY_LEADER=1, RAID=1, RAID_LEADER=1, RAID_WARNING=1, YELL=1;
	EMOTE=2;
	TEXT_EMOTE=3; ROLL=3;
}	

local g_m1_prefix = {
	PARTY        = "[P] ";
	PARTY_LEADER = "[PL] ";
	RAID         = "[R] ";
	RAID_LEADER  = "[RL] ";
	RAID_WARNING = "[RW] ";
}

-------------------------------------------------------------------------------
-- Multiply the components of a rrggbb color code by a factor
--
local function ToNumber2( expr )
	return tonumber( expr ) or 0
end

function MulColorCode( code, factor )
	local split = {
		ToNumber2("0x"..code:sub(3,4));
		ToNumber2("0x"..code:sub(5,6));
		ToNumber2("0x"..code:sub(7,8));
	}
	split[1] = math.min( split[1] * factor, 255 )
	split[2] = math.min( split[2] * factor, 255 )
	split[3] = math.min( split[3] * factor, 255 )
	return string.format( "ff%02x%02x%02x", split[1], split[2], split[3] )
end

function Main:FormatChatMessage( e )
	local msgtype = g_msgtypes[e.e]
	
	local stamp = ""
	if Main.db.profile.frame.timestamps then
		stamp = date( "%H:%M ", e.t )
		
		stamp = "|cff808080" .. stamp .. "|r" 
	end
	
	-- get icon and name 
	local name, icon, color = self:GetICName( e.s, e.g )
	
	if icon and Main.db.profile.frame.show_icons then
		if Main.db.profile.frame.zoom_icons then
			icon = "|TInterface\\Icons\\" .. icon .. ":0:0:0:0:100:100:10:90:10:90:255:255:255|t "
		else
			icon = "|TInterface\\Icons\\" .. icon .. ":0|t "
		end
	else
		icon = ""
	end
	
	if color then 
		name = "|c" .. color .. name .. "|r"
	end
	
	name = "|Hplayer:" .. e.s .. "|h" .. name .. "|h" 
	
	local text = ""
	
	if msgtype == 1 then
	   -- say/party
	   
		local prefix = g_m1_prefix[e.e] or ""
		prefix = stamp .. icon .. prefix
		
		text = string.format( "%s%s: %s", prefix, name, e.m )
		
	elseif msgtype == 2 then
		-- emote message
		text = string.format( "%s%s%s %s", stamp, icon, name, e.m )
		
	elseif msgtype == 3 then
		-- text emote/roll
	
		-- replace sender name with IC name
		local msg = e.m:gsub( e.s, name )
		
		text = string.format( "%s%s%s", stamp, icon, msg )
	end
	
	return text
	
end

-------------------------------------------------------------------------------
-- Add a message directly to the chat window.
--
-- @param e    Message event data.
-- @param beep Enable playing a beep.
--
function Main:AddMessage( e, beep )
	if not EntryFilter( e ) then return end
	
	Me.chatid = Me.chatid + 1
	
	table.insert( self.chat_buffer, { e = e, c = Me.chatid } ) 
	while #self.chat_buffer > g_chat_buffer_size do 
		table.remove( self.chat_buffer, 1 )
	end
	
	local hidden = not e.p and (Main.player_list[e.s] == 0 or (Main.player_list[e.s] ~= 1 and not Main.db.char.listen_all))
	
	if not e.r and not e.p and not hidden then -- not read and not from the player and not hidden
		if ListenerFrame:IsShown() then
			if beep and Main.db.profile.sound.msg then
				Main:PlayMessageBeep() 
			end
			Main:FlashClient() -- this has its own config check inside
		end
		
		if g_top_unread_id == nil then
			g_top_unread_id = e.id
		end
		
		self:FlagUnreadEntries()
	end
	
	local color = GetEntryColor( e )
	
	if not hidden then
		ListenerFrameChat:AddMessage( self:FormatChatMessage( e, hidden ), 
	                              color[1], color[2], color[3], Me.chatid )
	else
		ListenerFrameChat:AddMessage( self:FormatChatMessage( e, hidden ), 
	                              color[1]*0.5, color[2]*0.5, color[3]*0.5, Me.chatid )
	end
end
--[[
-------------------------------------------------------------------------------
function Main:UpdateMessageColor( e )
	if not e.c or (e.c < Me.chatid - g_chat_buffer_size) then
		return -- out of range? this should be an error
	end
	
	local offset = math.max( Me.chatid - g_chat_buffer_size, 0 )
	local color = GetEntryColor( e ) 
	ListenerFrameChat:UpdateColorByID( e.c - offset, color[1], color[2], color[3] )
end]]

-------------------------------------------------------------------------------
function Main:CheckUnread()
	self:UnflagUnreadEntries()
	g_has_unread_entries = false
	g_top_unread_id = nil
	for k,v in pairs( self.unread_entries ) do
		if EntryFilter( v ) 
		   and (self.player_list[ v.s ] == 1 
		        or (self.player_list[v.s] ~= 0 and Main.listen_all) 
				or guid == UnitGUID("player")) then
				
			if not g_top_unread_id or g_top_unread_id < v.id then
				g_top_unread_id = v.id
			end
			
			self:FlagUnreadEntries()
		end
	end
end

-------------------------------------------------------------------------------
function Main:UpdateHighlight()
	if not Main.db then return end -- not initialized yet.
	
	local regions = {}

	-- create a list of message regions
	for k,v in pairs( { ListenerFrameChat.FontStringContainer:GetRegions() } ) do
		
		if v:GetObjectType() == "FontString" and v:IsShown() then
			v:SetNonSpaceWrap( true ) -- a nice hack for nonspacewrap text
			table.insert( regions, v )
		end
	end
	
	-- sort by Y
	table.sort( regions, function( a, b ) 
		return a:GetTop() < b:GetTop()
	end)
	
	local offset = math.max( Me.chatid - g_chat_buffer_size, 0 )
	local chat_index_start = Me.chatid - ListenerFrameChat:GetScrollOffset() - offset
	local chat_index = chat_index_start
	local count = 0
	
	local top_edge = ListenerFrameChat:GetTop() + 1 -- that one pixel
	
	local first_unread_region = nil
	--local first_unread_id     = 0
	
	for k,v in ipairs( regions ) do
		local e = Main.chat_buffer[chat_index]
		
		if not e then break end
		e = e.e
		
		if v:GetBottom() < top_edge then -- within the chatbox only
		
			local hidden = not e.p and (Main.player_list[e.s] == 0 or (Main.player_list[e.s] ~= 1 and not Main.db.char.listen_all))
			if hidden then
				v:SetAlpha( 0.5 )
			else
				v:SetAlpha( 1.0 )
			end
			
			if e.id == g_top_unread_id then
				first_unread_region = v
			end
			
			local hidden = not (Main.player_list[e.s] == 1 or Main.player_list[e.s]~=0 and Main.db.char.listen_all)  
			local mouseover = g_mouseover_highlight == e.s
			
			local enabled = mouseover or e.p or e.h
			
			if enabled then
				-- setup block
				count = count + 1
				if not Me.hl_texes[count] then
					Me.hl_texes[count] = ListenerFrame:CreateTexture() 
				end 
				local tex = Me.hl_texes[count]
				
				tex:ClearAllPoints()
				tex:SetPoint( "LEFT", v, "LEFT", -3, 0 )
				tex:SetPoint( "RIGHT", v, "LEFT", -1, 0 )
				tex:SetPoint( "BOTTOM", v, "BOTTOM", 0, 0 )
				
				local clip = math.max( v:GetTop() - top_edge, 0 )
				
				tex:SetPoint( "TOP", v, "TOP", 0, -clip )
				tex:SetBlendMode( "BLEND" )
				if e.h then
					tex:SetColorTexture( unpack( Main.db.profile.colors.tab_highlight ) )
				elseif e.p then
					tex:SetColorTexture( unpack( Main.db.profile.colors.tab_self ) )
				elseif mouseover then
					tex:SetColorTexture( unpack( Main.db.profile.colors.tab_mouseover ) )
				end
				tex:Show()	
			end
		end

		chat_index = chat_index - 1
	end
	ListenerFrame.readmark:SetColorTexture( unpack( Main.db.profile.colors.readmark ) )
	if first_unread_region then
		ListenerFrame.readmark:Show()
		-- set the marker here
		local top = ListenerFrame:GetTop() - (first_unread_region:GetTop() + 1)
		if top < 2 then 
			top = 2 
			ListenerFrame.readmark:SetHeight( 2 )
		else
			ListenerFrame.readmark:SetHeight( 1 )
		end
		ListenerFrame.readmark:SetPoint( "TOP", 0, -top )
		
	elseif g_has_unread_entries then
		ListenerFrame.readmark:SetHeight( 2 )
		ListenerFrame.readmark:Show()
		local e = Main.chat_buffer[chat_index_start]
		if e then e = e.e end
		if e then
			if e.id < g_top_unread_id then
				-- past the bottom
				
				ListenerFrame.readmark:SetPoint( "TOP", ListenerFrame, "BOTTOM", 0, 3 )
			else
				-- past the top
				
				ListenerFrame.readmark:SetPoint( "TOP", 0, -2 )
				--ListenerFrameReadmark:SetPoint( "TOP", ListenerFrameChat, "TOP", 0, 0 )
			end
		end
	else
		ListenerFrame.readmark:Hide()
	end
	
	for i = count+1, #Me.hl_texes do
		Me.hl_texes[i]:Hide()
	end
	 
end

-------------------------------------------------------------------------------
function Main:ClearChatBuffer()  
	self.chat_buffer = {}
	Me.chatid = 0
end

-------------------------------------------------------------------------------
function Main:RefreshChat()
	ListenerFrameChat:Clear()
	self:ClearChatBuffer()
	self:UnflagUnreadEntries()
	local entries = {}
	
	local listen_all = Main.db.char.listen_all
	local showhidden = Main.db.char.showhidden
	
	-- go through the chat list and populate entries
	for i = Main.next_lineid-1, 1, -1 do
		local entry = Main.chatlist[i]
		if entry then
			if EntryFilter( entry ) then
				
				if showhidden or entry.p or Main.player_list[entry.s] == 1 or (Main.player_list[entry.s] ~= 0 and listen_all) then
					table.insert( entries, entry )
				end
			end
		end
		
		-- break when we have enough messages
		if #entries >= g_chat_buffer_size then
			break
		end
	end

	for i = #entries, 1, -1 do
		self:AddMessage( entries[i] )
	end
	
--	Main:UpdateHighlight() -- this will be called when the chat refreshes
end

-------------------------------------------------------------------------------
function Main:SetChatFont( font )
	self.db.profile.frame.font.face = font
	self:LoadChatFont()
end

-------------------------------------------------------------------------------
function Main:SetChatOutline( value )
	self.db.profile.frame.font.outline = value
	self:LoadChatFont()
end

-------------------------------------------------------------------------------
function Main:SetFontSize( size )
	size = math.max( size, 6 )
	size = math.min( size, 24 )
	self.db.profile.frame.font.size = size
	self:LoadChatFont()
end

-------------------------------------------------------------------------------
function Main.Frame_SetupEdge( frame )
	frame.edges = {}
	local e = frame:CreateTexture( "BORDER" ) -- top
	e:SetPoint( "TOPLEFT",     frame, "TOPLEFT",  -2, 2 )
	e:SetPoint( "BOTTOMRIGHT", frame, "TOPRIGHT",  2, 0 )
	table.insert( frame.edges, e )
	local e = frame:CreateTexture( "BORDER" ) -- bottom
	e:SetPoint( "TOPLEFT",     frame, "BOTTOMLEFT",  -2, 0 )
	e:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT",  2, -2 )
	table.insert( frame.edges, e )
	local e = frame:CreateTexture( "BORDER" ) -- left
	e:SetPoint( "TOPLEFT",     frame, "TOPLEFT",    -2, 0 )
	e:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMLEFT", -0, 0 )
	table.insert( frame.edges, e )
	local e = frame:CreateTexture( "BORDER" ) -- right
	e:SetPoint( "TOPLEFT",     frame, "TOPRIGHT",     0, 0 )
	e:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT",  2, 0 )
	table.insert( frame.edges, e )
end

-------------------------------------------------------------------------------
function Main:Frame_SetShadow( val )
	self.db.profile.frame.font.shadow = val
	self:LoadChatFont()
end	

-------------------------------------------------------------------------------
function Main:Frame_SetBGColor( r, g, b, a )
	self.db.profile.frame.bg = { r, g, b, a }
	self:LoadFrameSettings()
end

-------------------------------------------------------------------------------
function Main:Frame_SetEdgeColor( r, g, b, a )
	self.db.profile.frame.edge = { r, g, b, a }
	self:LoadFrameSettings()
end

function Main:Frame_SetTimestamps( stamps )
	self.db.profile.frame.timestamps = stamps
	Main:RefreshChat()
end

function Main:Frame_SetPlayerName( val )
	self.db.profile.frame.playername = val
	Main:RefreshChat()
end

-------------------------------------------------------------------------------
-- FRAME SCRIPTS
-------------------------------------------------------------------------------

function Main.Frame_OnEnter( self )
	
	Main.Frame_UpdateResizeShow()
end

-------------------------------------------------------------------------------
function Main.Frame_OnLeave( self )
	
	Main.Frame_UpdateResizeShow()
end

-------------------------------------------------------------------------------
function Main.Frame_OnMouseDown( self, button )
	if button == "LeftButton" then
		ListenerFrame.dragging = true
		ListenerFrame:StartMoving() 
	end
end

-------------------------------------------------------------------------------
function Main.Frame_OnMouseUp( self )
	
	Main.Frame_StopDragging()

end

function Main.Frame_StopDragging()
	if ListenerFrame.dragging then
		ListenerFrame.dragging = false
		ListenerFrame:StopMovingOrSizing()
		ListenerAddon:ClipFramePosition()
		ListenerAddon:SaveFramePosition()
	end
end

-------------------------------------------------------------------------------
function Main.FrameResizeButton_OnMouseDown( self, button )
	
	self:SetButtonState( "PUSHED", true ); 
	self:GetHighlightTexture():Hide();
	ListenerFrame:StartSizing( "BOTTOMRIGHT" );
	ListenerFrame.doingSizing = true
end

-------------------------------------------------------------------------------
function Main.FrameResizeButton_OnMouseUp( self, button )

	self:SetButtonState( "NORMAL", false );
	self:GetHighlightTexture():Show();
	ListenerFrame:StopMovingOrSizing();
	ListenerAddon:ClipFramePosition()
	ListenerAddon:SaveFramePosition()
	ListenerFrame.doingSizing = false
	
	Main.Frame_UpdateResizeShow()
end

-------------------------------------------------------------------------------
function Main.FrameResizeButton_OnLeave( self )
	
	-- hide ourselves, but we're shown again right after
	Main.Frame_UpdateResizeShow()
end

function Main.Frame_UpdateResizeShow()
	if ListenerFrame:IsMouseOver() and IsShiftKeyDown() or ListenerFrame.doingSizing then
		ListenerFrameResizeButton:Show()
	else
		ListenerFrameResizeButton:Hide()
	end
end

-------------------------------------------------------------------------------
-- Tooltip for filter (green) button
--
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
end

-------------------------------------------------------------------------------
-- Tooltip for public chat (white) button.
--
local function Tooltip_ShowSay( self )
	if Me.showsay then
		GameTooltip:AddDoubleLine( L["Public Chat"], L["Shown"], 1,1,1, 1,1,1 )
		GameTooltip:AddLine( L["Click to hide public emotes."] )
	else
		GameTooltip:AddDoubleLine( L["Public Chat"], L["Hidden"], 1,1,1, 0.75,0.75,0.75 )
		GameTooltip:AddLine( L["Click to show public emotes."] )
	end
end

-------------------------------------------------------------------------------
-- Tooltip for group chat (blue) button.
--
local function Tooltip_ShowParty( self )
	if Me.showparty then
		GameTooltip:AddDoubleLine( L["Group Chat"], L["Shown"], 1,1,1, 1,1,1 )
		GameTooltip:AddLine( L["Click to hide group/party chat."] )
	else
		GameTooltip:AddDoubleLine( L["Group Chat"], L["Hidden"], 1,1,1, 0.75,0.75,0.75 )
		GameTooltip:AddLine( L["Click to show group/party chat."] )
	end
end


-------------------------------------------------------------------------------
-- Tooltip for unread messages button.
--
local function Tooltip_Read( self )
	if g_has_unread_entries then
		GameTooltip:AddLine( L["Unread Messages"], 1,1,1 )
		GameTooltip:AddLine( L["Click to mark all messages as read."] )
	else
		GameTooltip:AddLine( L["No Unread Messages"], 0.75, 0.75, 0.75 )
	end
end

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
end

local function InitFrameMenu( menu )
	if not Main.frame_menu then
		Main.frame_menu = CreateFrame( "Button", "ListenerFrameMenu", UIParent, "UIDropDownMenuTemplate" )
		Main.frame_menu.displayMode = "MENU"
	end
	
	UIDropDownMenu_Initialize( ListenerFrameMenu, InitializeFrameMenu )
	UIDropDownMenu_JustifyText( ListenerFrameMenu, "LEFT" )
end

function Main:ShowFrameMenu()
	InitFrameMenu()
	local x,y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	ToggleDropDownMenu( 1, nil, Main.frame_menu, "UIParent", x / scale, y / scale )
end
 
-------------------------------------------------------------------------------
Main:AddLoadCall( function() 
	Main:SetupTooltip( ListenerFrameBarToggle, Tooltip_Toggle )
	Main:SetupTooltip( ListenerFrameBarShowSay, Tooltip_ShowSay )
	Main:SetupTooltip( ListenerFrameBarShowParty, Tooltip_ShowParty )
	Main:SetupTooltip( ListenerFrameBarRead, Tooltip_Read )
	
	Main:ProbePlayer()
	ListenerFrameBarShowSay:SetOn( true )
	ListenerFrameBarShowParty:SetOn( true )
	ListenerFrameBarRead:SetOn( false )
	
end)
