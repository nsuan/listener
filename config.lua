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
local DB_DEFAULTS = {
	
	global = {
		version = nil;
		help    = {};
	};
	
	char = { 
		player_list  = {};
		listen_all   = true; -- } reset these after a long longout
		listen_party = true; -- }
		listen_say   = true; -- }
		showhidden   = false; -- fade out filtered messages instead of hiding
	};
	
	profile = {
	
		minimapicon = {
			hide = false;
		};
		locked      = false; -- unused?
		combathide  = true; -- hide in combat
		addgrouped  = true; -- add player's party automatically (todo)
		flashclient = true; -- flash taskbar on message
		beeptime    = 3;    -- time needed between emotes to play another sound
		highlight_mouseover = true; -- highlight mouseover's emotes in main window
		
		sound = {
			
			msg    = true; -- play sound on filtered emote
			target = true; -- play sound when target emotes
			poke   = true; -- play sound when someone emotes at you
		};
		
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
			
			P_SAY            = Hexc "30f715";
			P_EMOTE          = Hexc "30f715";
			P_TEXT_EMOTE     = Hexc "30f715";
			P_PARTY          = Hexc "30f715";
			P_PARTY_LEADER   = Hexc "30f715";
			P_RAID           = Hexc "30f715";
			P_RAID_LEADER    = Hexc "30f715";
			P_RAID_WARNING   = Hexc "30f715";
			P_YELL           = Hexc "ff0000";
			
			highlight           = { 0.15, 0.15, 0.15, 1 };
			highlight_mouseover = Hexc "2e0007ff";
			highlight_add = true;
		};
		
		frame = {
			point   = {};
		--	x       = nil;
		--	y       = nil;
			width   = 350;
			height  = 400;
			hidden  = false;
			timestamps = false;
			playername = true; -- show player's name in window
			time_visible = 9999;
			
			highlight_new = true;
			
			font = {
				size = 14;
				face = "Arial Narrow";
				outline = 1;
				shadow = false;
			};
			bg = {
				r = 0;
				g = 0;
				b = 0;
				a = 0.75;
			};
			edge = {
				r = 1;
				g = 1;
				b = 1;
				a = 0.25;
			};
		};
		
		snoop = {
			point   = {};
		--	x      = nil;
		--	y      = nil;
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
					name  = L["Font"];
					desc  = L["Chat font."];
					type  = "select"; 
					set   = function( info, val ) Main:SetChatFont( g_font_list[val] ) end;
					get   = function( info ) return FindValueKey( g_font_list, Main.db.profile.frame.font.face ) end;
					
				};
				outline = {
					order = 20;
					name  = L["Outline"];
					desc  = L["Chat text outline."];
					type  = "select"; 
					values = outline_values;
					set   = function( info, val ) Main:SetChatOutline( val ) end;
					get   = function( info ) return Main.db.profile.frame.font.outline end;
					
				};
				shadow = {
					order = 30;
					name  = L["Shadow"];
					desc  = L["Show text shadow."];
					type  = "toggle"; 
					set   = function( info, val ) Main:Frame_SetShadow( val ) end;
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
					get = function( info ) return Main.db.profile.frame.bg.r, Main.db.profile.frame.bg.g, Main.db.profile.frame.bg.b, Main.db.profile.frame.bg.a end;
				};
				
				edgecolor = {
					order = 51;
					name = L["Edge Color"];
					desc = L["Color of frame edge."];
					type = "color";
					hasAlpha = true;
					set = function( info, r, g, b, a ) Main:Frame_SetEdgeColor( r, g, b, a ) end;
					get = function( info ) return Main.db.profile.frame.edge.r, Main.db.profile.frame.edge.g, Main.db.profile.frame.edge.b, Main.db.profile.frame.edge.a end;
				};
				
				playsound = {
					order = 60;
					name = L["Play Sound On Message"];
					desc = L["Play a sound when a new message is received or your target emotes."];
					width = "full";
					type = "toggle";
					set = function( info, val ) Main.db.profile.sound.msg = val end;
					get = function( info ) return Main.db.profile.sound.msg end;
				};
				
				soundthrottle = {
					order = 61;
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
					name = L["Play Sound On Poke"];
					desc = L["Play a sound when a person directs a stock emote at you. (i.e. /poke)"];
					width = "full";
					type = "toggle";
					set = function( info, val ) Main.db.profile.sound.poke = val end;
					get = function( info ) return Main.db.profile.sound.poke end;
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
				playername = {
					order = 80;
					width = "full";
					name = L["Show Player Name"];
					desc = L["Show player's name in Listener window."];
					type = "toggle";
					set = function( info, val ) Main:Frame_SetPlayerName( val ) end;
					get = function( info ) return Main.db.profile.frame.playername end;
				};
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
					func = function() Main:Snoop_Unlock() end;
				};
				show = {
					order= 3;
					width = "full";
					name = L["Show"];
					desc = L["Show the snooper window."];
					type = "toggle";
					set  = function( info, val ) Main:Snoop_Show( val ) end;
					get  = function( info ) return Main.db.profile.snoop.show end;
				};
				
				fontface = {
					order = 4;
					name  = L["Font"];
					desc  = L["Chat font."];
					type  = "select"; 
					set   = function( info, val ) Main:Snoop_SetFont( g_font_list[val] ) end;
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
					set = function( info, val ) Main:Snoop_SetFontSize( val ) end;
					get = function( info ) return Main.db.profile.snoop.font.size end;
				};
				outline = {
					order = 6;
					name  = L["Outline"];
					desc  = L["Chat text outline."];
					type  = "select"; 
					values = outline_values;
					
					set   = function( info, val ) Main:Snoop_SetOutline( val ) end;
					get   = function( info ) return Main.db.profile.snoop.font.outline end;
				};
				shadow = {
					order = 7;
					name  = L["Shadow"];
					desc  = L["Show text shadow."];
					type  = "toggle"; 
					set   = function( info, val ) Main:Snoop_SetShadow( val ) end;
					get   = function( info ) return Main.db.profile.snoop.font.shadow end;
				};
				partyprefix = {
					order = 8;
					name  = L["Party Prefix"];
					desc  = L["Show channel prefixes for party chat."];
					type  = "toggle";
					set   = function( info, val ) Main.db.profile.snoop.partyprefix = val Main:Snoop_DoUpdate() end;
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
	
end
  
-------------------------------------------------------------------------------
function Main:CreateDB() 

	local acedb = LibStub( "AceDB-3.0" )
 
  
	self.db = acedb:New( "ListenerAddonSaved", DB_DEFAULTS, true )
	
	self.db.RegisterCallback( self, "OnProfileChanged", "ApplyConfig" )
	self.db.RegisterCallback( self, "OnProfileCopied",  "ApplyConfig" )
	self.db.RegisterCallback( self, "OnProfileReset",   "ApplyConfig" )
	
	-- insert older database patches here: --
	
	-----------------------------------------
 
	self.db.global.version = VERSION
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
	 
	self:LoadFrameSettings()
end
 