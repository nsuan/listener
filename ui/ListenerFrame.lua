
local Main = ListenerAddon
local L    = Main.Locale
Main.Frame = {}

local Me          = ListenerAddon.Frame
local SharedMedia = LibStub("LibSharedMedia-3.0")

local CHAT_BUFFER_SIZE = 300
local CLICKBLOCK_TIME  = 0.4
local FADEOUT_DURATION = 1

local DEFAULT_LISTEN_EVENTS = {
	"SAY", "EMOTE", "TEXT_EMOTE", "YELL", 
	"PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
	"ROLL"
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
	INSTANCE_CHAT=1, INSTANCE_CHAT_LEADER=1, GUILD=1, OFFICER=1, CHANNEL=1;
	
	-- "<name> <msg>"
	EMOTE=2;
	
	-- "<name> <msg>" name is substituted
	TEXT_EMOTE=3; ROLL=3;
}

-------------------------------------------------------------------------------
-- Prefix behind name for these types of messages.
--
local MSG_FORMAT_PREFIX = {
	PARTY                 = "[P] ";
	PARTY_LEADER          = "[P] ";
	RAID                  = "[R] ";
	RAID_LEADER           = "[R] ";
	INSTANCE_CHAT         = "[I] ";
	INSTANCE_CHAT_LEADER  = "[I] ";
	GUILD                 = "[G] ";
	OFFICER               = "[O] ";
	RAID_WARNING          = "[RW] ";
	CHANNEL               = "[C] "
}

-------------------------------------------------------------------------------
-- Static methods
-------------------------------------------------------------------------------
local ENTRY_CHAT_REMAP = { ROLL = "SYSTEM" }
local function GetEntryColor( e )
	local info
	if e.c then
		local index = GetChannelName( e.c )
		info = ChatTypeInfo[ "CHANNEL" .. index ]
		if not info then info = ChatTypeInfo.CHANNEL end
		
	else
		local t = ENTRY_CHAT_REMAP[e.e] or e.e
		info = ChatTypeInfo[t]
		if not info then info = ChatTypeInfo.SAY end
	end
	return { info.r, info.g, info.b, 1 }
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
	self.top_unread_id = nil
	
	-- when a new messages is added, this saves the time
	-- if the user clicks on the frame at the moment a message is added, 
	-- its ignore to prevent error
	self.clickblock = 0
	
	-- textures used for the tab strips on the left side of the window
	self.tab_texes = {}
	
	-- for keeping track of line IDs in the chatbox
	-- (new id = chatid+1)
	self.chatid    = 0
	
	-- this is a list of things that we can pick from with the mouse
	self.pick_regions = {
		-- table of:
		-- { region = region, entry = entry }
	}
	
	-- cached auto_fade value
	self.auto_fade = 0
	self.auto_fade_opacity = 0
	
	-- time since last activity
	self.fade_time = 0
	
	-- this dictates that the mouse is being held over a region
	--self.picked = nil (too complex)
end

local function SplitOptions( self )
	if self.frame_index == 1 then return Main.db.profile.frame end
	return Main.db.char.frames[self.frame_index]
end

-------------------------------------------------------------------------------
local function PickTextRegion( self, setup_highlight )
	for _,v in pairs( self.pick_regions ) do
		if v.region:IsMouseOver() then
			if setup_highlight then
				self.chatbox.highlight:SetPoint( "TOP", v.region, "TOP" )
				self.chatbox.highlight:SetPoint( "BOTTOM", v.region, "BOTTOM" )
				self.chatbox.highlight:Show()
			end
			return v
		end
	end
	
	if setup_highlight and self.chatbox.highlight:IsShown() then
		self.chatbox.highlight:Hide()
	end
end

-------------------------------------------------------------------------------
-- Setup the frames that form the edge around the window.
--
local function CreateEdges( self )
	if self.edges then return end
	self.edges = {}
	for i = 1,4 do
		table.insert( self.edges, self:CreateTexture( "BORDER" ))
	end
	
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
	local point, region, point2, x, y = self:GetPoint(1)
	local width, height = self:GetSize()
	width  = math.floor( width + 0.5 )
	height = math.floor( height + 0.5 )
	if region then region = region:GetName() end
	
	local layout = {
		anchor = { point, region, point2, x, y };
		width  = width;
		height = height;
	}
	
	if self.frame_index == 1 then
		-- primary frame
		Main.db.profile.frame.layout = layout
	else
		-- other frame
		Main.db.char.frames[self.frame_index].layout = layout
	end
	
	LibStub("AceConfigRegistry-3.0"):NotifyChange( "Listener Frame Settings" )
