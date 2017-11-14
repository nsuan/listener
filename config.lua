-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2016)
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L    = Main.Locale

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
	
	realm = {
		guids = {};
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
			--  tab_size (inherit)
			--  combathide          hide during combat
			--  readmark = true     show readmark
			--  
			--  color_bg   = {color} background color
			--  color_edge = {color} edge color
			--  color_bar  = {color} bar color
		};
		
		-- events that the snooper is listening to
		snoop_filter = { 
			SAY  = true, EMOTE       = true, TEXT_EMOTE   = true, 
			YELL = true, PARTY       = true, PARTY_LEADER = true, 
			RAID = true, RAID_LEADER = true, RAID_WARNING = true,
			ROLL = true
		};
	};
	
	profile = {
	
		-- for minimap lib
		minimapicon = {
			hide = false;
		};
		
		-- general settings
		locked           = false; -- unused?
		addgrouped       = true;  -- add player's party automatically (todo)
		flashclient      = true;  -- flash taskbar on message
		beeptime         = 3;     -- time needed between emotes to play another sound
		rpconnect        = true;  -- rpconnect support
		
		shorten_names    = true;
		strip_titles     = true;
		
		convert_links    = true;
		
		keywords_enable  = true;
		keywords_string  = "<firstname> <lastname> <oocname>";
		keywords_color   = Hexc "75F754";
		
		-- notification settings
		sound = {
			msg    = true; -- play sound on filtered emote (this is moved inside of the frame settings)
			target = true; -- play sound when target emotes
			poke   = true; -- play sound when someone emotes at you
		};
		
		-- profile frame settings (see note above)
		frame = {
		
			-- anchor and size
			-- subframes inherit this or can define it themselves
			layout = {
				anchor = {};
				width  = 350;
				height = 400;
			};
			
			-- can drag
			locked = false;
			
			-- enable timestamps
			timestamps = 0;
			
			-- time that text is kept visible
			time_visible = 0;
			
			-- this is time_visible's successor
			-- the entire window just fades.
			auto_fade = 0;
			
			-- automatically show on new message
			auto_popup = false;
			
			-- shared between all windows:
			
			-- show trp icons; zoom is for removing border
			show_icons = true;
			zoom_icons = true;
			
			-- pixel width of the tabs next to messages
			tab_size = 2;
			
			-- pixel size of edges around frames
			edge_size = 2;
			
			-- opacity for faded windows (percent)
			auto_fade_opacity = 20;
			
			font = {
				size = 14; -- except for this - this is custom per window
				face = "Arial Narrow";
				outline = 1;
				shadow = false;
			};
			
			-- shared between all windows
			barfont = {
				size = 14;
				face = "Accidental Presidency";
			};
			
			color = {
				-- these are default values when
				-- new windows are created
				bg       = Hexc "090f17ff";
				edge     = Hexc "1F344E80";
				bar      = Hexc "1F344Eff";
			
				-- the following are used globally 
				-- and aren't configured per-frame
				readmark = Hexc "BF060FC0";
				
				tab_self   = Hexc "29D24EFF";
				tab_target = Hexc "BF060FFF";
				tab_marked = Hexc "D3DA37FF";
			};
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
	Main.Frame.ApplyGlobalOptions()
	for _, frame in pairs( Main.frames ) do
		frame:ApplyOptions()
	end
end

-------------------------------------------------------------------------------
local function RefreshAllChat()
	for _, frame in pairs( Main.frames ) do
		frame:RefreshChat()
		frame:UpdateProbe()
	end
end

local function FrameColorOption( order, name, desc, color )
	return {
		order = order;
		name  = name;
		desc  = desc;
		type  = "color";
		hasAlpha = true;
		get   = function( info )
			return unpack( Main.db.profile.frame.color[color] )
		end;
		set   = function( info, r, g, b, a )
			Main.db.profile.frame.color[color] = { r, g, b, a }
			FrameSettingsChanged()
		end;
	}
end

-------------------------------------------------------------------------------
Main.config_options = {
	type = "group";
	
	args = { 
		
		mmicon = {
			name = L["Minimap Icon"];
			desc = L["Hide/Show the minimap icon."];
			type = "toggle";
			set = function( info, val ) Main.MinimapButton.Show( val ) end;
			get = function( info ) return not Main.db.profile.minimapicon.hide end;
		};
		 
		general = {
			name  = L["General"];
			type  = "group";
			order = 1;
			args  = {
			
				playsound_target = {
					order = 61;
					name = L["Target Emote Sound"];
					desc = L["Play a sound when your targeted player emotes."];
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
					type = "toggle";
					set = function( info, val ) Main.db.profile.notify_poke = val end;
					get = function( info ) return Main.db.profile.notify_poke end;
				};
				
				flash1 = {
					order = 65;
					name = L["Flash Taskbar Icon"];
					desc = L["Flash Taskbar Icon when Listener plays a sound."];
					type = "toggle";
					set = function( info, val ) Main.db.profile.flashclient = val end;
					get = function( info ) return Main.db.profile.flashclient end;
				};
				
				shorten_names = {
					order = 71;
					name = L["Shorten Names"];
					desc = L["Shorten names in chat and other places. Cuts off surnames unless the first name is really short."];
					type = "toggle";
					set = function( info, val ) 
						Main.ClearICNameCache()
						Main.db.profile.shorten_names = val
						RefreshAllChat()
						FrameSettingsChanged()
					end;
					get = function( info ) return Main.db.profile.shorten_names end;
				};
				
				links = {
					order = 81;
					name = L["Clickable Links"];
					desc = L["Convert links into clickable items. You might want to disable this if you already have another addon that handles this."];
					type = "toggle";
					set = function( info, val )
						Main.db.profile.convert_links = val
					end;
					get = function( info, val )
						return Main.db.profile.convert_links
					end;
				};
				
				keywords_desc = {
					order = 91;
					type  = "description";
					name  = L["The keywords feature highlights things that appear in chat, such as your name. They also make a notification. Some substitutions are available:\n<firstname> - Your character's RP first name.\n<lastname> - Your character's RP last name.\n<oocname> - Your character's in-game name."];
				};
				
				keywords_enable = {
					order = 92;
					type  = "toggle";
					name  = L["Enable Keywords"];
					set = function( info, val )
						Main.db.profile.keywords_enable = val;
					end;
					get = function( info )
						return Main.db.profile.keywords_enable
					end;
				};
				
				keywords_string = {
					order = 93;
					type  = "input";
					width = "full";
					name  = L["Keywords To Highlight"];
					desc  = L["Enter keywords separated by spaces."];
					set = function( info, val )
						Main.db.profile.keywords_string = val;
						Main.LoadKeywordsConfig()
					end;
					get = function( info )
						return Main.db.profile.keywords_string
					end;
				};
				
				keywords_color = {
					order    = 94;
					type     = "color";
					name     = L["Highlight Color"];
					desc     = L["The color that keywords will be highlighted with."];
					hasAlpha = false;
					
					set = function( info, r, g, b )
						Main.db.profile.keywords_color = {r,g,b,1.0};
						Main.LoadKeywordsConfig()
					end;
					get = function( info )
						return unpack( Main.db.profile.keywords_color )
					end;
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
		
		frame = {
			name  = L["Frame"];
			type  = "group";
			order = 2;
			args  = {
				desc1 = {
					name  = L["Listener frames can be resized holding shift. The font size can be adjusted by holding Ctrl and scrolling! Additional options can be found per-frame, which is accessed from the context menu (right click the top left corner of the frame)."];
					type  = "description"; 
					order = 9;
				};
				fontface = {
					order = 10;
					name  = L["Chat Font"];
					desc  = L["Font face for chatbox text."];
					type  = "select";
					set   = function( info, val ) 
						Main.db.profile.frame.font.face = g_font_list[val]
						FrameSettingsChanged()
					end;
					get   = function( info ) 
						return FindValueKey( g_font_list, Main.db.profile.frame.font.face ) 
					end;
				};
				outline = {
					order  = 11;
					name   = L["Outline"];
					desc   = L["Font outline for chatbox text."];
					type   = "select"; 
					values = outline_values;
					set    = function( info, val ) 
						Main.db.profile.frame.font.outline = val
						FrameSettingsChanged()
					end;
					get    = function( info ) 
						return Main.db.profile.frame.font.outline 
					end;
				};
				shadow = {
					order = 12;
					name  = L["Text Shadow"];
					desc  = L["Enable text shadow for chatbox text."];
					type  = "toggle"; 
					set   = function( info, val ) 
						Main.db.profile.frame.font.shadow = val
						FrameSettingsChanged()
					end;
					get   = function( info ) 
						return Main.db.profile.frame.font.shadow 
					end;
				};
				edge_size = {
					order = 20;
					name  = L["Edge Size"];
					desc  = L["Thickness of the border around frames."];
					type  = "range";
					min   = 0;
					max   = 16;
					step  = 1;
					set   = function( info, val )
						Main.db.profile.frame.edge_size = val
						FrameSettingsChanged()
					end;
					get   = function( info )
						return Main.db.profile.frame.edge_size
					end;
				};
				bar_fontface = {
					order = 30;
					name  = L["Header Font"];
					desc  = L["Font face for header above the chatbox."];
					type  = "select";
					set   = function( info, val ) 
						Main.db.profile.frame.barfont.face = g_font_list[val]
						FrameSettingsChanged()
					end;
					get   = function( info ) 
						return FindValueKey( g_font_list, Main.db.profile.frame.barfont.face ) 
					end;
				};
				bar_font_size = {
					order = 31;
					name  = L["Header Font Size"];
					desc  = L["Font size for header above the chatbox."];
					type  = "range";
					min   = 6;
					max   = 24;
					step  = 1;
					set   = function( info, val )
						Main.db.profile.frame.barfont.size = val
						FrameSettingsChanged()
					end;
					get   = function( info )
						return Main.db.profile.frame.barfont.size
					end;
				};
				timestamp = {
					order = 32;
					name = L["Timestamps"];
					type = "select";
					values = { 
						[0] = "None";
						[1] = "HH:MM:SS";
						[2] = "HH:MM";
						[3] = "HH:MM (12-hour)";
						[4] = "MM:SS";
						[5] = "MM";
					};
					set = function( info, val )
						Main.db.profile.frame.timestamps = val
						RefreshAllChat()
					end;
					get = function( info ) 
						return Main.db.profile.frame.timestamps 
					end;
				};
				readmark_color = FrameColorOption( 40, L["Readmark Color"], L['Color for the line that separates "new" messages. (Set to transparent to disable.)'], "readmark" );
				
				show_icons = {
					order = 60;
					name  = L["Show Icons"];
					desc  = L["If using Total RP 3, show character icons next to names."];
					type  = "toggle";
					get   = function( info )
						return Main.db.profile.frame.show_icons
					end;
					set   = function( info, val )
						Main.db.profile.frame.show_icons = val
						RefreshAllChat()
					end;
				};
				zoom_icons = {
					order = 61;
					name  = L["Zoom Icons"];
					desc  = L["Zoom icons to cut off ugly borders."];
					type  = "toggle";
					get   = function( info )
						return Main.db.profile.frame.zoom_icons
					end;
					set   = function( info, val )
						Main.db.profile.frame.zoom_icons = val
						RefreshAllChat()
					end;
				};
				auto_fade_opacity = {
					order = 70;
					name  = L["Auto-fade Opacity"];
					desc  = L["Opacity for windows that fade out due to inactivity."];
					type  = "range";
					min   = 0;
					max   = 100;
					get   = function( info )
						return Main.db.profile.frame.auto_fade_opacity
					end;
					set   = function( info, val )
						Main.db.profile.frame.auto_fade_opacity = val
						for _,f in pairs( Main.frames ) do
							f:ApplyOtherOptions()
						end
					end;
				};
				
				-- tab colors
				group_tab_colors = {
					order  = 80;
					type   = "group";
					name   = L["Tab Colors"];
					inline = true;
					args   = {
						desc1 = {
							order = 1;
							type  = "description";
							name  = L["Colors for the tabs next to messages. To disable anything, just set them to transparent."];
						};
						tab_self   = FrameColorOption( 10, L["Self"], L["The tab that marks your messages."], "tab_self" );
						tab_target = FrameColorOption( 11, L["Target"],	L["The tab that marks your target's messages."], "tab_target" );
						tab_marked = FrameColorOption( 12, L["Marked"],	L["The tab that marks messages that you click!"], "tab_marked" );
					};
				};
			};
		};
		
		snoop = {
			name = L["Snooper"];
			type = "group";
			order=3;
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
					name  = L["Channel Prefix"];
					desc  = L["Show channel prefixes."];
					type  = "toggle";
					set   = function( info, val ) Main.db.profile.snoop.partyprefix = val Main.Snoop.DoUpdate() end;
					get   = function( info ) return Main.db.profile.snoop.partyprefix end;
				};
			};
		};
		
	};
}
  
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
local function InitConfigPanel()
	if g_init then return end
	g_init = true
	
	local options = Main.config_options
	
	g_font_list = SharedMedia:List( "font" ) 
	options.args.frame.args.fontface.values = g_font_list 
	options.args.frame.args.bar_fontface.values = g_font_list 
	options.args.snoop.args.fontface.values = g_font_list 
	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable( Main.db )
	options.args.profile.order = 500
	 
	AceConfig:RegisterOptionsTable( "Listener", options )
end

-------------------------------------------------------------------------------
-- Open the configuration panel.
--
function Main.OpenConfig()
	InitConfigPanel()	
	AceConfigDialog:Open( "Listener" )
	
	-- hack to fix the scrollbar missing on the first page when you
	-- first open the panel
	LibStub("AceConfigRegistry-3.0"):NotifyChange( "Listener" )
end
 
 
-------------------------------------------------------------------------------
-- Apply the configuration settings.
--
function Main:ApplyConfig( onload )
	FrameSettingsChanged()
end
 