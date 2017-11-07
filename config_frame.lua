
local Main = ListenerAddon
local L    = Main.Locale

local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local SharedMedia     = LibStub("LibSharedMedia-3.0")

-- todo;
--anchor (point, frame, relativePoint, offsetX, offsetY)
--width
--height

-------------------------------------------------------------------------------
local ANCHOR_VALUES = {
	TOPLEFT     = "Top Left";
	TOP         = "Top";
	TOPRIGHT    = "Top Right";
	LEFT        = "Left";
	CENTER      = "Center";
	RIGHT       = "Right";
	BOTTOMLEFT  = "Bottom Left";
	BOTTOM      = "Bottom";
	BOTTOMRIGHT = "Bottom Right";
};

local g_frame  -- the current frame
local g_char   -- per character options for current frame
local g_prof   -- per profile options for current frame
local g_main   -- if this is frame 1

local function SwitchMain()
	return g_main and g_prof or g_char
end

local function ApplyOptionsAll()
	for _, frame in pairs( Main.frames ) do
		frame:ApplyOptions()
	end
end

local function ApplyOptionsAllIfMain()
	if g_main then
		for _, frame in pairs( Main.frames ) do
			frame:ApplyOptions()
		end
	else
		g_frame:ApplyOptions()
	end	
end

local function ValidateAnchorName( info, val )
	return true
end

local function ValidateNumber( info, val )
	local a = tonumber(val)
	if not a then
		return "Value must be a number."
	end
	return true
end

-------------------------------------------------------------------------------
-- Creates a color option block.
--
local function ColorOption( order, name, desc, color )	
	return {
		order    = order;
		name     = name;
		desc     = desc;
		type     = "color";
		hasAlpha = true;
		
		get = function( info )
			local col = g_char.color[color] or g_prof.color[color]
			return unpack( col )
		end;
		
		set = function( info, r, g, b, a )
			SwitchMain().color[color] = { r, g, b, a }
			if g_main then
				for _, frame in pairs( Main.frames ) do
					frame:ApplyColorOptions()
				end
			else
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
		easycolor = {
			order = 13;
			name = L["Easy Color"];
			desc = L["Set background and edge color according to title bar color."];
			type = "execute";
			func = function()
				local base = g_char.color.bar or g_prof.color.bar
				
				local options = SwitchMain()
				if not options.color.bg then
					options.color.bg = { 1, 1, 1, 1 }
				end
				
				if not options.color.edge then
					options.color.edge = {1,1,1,1}
				end
				
				options.color.bg[1] = base[1] * 0.2
				options.color.bg[2] = base[2] * 0.2
				options.color.bg[3] = base[3] * 0.2
				options.color.edge[1] = base[1]
				options.color.edge[2] = base[2]
				options.color.edge[3] = base[3]
				if g_main then
					for _, frame in pairs( Main.frames ) do
						frame:ApplyColorOptions()
					end
				else
					g_frame:ApplyColorOptions()
				end
			end;
		};
		hidecombat = {
			order = 20;
			name = L["Hide During Combat"];
			desc = L["Hide this window during combat."];
			type = "toggle";
			set = function( info, val ) g_char.combathide = val end;
			get = function( info ) return g_char.combathide end;
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
				SwitchMain().tab_size = val
				ApplyOptionsAllIfMain()
			end;
			get   = function( info )
				return g_char.tab_size or g_prof.tab_size
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
				SwitchMain().time_visible = val
				ApplyOptionsAllIfMain()
			end;
			
			get = function( info, val )
				return g_char.time_visible or g_prof.time_visible
			end;
		};
		
		-- layout settings
		layout = {
			name = L["Layout"];
			type = "group";
			inline = true;
			args = {
				anchor_from = {
					order  = 10;
					name   = L["Anchor From"];
					desc   = L["Point on the frame to anchor from."];
					type   = "select";
					values = ANCHOR_VALUES;
					get = function( info ) 
						return SwitchMain().layout.anchor[1]
					end;
					set = function( info, val ) 
						SwitchMain().layout.anchor[1] = val
						g_frame:ApplyLayoutOptions()
					end;
				};
				
				anchor_to = {
					order  = 11;
					name   = L["Anchor To"];
					desc   = L["Point on the anchor frame to attach to."];
					type   = "select";
					values = ANCHOR_VALUES;
					get = function( info ) 
						return SwitchMain().layout.anchor[3]
					end;
					set = function( info, val ) 
						SwitchMain().layout.anchor[3] = val
						g_frame:ApplyLayoutOptions()
					end;
				};
				
				anchor_name = {
					order = 12;
					name  = L["Anchor Region"];
					desc  = L["Name of frame to anchor to. Leave blank to anchor to screen. Use /fstack to find frame names."];
					type  = "input";
					validate = ValidateAnchorName;
					get = function( info )
						return SwitchMain().layout.anchor[2] or ""
					end;
					set = function( info, val )
						if val == "" then
							SwitchMain().layout.anchor[2] = nil
						else
							SwitchMain().layout.anchor[2] = val
						end
						g_frame:ApplyLayoutOptions()
					end;
				};
				
				separator2 = {
					order = 13;
					type  = "description";
					name  = "";
				};
				anchor_x = {
					order = 20;
					name  = L["X"];
					desc  = L["Horizontal offset."];
					type  = "input";
					width = "half";
					validate = ValidateNumber;
					get = function( info )
						return tostring(SwitchMain().layout.anchor[4])
					end;
					set = function( info, val )
						SwitchMain().layout.anchor[4] = tonumber(val)
						g_frame:ApplyLayoutOptions()
					end;
				};
				
				anchor_y = {
					order = 21;
					name  = L["Y"];
					desc  = L["Vertical offset."];
					type  = "input";
					width = "half";
					validate = ValidateNumber;
					get = function( info )
						return tostring(SwitchMain().layout.anchor[5])
					end;
					set = function( info, val )
						SwitchMain().layout.anchor[5] = tonumber(val)
						g_frame:ApplyLayoutOptions()
					end;
				};
				
		--[[		separator1 = {
					order = 22;
					type  = "description";
					name  = "";
				};]]
				
				width = {
					order = 30;
					name  = L["Width"];
					desc  = L["Width of frame."];
					type  = "input";
					width = "half";
					validate = ValidateNumber;
					get = function( info )
						return tostring(SwitchMain().layout.width)
					end;
					set = function( info, val )
						SwitchMain().layout.width = tonumber(val)
						g_frame:ApplyLayoutOptions()
					end;
				};
				
				height = {
					order = 31;
					name  = L["Height"];
					desc  = L["Height of frame."];
					type  = "input";
					width = "half";
					validate = ValidateNumber;
					get = function( info )
						return tostring(SwitchMain().layout.height)
					end;
					set = function( info, val )
						SwitchMain().layout.height = tonumber(val)
						g_frame:ApplyLayoutOptions()
					end;
				};
			};
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
	g_char  = Main.db.char.frames[frame.frame_index]
	g_prof  = Main.db.profile.frame
	g_main  = frame.frame_index == 1
	AceConfigDialog:SetDefaultSize( "Listener Frame Settings", 420, 400 )
	AceConfigDialog:Open( "Listener Frame Settings" )
	LibStub("AceConfigRegistry-3.0"):NotifyChange( "Listener Frame Settings" )
end

-------------------------------------------------------------------------------
function Main.CloseFrameConfig( frame )
	if frame == g_frame then
		AceConfigDialog:Close( "Listener Frame Settings" )
	end
end