end

-------------------------------------------------------------------------------
local function ShowOrHide( self, show, save )
	if show and not self:IsShown() then
		self.fade_time = GetTime()
		self:Show()
	elseif not show and self:IsShown() then
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
		return self.listen_events[ "#" .. entry.c ]
	end
	return self.listen_events[entry.e]
end

local TIMESTAMP = {
	
	-- HH:MM:SS
	[1] = function( t ) return date( "%H:%M:%S ", t ) end;
	
	-- HH:MM
	[2] = function( t ) return date( "%H:%M ", t ) end;
	
	-- HH:MM (12-hour)
	[3] = function( t ) return date( "%I:%M ", t ):gsub( "^0", "" ) end;
	
	-- MM:SS
	[4] = function( t ) return date( "%M:%S ", t ) end;
	
	-- MM
	[5] = function( t ) return date( "%M ", t ) end;
}

-------------------------------------------------------------------------------
local function FormatChatMessage( self, e )
	local msgtype = MSG_FORMAT_TYPES[e.e]
	
	local stamp = ""
	local ts = Main.db.profile.frame.timestamps
	if TIMESTAMP[ts] then
		stamp = "|cff808080" .. TIMESTAMP[ts](e.t) .. "|r" 
	end
	
	-- get icon and name 
	local name, icon, color = Main.GetICName( e.s, e.g )
	
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
		if e.e == "CHANNEL" then
			prefix = prefix:gsub( "C", (GetChannelName( e.c )) )
		end
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
	self.groups        = Main.db.char.frames[index].groups
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
function Method:UpdateVisibility()
	local hover = self:IsMouseOver( 8, -8, -8, 8 )
	
	local faded = self.auto_fade > 0 and GetTime() > self.fade_time + self.auto_fade
	
	self:ShowBar( hover or (Main.active_frame == self and not faded) )
	
	if self.auto_fade > 0 then
		local alpha = self:GetAlpha()
		local newalpha
		local time = GetTime()
		
		if hover then
			newalpha = 1
		else
			local fadeout_start = self.fade_time + self.auto_fade
			if time >= fadeout_start then
				if time - fadeout_start < FADEOUT_DURATION then
					local d = (time - fadeout_start) / FADEOUT_DURATION
					newalpha = 1 + (self.auto_fade_opacity - 1) * d
					
					
				else
					newalpha = self.auto_fade_opacity
					if Main.active_frame == self and self.frame_index ~= 1 then
						Main.SetActiveFrame( Main.frames[1] )
					end
				end
			else
				newalpha = 1
				
			end
		end
		
		if alpha ~= newalpha then
			self:SetAlpha( newalpha )
		end
	end
end

-------------------------------------------------------------------------------
function Method:ShowBar( show )
	if show and not self.bar2:IsShown() then
		self.bar2:Show()
		self.chatbox:SetPoint( "TOP", self.bar2, "BOTTOM", 0, -1 )
	elseif not show and self.bar2:IsShown() then
		self.bar2:Hide()
		self.chatbox:SetPoint( "TOP", self, 0, -2 )
	end
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
	self.auto_fade = Main.db.char.frames[self.frame_index].auto_fade or Main.db.profile.frame.auto_fade
	self.auto_fade_opacity = Main.db.profile.frame.auto_fade_opacity / 100
end

