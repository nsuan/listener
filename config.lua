-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2016)
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L = Main.Locale

local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local SharedMedia     = LibStub("LibSharedMedia-3.0")

local VERSION = 1

local g_font_list = {}
local g_init = nil
 
-------------------------------------------------------------------------------
local function ToNumber2( expr )
	return tonumber( expr ) or 0
end
-------------------------------------------------------------------------------
local function Hexc( hex )
	if hex:len() == 3 then
		return {ToNumber2("0x"..hex:sub(1,1))/15, ToNumber2("0x"..hex:sub(2,2))/15, ToNumber2("0x"..hex:sub(3,3))/15}
	elseif hex:len() == 4 then
		return {ToNumber2("0x"..hex:sub(1,1))/15, ToNumber2("0x"..hex:sub(2,2))/15, ToNumber2("0x"..hex:sub(3,3))/15, ToNumber2("0x"..hex:sub(4,4))/15}
	elseif hex:len() == 6 then
		return {ToNumber2("0x"..hex:sub(1,2))/255, ToNumber2("0x"..hex:sub(3,4))/255, ToNumber2("0x"..hex:sub(5,6))/255}
	elseif hex:len() == 8 then
		return {ToNumber2("0x"..hex:sub(1,2))/255, ToNumber2("0x"..hex:sub(3,4))/255, ToNumber2("0x"..hex:sub(5,6))/255, ToNumber2("0x"..hex:sub(7,8))/255}
	end
	return {1, 1, 1}
end

-------------------------------------------------------------------------------
-- A note about frame configuration:
-- Some of the options are stored in the PROFILE while most are stored in CHAR.
-- For the primary frame (index 1), the position settings are stored in the PROFILE.
-- For other frames, they're character based, and are entirely stored in the CHAR.

