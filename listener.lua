-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
-------------------------------------------------------------------------------
 
local Main = ListenerAddon 
local L    = Main.Locale
local SharedMedia = LibStub("LibSharedMedia-3.0")

local g_history_size = 50

local g_loadtime = 0

-- english is "%s rolls %d (%d-%d)";
local SYSTEM_ROLL_PATTERN = RANDOM_ROLL_RESULT 

SYSTEM_ROLL_PATTERN = SYSTEM_ROLL_PATTERN:gsub( "%%s", "(%%S+)" )
SYSTEM_ROLL_PATTERN = SYSTEM_ROLL_PATTERN:gsub( "%%d", "(%%d+)" )
SYSTEM_ROLL_PATTERN = SYSTEM_ROLL_PATTERN:gsub( "%(%(%%d%+%)%-%(%%d%+%)%)", "%%((%%d+)%%-(%%d+)%%)" ) -- this is what we call voodoo?

--[[
 Chat history database:
    Main.chat_history = {
		[playername] = {
			[max_messages] = {  -- previous message history
				id = line id
				t = time received (unixtime)
				e = event type
				m = message
				r = message has been read
				s = sender
			}
		}
	}
	Main.chatlist = { -- list of chat messages
	  [lineid] = event reference
	}
]]

--[[
  Player Filter Data (player_list) = {
    [playername] = 1   (show in window)
	               0   (remove from window)
				   nil (default setting)
  }
]]

Main.unread_entries = {}
Main.RPConnect      = true -- enable RP Connect support
Main.next_lineid    = 1
 
-------------------------------------------------------------------------------		  
function Main:OnInitialize() 
	SLASH_LISTENER1 = "/listener"
	SLASH_LISTENER2 = "/lr"
end

-------------------------------------------------------------------------------
function Main:CleanChatHistory()
	ListenerChatHistory = ListenerChatHistory or {}
	Main.chatlist = {}
	
	if ListenerChatHistory.version ~= Main.version then
		-- old version, drop history
		ListenerChatHistory = { 
			version = Main.version;
			data    = {};
		}
		self.chat_history = ListenerChatHistory.data
		return
	end
	
	Main.chat_history = ListenerChatHistory.data
	
	local time = time()
	local expiry = 60*30 -- 30 mins
	
	-- we want to find the highest lineid so we can continue
	-- (it should reset overnight!)
	local max_lineid = 0
	
	for playername,chat_table in pairs( ListenerChatHistory.data ) do
		local writeto = 1
		
		for i = 1, #chat_table do
			if chat_table[i] then
				chat_table[i].r = true
				
				if time > chat_table[i].t + expiry then
					chat_table[i] = nil
				else
					local a = chat_table[i]
					chat_table[i] = nil
					chat_table[writeto] = a
					max_lineid = math.max( a.id, max_lineid )
					writeto = writeto + 1
					
					Main.chatlist[ a.id ] = a
				end
			end
		end
		 
		-- if the list is empty, delete the player from the history
		if #chat_table == 0 then
			self.chat_history[playername] = nil 
		end
	end
	 
	Main.next_lineid = max_lineid + 1
end

-------------------------------------------------------------------------------
-- Reset player filters with no chat history.
--
function Main:CleanPlayerList()

	for k,v in pairs(self.player_list) do
		if not self.chat_history[k] then
			self.player_list[k] = nil
		end
	end 
end

-------------------------------------------------------------------------------
-- Scan friends list and add them to the filter.
--
function Main:AddFriendsList()
	for i = 1, GetNumFriends() do
		local name = GetFriendInfo( i )
		if name and name ~= "Unknown" then
			self.player_list[name] = 1
		end
	end
end

-------------------------------------------------------------------------------
-- Prepare showing a tooltip for a frame.
--
function Main:StartTooltip( frame )
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
	
end

-------------------------------------------------------------------------------
local function FrameTooltip_Start( self )
	Main:StartTooltip( self )
	self.tooltip_func( self )
	GameTooltip:Show()