-------------------------------------------------------------------------------
function Method:ApplyColorOptions()
	if not Main.db.char.frames[self.frame_index].color then Main.db.char.frames[self.frame_index].color = {} end
	local bgcolor = Main.db.char.frames[self.frame_index].color.bg or Main.db.profile.frame.color.bg
	self.bg:SetColorTexture( unpack( bgcolor ))
	
	local edgecolor = Main.db.char.frames[self.frame_index].color.edge or Main.db.profile.frame.color.edge
	for k,v in pairs( self.edges ) do
		v:SetColorTexture( unpack( edgecolor )) 
	end
	
	local bar_color = Main.db.char.frames[self.frame_index].color.bar or Main.db.profile.frame.color.bar
	self.bar2.bg:SetColorTexture( unpack( bar_color ) )
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
	local anchor = layout.anchor
	if not anchor or #anchor == 0 then
		if self.frame_index == 1 then
			-- primary
			self:SetPoint( "LEFT", 50, 0 )
		else
			-- secondary
			self:SetPoint( "CENTER", 0, 0 )
		end
	else
		local region = anchor[2]
		if not region then
			region = UIParent
		else
			region = _G[region]
		end
		self:SetPoint( anchor[1], region, anchor[3], anchor[4], anchor[5] )
	end
	
	self:SetSize( math.max( layout.width, 50 ), 
	              math.max( layout.height, 50 ) )
				  
	
	-- setup edges
	local es = Main.db.profile.frame.edge_size
	if es == 0 then
		for _, edge in pairs( self.edges ) do
			edge:Hide()
		end
	else
		-- top
		self.edges[1]:SetPoint( "TOPLEFT",     self, "TOPLEFT",  -es, es )
		self.edges[1]:SetPoint( "BOTTOMRIGHT", self, "TOPRIGHT",  es, 0 )
		-- bottom
		self.edges[2]:SetPoint( "TOPLEFT",     self, "BOTTOMLEFT",  -es, 0 )
		self.edges[2]:SetPoint( "BOTTOMRIGHT", self, "BOTTOMRIGHT",  es, -es )
		-- left
		self.edges[3]:SetPoint( "TOPLEFT",     self, "TOPLEFT",    -es, 0 )
		self.edges[3]:SetPoint( "BOTTOMRIGHT", self, "BOTTOMLEFT", -0, 0 )
		-- right
		self.edges[4]:SetPoint( "TOPLEFT",     self, "TOPRIGHT",     0, 0 )
		self.edges[4]:SetPoint( "BOTTOMRIGHT", self, "BOTTOMRIGHT",  es, 0 )
		
		for _, edge in pairs( self.edges ) do
			edge:Show()
		end
	end
	
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
	
	local tabsize = Main.db.char.frames[self.frame_index].tab_size
	                or Main.db.profile.frame.tab_size
	
	self.chatbox:SetPoint( "LEFT", self, "LEFT", 2 + tabsize, 0 )
	
	--local time_visible = Main.db.char.frames[self.frame_index].time_visible 
	--                     or Main.db.profile.frame.time_visible
--[[	if time_visible == 0 then
		self.chatbox:SetFading( false )
	else
		self.chatbox:SetFading( true )
		self.chatbox:SetFadeDuration( 3.0 )
		self.chatbox:SetTimeVisible( time_visible )
	end]]
end

-------------------------------------------------------------------------------
-- Options for the title bar.
--
function Method:ApplyBarOptions()

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
-- Returns true if this entry is displayed.
--
function Method:ShowsEntry( entry )
	return EntryFilter( self, entry )
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
	-- filter path:
	-- global (listenall) -> group -> player
	--
	local f = self.players[name]
	
	if IsInRaid() then
		local g = Main.raid_groups[name]
		if g then
			-- if f is default then try using group filter
			f = f or self.groups[g]
		end
	end
	
	return f == 1 or (Main.db.char.frames[self.frame_index].listen_all and f ~= 0)
end