-------------------------------------------------------------------------------
local DB_DEFAULTS = {
	
	global = {
		version = nil;
		help    = {};
	};
	
	char = {
		frames = {
			-------------------------------------------------------------------
			-- frames[1] is the primary frame, frames[2..x] are subframes
			-- contents:
			--   players    = {}    player filter list
			--	 listen_all = true  inclusion mode
			--   filter     = {}    events that are included (should use default value table)
			--    [event_type] = true/false
			--    [#channel]   = true/false
			--  showhidden = false  show hidden players
			--  layout              position/size (uses profile entry for primary frame)
			--    point  = {}       anchor point info
			--    width  = x        size
			--    height = y        size
			--  hidden = false      frame is hidden
			--  sound = true        play a sound on new message
			--  flash = true        flash the taskbar on new message
			--  
			--  color_bg   = {color} background color
			--  color_edge = {color} edge color
			--  color_bar  = {color} bar color
		};
		
		-- events that the snooper is listening to
		snoop_filter = {};
	};
	
	profile = {
	
		-- for minimap lib
		minimapicon = {
			hide = false;
		};
		
		-- general settings
		locked      = false; -- unused?
		combathide  = true;  -- hide in combat
		addgrouped  = true;  -- add player's party automatically (todo)
		flashclient = true;  -- flash taskbar on message
		beeptime    = 3;     -- time needed between emotes to play another sound
		highlight_mouseover = true; -- highlight mouseover's emotes in main window
		rpconnect   = true;  -- rpconnect support
		
		-- notification settings
		sound = {
			msg    = true; -- play sound on filtered emote (this is moved inside of the frame settings)
			target = true; -- play sound when target emotes
			poke   = true; -- play sound when someone emotes at you
		};
		
		-- mostly text color options
		colors = {
			SAY            = Hexc "f0f0f0";
			EMOTE          = Hexc "ff9e12";
			TEXT_EMOTE     = Hexc "ff9e12";
			PARTY          = Hexc "58c9ff";
			PARTY_LEADER   = Hexc "58c9ff";
			RAID           = Hexc "58c9ff";
			RAID_LEADER    = Hexc "58c9ff";
			RAID_WARNING   = Hexc "d961ff";
			YELL           = Hexc "ff0000";
			ROLL           = Hexc "ffff00";
			
			P_SAY            = Hexc "30f715";
			P_EMOTE          = Hexc "30f715";
			P_TEXT_EMOTE     = Hexc "30f715";
			P_PARTY          = Hexc "30f715";
			P_PARTY_LEADER   = Hexc "30f715";
			P_RAID           = Hexc "30f715";
			P_RAID_LEADER    = Hexc "30f715";
			P_RAID_WARNING   = Hexc "30f715";
			P_YELL           = Hexc "ff0000";
			P_ROLL           = Hexc "30f715";
			
			tab_self         = Hexc "94C7A9";
			tab_mouseover    = Hexc "BF060F";
			tab_highlight    = Hexc "D3DA37";
			
			readmark         = Hexc "BF060FC0";
			
			highlight           = { 0.15, 0.15, 0.15, 1 };
			highlight_mouseover = Hexc "2e0007ff";
			highlight_add = true;
		};
		
		-- profile frame settings (see note above)
		frame = {
			layout = {
				point        = {};  -- } only used for primary frame
				width        = 350; -- } but subframes inherit this
				height       = 400; -- } upon creation
			};
			
			hidden       = false; -- this is being moved
			timestamps   = false;
			playername   = true; -- show player's name in window
			time_visible = 9999;
			zoom_icons   = true;
			show_icons   = true;
			
			highlight_new = true;
			
			-- shared between all windows
			font = {
				size = 14;
				face = "Arial Narrow";
				outline = 1;
				shadow = false;
			};
			
			-- shared between all windows
			barfont = {
				size = 14;
				face = "Accidental Presidency";
			};
			
			-- these are default values when
			-- new windows are created
			color_bg   = Hexc "090f17ff";
			color_edge = Hexc "4777b380";
			color_bar  = Hexc "1F344Eff";
		};
		
		-- snooper settings
		snoop = {
			point   = {};
			width  = 400;
			height = 500;
			show   = true;
			partyprefix = false; -- show prefixes for party chat channels
			
			font = {
				size = 11;
				face = "Myriad Condensed Web";
				outline = 2;
				shadow = true;
			};
		};
		
	};
}
 
-------------------------------------------------------------------------------
local function FindValueKey( table, value ) 
	for k,v in pairs( table ) do
		if v == value then return k end
	end
end

local outline_values = { "None", "Thin Outline", "Thick Outline" }

-------------------------------------------------------------------------------
local function FrameSettingsChanged()
	for _, frame in pairs( Main.frames ) do
		frame:ApplyOptions()
	end
end

