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
		
		--if Ambiguate(sender,"all") == UnitName("player") then return end
		
		local replaced = {}
		
		msg = msg:gsub( "(|cff[0-9a-f]+|H[^|]+|h[^|]+|h|r)", function( link )
			table.insert( replaced, link )
			return "\001\001" .. #replaced .. "\001\001"
		end)
		
		-- we pad with space so that word boundaries at start and end are found.
		msg = " " .. msg .. " "
		for trigger, _ in pairs( g_triggers ) do
			
			local subs
			msg, subs = msg:gsub( trigger, function( a,b,c )
				table.insert( replaced, a .. g_color .. b .. "|r" .. c )
				return "\001\001" .. #replaced .. "\001\001"
			end)
			
			if subs > 0 then
				found = true
				if GetTime() > g_beeptime then
					-- we have our own cooldown in here because this shit is going to be spammed a lot
					-- on message matches.
					g_beeptime = GetTime() + 0.15
					PlaySoundFile( SharedMedia:Fetch( "sound", "ListenerPoke" ), "Master" )
					Main:FlashClient()
				end
			end
		end
		
		if found then
			msg = msg:gsub( "\001\001(%d+)\001\001", function( index )
				return replaced[tonumber(index)]
			end)
			return false, msg:sub( 2, msg:len() - 1 ), sender, ...
		end
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
	
	local firstname = Main.GetICName( UnitName("player") ):match( "^%s*(%S+)" )
	local lastname  = Main.GetICName( UnitName("player"), true ):match( "(%S+)%s*$" )
	local oocname   = UnitName('player')
	
	for word in Main.db.profile.keywords_string:gmatch( "[^,]+" ) do
		word = word:match( "^%s*(.-)%s*$" )
		word = word:lower()
		
		word = word:gsub( "<firstname>", firstname )
		word = word:gsub( "<lastname>", lastname )
		word = word:gsub( "<oocname>", oocname )
		
		if word then
			-- and now, format the trigger...
			word = word:lower()
			
			if not word:find( "[^%a%d%s]" ) then
				-- if word doesn't have any special characters, then we
				-- turn it into a case insensitive pattern, and wrap it
				-- in word boundaries
				word = word:gsub( "%a", function(c)
					return string.format( "[%s%s]", c:lower(), c:upper() )
				end)
				-- convert space to patterned space
				word = word:gsub( "%s+", "%%s+" )
				word = "([%s%p])(" .. word .. ")([%s%p])"
			else
				-- otherwise, they're doing something weird, and let them do it.
			end
			g_triggers[word] = true
		end
	end
	DEBUG1 = g_triggers
end