function Method:ResetGroupsFilter()
	for k,_ in pairs( self.groups ) do
		self.groups[k] = nil
	end
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

	local title = "—"
	local on = false
	
	if Main.active_frame == self then
		local target, guid = Main:GetProbed()
		
		if target then
			
			on = self:ListeningTo( target )
			
			local name, icon, color = Main.GetICName( target, guid )
			title = " " .. name
			
		end
	end
	
	self.bar2.title:SetText( title )
	
	if on then
		self.bar2.toggle_button:Show()
	else
		self.bar2.toggle_button:Hide()
	end
	
	if Main.db.profile.frame.color.tab_target[4] > 0 then
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
	
	self.fade_time = GetTime()
	
	-- autopopup
	if not self:IsShown() then
		local autopopup = self.frame_index == 1 and Main.db.profile.frame.auto_popup
		                                         or Main.db.char.frames[self.frame_index].auto_popup
		if autopopup then
			if Main.db.char.frames[self.frame_index].combathide and InCombatLockdown() then
				-- if we're in combat, just clear the hidden flag
				-- so that it opens when we exit combat
				Main.db.char.frames[self.frame_index].hidden = false
			else
				self:Open()
			end
		end
	end
	
	self.chatid = self.chatid + 1
	
	table.insert( self.chat_buffer, { e = e, c = self.chatid } ) 
	while #self.chat_buffer > CHAT_BUFFER_SIZE do 
		table.remove( self.chat_buffer, 1 )
	end
	
	local hidden = not self:ListeningTo( e.s )
	
	if e.r and not e.p and not hidden then -- not read and not from the player and not hidden
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
		if EntryFilter( self, k ) and self:ListeningTo( k.s ) then
			if not id or k.id < id then
				id = k.id
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
	
	self.readmark:SetColorTexture( unpack( Main.db.profile.frame.color.readmark ) )
	if region then
		
		-- set the marker here
		local point = region:GetTop() - self.chatbox:GetBottom()
		if point > self.chatbox:GetHeight()+1  then 
			--point = self.chatbox:GetHeight() 
			--self.readmark:SetHeight( 2 )
			self.readmark:Hide()
			return
		else
			self.readmark:SetHeight( 1 )
		end
		self.readmark:SetPoint( "TOP", self.chatbox, "BOTTOM", 0, point )
		self.readmark:Show()
		
	elseif self.top_unread_id then
		
		if first_id < self.top_unread_id then
			-- past the bottom
			self.readmark:SetHeight( 2 )
			self.readmark:SetPoint( "TOP", self, "BOTTOM", 0, 3 )
		else
			-- past the top
			
			self.readmark:Hide()
			return
			--self.readmark:SetPoint( "TOP", self.chatbox, "BOTTOM", 0, self.chatbox:GetHeight() - 1 )
		end
		self.readmark:Show()
		
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
	
	local tabsize = Main.db.char.frames[self.frame_index].tab_size
	                or Main.db.profile.frame.tab_size
					
	-- we'll build the pick_regions table in here too!
	local pick_regions = {}
	
	for k,v in ipairs( regions ) do
		local e = self.chat_buffer[chat_index]
		
		if not e then break end
		e = e.e
		
		if v:GetBottom() < top_edge then -- within the chatbox only
		
			table.insert( pick_regions, { region = v, entry = e } )
		
			local hidden = not self:ListeningTo( e.s )
			v:SetAlpha( hidden and 0.35 or 1.0 )
			
			if e.id == self.top_unread_id then
				first_unread_region = v
			end
			
			local targeted = (Main.GetProbed() == e.s) and (Main.db.profile.frame.color.tab_target[4] > 0)

			if tabsize > 0 and targeted or e.p or e.h then
				-- setup block
				count = count + 1
				if not self.tab_texes[count] then
					self.tab_texes[count] = self:CreateTexture() 
				end 
				local tex = self.tab_texes[count]
				
				tex:ClearAllPoints()
				tex:SetPoint( "LEFT", v, "LEFT", -1 - tabsize, 0 )
				tex:SetPoint( "RIGHT", v, "LEFT", -1, 0 )
				tex:SetPoint( "BOTTOM", v, "BOTTOM", 0, 0 )
				
				local clip = math.max( v:GetTop() - top_edge, 0 )
				
				tex:SetPoint( "TOP", v, "TOP", 0, -clip )
				tex:SetBlendMode( "BLEND" )
				if e.h then
					tex:SetColorTexture( unpack( Main.db.profile.frame.color.tab_marked ) )
				elseif e.p then
					tex:SetColorTexture( unpack( Main.db.profile.frame.color.tab_self ) )
				elseif targeted then
					tex:SetColorTexture( unpack( Main.db.profile.frame.color.tab_target ) )
				end
				tex:Show()	
			end
		end

		chat_index = chat_index - 1
	end
	
	self.pick_regions = pick_regions
	
	local e = self.chat_buffer[chat_index_start]
	if e then e = e.e end
	if e and (Main.db.profile.frame.color.readmark[4] > 0) and Main.db.char.frames[self.frame_index].readmark then
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
	for i = Main.next_lineid-1, Main.first_lineid, -1 do
		local entry = Main.chatlist[i]
		if entry then
			if EntryFilter( self, entry ) then
				
				if showhidden or self:ListeningTo( entry.s ) then
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
		if bg then self.db.profile.frame.color.bg = bg end
		if edge then self.db.profile.frame.color.edge = edge end
		if bar then self.db.profile.frame.color.bar = bar end
	else
		if bg then self.db.char.frames[self.frame_index].color.bg = bg end
		if edge then self.db.char.frames[self.frame_index].color.edge = edge end
		if bar then self.db.char.frames[self.frame_index].color.bar = bar end
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
function Method:CombatHide( combat )
	if combat then
		if Main.db.char.frames[self.frame_index].combathide then
			self:Close( true )
		end
	else
		if not Main.db.char.frames[self.frame_index].hidden then
			self:Open( true )
		end
	end