-------------------------------------------------------------------------------
Main.config_options = {
	type = "group";
	
	args = { 
		
		mmicon = {
			name = L["Minimap Icon"];
			desc = L["Hide/Show the minimap icon."];
			type = "toggle";
			set = function( info, val ) Main.MinimapButton:Show( val ) end;
			get = function( info ) return not Main.db.profile.minimapicon.hide end;
		};
		 
		general = {
			name = L["General"];
			type = "group";
			order=1;
			args = {
			
				desc1 = {
					name  = L["The main window can be moved and resized by holding Shift. The font size can be changed by holding Ctrl and scrolling."];
					type  = "description"; 
					order = 9;
				};
			  
				fontface = {
					order = 10;
					name  = L["Chat Font"];
					desc  = L["Font for the chatbox text."];
					type  = "select"; 
					set   = function( info, val ) 
						Main.db.profile.frame.font.face = g_font_list[val]
						FrameSettingsChanged()
					end;
					get   = function( info ) return FindValueKey( g_font_list, Main.db.profile.frame.font.face ) end;
					
				};
				outline = {
					order = 20;
					name  = L["Outline"];
					desc  = L["Chat text outline."];
					type  = "select"; 
					values = outline_values;
					set   = function( info, val ) 
						Main.db.profile.frame.font.outline = val
						FrameSettingsChanged()
					end;
					get   = function( info ) return Main.db.profile.frame.font.outline end;
					
				};
				shadow = {
					order = 30;
					name  = L["Shadow"];
					desc  = L["Show text shadow."];
					type  = "toggle"; 
					set   = function( info, val ) 
						Main.db.profile.frame.font.shadow = val
						FrameSettingsChanged()
					end;
					get   = function( info ) return Main.db.profile.frame.font.shadow end;
				};
				
				hidecombat = {
					order = 40;
					name = L["Hide During Combat"];
					desc = L["Hide the Listener windows during combat."];
					type = "toggle";
					set = function( info, val ) Main.db.profile.combathide = val end;
					get = function( info ) return Main.db.profile.combathide end;
				};
				
				bgcolor = {
					order = 50;
					name = L["Background Color"];
					desc = L["Color of frame background."];
					type = "color";
					hasAlpha = true;
					set = function( info, r, g, b, a ) Main:Frame_SetBGColor( r, g, b, a ) end;
					get = function( info ) return unpack( Main.db.profile.frame.color_bg ) end;
				};
				
				edgecolor = {
					order = 51;
					name = L["Edge Color"];
					desc = L["Color of frame edge."];
					type = "color";
					hasAlpha = true;
					set = function( info, r, g, b, a ) Main:Frame_SetEdgeColor( r, g, b, a ) end;
					get = function( info ) return unpack( Main.db.profile.frame.color_edge ) end;
				};
				--[[
				playsound = {
					order = 60;
					name = L["Play Sound On Message"];
					desc = L["Play a sound when a new message is received."];
					width = "full";
					type = "toggle";
					set = function( info, val ) Main.db.profile.sound.msg = val end;
					get = function( info ) return Main.db.profile.sound.msg end;
				};]]
				
				playsound_target = {
					order = 61;
					name = L["Target Emote Sound"];
					desc = L["Play a sound when your targeted player emotes."];
					width = "full";
					type = "toggle";
					set = function( info, val ) Main.db.profile.sound.target = val end;
					get = function( info ) return Main.db.profile.sound.target end;
				};
				
				soundthrottle = {
					order = 62;
					name = L["Sound Throttle Time"];
					desc = L["Minimum amount of time between emotes before playing another sound is allowed."];
					type = "range";
					min  = 0.1;
					max  = 120;
					softMax = 10;
					step = 0.1;
					set = function( info, val ) Main.db.profile.beeptime = val end;
					get = function( info ) return Main.db.profile.beeptime end;
				};
				
				playsound2 = {
					order = 63;
					name = L["Poke Sound"];
					desc = L["Play a sound when a person directs a stock emote at you. (e.g. /poke)"];
					width = "full";
					type = "toggle";
					set = function( info, val ) Main.db.profile.notify_poke = val end;
					get = function( info ) return Main.db.profile.notify_poke end;
				};
				
				flash1 = {
					order = 65;
					name = L["Flash Taskbar Icon"];
					desc = L["Flash Taskbar Icon when Listener plays a sound."];
					width = "full";
					type = "toggle";
					set = function( info, val ) Main.db.profile.flashclient = val end;
					get = function( info ) return Main.db.profile.flashclient end;
				};
				
				timestamp = {
					order = 70;
					width = "full";
					name = L["Show Timestamps"];
					type = "toggle";
					set = function( info, val ) Main:Frame_SetTimestamps( val ) end;
					get = function( info ) return Main.db.profile.frame.timestamps end;
				};
				
				--[[
				playername = {
					order = 80;
					width = "full";
					name = L["Show Player Name"];
					desc = L["Show player's name in Listener window."];
					type = "toggle";
					set = function( info, val ) Main:Frame_SetPlayerName( val ) end;
					get = function( info ) return Main.db.profile.frame.playername end;
				};]]
				
				hlmouseover ={
					order = 90;
					width = "full";
					name = L["Highlight Mouseover Text"];
					desc = L["Highlight emotes in the main window when you mouseover someone."];
					type = "toggle";
					set = function( info, val ) 
						Main.db.profile.highlight_mouseover = val
						if not val then
							Main:ResetHighlightMouseover()
						end
					end;
					get = function( info ) return Main.db.profile.highlight_mouseover end;
				};
				resethelp = {
					order = 150;
					type= "execute";
					name = L["Reset Help"];
					desc = L["Click to reset the help notes. (Will show on next login.)"];
					func = function() Main:Help_Reset() end;
				};
			};
			
		}; 
		
		snoop = {
			name = L["Snooper"];
			type = "group";
			order=2;
			args = {
				desc = {
					order = 1;
					type = "description";
					name = L["The snooper is a transparent window that shows a chat history for a person that you mouseover or target."];
					
				};
				unlock = {
					order = 2;
					name = L["Unlock"];
					desc = L["Unlock frame."];
					type = "execute";
					func = function() Main.Snoop.Unlock() end;
				};
				show = {
					order= 3;
					width = "full";
					name = L["Show"];
					desc = L["Show the snooper window."];
					type = "toggle";
					set  = function( info, val ) Main.Snoop.Show( val ) end;
					get  = function( info ) return Main.db.profile.snoop.show end;
				};
				
				fontface = {
					order = 4;
					name  = L["Font"];
					desc  = L["Chat font."];
					type  = "select"; 
					set   = function( info, val ) Main.Snoop.SetFont( g_font_list[val] ) end;
					get   = function( info ) return FindValueKey( g_font_list, Main.db.profile.snoop.font.face ) end;
				};
				
				fontsize = {
					order = 5;
					name = L["Font Size"];
					desc = L["Size of font."];
					type = "range";
					min = 4;
					max = 20;
					step = 1;
					set = function( info, val ) Main.Snoop.SetFontSize( val ) end;
					get = function( info ) return Main.db.profile.snoop.font.size end;
				};
				outline = {
					order = 6;
					name  = L["Outline"];
					desc  = L["Chat text outline."];
					type  = "select"; 
					values = outline_values;
					
					set   = function( info, val ) Main.Snoop.SetOutline( val ) end;
					get   = function( info ) return Main.db.profile.snoop.font.outline end;
				};
				shadow = {
					order = 7;
					name  = L["Shadow"];
					desc  = L["Show text shadow."];
					type  = "toggle"; 
					set   = function( info, val ) Main.Snoop.SetShadow( val ) end;
					get   = function( info ) return Main.db.profile.snoop.font.shadow end;
				};
				partyprefix = {
					order = 8;
					name  = L["Party Prefix"];
					desc  = L["Show channel prefixes for party chat."];
					type  = "toggle";
					set   = function( info, val ) Main.db.profile.snoop.partyprefix = val Main.Snoop.DoUpdate() end;
					get   = function( info ) return Main.db.profile.snoop.partyprefix end;
				};
			};
		};
		
		colors = {
			name = L['Colors'];
			type = "group";
			order=3;
			args = {
				refresh = {
					order = 1;
					type= "execute";
					name = L["Refresh"];
					desc = L["Click to refresh the chat box to see changes."];
					func = function() Main:RefreshChat() end;
				};
				message_highlight = {
					order = 11;
					name  = L["Message Highlight"];
					desc  = L["Color for new message highlighter."];
					type  = "color";
					width = "full";
					hasAlpha = true;
					get = function( info ) return unpack( Main.db.profile.colors.highlight ) end;
					set = function( info, r, g, b, a ) Main.db.profile.colors.highlight = {r, g, b, a} end;
				};
				message_mouse_highlight = {
					order = 11;
					name  = L["Mouseover Highlight"];
					desc  = L["Color for highlighting messages from whom you're mousing over."];
					type  = "color";
					width = "full";
					hasAlpha = true;
					get = function( info ) return unpack( Main.db.profile.colors.highlight_mouseover ) end;
					set = function( info, r, g, b, a ) Main.db.profile.colors.highlight_mouseover = {r, g, b, a} end;
				};
				message_highlight_add = {
					order = 22;
					name = L["Additive Blending"];
					desc = L["Use additive blending for the message highlighter."];
					type = "toggle";
					get = function( info ) return Main.db.profile.colors.highlight_add end;
					set = function( info, val ) Main.db.profile.colors.highlight_add = val end;
				};
				group_others = {
					order = 33;
					type = "group";
					inline = true;
					name = L["Others' Messages"];
					args = {};
				};
				group_self = {
					order = 44;
					type = "group";
					inline = true;
					name = L["Your Messages"];
					args = {};
				};
			};
		};
	};
}