end

-------------------------------------------------------------------------------
local function FrameTooltip_End()
	GameTooltip:Hide()
end

-------------------------------------------------------------------------------
local function FrameTooltip_Refresh( self )
	if GameTooltip:GetOwner() == self and GameTooltip:IsShown() then
		GameTooltip:ClearLines()
		self.tooltip_func( self )
		GameTooltip:Show()
	end
end

-------------------------------------------------------------------------------
function Main:SetupTooltip( frame, func )
	frame.tooltip_func = func
	frame:SetScript( "OnEnter", FrameTooltip_Start )
	frame:SetScript( "OnLeave", FrameTooltip_End ) 
	frame.RefreshTooltip = FrameTooltip_Refresh
end	

-------------------------------------------------------------------------------
local g_probe_frame
local g_probe_target
local g_probe_mouse

function Main:SetupProbe()
	if g_probe_frame then error( "no" ) end
	g_probe_frame = CreateFrame("Frame")
	g_probe_frame:SetScript( "OnUpdate", function()
		local target, mouseover = UnitName("target"), UnitName("mouseover")
		if (target or mouseover) ~= g_probe_target then 
			g_probe_target = (target or mouseover)
			
			Main:ProbePlayer( g_probe_target )
		end
		
		if mouseover ~= g_probe_mouse then
			g_probe_mouse = mouseover
			Main:HighlightMouseover( g_probe_mouse )
		end
	end)
	g_probe_frame:Show()
end

-------------------------------------------------------------------------------
function Main.SetupBindingText()
	_G["BINDING_NAME_LISTENER_TOGGLEFILTER"] = L["Toggle Player Filter"]
	_G["BINDING_NAME_LISTENER_MARKUNREAD"]   = L["Mark Messages as Read"]
	_G["BINDING_HEADER_LISTENER"]            = L["Listener"]
end

-------------------------------------------------------------------------------
function Main:OnEnable()

	Main.SetupBindingText()

	self:CleanChatHistory() 
	self:Setup()
	self:CreateDB()

	self.MinimapButton:OnLoad()
	
	self.player_list = self.db.char.player_list
	
	self:CleanPlayerList()
	
	self:AddFriendsList()
	g_loadtime = GetTime()
	self:RegisterEvent( "FRIENDLIST_UPDATE", "OnFriendlistUpdate" )

	self:RegisterEvent( "CHAT_MSG_SAY", "OnChatMsg" )
	self:RegisterEvent( "CHAT_MSG_EMOTE", "OnChatMsg" )
	self:RegisterEvent( "CHAT_MSG_TEXT_EMOTE", "OnChatMsg" )
--	self:RegisterEvent( "CHAT_MSG_WHISPER", "OnChatMsg" )
--	self:RegisterEvent( "CHAT_MSG_WHISPER_INFORM", "OnChatMsg" )
	self:RegisterEvent( "CHAT_MSG_PARTY", "OnChatMsg" )
	self:RegisterEvent( "CHAT_MSG_PARTY_LEADER", "OnChatMsg" )
	self:RegisterEvent( "CHAT_MSG_RAID", "OnChatMsg" )
	self:RegisterEvent( "CHAT_MSG_RAID_LEADER", "OnChatMsg" )
	self:RegisterEvent( "CHAT_MSG_RAID_WARNING", "OnChatMsg" )
	self:RegisterEvent( "CHAT_MSG_YELL", "OnChatMsg" )
	self:RegisterEvent( "CHAT_MSG_SYSTEM", "OnSystemMsg" )
	self:RegisterMessage( "DiceMaster4_Roll", "OnDiceMasterRoll" )
	
	-- just create a stupid frame for this
	
	--self:RegisterEvent( "UPDATE_MOUSEOVER_UNIT", "OnProbeUpdate" )
	--self:RegisterEvent( "PLAYER_TARGET_CHANGED", "OnProbeUpdate" )
	
	self:RegisterEvent( "PLAYER_REGEN_DISABLED", "OnEnterCombat" )
	self:RegisterEvent( "PLAYER_REGEN_ENABLED", "OnLeaveCombat" )
	
	self:RegisterEvent( "MODIFIER_STATE_CHANGED", "OnModifierChanged" )
	  

	self:Print( L["Version:"] .. " " .. self.version )
	   
	self:ApplyConfig()

	
	self:Snoop_Setup()
	
	self:Init_OnEnabled()
	Main:SetupProbe()
	self:RefreshChat()
