-------------------------------------------------------------------------------
-- Snooper module.
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L    = Main.Locale
local SharedMedia = LibStub("LibSharedMedia-3.0")
Main.Snoop = {}
local Me = Main.Snoop

local g_current_name = nil
local g_update_time  = 0

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
	RAID_WARNING    = "[RW] ";
	WHISPER         = "[W From] ";
	WHISPER_INFORM  = "[W To] ";
}

-------------------------------------------------------------------------------
function Me.Setup()
	local frame = CreateFrame( "Frame", "ListenerSnoopFrame", UIParent )
	Me.frame = frame
	
	frame:SetSize( 300, 500 )
	frame:SetPoint( "CENTER", 0, 0 )
	frame:Hide()
	frame:EnableMouse( false )
	frame:SetMinResize( 300, 100 )
	
	frame:SetScript( "OnUpdate", Me.OnUpdate )
	
	frame.text = frame:CreateFontString()
	frame.text:SetPoint( "BOTTOMLEFT" )
	frame.text:SetPoint( "BOTTOMRIGHT" )
	frame.text:SetJustifyH( "LEFT" )
	frame.text:SetNonSpaceWrap( true )
	frame.text:SetWordWrap( true )
 -- frame.text:SetIndentedWordWrap( true )
 
    frame:SetClampedToScreen( true )
	
	Me.LoadSettings()
	
end

-------------------------------------------------------------------------------
-- Force refresh of the snooper window if the current target matches.
--
-- @param sender Name to check current target against.
--               nil will cause a forced refresh always.
--
function Me.DoUpdate( sender )
	if sender == nil then
		g_update_time = 0
		return
	end
	
	if g_current_name == sender then
		g_update_time = 0
	end
end

-------------------------------------------------------------------------------
-- Refresh the snooper display.
--
function Me.OnUpdate()

	if Me.unlocked then return end
	
	local name = Main.GetProbed()
	
	if g_current_name == name and GetTime() - g_update_time < 5 then
		-- throttle updates when the name matches
		return
	end
	
	g_update_time  = GetTime()
	g_current_name = name
	
	Me.SetText( g_current_name )
end

-------------------------------------------------------------------------------
local function GetHexCode( color )
	return string.format( "ff%2x%2x%2x", color[1]*255, color[2]*255, color[3]*255 )
end

-------------------------------------------------------------------------------
local ENTRY_CHAT_REMAP = { ROLL = "SYSTEM", OFFLINE = "SYSTEM", ONLINE = "SYSTEM" }
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
-- Set the text contents to name's chat history.
--
function Me.SetText( name )
 
	if name == nil or not Main.chat_history[name] or #Main.chat_history[name] == 0 then
		Me.frame.text:SetText( "" )
		return
	end
	
	local text          = ""
	local curtime       = time()
	local snooped_types = Main.db.char.snoop_filter -- todo: maybe reset this on long logout?
	
	local count = 0
	for i = #Main.chat_history[name], 1, -1 do
		local e = Main.chat_history[name][i]
		
		local msgtype = snooped_types[e.e]
		
		if msgtype then -- debug bypass
			local stamp = ""
			local old = curtime - e.t
			
			if old < 30*60 then
				-- within 30 minutes, use relative time
				if old < 60 then
					stamp = "[<1m]"
				else
					stamp = string.format( "[%sm]", math.floor(old / 60) )
				end
			else
				-- use absolute stamp
				stamp = date( "[%H:%M]", e.t )
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
			
			stamp = timecolor .. stamp
			
			if text ~= "" then
				text = "|n" .. text
			end
			
			local color = "|c" .. GetHexCode( GetEntryColor( e ) )
			
			-- replace |r in message with the text color code instead
			local msgtext = e.m
			msgtext = msgtext:gsub( "|r", color )
			
			if e.e == "EMOTE" then
				msgtext = Main.GetICName(e.s) .. " " .. msgtext
			end
			
			local prefix = MESSAGE_PREFIXES[ e.e ] or ""
			text = string.format( "%s %s%s%s", stamp, color, prefix, msgtext ) .. text
			
			count = count + 1
			if count == 10 then break end
		end
	end
	
	Me.frame.text:SetText( text )
end

-------------------------------------------------------------------------------
-- Load settings from configuration database.
--
function Me.LoadSettings()
	
	Me.frame:ClearAllPoints()
	local point = Main.db.profile.snoop.point
	if #point == 0 then
		Me.frame:SetPoint( "CENTER" )
	else
		Me.frame:SetPoint( point[1], UIParent, point[2], point[3], point[4] )
	end
	
	Me.frame:SetSize( Main.db.profile.snoop.width, Main.db.profile.snoop.height )
	Me.LoadFont()
	
	if Main.db.profile.snoop.show then
		Me.frame:Show()
	else
		Me.frame:Hide()
	end
end

-------------------------------------------------------------------------------
-- Show/hide snooper window.
--
-- @param show True to show. Saves setting in config DB.
--
function Me.Show( show )
	Main.db.profile.snoop.show = show
	if show then
		Me.frame:Show()
	else
		Me.frame:Hide()
	end
end

-------------------------------------------------------------------------------
-- Change the snooper font and save settings.
--
-- @param font Font to use. This is a SharedMedia name, not a font path.
--
function Me.SetFont( font )
	Main.db.profile.snoop.font.face = font
	Me.LoadFont()
end

