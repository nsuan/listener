
local Main = ListenerAddon
local L    = Main.Locale
Main.Frame = {}

local Me          = ListenerAddon.Frame
local SharedMedia = LibStub("LibSharedMedia-3.0")

local CHAT_BUFFER_SIZE = 300

local DEFAULT_LISTEN_EVENTS = {
	"SAY", "EMOTE", "TEXT_EMOTE", "YELL", 
	"PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING"
}

-------------------------------------------------------------------------------
-- These message types are included in the "public" filter.
--
local SAY_EVENTS = { SAY=true, EMOTE=true, TEXT_EMOTE=true, YELL=true }

-------------------------------------------------------------------------------
-- Message format types. For building strings in window.
--
local MSG_FORMAT_TYPES = { 

	-- "<name>: <msg>"
	SAY=1, PARTY=1, PARTY_LEADER=1, RAID=1, RAID_LEADER=1, RAID_WARNING=1, YELL=1;
	INSTANCE=1, INSTANCE_LEADER=1;
	
	-- "<name> <msg>"
	EMOTE=2;
	
	-- "<name> <msg>" name is substituted
	TEXT_EMOTE=3; ROLL=3;
}

-------------------------------------------------------------------------------
-- Prefix behind name for these types of messages.
--
local MSG_FORMAT_PREFIX = {
	PARTY            = "[P] ";
	PARTY_LEADER     = "[P] ";
	RAID             = "[R] ";
	RAID_LEADER      = "[R] ";
	INSTANCE         = "[I] ";
	INSTANCE_LEADER  = "[I] ";
	GUILD            = "[G] ";
	OFFICER          = "[O] ";
	RAID_WARNING     = "[RW] ";
}

-------------------------------------------------------------------------------
-- Static methods
-------------------------------------------------------------------------------

local function GetEntryColor( e )
	
	if e.c then
		-- channel (todo)
		return { 1, 1, 1, 1 }
	else
		local info = ChatTypeInfo[ e.e ]
		return { info.r, info.g, info.b, 1 }
	end
end

-------------------------------------------------------------------------------
-- Private methods
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Initialize member variables
--
local function SetupMembers( self )
	-- this is to be overridden by SetFrameIndex
	self.listen_events = {}
	
	-- ordered list of chat history entries that should appear in the frame
	self.chat_buffer = {}
	
	-- the uppermost unread message ID
	-- nil if the window has no "unread" messages
	self.top_unread_id       = nil
	
	-- the name of the player being targeted by the mouseover highlight feature
	self.mouseover_highlight = nil
	
	-- when a new messages is added, this saves the time
	-- if the user clicks on the frame at the moment a message is added, 
	-- its ignore to prevent error
	self.clickblock = 0
	
	-- textures used for the tab strips on the left side of the window
	self.tab_texes = {}
	
	-- for keeping track of line IDs in the chatbox
	-- (new id = chatid+1)
	self.chatid    = 0
	
end

-------------------------------------------------------------------------------
-- Setup the frames that form the edge around the window.
--
local function SetupEdge( self )
	if self.edges then return end
	
	self.edges = {}
	local e = self:CreateTexture( "BORDER" ) -- top
	e:SetPoint( "TOPLEFT",     self, "TOPLEFT",  -2, 2 )
	e:SetPoint( "BOTTOMRIGHT", self, "TOPRIGHT",  2, 0 )
	table.insert( self.edges, e )
	local e = self:CreateTexture( "BORDER" ) -- bottom
	e:SetPoint( "TOPLEFT",     self, "BOTTOMLEFT",  -2, 0 )
	e:SetPoint( "BOTTOMRIGHT", self, "BOTTOMRIGHT",  2, -2 )
	table.insert( self.edges, e )
	local e = self:CreateTexture( "BORDER" ) -- left
	e:SetPoint( "TOPLEFT",     self, "TOPLEFT",    -2, 0 )
	e:SetPoint( "BOTTOMRIGHT", self, "BOTTOMLEFT", -0, 0 )
	table.insert( self.edges, e )
	local e = self:CreateTexture( "BORDER" ) -- right
	e:SetPoint( "TOPLEFT",     self, "TOPRIGHT",     0, 0 )
	e:SetPoint( "BOTTOMRIGHT", self, "BOTTOMRIGHT",  2, 0 )
	table.insert( self.edges, e )