do
	local order = 1
	local function add_color_option( tag, name, desc ) 
	
		Main.config_options.args.colors.args.group_others.args[tag] = {
			order = order;
			name = L[name];
			desc = L[desc];
			type = "color";
			get = function( info ) return unpack( Main.db.profile.colors[tag] ) end;
			set = function( info, r, g, b ) Main.db.profile.colors[tag] = {r, g, b} end;
		}
		
		Main.config_options.args.colors.args.group_self.args[tag] = {
			order = order;
			name = L[name];
			desc = L[desc];
			type = "color";
			get = function( info ) return unpack( Main.db.profile.colors["P_"..tag] ) end;
			set = function( info, r, g, b ) Main.db.profile.colors["P_"..tag] = { r, g, b } end;
		}
		order = order + 1
	end

	add_color_option( "SAY",          "Say",          "Color for /say messages." )
	add_color_option( "EMOTE",        "Emote",        "Color for /e messages." )
	add_color_option( "TEXT_EMOTE",   "Text Emote",   "Color for character emotes. (/wave)" )
	add_color_option( "PARTY",        "Party",        "Color for party messages." )
	add_color_option( "PARTY_LEADER", "Party Leader", "Color for party leader messages." )
	add_color_option( "RAID",         "Raid",         "Color for raid messages." )
	add_color_option( "RAID_LEADER",  "Raid Leader",  "Color for raid leader messages." )
	add_color_option( "RAID_WARNING", "Raid Warning", "Color for raid warning messages." )
	add_color_option( "YELL",         "Yell",         "Color for /yell messages." )
	add_color_option( "ROLL",         "Rolls",        "Color for /roll messages." )
	
