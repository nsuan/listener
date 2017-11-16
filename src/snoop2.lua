---
-- snooper version 2.0
---

local Main = ListenerAddon
local L    = Main.Locale
local SharedMedia = LibStub("LibSharedMedia-3.0")

Main.Snoop2 = {}
local Me = Main.Snoop2

local g_current_name = nil
local g_update_time  = 0

-------------------------------------------------------------------------------
function Me.Setup()

	Main.RegisterFilterMenu( "SNOOPER",
		{ "Public", "Party", "Raid", "Instance", 
		  "Guild", "Officer", "Rolls", "Whisper", "Channel" },
		function( filter )
			return Main.frames[2].charopts.filter[filter]
		end,
		function( filters, checked )
			if checked then
				Main.frames[2]:AddEvents( unpack( filters ))
			else
				Main.frames[2]:RemoveEvents( unpack( filters))
			end
		end)
	
	local frame = Main.frames[2]
	frame.snooper             = true
	frame.charopts.listen_all = false
	frame.charopts.showhidden = false
	frame.frameopts.readmark  = false
	frame.players             = {}
	
	frame.FormatChatMessage = Me.FormatChatMessage
	frame.UpdateResizeShow  = Me.UpdateResizeShow
	
	-- customize the ui a bit
	frame.bar2.title:SetText( "Snooper" )
	frame.bar2.hidden_button:Hide()
	
	Me.LoadConfig()
	
	Me.update_frame = CreateFrame( "Frame" )
	Me.update_frame:SetScript( "OnUpdate", function()
		Me.OnUpdate( frame )
	end)
end

-------------------------------------------------------------------------------
function Me.LoadConfig()
	local self = Main.frames[2]
	
	Me.UpdateMouseLock()
	
	self:UpdateResizeShow()
	self:RefreshChat()
end

-------------------------------------------------------------------------------
function Me.UpdateMouseLock()
	local self = Main.frames[2]
	self:EnableMouse( self.frameopts.enable_mouse or (self.frameopts.shift_mouse and IsShiftKeyDown()) )
	self.chatbox:EnableMouseWheel( self.frameopts.enable_scroll or (self.frameopts.shift_mouse and IsShiftKeyDown()) )
end

-------------------------------------------------------------------------------
function Me.OnUpdate( self )
	
	if self.frameopts.hidecombat and InCombatLockdown() then return end
	
	local name = IsShiftKeyDown() and g_current_name or Main.GetProbed()
	
	if g_current_name == name and GetTime() - g_update_time < 10 then
		-- throttle updates when the name matches
		return
	end
	
	local hard_update = g_current_name ~= name
	
	g_current_name = name
	
	-- setup filter.
	self.players = {}
	if name then
		-- the snooper filter is a single player.
		self.players[name] = 1
		self.snoop_player = name
	else
		self.snoop_player = nil
	end
	
	if hard_update then
		-- and refresh chat
		self:RefreshChat()
		g_update_time = GetTime()
	else
		-- if they're scrolled up, don't mess with them.
		-- 
		if self.chatbox:AtBottom() then
			self:RefreshChat()
			g_update_time = GetTime()
		end
	end
	
	if self.frameopts.hideempty and not self.charopts.hidden then
		if name then
			if self.chatid > 0 then
				if not (InCombatLockdown() and self.frameopts.combathide) then
					self:Open( true )
				end
			end
		else
			if self.frameopts.hideempty then
				self:Close(true)
			end
		end
	end
end

-------------------------------------------------------------------------------
function Me:UpdateResizeShow()
	if not self.frameopts.locked then
		self.resize_thumb:Show()
	else
		self.resize_thumb:Hide()
	end
end

-------------------------------------------------------------------------------
local MESSAGE_PREFIXES = {
	PARTY           = "[P] ";
	PARTY_LEADER    = "[P] ";
	RAID            = "[R] ";
	RAID_LEADER     = "[R] ";
	INSTANCE        = "[I] ";
	INSTANCE_LEADER = "[I] ";
	OFFICER         = "[O] ";
	GUILD           = "[G] ";
	CHANNEL         = "[C] ";
	RAID_WARNING    = "[RW] ";
	WHISPER         = L["[W From] "];
	WHISPER_INFORM  = L["[W To] "];
}
-------------------------------------------------------------------------------
-- Normal "name: text"
local function MsgFormatNormal( e, name )
	local prefix = MESSAGE_PREFIXES[e.e] or ""
	if e.e == "CHANNEL" then
		prefix = prefix:gsub( "C", (GetChannelName( e.c )) )
	end
	return prefix .. e.m
end

-------------------------------------------------------------------------------
-- No separator between name and text.
local function MsgFormatEmote( e, name )
	if Main.db.profile.trp_emotes and e.m:sub(1,3) == "|| " then
		return e.m:sub( 4 )
	end
	return name .. " " .. e.m