end

-------------------------------------------------------------------------------
-- Add or subtract from the frame's font size.
--
local function AdjustFontSize( self, delta )
	local size = 0
	if self.frame_index == 1 then
		size = Main.db.profile.frame.font.size
	else
		size = Main.db.char.frames[self.frame_index].font_size or Main.db.profile.frame.font.size
	end
	
	size = size + delta
	
	self:SetFontSize( size )
end

-------------------------------------------------------------------------------
-- Save the window layout in the database.
--
local function SaveFrameLayout( self )
	if not self.frame_index then return end
	local point, _, point2, x, y = self:GetPoint(1)
	
	local layout = {
		point  = { point, point2, x, y };
		width  = self:GetWidth();
		height = self:GetHeight();
	}
	
	if self.frame_index == 1 then
		-- primary frame
		Main.db.profile.frame.layout = layout
	else
		-- other frame
		Main.db.char.frames[self.frame_index].layout = layout
	end
end

-------------------------------------------------------------------------------
local function ShowOrHide( self, show, save )
	if show then
		self:Show()
	else
		self:Hide()
	end
	
	if save then
		Main.db.char.frames[self.frame_index].hidden = not show
	end
end

-------------------------------------------------------------------------------
-- Add or remove player from the filter.
--
-- @param name   Name of player.
-- @param mode   1 = add player; 0 = remove player; nil = reset player
-- @param silent Don't print chat messages.
--
local function AddOrRemovePlayer( self, name, mode, silent )
	if mode ~= 1 and mode ~= 0 and mode ~= nil then error( "Invalid mode." ) end
	name = Main.FixupName( name )
	
	if self.players[name] == mode then
		if not silent then
			if mode == 1 then
				Main.Print( string.format( L["Already listening to %s."], name ) ) 
			elseif mode == 0 then
				Main.Print( string.format( L["%s is already filtered out."], name ) ) 
			else
				Main.Print( string.format( L["%s wasn't found."], name ) ) 
			end
		end
		return
	end
	
	self.players[name] = mode
	if not silent then 
		if mode == 1 then
			Main.Print( string.format( L["Added %s."], name ) ) 
		elseif mode == 0 then
			Main.Print( string.format( L["Removed %s."], name ) ) 
		else
			Main.Print( string.format( L["Reset %s."], name ) ) 
		end
	end
	
	self:RefreshChat()
	self:UpdateProbe()
end

-------------------------------------------------------------------------------
-- Returns true if an entry should be displayed according to event filters.
--
local function EntryFilter( self, entry )
	if entry.c then
		return self.listen_events( "#" .. entry.c )
	end
	return self.listen_events[entry.e]
end

-------------------------------------------------------------------------------
local function FormatChatMessage( self, e )
	local msgtype = MSG_FORMAT_TYPES[e.e]
	
	local stamp = ""
	if Main.db.profile.frame.timestamps then
		-- todo: additional stamp formats
		stamp = date( "%H:%M ", e.t )
		stamp = "|cff808080" .. stamp .. "|r" 
	end
	
	-- get icon and name 
	local name, icon, color = Main:GetICName( e.s, e.g )
	
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
	   
		local prefix = MSG_FORMAT_PREFIX[e.e] or ""
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
-- Public Methods
-------------------------------------------------------------------------------
local Method = {}
Me.methods = Method

-------------------------------------------------------------------------------
-- Link this frame to the database.
--
function Method:SetFrameIndex( index )
	self.frame_index = index
	if not Main.db.char.frames[index] then
		Me.InitOptions( index )
	end
	self.players       = Main.db.char.frames[index].players
	self.listen_events = Main.db.char.frames[index].filter
end

-------------------------------------------------------------------------------
-- Blocks clicks temporarily.
--
-- This is called when a new message is added, as to prevent accidental clicks
-- when the frame is scrolling.
--
function Method:SetClickBlock()
	self.clickblock = GetTime()
end

-------------------------------------------------------------------------------
-- Toggle the frame.
--
function Method:Toggle()
	ShowOrHide( self, not self:IsShown(), true )
