
local Main = ListenerAddon
local L    = Main.Locale

local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local SharedMedia     = LibStub("LibSharedMedia-3.0")

-- todo;
--anchor (point, frame, relativePoint, offsetX, offsetY)
--width
--height

local g_frame -- the current frame

local function ApplyOptionsAll()
	for _, frame in pairs( Main.frames ) do
		frame:ApplyOptions()
	end
end

-------------------------------------------------------------------------------
-- Creates a color option block.
--
local function ColorOption( order, name, desc, color )	
	return {
		order    = 10;
		name     = name;
		desc     = desc;
		type     = "color";
		hasAlpha = true;
		
		get = function( info )
			if g_frame.frame_index == 1 then
				return unpack( Main.db.profile.frame.color[color] )
			else
				local c = Main.db.char.frames[g_frame.frame_index].color[color] or Main.db.profile.frame.color[color]
				return unpack( c )
			end
		end;
		
		set = function( info, r, g, b, a )
			if g_frame.frame_index == 1 then
				Main.db.profile.frame.color[color] = { r, g, b, a }
				for _, frame in pairs( Main.frames ) do
					frame:ApplyColorOptions()
				end
			else
				Main.db.char.frames[g_frame.frame_index].color[color] = { r, g, b, a }
				g_frame:ApplyColorOptions()
			end
		end;
	}
end

-------------------------------------------------------------------------------
local OPTIONS = {
	type = "group";
	args = {
		bg_color   = ColorOption( 10, L["Background Color"], nil, "bg" );
		edge_color = ColorOption( 11, L["Edge Color"], nil, "edge" );
		bar_color  = ColorOption( 12, L["Bar Color"], nil, "bar" );
		hidecombat = {
			order = 20;
			name = L["Hide During Combat"];
			desc = L["Hide this window during combat."];
			type = "toggle";
			set = function( info, val )
				Main.db.char.frames[g_frame.frame_index].combathide = val
			end;
			get = function( info ) 
				return Main.db.char.frames[g_frame.frame_index].combathide 
			end;
		};
		tabsize = {
			order = 30;
			name  = L["Tab Size"];
			desc  = L["Size of the marker tabs to the left of the messages."];
			type  = "range";
			min   = 0;
			max   = 16;
			step  = 1;
			set   = function( info, val )
				if g_frame.frame_index == 1 then 
					Main.db.profile.frame.tab_size = val
					ApplyOptionsAll()
				else
					Main.db.char.frames[g_frame.frame_index] = val
					g_frame:ApplyOptions()
				end
			end;
			get   = function( info )
				return Main.db.char.frames[g_frame.frame_index].tab_size
					   or Main.db.profile.frame.tab_size
			end;
		};
		time_visible = {
			order = 40;
			name  = L["Message visible time."];
			desc  = L["Time that messages are kept visible (seconds). 0 disables fading."];
			type  = "range";
			min   = 0;
			max   = 1000;
			step  = 1;
			
			set = function( info, val )
				if g_frame.frame_index == 1 then
					Main.db.profile.frame.time_visible = val
					ApplyOptionsAll()
				else
					Main.db.char.frames[self.frame_index].time_visible = val
					g_frame:ApplyOptions()
				end
			end;
			
			get = function( info, val )
				
				return Main.db.char.frames[g_frame.frame_index].time_visible
				       or Main.db.profile.frame.time_visible
			end;
		};
	};
}

-------------------------------------------------------------------------------
-- Open the configuration panel for a frame.
local g_init
function Main.OpenFrameConfig( frame )
	if not g_init then
		AceConfig:RegisterOptionsTable( "Listener Frame Settings", OPTIONS )
	end
	
	g_frame = frame
	AceConfigDialog:SetDefaultSize( "Listener Frame Settings", 400, 300 )
	AceConfigDialog:Open( "Listener Frame Settings" )
	LibStub("AceConfigRegistry-3.0"):NotifyChange( "Listener Frame Settings" )
end

-------------------------------------------------------------------------------
function Main.CloseFrameConfig( frame )
	if frame == g_frame then
		AceConfigDialog:Close( "Listener Frame Settings" )
	end
end