-------------------------------------------------------------------------------
-- Change the font size and save settings.
--
-- @param size Height of font.
--
function Me.SetFontSize( size )
	Main.db.profile.snoop.font.size = size
	Me.LoadFont()
end

-------------------------------------------------------------------------------
-- Change the font outline and save settings.
--
-- @param val 2 = OUTLINE, 3 = THICKOUTLINE, 1/nil = no outline
--
function Me.SetOutline( val )
	Main.db.profile.snoop.font.outline = val
	Me.LoadFont()
end

-------------------------------------------------------------------------------
-- Change the text shadow setting and save config.
--
-- @param val true/false to apply text shadow.
--
function Me.SetShadow( val )
	Main.db.profile.snoop.font.shadow = val
	Me.LoadFont()
end

-------------------------------------------------------------------------------
-- Refresh the font used in the snooper window according to the configuration.
--
function Me.LoadFont()
	local outline = nil
	if Main.db.profile.snoop.font.outline == 2 then
		outline = "OUTLINE"
	elseif Main.db.profile.snoop.font.outline == 3 then
		outline = "THICKOUTLINE"
	end
	local font = SharedMedia:Fetch( "font", Main.db.profile.snoop.font.face )
	Me.frame.text:SetFont( font, Main.db.profile.snoop.font.size, outline )
	
	if Main.db.profile.snoop.font.shadow then
		
		Me.frame.text:SetShadowColor( 0, 0, 0, 0.8 )
		Me.frame.text:SetShadowOffset( 1,-1 )
	else
		
		Me.frame.text:SetShadowColor( 0, 0, 0, 0 )
	end
end

-------------------------------------------------------------------------------
-- Unlock the snooper frame and allow it to be dragged around.
--
function Me.Unlock()
	if not Me.frame.editor then
		local frame = CreateFrame( "Frame", nil, Me.frame )
		Me.frame.editor = frame
		frame:EnableMouse( true )
		frame:SetAllPoints()
		
		local label = frame:CreateFontString()
		label:SetFont( "Fonts\\ARIALN.TTF", 10, "OUTLINE" )
		label:SetText( "Right-click to lock." )
		label:SetPoint( "CENTER" )
		
		local sizer = CreateFrame( "Frame", nil, frame )
		frame.sizer = sizer
		sizer:SetSize( 16, 16 )
		sizer:SetPoint( "BOTTOMRIGHT" )
		sizer:EnableMouse( true )
		
		local tex = frame:CreateTexture( nil, "BACKGROUND" )
		tex:SetAllPoints()
		tex:SetColorTexture( 0, 0.75, 0, 0.5 )
		
		local tex = sizer:CreateTexture()
		tex:SetAllPoints()
		tex:SetTexture( "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up" )
		
		frame:SetScript( "OnMouseDown", function( self, button )
			if button == "LeftButton" then
				Me.frame:SetMovable( true )
				Me.frame:StartMoving()
			elseif button == "RightButton" then
				Me.Lock()
			end
			
			
		end)
		
		frame:SetScript( "OnMouseUp", function()
			Me.frame:StopMovingOrSizing()
			Me.frame:SetMovable( false )
		end)
		
		sizer:SetScript( "OnMouseDown", function( self, button )
			
			if button == "LeftButton" then
				Me.frame:SetResizable( true )
				Me.frame:StartSizing( "BOTTOMRIGHT" )
			end
		end)
		
		sizer:SetScript( "OnMouseUp", function()
			Me.frame:StopMovingOrSizing()
			Me.frame:SetResizable( false )
		end)
		
	end
	Me.unlocked = true
	Me.frame.text:SetText( 
[[Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut auctor convallis lobortis. Pellentesque ultrices dui mi, facilisis efficitur ante vehicula in. Donec a nibh varius, interdum metus quis, feugiat nulla.
Mauris viverra pretium convallis. Integer porta, orci ut scelerisque efficitur, felis est volutpat velit, sit amet ornare neque nulla id enim.
Maecenas enim leo, finibus id lectus porttitor, lobortis consequat arcu. Integer sed nisi et metus sagittis condimentum. Praesent in erat vulputate, porttitor magna nec, varius libero. 
Proin porta, erat id sagittis fermentum, elit lectus porttitor augue, eget rhoncus diam justo ut libero. Nunc non neque sapien.]] 
)
	Me.frame.editor:Show()
end

-------------------------------------------------------------------------------
-- Lock the snooper frame and save the position in the settings.
--
function Me.Lock()
	if Me.frame.editor then
		Me.unlocked = false
		Me.frame.editor:Hide()
		
		local point, _, point2, x, y = Me.frame:GetPoint(1)
		Main.db.profile.snoop.point = { point, point2, x, y }
		Main.db.profile.snoop.width  = Me.frame:GetWidth()
		Main.db.profile.snoop.height = Me.frame:GetHeight()
		
		Me.DoUpdate()
	end
end

function Me.SetupFilterMenu()
	Main.SetupFilterMenu(
		{ "Public", "Party", "Raid", "Instance", 
		  "Guild", "Officer", "Rolls", "Whisper", "Channel" },
		function( filter )
			return Main.db.char.snoop_filter[filter]
		end,
		function( filters, checked )
			for _,v in pairs(filters) do
				Main.db.char.snoop_filter[v] = checked
			end
			Me.DoUpdate()
		end)
end

-------------------------------------------------------------------------------
function Me.PopulateFilterSubMenu( level, menuList )
	Main.PopulateFilterSubMenu( level, menuList )
end