end

-------------------------------------------------------------------------------
-- Hide the frame.
--
function Method:Close( dontsave )
	ShowOrHide( self, false, not dontsave )
end

-------------------------------------------------------------------------------
-- Show the frame.
--
function Method:Open( dontsave )
	ShowOrHide( self, true, not dontsave )
end

-------------------------------------------------------------------------------
-- Set the chat font size.
--
function Method:SetFontSize( size )

	size = math.max( size, 6 )
	size = math.min( size, 24 )
	
	if self.frame_index == 1 then
		Main.db.profile.frame.font.size = size
	else
		Main.db.char.frames[self.frame_index].font_size = size
	end
	
	self:ApplyChatOptions()
end

-------------------------------------------------------------------------------
-- Load all options.
--
function Method:ApplyOptions()
	self:ApplyLayoutOptions()
	self:ApplyChatOptions()
	self:ApplyColorOptions()
	self:ApplyBarOptions()
	self:ApplyOtherOptions()
end

-------------------------------------------------------------------------------
function Method:ApplyOtherOptions()
	self.bar2.hidden_button:SetOn( Main.db.char.frames[self.frame_index].showhidden )
end

-------------------------------------------------------------------------------
function Method:ApplyColorOptions()
	local bgcolor = Main.db.char.frames[self.frame_index].color_bg or Main.db.profile.frame.color_bg
	self.bg:SetColorTexture( unpack( bgcolor ))
	
	local edgecolor = Main.db.char.frames[self.frame_index].color_edge or Main.db.profile.frame.color_edge
	for k,v in pairs( self.edges ) do
		v:SetColorTexture( unpack( edgecolor )) 
	end
end

-------------------------------------------------------------------------------
-- Options for the positioning/size.
--
function Method:ApplyLayoutOptions()
	local layout
	if self.frame_index == 1 then
		layout = Main.db.profile.frame.layout
	else
		layout = Main.db.char.frames[self.frame_index].layout
	end
	
	self:ClearAllPoints()
	local point = layout.point
	if not point or #point == 0 then
		if self.frame_index == 1 then
			-- primary
			self:SetPoint( "LEFT", 50, 0 )
		else
			-- secondary
			self:SetPoint( "CENTER", (self.frame_index-2) * 50, (self.frame_index-2) * -50 )
		end
	else
		self:SetPoint( point[1], UIParent, point[2], point[3], point[4] )
	end
	
	self:SetSize( math.max( layout.width, 50 ), 
	              math.max( layout.height, 50 ) )
	
	if Main.db.char.frames[self.frame_index].hidden then
		self:Hide()
	else
		self:Show()
	end
end

-------------------------------------------------------------------------------
-- Options for the chat/text appearance.
--
function Method:ApplyChatOptions()
	local outline = nil
	if Main.db.profile.frame.font.outline == 2 then
		outline = "OUTLINE"
	elseif Main.db.profile.frame.font.outline == 3 then
		outline = "THICKOUTLINE"
	end
	local font = SharedMedia:Fetch( "font", Main.db.profile.frame.font.face )
	
	local size = 0
	if self.frame_index == 1 then
		size = Main.db.profile.frame.font.size
	else
		size = Main.db.char.frames[self.frame_index].font_size 
		       or Main.db.profile.frame.font.size
	end
	
	self.chatbox:SetFont( font, size, outline )
	
	if Main.db.profile.frame.font.shadow then 
		self.chatbox:SetShadowColor( 0, 0, 0, 0.8 )
		self.chatbox:SetShadowOffset( 1,-1 )
	else
		self.chatbox:SetShadowColor( 0, 0, 0, 0 )
	end
end

-------------------------------------------------------------------------------
-- Options for the title bar.
--
function Method:ApplyBarOptions()
	local bar_color = Main.db.char.frames[self.frame_index].color_bar or Main.db.profile.frame.color_bar
	self.bar2.bg:SetColorTexture( unpack( bar_color ) )
	
	-- move this to a static function
	local font = SharedMedia:Fetch( "font", Main.db.profile.frame.barfont.face )
	ListenerBarFont:SetFont( font, Main.db.profile.frame.barfont.size )
end