end

-------------------------------------------------------------------------------
function Main:OnModifierChanged( evt, key, state )

	if key == "LSHIFT" or key == "RSHIFT" then
		Main.Frame_UpdateResizeShow()
		
		-- allow/disable dragging
		if IsShiftKeyDown() then
			ListenerFrame:EnableMouse( true )
		else
			ListenerFrame:EnableMouse( false )
			Main.Frame_StopDragging()
		end
	end
end

-------------------------------------------------------------------------------
--function Main:OnProbeUpdate()
--	self:ProbePlayer()
--end

-------------------------------------------------------------------------------
function Main:OnFriendlistUpdate()
	-- if this event occurs 30 seconds within load time, then we
	-- wanna update our initial friends list adding
	if GetTime() - g_loadtime < 30 then
		Main:AddFriendsList()
	end
end

-------------------------------------------------------------------------------
function Main:FlashClient()
	if Main.db.profile.flashclient then
		FlashClientIcon()
	end
end

-------------------------------------------------------------------------------
local g_message_beep_cd = 0
function Main:PlayMessageBeep()

	-- we want to only play a beep if a beep hasn't tried to play in the last X seconds
	-- in other words, if there is a constant stream of spam, no beeps will play
	
	-- we moved the flash client bit outside so that if someone is tabbed out
	-- they arent going to miss a message because of this
	if GetTime() < g_message_beep_cd + Main.db.profile.beeptime then
		g_message_beep_cd = GetTime()
		return
	end
	g_message_beep_cd = GetTime()
	
	PlaySoundFile( SharedMedia:Fetch( "sound", "ListenerBeep" ), "Master" )
end

-------------------------------------------------------------------------------
-- Check if someone has used a text emote on us and then act accordingly.
-- 
-- @param msg Contents of text emote.
--
function Main:CheckPoke( msg, sender )
	if not Main.db.profile.sound.poke then return end
	
	sender = sender:gsub( "-.*", "" )
	local loc = GetLocale()
	if loc == "enUS" then
		if msg:find( " you" ) then
			--if ListenerFrame:IsShown() and self.player_list[sender] then return end
			if UnitName('target') == sender then return end
			if msg:find( "orders you to open fire." ) then return end
			if msg:find( "asks you to wait." ) then return end
			if msg:find( "tells you to attack" ) then return end
		
			PlaySoundFile( SharedMedia:Fetch( "sound", "ListenerPoke" ), "Master" )
			Main:FlashClient()
		end
	end
end

-------------------------------------------------------------------------------
-- Hook for DiceMaster4 roll messages.
--
function Main:OnDiceMasterRoll( event, sender, message )
	self:AddChatHistory( sender, "ROLL", message )
	self:Snoop_DoUpdate( sender )
end

-------------------------------------------------------------------------------
-- Hook for system messages (player rolls)
--
function Main:OnSystemMsg( event, message )
	if DiceMaster4 then
		-- user is using DiceMaster4, and we should instead listen for dicemaster events
		return
	end
	
	local sender, roll, min, max = message:match( SYSTEM_ROLL_PATTERN )
	if sender then
		-- this is a roll message
		self:AddChatHistory( sender, "ROLL", message )
		self:Snoop_DoUpdate( sender )
	end
end

