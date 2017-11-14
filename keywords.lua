--
-- highlights keywords
--

local Main = ListenerAddon
local L    = Main.Locale
local SharedMedia = LibStub("LibSharedMedia-3.0")

-------------------------------------------------------------------------------
local g_triggers = {}
local g_color    = ""
local g_beeptime = 0

-------------------------------------------------------------------------------
local function GetHexCode( color )
	return string.format( "ff%2x%2x%2x", color[1]*255, color[2]*255, color[3]*255 )
end

-------------------------------------------------------------------------------
-- Which events we want to hook for filtering chat links.
--
local chat_events = { 
	"SAY";
	"YELL";
	"EMOTE";
	"GUILD";
	"OFFICER";
	"PARTY";
	"PARTY_LEADER";
	"RAID";
	"RAID_LEADER";
	"CHANNEL";
}

-------------------------------------------------------------------------------
local function ChatFilter( self, event, msg, sender, ... )
	if Main.db.profile.keywords_enable then
		local found = false
		msg = msg:gsub( "%S+", function( t )
			if g_triggers[t:lower()] then
				if GetTime() > g_beeptime then
					-- we have our own cooldown in here because this shit is going to be spammed a lot
					-- on message matches.
					g_beeptime = GetTime() + 0.15
					PlaySoundFile( SharedMedia:Fetch( "sound", "ListenerPoke" ), "Master" )
					Main:FlashClient()
				end
				
				return g_color .. t .. "|r"
			end
		end)
		
		return false, msg, sender, ...
	end
end

-------------------------------------------------------------------------------
function Main.InitKeywords()
	Main.LoadKeywordsConfig()
	for i, event in ipairs(chat_events) do
		ChatFrame_AddMessageEventFilter( "CHAT_MSG_" .. event, ChatFilter );
	end
end

-------------------------------------------------------------------------------
function Main.LoadKeywordsConfig()
	g_color = "|c" .. GetHexCode( Main.db.profile.keywords_color )
	g_triggers = {}
	
	for word in Main.db.profile.keywords_string:gmatch( "%S+" ) do
		print( "a", word )
		word = word:lower()
		if word == "<firstname>" then
			word = Main.GetICName( UnitName("player") ):match( "^%s*(%S+)" )
		elseif word == "<lastname>" then
			word = Main.GetICName( UnitName("player"), true ):match( "(%S+)%s*$" )
		elseif word == "<oocname>" then
			word = UnitName('player')
		elseif word == "<nicknames>" then
			-- todo: parse nicknames
		end
		print( "b", word )
		if word then
			g_triggers[word:lower()] = true
		end
	end
	DEBUG1 = g_triggers
end