-------------------------------------------------------------------------------
-- Add chat events to the chat filter.
--
-- Channels are treated differently. To listen to a channel, prefix name
-- with #, e.g. "#secret"
--
function Method:AddEvents( ... )
	local arg = {...}
	local dirty = false
	
	for k,v in pairs(arg) do
		v = v:upper()
		if not self.listen_events[v] then
			self.listen_events[v] = true
			dirty = true
		end
	end
	
	if dirty then self:RefreshChat() end
end

-------------------------------------------------------------------------------
-- Remove chat events from display.
--
function Method:RemoveEvents( ... )
	local arg = {...}
	local dirty = false
	
	for k,v in pairs(arg) do
		v = v:upper()
		if self.listen_events[v] then
			self.listen_events[v] = nil
			dirty = true
		end
	end
	
	if dirty then self:RefreshChat() end
end

-------------------------------------------------------------------------------
-- Returns true if an event is being listened to.
--
function Method:HasEvent( event )
	if self.listen_events[event:upper()] then return true end
	return nil
end

-------------------------------------------------------------------------------
-- Returns the listen_events table.
-- This is a map of which events are being listened to.
-- Do not modify the returned table.
--
function Method:GetListenEvents()
	return self.listen_events
end	

-------------------------------------------------------------------------------
-- Add player to filter.
-- 
-- @param name   Name of player.
-- @param silent Do not print chat message.
function Method:AddPlayer( name, silent )
	AddOrRemovePlayer( self, name, 1, silent )
end

-------------------------------------------------------------------------------
function Method:RemovePlayer( name, silent )
	AddOrRemovePlayer( self, name, 0, silent )
end 

-------------------------------------------------------------------------------
-- Returns true if the window is listening to someone.
--
function Method:ListeningTo( name )
	local f = self.players[name]
	return f == 1 or (Main.db.char.frames[self.frame_index].listen_all and f ~= 0)
end

-------------------------------------------------------------------------------
-- Toggle filter for player.
--
-- @param name   Player name.
-- @param silent Do not print chat message.
--
function Method:TogglePlayer( name, silent )
	if self.players[name] == 1 then
		self:RemovePlayer( name, silent )
	elseif self.players[name] == 0 then
		self:AddPlayer( name, silent )
	else
		if Main.db.char.frames[self.frame_index].listen_all then
			self:RemovePlayer( name, silent )
		else
			self:AddPlayer( name, silent )
		end
	end
end

-------------------------------------------------------------------------------
-- Called when the window is active and the probe target changes.
--
function Method:UpdateProbe()
	local target, guid = Main:GetProbed()
	local on = false
	local title = "—"
	
	if target then
		
		on = self:ListeningTo( target )
		
		local name, icon, color = Main:GetICName( target, guid )
		title = " " .. name
		
	end
	
	self.bar2.title:SetText( title )
	
	if on then
		self.bar2.toggle_button:Show()
	else
		self.bar2.toggle_button:Hide()
	end
	
	if Main.db.profile.highlight_mouseover then
		self:UpdateHighlight()
	end
end

-------------------------------------------------------------------------------
-- Add a message directly to the chat window.
--
-- @param e    Message event data.
-- @param beep Enable playing a beep.
--
function Method:AddMessage( e, beep )
	if not EntryFilter( self, e ) then return end
	
	self.chatid = self.chatid + 1
	
	table.insert( self.chat_buffer, { e = e, c = self.chatid } ) 
	while #self.chat_buffer > CHAT_BUFFER_SIZE do 
		table.remove( self.chat_buffer, 1 )
	end
	
	local hidden = not self:ListeningTo( e.s )
	
	if not e.r and not e.p and not hidden then -- not read and not from the player and not hidden
		if self:IsShown() then
			if beep and Main.db.char.frames[self.frame_index].sound then
				Main:PlayMessageBeep() 
				Main:FlashClient()
			end
			
		end
		
		if self.top_unread_id == nil then
			self.top_unread_id = e.id
		end
	end
	
	local color = GetEntryColor( e )
	
	self.chatbox:AddMessage( FormatChatMessage( self, e ), color[1], color[2], color[3], self.chatid )
end