-------------------------------------------------------------------------------
function Main:OnChatMsg( event, message, sender, language, a4, a5, a6, a7, a8, a9, a10, a11, guid, a13, a14 )
	local filters = ChatFrame_GetMessageEventFilters( event )
	event = event:sub( 10 )
	if event == "TEXT_EMOTE" then
		if guid ~= UnitGUID( "player" ) then
			Main:CheckPoke( message, sender )
		end
	end
	
	if filters then 
		local skipfilters = false

		if message:sub(1,3) == "|| " then
			-- trp hack for npc emotes
			skipfilters = true
		elseif message:sub(1,2) == "'s" and event == "EMOTE" then
			-- trp hack for 's stuff
		--	skipfilters = true
		end
		
		if not skipfilters then
			for _, filterFunc in next, filters do
				local block, na1, na2, na3, na4, na5, na6, na7, na8, na9, na10, na11, na12, na13, na14 = filterFunc( ListenerFrameChat, "CHAT_MSG_"..event, message, sender, language, a4, a5, a6, a7, a8, a9, a10, a11, guid, a13, a14 )
				if( block ) then
					return
				elseif( na1 and type(na1) == "string" ) then
					local skip = false
					if event == "EMOTE" and message:sub(1,2) == "'s" and na1:sub(1,2) ~= "'s" then
						skip = true -- block out trp's ['s] hack
					end
					if event == "EMOTE" and message:sub(1,2) == ", " and na1:sub(1,2) ~= ", " then
						skip = true -- block out trp's [, ] hack
					end
					  
					if not skip then
						message, sender, language, a4, a5, a6, a7, a8, a9, a10, a11, guid, a13, a14 = na1, na2, na3, na4, na5, na6, na7, na8, na9, na10, na11, na12, na13, na14
					end
				end
			end
		end
	end
	
	self:AddChatHistory( sender, event, message, language, guid )
	self:Snoop_DoUpdate( sender )
end

-------------------------------------------------------------------------------
local function GetTRPCharacterInfo( name )
	
	local char, realm = TRP3_API.utils.str.unitIDToInfo( name )
	if not realm then
		realm = TRP3_API.globals.player_realm_id
	end
	name = TRP3_API.utils.str.unitInfoToID( char, realm )
	
	if name == TRP3_API.globals.player_id then
		return TRP3_API.profile.getData("player");
	elseif TRP3_API.register.isUnitIDKnown( name ) then
		return TRP3_API.register.getUnitIDCurrentProfile( name ) or {};
	end
	return {};
end

-------------------------------------------------------------------------------
local function GetCharacterClassColor( guid )
	  
	local _, cls = GetPlayerInfoByGUID( guid )
	if cls and RAID_CLASS_COLORS[cls] then
		local c = RAID_CLASS_COLORS[cls]
		return ("|cff%.2x%.2x%.2x"):format(c.r*255, c.g*255, c.b*255)
	end
end

-------------------------------------------------------------------------------
function Main:OnEnterCombat()
	if self.db.profile.combathide then
		self:HideFrame( true )
	end
end

-------------------------------------------------------------------------------
function Main:OnLeaveCombat()
	if self.db.profile.combathide and not self.db.profile.frame.hidden then
		self:ShowFrame( true )
	end
end

-------------------------------------------------------------------------------
local RAID_TARGETS = { 
	star     = 1; rt1 = 1;
	circle   = 2; rt2 = 2;
	diamond  = 3; rt3 = 3;
	triangle = 4; rt4 = 4;
	moon     = 5; rt5 = 5;
	square   = 6; rt6 = 6;
	x        = 7; rt7 = 7;
	cross    = 7; 
	skull    = 8; rt8 = 8;
}

-------------------------------------------------------------------------------
-- Substitute raid target keywords with textures.
--
local function SubRaidTargets( message )
	message = message:gsub( "{(%S-)}", function( term )
		term = term:lower()
		local t = RAID_TARGETS[term]
		if t then
			return "|TInterface/TargetingFrame/UI-RaidTargetingIcon_" .. t .. ":0|t"
		end 
	end)
	return message
end