end

-------------------------------------------------------------------------------
function Method:OpenConfig()
	Main.OpenFrameConfig( self )
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
	CreateEdges( self )
	
	hooksecurefunc( self.chatbox, "RefreshDisplay", function()
		Me.OnChatboxRefresh( self )
	end)
end

-------------------------------------------------------------------------------
function Me.OnEnter( self )
	self.show_highlight = true
	self:UpdateResizeShow()
end

-------------------------------------------------------------------------------
function Me.OnLeave( self )
	self.show_highlight = false
	self:UpdateResizeShow()
end

-------------------------------------------------------------------------------
function Me.OnUpdate( self )
	self:UpdateVisibility()
	
	local picked = nil
	
	if Main.active_frame == self 
	   and self.show_highlight
	   and not (self.auto_fade > 0 and GetTime() > self.fade_time + self.auto_fade) then
		-- do some picking
		picked = PickTextRegion( self, true )
	else
		if self.chatbox.highlight:IsShown() then
			self.chatbox.highlight:Hide()
		end
	end
end

-------------------------------------------------------------------------------
function Me.OnMouseDown( self, button )
	local active = Main.active_frame == self
	
	
	if not active then
		Main.SetActiveFrame( self )
	end
	
	local faded = false

	if self.auto_fade > 0 and GetTime() > self.fade_time + self.auto_fade then
		faded = true
	end
	
	if active and GetTime() > self.clickblock + CLICKBLOCK_TIME and not faded then
		local p = PickTextRegion( self, false )
		if p then
			if button == "LeftButton" then
				Main.HighlightEntry( p.entry, not p.entry.h )
			elseif button == "RightButton" then
				if IsShiftKeyDown() then
					self:TogglePlayer( p.entry.s )
				end
			end
		end
	end
	
	self.fade_time = GetTime()
end

-------------------------------------------------------------------------------
function Me.OnMouseUp( self )

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
	
	self.fade_time = GetTime()
end

-------------------------------------------------------------------------------
local g_listener_copylink_text = ""
StaticPopupDialogs["LISTENER_COPYLINK"] = {
	text                   = L["Copy Link"];
	button1                = L["Got it!"];
	timeout                = 0,
	whileDead              = true,
	hideOnEscape           = true,
	enterClicksFirstButton = true,
	hasEditBox             = true,
	
	OnShow = function ( self )
		self.editBox:SetText( g_listener_copylink_text )
		self.editBox:HighlightText()
	end
}

-------------------------------------------------------------------------------
function Me.OnChatboxHyperlinkClick( self, link, text, button )
	if GetTime() < self.clickblock + CLICKBLOCK_TIME then
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
	
	if link == "lrurl" then
		g_listener_copylink_text = text:match( "url|h(%S+)|h|r$" )
		StaticPopup_Show( "LISTENER_COPYLINK" )
		return
	end
	
	SetItemRef( link, text, button, DEFAULT_CHAT_FRAME );
	
	self.fade_time = GetTime()
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
function Me.BarMouseDown( self )
	self.fade_time = GetTime()
	Main.SelectFrame( self )
end

function Me.BarMouseUp( self ) end

function Me.BarDragStart( self )
	if not SplitOptions(self).locked then
		self:StartDragging()
	end
end

function Me.BarDragStop( self )
	self:StopDragging()
	self.fade_time = GetTime()
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
	-- only initialize things that are per-character options
	-- don't initialize things that you don't want in the
	-- primary frame's options
	
	local data = {
		players    = {};
		groups     = {};
		listen_all = true;
		filter     = {}; -- filled in below
		showhidden = true;
		layout     = {
			anchor   = {};
			width    = 200;
			height   = 300;
		};
		hidden       = false;
		color        = {};
		combathide   = true;
		readmark     = true;
	}
	
	for k,v in pairs( DEFAULT_LISTEN_EVENTS ) do
		data.filter[v] = true
	end
	
	data.players[ UnitName("player") ] = 1
	
	Main.db.char.frames[index] = data
end

-------------------------------------------------------------------------------
-- Apply the globally set options (ones that affect all frames, like the
-- titlebar font).
--
function Me.ApplyGlobalOptions()
	
	-- bar font
	local font = SharedMedia:Fetch( "font", Main.db.profile.frame.barfont.face )
	ListenerBarFont:SetFont( font, Main.db.profile.frame.barfont.size )
	
end