-------------------------------------------------------------------------------
-- Add a message into the chat window if it passes our filters.
--
function Method:TryAddMessage( e, beep )
	if Main.db.char.frames[self.frame_index].showhidden or self:ListeningTo( e.s ) then
		self:AddMessage( e, beep )
	end
end

-------------------------------------------------------------------------------
function Method:CheckUnread()
	self.top_unread_id = nil
	local id = nil
	
	for k,v in pairs( Main.unread_entries ) do
		if EntryFilter( self, v ) and self:ListeningTo( v.s ) then
			if not id or v.id < id then
				id = v.id
			end
		end
	end
	
	self.top_unread_id = id
end

-------------------------------------------------------------------------------
-- Update the unread messages marker.
--
-- Sub function for UpdateHighlight.
--
-- @param region This is the fontstring that is showing the first unread
--               region
--
local function UpdateReadmark( self, region, first_id )

	-- todo: option for hiding readmark here.
	
	self.readmark:SetColorTexture( unpack( Main.db.profile.colors.readmark ) )
	if region then
		self.readmark:Show()
		
		-- set the marker here
		local top = self.chatbox:GetTop() - (region:GetTop() + 1)
		if top < 2 then 
			top = 2 
			self.readmark:SetHeight( 2 )
		else
			self.readmark:SetHeight( 1 )
		end
		self.readmark:SetPoint( "TOP", self.chatbox, "TOP", 0, -top )
		
	elseif self.top_unread_id then
		self.readmark:SetHeight( 2 )
		self.readmark:Show()
		
		if first_id < self.top_unread_id then
			-- past the bottom
			self.readmark:SetPoint( "TOP", self, "BOTTOM", 0, 3 )
		else
			-- past the top
			self.readmark:SetPoint( "TOP", self.chatbox, "TOP", 0, -2 )
		end
	else
		-- no unread messages
		self.readmark:Hide()
	end
	
end

-------------------------------------------------------------------------------
function Method:UpdateHighlight()
	if not Main.db then return end -- not initialized yet
	
	local regions = {}

	-- create a list of message regions
	for k,v in pairs( { self.chatbox.FontStringContainer:GetRegions() } ) do
		if v:GetObjectType() == "FontString" and v:IsShown() then
			v:SetNonSpaceWrap( true ) -- a nice hack for nonspacewrap text
			table.insert( regions, v )
		end
	end
	
	-- sort by Y
	table.sort( regions, function( a, b ) 
		return a:GetTop() < b:GetTop()
	end)
	
	-- this is some voodoo that i dont understand
	local offset = math.max( self.chatid - CHAT_BUFFER_SIZE, 0 )
	local chat_index_start = self.chatid - self.chatbox:GetScrollOffset() - offset
	local chat_index = chat_index_start
	local count = 0
	
	local top_edge = self.chatbox:GetTop() + 1 -- that one pixel
	
	local first_unread_region = nil
	--local first_unread_id     = 0
	
	for k,v in ipairs( regions ) do
		local e = self.chat_buffer[chat_index]
		
		if not e then break end
		e = e.e
		
		if v:GetBottom() < top_edge then -- within the chatbox only
		
			local hidden = not self:ListeningTo( e.s )
			v:SetAlpha( hidden and 0.35 or 1.0 )
			
			if e.id == self.top_unread_id then
				first_unread_region = v
			end
			
			local targeted = (Main.GetProbed() == e.s) and Main.db.profile.highlight_mouseover

			if targeted or e.p or e.h then
				-- setup block
				count = count + 1
				if not self.tab_texes[count] then
					self.tab_texes[count] = self:CreateTexture() 
				end 
				local tex = self.tab_texes[count]
				
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
				elseif targeted then
					tex:SetColorTexture( unpack( Main.db.profile.colors.tab_mouseover ) )
				end
				tex:Show()	
			end
		end

		chat_index = chat_index - 1
	end
	
	local e = self.chat_buffer[chat_index_start]
	if e then e = e.e end
	if e then
		UpdateReadmark( self, first_unread_region, e.id )
	else
		self.readmark:Hide()
	end
	
	for i = count+1, #self.tab_texes do
		self.tab_texes[i]:Hide()
	end
end	