-------------------------------------------------------------------------------
function Main:AddChatHistory( sender, event, message, language, guid )
 
	--local time = date("*t")
	--time = string.format( "[%02d:%02d]", time.hour, time.min );
	
	local original_sender = sender
	
	if message == "" then return end
	
	-- just strip the realm. collisions are -very- rare, and it just
	-- messes things up
	sender = sender:gsub( "-.*", "" )
	
	self.chat_history[sender] = self.chat_history[sender] or {}
	
	local isplayer = sender == UnitName("player")
	
	---------------------------------------------------------------------------
	-- Language Filter
	---------------------------------------------------------------------------
	local langdef = language -- langdef is language or default language
	if not langdef or langdef == "" then langdef = GetDefaultLanguage() end
	
	if Main.LanguageFilter and not isplayer then
		-- language filter option enabled
	
		if Main.LanguageFilter.known[langdef] then
			-- mark this sender as understandable, they've spoken in our languages
			Main.LanguageFilter.emotes[sender] = true
		end
		
		if event == "SAY" and not Main.LanguageFilter.known[langdef] then
			-- feature to block out unknown languages
			 
			local oocmarks = { "{{", "}}", "%[%[", "%]%]", "%(%(", "%)" }
			local ooc = false
			
			for k,v in pairs(oocmarks) do
				if message:find( v ) then ooc = true break end
			end
			
			if not ooc then
			
				if message:sub(1,1) == '"' then
					message = message:gsub( [[".-[-,.?~]"]], '"<' .. langdef .. '>"' )
				else
					message = "<" .. langdef .. ">"
				end
			end
		end
		
		if event == "EMOTE" and not Main.LanguageFilter.emotes[sender] then
			-- cut out speech from unknown emotes
			message = message:gsub( [[".-[-,.?~]"]], '"<' .. langdef .. '>"' )
		end
	end
	
	if language and language ~= GetDefaultLanguage() and language ~= "" then
		message = string.format( "[%s] %s", language, message )
	end
	---------------------------------------------------------------------------
	
	---------------------------------------------------------------------------
	-- RPConnect splitter
	---------------------------------------------------------------------------
	if Main.RPConnect and event == "PARTY" or event == "RAID" or event == "RAID_LEADER" then
		local name = message:match( "^<%[(.+)%]" )
		if name and not UnitName( name ) then
			-- we found the RP Connect pattern for a relayed message
			-- crop the message and change the sender
			message = message:sub( #name+6 )
			sender = name
			event = "RAID"
			self.chat_history[sender] = self.chat_history[sender] or {}
		end
	end
	---------------------------------------------------------------------------
	
	message = SubRaidTargets( message )
	
	local entry = {
		id = Main.next_lineid;
		t  = time();
		e  = event;
		m  = message;
		s  = sender;
		g  = guid;
	}
	
	if isplayer then
		entry.p = true -- is player
		entry.r = true -- read
	end
	if event == "YELL" then
		entry.r = true -- yells dont cause unread messages
	end
	
	Main.chatlist[entry.id] = entry
	Main.next_lineid = Main.next_lineid + 1
	
	table.insert( self.chat_history[sender], entry )
	
	while #self.chat_history[sender] > g_history_size do
		table.remove( self.chat_history[sender], 1 )
	end
	
	if not entry.r then
		table.insert( self.unread_entries, entry )
	end
	 
	
	if entry.p then
		-- player is posting...
	--	if event == "SAY" or event == "EMOTE" or event == "TEXT_EMOTE" then
			-- player is publicly emoting, clear read status
			Main:MarkAllRead( true ) 
	--	end
	end
	
	-- if the player's target emotes, then beep+flash
	if Main.db.profile.sound.target and (UnitName("target") == sender or (guid and guid == UnitGUID( "target" ))) and not isplayer then
		
		Main:PlayMessageBeep()
		Main:FlashClient()
	end
 
	if ((Main.db.char.showhidden or Main.player_list[sender] == 1 or (Main.db.char.listen_all and Main.player_list[sender] ~= 0)) or isplayer) then
		 
		Main:AddMessage( entry, true )
	
		Main:UpdateHighlight()
	end
end

function Main:ToggleCommand( arg, command )
	
	if arg == nil and UnitIsPlayer( "target" ) then
		arg = UnitName( "target" )
	end
	if arg == nil and UnitIsPlayer( "mouseover" ) then
		arg = UnitName( "mouseover" )
	end
	if arg == nil then
		Main:Print( L["Specify name or target someone."] )
		return
	end
	
	if command == "add" then
		Main:AddPlayer( arg )
	elseif command == "remove" then
		Main:RemovePlayer( arg )
	elseif command == "toggle" then
		Main:TogglePlayer( arg )
	end
end

-------------------------------------------------------------------------------
function SlashCmdList.LISTENER( msg )
	local args = {}
	
	for i in string.gmatch( msg, "%S+" ) do
		table.insert( args, i )
	end
	
	if args[1] == nil then
		Main:OpenConfig()
		return
	end
	
	if args[1] ~= nil then args[1] = string.lower( args[1] ) end
	
	if args[1] == "read" or args[1] == L["read"] then
		
	elseif args[1] == "add" or args[1] == L["add"] then
	
		Main:ToggleCommand( args[2], "add" )
		
	elseif args[1] == "remove" or args[1] == L["remove"] then
	
		Main:ToggleCommand( args[2], "remove" )
		
	elseif args[1] == "toggle" or args[1] == L["toggle"] then
	
		Main:ToggleCommand( args[2], "toggle" )
		
	elseif args[1] == "clear" or args[1] == L["clear"] then
	
		Main:ClearAllPlayers()
		
	elseif args[1] == "list" or args[1] == L["list"] then
	
		Main:ListPlayers()
	
	elseif args[1] == "show" or args[1] == L["show"] then
	
		Main:ShowFrame()

	elseif args[1] == "hide" or args[1] == L["hide"] then
		
		Main:HideFrame()
	
	end  
end

-------------------------------------------------------------------------------
-- Set Listen All mode. (default filter mode)
--
function Main:SetListenAll( listen_all )
	listen_all = not not listen_all
	if Main.db.char.listen_all == listen_all then return end
	
	Main.db.char.listen_all = listen_all
	
	Main:RefreshChat() 
	Main:ProbePlayer()
	ListenerFrameBarToggle:RefreshTooltip()
end

-------------------------------------------------------------------------------
-- Enable/disable showing filtered out players.
--
function Main:SetShowHidden( showhidden )
	showhidden = not not showhidden
	if Main.db.char.showhidden == showhidden then return end
	Main.db.char.showhidden = showhidden
	
	Main:RefreshChat() 
	ListenerFrameBarToggle:RefreshTooltip()
end

-------------------------------------------------------------------------------
-- Clean a name so that it starts with a capital letter.
--
local function FixupName( name )
	name = name:lower()
	
	-- strip realm
	name = name:gsub( "-.*", "" )
	  
	-- (utf8 friendly) capitalize first character
	name = name:gsub("^[%z\1-\127\194-\244][\128-\191]*", string.upper)
	return name
end
 
-------------------------------------------------------------------------------
-- Add or remove player to listening filter
-- 
-- @param name   Name of player or GROUP for all players in group.
-- @param mode   1 = add player; 0 = remove player; nil = reset player.
-- @param silent Don't print chat messages.
--
function Main:AddOrRemovePlayer( name, mode, silent )
	if mode ~= 1 and mode ~= 0 and mode ~= nil then error( "Invalid mode." ) end
	name = FixupName( name )
	if name == UnitName( "player" ) then return end -- do nothing if they try to toggle the player
	
	if name == "Group" then
		if not IsInGroup( LE_PARTY_CATEGORY_HOME ) then
			Main:Print( L["You aren't in a group."] )
			return
		end
		
		if not silent then 
			if mode == 1 then
				self:Print( L["Adding all in group."] )
			elseif mode == 0 then
				self:Print( L["Removing all in group."] )
			else
				self:Print( L["Resetting all in group."] )
			end
		end
		
		if IsInRaid() then
			for i = 1,40 do
				local name = UnitName( "raid" .. i )
				if name and name ~= UnitName("player") then
					self.player_list[name] = mode
				end
			end
		else
			for i = 1,5 do
				local name = UnitName( "party" .. i )
				if name and name ~= UnitName("player") then
					self.player_list[name] = mode
				end
			end
		end
		
	else
		
		if self.player_list[name] == mode then
			if not silent then
				if mode == 1 then
					self:Print( string.format( L["Already listening to %s."], name ) ) 
				elseif mode == 0 then
					self:Print( string.format( L["%s is already filtered out."], name ) ) 
				else
					self:Print( string.format( L["%s wasn't found."], name ) ) 
				end
			end
			
			return
		end
		
		self.player_list[name] = mode
		if not silent then 
			if mode == 1 then
				self:Print( string.format( L["Added %s."], name ) ) 
			elseif mode == 0 then
				self:Print( string.format( L["Removed %s."], name ) ) 
			else
				self:Print( string.format( L["Reset %s."], name ) ) 
			end
		end
			
	end
	
	Main:RefreshChat() 
	Main:ProbePlayer()
	ListenerFrameBarToggle:RefreshTooltip()
end

------------------------------------------------------------------------------- 
function Main:AddPlayer( name, silent )
	Main:AddOrRemovePlayer( name, 1, silent ) 
end

-------------------------------------------------------------------------------
function Main:RemovePlayer( name, silent )
	Main:AddOrRemovePlayer( name, 0, silent ) 
end

-------------------------------------------------------------------------------
function Main:TogglePlayer( name, silent )
	if name:lower() == "group" then 
		Main:Print( L["Cannot toggle group. Use add or remove."] ) 
		return
	end
	
	if Main.player_list[name] == 1 then
		self:RemovePlayer( name, silent )
	elseif Main.player_list[name] == 0 then
		self:AddPlayer( name, silent )
	else 
		if Main.db.char.listen_all then
			self:RemovePlayer( name, silent )
		else
			self:AddPlayer( name, silent )
		end
	end 
end

-------------------------------------------------------------------------------
-- Mark all new messages as "read".
--
-- @param forcerefresh Force CheckUnread, UpdateUnreadHighlight (I DONT know what this is for.)
--
function Main:MarkAllRead( forcerefresh )
 
	if #self.unread_entries == 0 and not forcerefresh then return end
	
	ListenerFrameBarRead:SetOn( false ) 
	local new_list = {}
	
	local time = time()
	for k,v in pairs( self.unread_entries ) do
		if time < v.t + 4 then
			-- we dont mark messages that arent 4 seconds old
			-- since theyre pretty fresh and probably not read yet!
			table.insert( new_list, v )
		else	
			v.r = true 
		end
	end
	self.unread_entries = new_list
	Main:CheckUnread()
	Main:UpdateHighlight()
	
	ListenerFrameBarRead:RefreshTooltip()
end

-------------------------------------------------------------------------------
-- Reset the player filter.
--
function Main:ClearAllPlayers()
	wipe( self.player_list )
	self:Print( L["Reset filter."] )
	Main:RefreshChat()
	Main:ProbePlayer()
	ListenerFrameBarToggle:RefreshTooltip()
end

-------------------------------------------------------------------------------
function Main:ListPlayers()
	local list = ""
	
	Main:Print( L["::Player filter::"])
	
	local count = 0
	
	for k,v in pairs( Main.player_list ) do
		
		if #list > 300 then
			Main:Print( list, true )
			list = ""
		end
		if v == 1 then
			list = list .. "|cff00ff00" .. k .. " "
		elseif v == 0 then
			list = list .. "|cffff0000" .. k .. " "
		end
		
	end
	Main:Print( list, true )
end

-------------------------------------------------------------------------------
function Main:Print( text, hideprefix )
	text = tostring( text )
	
	local prefix = hideprefix and "" or "|cff9e5aea<Listener>|r "
	print( prefix .. text )
end