end
  
-------------------------------------------------------------------------------
function Main.CreateDB() 

	local acedb = LibStub( "AceDB-3.0" )
 
  
	Main.db = acedb:New( "ListenerAddonSaved", DB_DEFAULTS, true )
	
	Main.db.RegisterCallback( Main, "OnProfileChanged", "ApplyConfig" )
	Main.db.RegisterCallback( Main, "OnProfileCopied",  "ApplyConfig" )
	Main.db.RegisterCallback( Main, "OnProfileReset",   "ApplyConfig" )
	
	-- insert older database patches here: --
	
	-----------------------------------------
 
	Main.db.global.version = VERSION
end

-------------------------------------------------------------------------------
function Main:InitConfigPanel()
	if g_init then return end
	g_init = true
	
	local options = self.config_options
	
	g_font_list = SharedMedia:List( "font" ) 
	options.args.general.args.fontface.values = g_font_list 
	options.args.snoop.args.fontface.values = g_font_list 
	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable( self.db )
	options.args.profile.order = 500
	 
	AceConfig:RegisterOptionsTable( "Listener", options )
end

-------------------------------------------------------------------------------
-- Open the configuration panel.
--
function Main:OpenConfig()
	self:InitConfigPanel()	
	AceConfigDialog:Open( "Listener" )
	
	-- hack to fix the scrollbar missing on the first page when you
	-- first open the panel
	LibStub("AceConfigRegistry-3.0"):NotifyChange( "Listener" )
end
 
 
-------------------------------------------------------------------------------
-- Apply the configuration settings.
--
function Main:ApplyConfig( onload )
	 
	for _, frame in pairs( Main.frames ) do
		frame:ApplyOptions()
	end
end
 