-------------------------------------------------------------------------------
function Method:RefreshChat()
	self.chatbox:Clear()
	self.chat_buffer = {}
	self.chatid = 0
	self:CheckUnread()
	
	local entries = {}
	
	local listen_all = Main.db.char.frames[self.frame_index].listen_all
	local showhidden = Main.db.char.frames[self.frame_index].showhidden
	
	-- go through the chat list and populate entries
	for i = Main.next_lineid-1, 1, -1 do
		local entry = Main.chatlist[i]
		if entry then
			if EntryFilter( self, entry ) then
				
				if showhidden or self.players[entry.s] == 1 or (self.players[entry.s] ~= 0 and listen_all) then
					table.insert( entries, entry )
				end
			end
		end
		
		-- break when we have enough messages
		if #entries >= CHAT_BUFFER_SIZE then
			break
		end
	end

	-- TODO: disable chatbox refreshes until this is done
	-- (check to see if its spammed.)
	for i = #entries, 1, -1 do
		self:AddMessage( entries[i] )
	end
	
end

-------------------------------------------------------------------------------
-- Set the window colors.
-- 
-- @param bg, edge, bar Colors for the background, edge, and titlebar
--                      {r, g, b, a}, range = 0-1, pass nil to not change.
--
function Method:SetColors( bg, edge, bar )
	if self.frame_index == 1 then
		if bg then self.db.profile.frame.color_bg = bg end
		if edge then self.db.profile.frame.color_edge = edge end
		if bar then self.db.profile.frame.color_bar = bar end
	else
		if bg then self.db.char.frames[self.frame_index].color_bg = bg end
		if edge then self.db.char.frames[self.frame_index].color_edge = edge end
		if bar then self.db.char.frames[self.frame_index].color_bar = bar end
	end
	
	self:ApplyColorOptions()
end

-------------------------------------------------------------------------------
-- Set Listen All mode. (default filter mode)
--
function Method:SetListenAll( listen_all )
	listen_all = not not listen_all
	if Main.db.char.frames[self.frame_index].listen_all == listen_all then return end
	
	Main.db.char.frames[self.frame_index].listen_all = listen_all
	
	self:RefreshChat()
	self:UpdateProbe()
end

-------------------------------------------------------------------------------
-- Enable/disable showing filtered out players.
--
function Method:ShowHidden( showhidden )
	
	showhidden = not not showhidden
	if Main.db.char.frames[self.frame_index].showhidden == showhidden then return end
	Main.db.char.frames[self.frame_index].showhidden = showhidden
	
	self:RefreshChat() 
	
	if showhidden then
		self.bar2.hidden_button:SetOn( true )
	else
		self.bar2.hidden_button:SetOn( false )
	end
end

-------------------------------------------------------------------------------
-- Update the visibility of the resize thumb.
--
function Method:UpdateResizeShow()
	if (self:IsMouseOver() and IsShiftKeyDown()) or self.doingSizing then
		self.resize_thumb:Show()
	else
		self.resize_thumb:Hide()
	end
end
-------------------------------------------------------------------------------
function Method:StartDragging()
	self.dragging = true
	self:StartMoving() 
end

-------------------------------------------------------------------------------
function Method:StopDragging()
	if self.dragging then
		self.dragging = false
		self:StopMovingOrSizing()
		SaveFrameLayout( self )
	end
end

-------------------------------------------------------------------------------
-- Handlers (And psuedo ones.)
-------------------------------------------------------------------------------
function Me.OnLoad( self )
	-- populate with methods
	for k,v in pairs( Method ) do
		self[k] = v
	end
	
	SetupMembers( self )
	
	-- initial settings
	self:EnableMouse( true )
	self:SetClampedToScreen( true )
	SetupEdge( self )
	
	hooksecurefunc( self.chatbox, "RefreshDisplay", function()
		Me.OnChatboxRefresh( self )
	end)
end

-------------------------------------------------------------------------------
function Me.OnEnter( self )
	self:UpdateResizeShow()
end

-------------------------------------------------------------------------------
function Me.OnLeave( self )
	self:UpdateResizeShow()
end

-------------------------------------------------------------------------------
function Me.OnMouseDown( self, button )
	if button == "LeftButton" and IsShiftKeyDown() then
		self:StartDragging()
	end