end

-------------------------------------------------------------------------------
-- <name> <msg> - name is substituted
local function MsgFormatTextEmote( e, name )
	local msg = e.m:gsub( e.s, name )
	return msg
end

-------------------------------------------------------------------------------
local MSG_FORMAT_FUNCTIONS = { 
	SAY                  = MsgFormatNormal;
	PARTY                = MsgFormatNormal;
	PARTY_LEADER         = MsgFormatNormal;
	RAID                 = MsgFormatNormal;
	RAID_LEADER          = MsgFormatNormal;
	RAID_WARNING         = MsgFormatNormal;
	YELL                 = MsgFormatNormal;
	INSTANCE_CHAT        = MsgFormatNormal;
	INSTANCE_CHAT_LEADER = MsgFormatNormal;
	GUILD                = MsgFormatNormal;
	OFFICER              = MsgFormatNormal;
	CHANNEL              = MsgFormatNormal;
	
	EMOTE = MsgFormatEmote;
	
	TEXT_EMOTE = MsgFormatTextEmote;
	ROLL       = MsgFormatTextEmote;
}

-------------------------------------------------------------------------------
setmetatable( MSG_FORMAT_FUNCTIONS, {
	__index = function( table, key ) 
		return MsgFormatNormal
	end;
})

-------------------------------------------------------------------------------
-- function override for formatting chat messages.
--
function Me:FormatChatMessage( e )
	
	local stamp = ""
	local old = time() - e.t
	
	if old < 30*60 then
		-- within 30 minutes, use relative time
		if old < 60 then
			stamp = "<1m"
		else
			stamp = string.format( "%sm", math.floor(old / 60) )
		end
	else
		-- use absolute stamp
		stamp = date( "%H:%M", e.t )
	end
	
	if self.frameopts.timestamp_brackets then
		stamp = "[" .. stamp .. "]"
	end
	
	local timecolor
	if old >= 600 then
		timecolor = "|cff777777"
	elseif old >= 300 then
		timecolor = "|cff888888"
	elseif old >= 60 then
		timecolor = "|cffbbbbbb"
	else
		timecolor = "|cff05ACF8"
	end
	
	stamp = timecolor .. stamp .. "|r "
	
	local name, _, color = Main.GetICName( e.s )
	
	if color and self.frameopts.name_colors then 
		name = "|c" .. color .. name .. "|r"
	end
	
	if self.frameopts.enable_mouse then
		-- we only make links for players when the mouse is enabled.
		name = "|Hplayer:" .. e.s .. "|h" .. name .. "|h"
	end
	
	return string.format( "%s%s", stamp, MSG_FORMAT_FUNCTIONS[e.e]( e, name ) )
end

function Me.ShowMenu()
	Main.ShowMenu( function( self, level, menuList )
		if level == 1 then
			menuList = "SNOOPER"
		end
		Me.PopulateMenu( level, menuList )
	end)
end

-------------------------------------------------------------------------------
function Me.PopulateMenu( level, menuList )
	local info
	
	if menuList == "SNOOPER" then
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Enable Mouse"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = Main.db.profile.snoop.enable_mouse
		info.func             = function( self, a1, a2, checked )
			Main.db.profile.snoop.enable_mouse = checked
			Me.LoadConfig()
		end
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Enable mouse."]
		info.tooltipText      = L["Enables interaction with the snooper frame (e.g. to mark messages)."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Enable Scroll"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = Main.db.profile.snoop.enable_scroll
		info.func             = function( self, a1, a2, checked )
			Main.db.profile.snoop.enable_scroll = checked
			Me.LoadConfig()
		end
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Enable mouse scrolling."]
		info.tooltipText      = L["Enables scrolling the text in the snooper window while the mouse is over the interactive area."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Lock"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = Main.db.profile.snoop.locked
		info.func             = function( self, a1, a2, checked )
			Main.db.profile.snoop.locked = checked
			Me.LoadConfig()
		end
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Lock frame."]
		info.tooltipText      = L["Prevents the snooper from being moved. Also hides the titlebar that appears when you mouseover."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Hide"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = Main.db.char.frames[2].hidden
		info.func             = function( self, a1, a2, checked )
			if checked then
				Main.frames[2]:Close()
			else
				Main.frames[2]:Open()
			end
			Me.LoadConfig()
		end
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Hide."]
		info.tooltipText      = L["Hides/disables the snooper window."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Filter"]
		info.notCheckable     = true
		info.hasArrow         = true
		info.menuList         = "FILTERS_SNOOPER"
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Settings"]
		info.notCheckable     = true
		info.func             = function( self, a1, a2, checked )
			Main.OpenFrameConfig( Main.frames[2] )
		end
		UIDropDownMenu_AddButton( info, level )
	elseif menuList and menuList:find("FILTERS") then
		Main.PopulateFilterMenu( level, menuList )
	end
end