end

-------------------------------------------------------------------------------
function Me.OnMouseUp( self )
	self:StopDragging()
end

-------------------------------------------------------------------------------
-- For scrollwheel.
--
function Me.OnChatboxScroll( self, delta )
	
	local reps = IsShiftKeyDown() and 5 or 1
	if delta > 0 then
		if IsAltKeyDown() then
			self.chatbox:ScrollToTop()
		elseif IsControlKeyDown() then
			AdjustFontSize( self, 1 )
		else
			for i = 1, reps do self.chatbox:ScrollUp() end
		end
	else
		if IsAltKeyDown() then
			self.chatbox:ScrollToBottom()
		elseif IsControlKeyDown() then
			AdjustFontSize( self, -1 )
		else
			for i = 1,reps do self.chatbox:ScrollDown() end
		end
	end
end

-------------------------------------------------------------------------------
function Me.OnChatboxHyperlinkClick( self, link, text, button )
	if GetTime() - self.clickblock < 0.4 then
		-- block clicks when scroll changes
		return
	end	
	
	if strsub(link, 1, 6) == "player" then
		local namelink, isGMLink;
		if strsub(link, 7, 8) == "GM" then
			namelink = strsub(link, 10);
			isGMLink = true;
		else
			namelink = strsub(link, 8);
		end
		
		local name, lineid, chatType, chatTarget = strsplit(":", namelink);
		
		if IsShiftKeyDown() and button == "RightButton" then
			self:TogglePlayer( name )
			return
		end
	end
	
	SetItemRef( link, text, button, DEFAULT_CHAT_FRAME );
end

-------------------------------------------------------------------------------
function Me.OnChatboxRefresh( self )
	-- show or hide the scroll marker if we are scrolled up
	if self.chatbox:GetScrollOffset() ~= 0 then
		self.scrollmark:Show()
	else
		self.scrollmark:Hide()
	end

	-- this should only be called when the scroll actually changes
	self:SetClickBlock()
	self:UpdateHighlight()
end

-------------------------------------------------------------------------------
function Me.TogglePlayerClicked( self, button )
	if button == "LeftButton" then 
		local name = Main.GetProbed()
		if name then 
			self:TogglePlayer( name, true )
		end
	elseif button == "RightButton" then
		self:ShowMenu()
	end
end

-------------------------------------------------------------------------------
function Me.ShowHiddenClicked( self, button )
	if button == "LeftButton" then
		self:ShowHidden( not Main.db.char.frames[self.frame_index].showhidden )
	end
end

-------------------------------------------------------------------------------
function Me.CloseClicked( self, button )
	if button == "LeftButton" then
		self:Close()
	end
end

-------------------------------------------------------------------------------
-- resize_thumb handlers.
-------------------------------------------------------------------------------
function Me.ResizeThumb_OnMouseDown( self, button )
	self:SetButtonState( "PUSHED", true ); 
	self:GetHighlightTexture():Hide();
	self:GetParent():StartSizing( "BOTTOMRIGHT" );
	self:GetParent().doingSizing = true
end

-------------------------------------------------------------------------------
function Me.ResizeThumb_OnMouseUp( self, button )
	
	self:SetButtonState( "NORMAL", false );
	self:GetHighlightTexture():Show();
	local parent = self:GetParent()
	parent:StopMovingOrSizing();
	SaveFrameLayout( parent )
	parent.doingSizing = false
	parent:UpdateResizeShow()
end

-------------------------------------------------------------------------------
function Me.ResizeThumb_OnLeave( self )
	self:GetParent():UpdateResizeShow()
end

-------------------------------------------------------------------------------
-- Other static functions
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Initialize a section in the database for a new frame
--
function Me.InitOptions( index )
	local data = {
		players    = {};
		listen_all = true;
		filter     = {}; -- filled in below
		showhidden = false;
		layout     = {
			width    = 200;
			height   = 300;
		};
		hidden       = false;
	}
	
	for k,v in pairs( DEFAULT_LISTEN_EVENTS ) do
		data.filter[v] = true
	end
	
	data.players[ UnitName("player") ] = 1
	
	Main.db.char.frames[index] = data
end
