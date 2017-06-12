-- snooper

local Main = ListenerAddon
local L = Main.Locale
local SharedMedia = LibStub("LibSharedMedia-3.0")

local g_current_name = nil
local g_update_time = 0

function Main:Snoop_Setup()
	local frame = CreateFrame( "Frame", "ListenerSnoopFrame", UIParent )
	frame:SetSize( 300, 500 )
	frame:SetPoint( "CENTER", 0, 0 )
	frame:Hide()
	frame:EnableMouse( false )
	frame:SetMinResize( 300, 100 )
	
	frame:SetScript( "OnUpdate", function() Main:Snoop_OnUpdate() end )
	
	frame.text = frame:CreateFontString()
	frame.text:SetPoint( "BOTTOMLEFT" )
	frame.text:SetPoint( "BOTTOMRIGHT" )
	frame.text:SetJustifyH( "LEFT" )
	frame.text:SetNonSpaceWrap( true )
	frame.text:SetWordWrap( true )
 --   frame.text:SetIndentedWordWrap( true )
 
    frame:SetClampedToScreen( true )
	
	self:Snoop_LoadSettings()
	
end

function Main:Snoop_DoUpdate()
	g_update_time = 0
end

function Main:Snoop_OnUpdate()

	if Main.snoop_unlocked then return end
	
    local name = UnitName( "target" )
    if name == nil then 
        name = UnitName("mouseover") 
    end
	
	if g_current_name == name and GetTime() - g_update_time < 5 then
		-- throttle updates when the name matches
		return
	end
	g_update_time = GetTime()
	g_current_name = name
	
	self:Snoop_SetText( g_current_name )
end

local function GetHexCode( color )
	return string.format( "ff%2x%2x%2x", color[1]*255, color[2]*255, color[3]*255 )
end


local g_prefixes = {
	
	PARTY          = "[P] ";
	PARTY_LEADER   = "[P] ";
	RAID           = "[R] ";
	RAID_LEADER    = "[R] ";
	RAID_WARNING   = "[RW] ";
}


function Main:Snoop_SetText( name )
 
	if name == nil or not self.chat_history[name] or #self.chat_history[name] == 0 then
		ListenerSnoopFrame.text:SetText( "" )
		return
	end
	
	local color_say = GetHexCode( Main.db.profile.colors.SAY )
	local color_say = GetHexCode( Main.db.profile.colors.SAY )
	local color_say = GetHexCode( Main.db.profile.colors.SAY )
	local color_say = GetHexCode( Main.db.profile.colors.SAY )
	
	local text = ""
	
	local curtime = time()
	
	local g_snooped_types = {}
	
	if Main.Frame.showsay then
		g_snooped_types["SAY"] = 1
		g_snooped_types["YELL"] = 1
		g_snooped_types["EMOTE"] = 1
		g_snooped_types["TEXT_EMOTE"] = 1
	end
	
	if Main.Frame.showparty then
		g_snooped_types["PARTY"] = 1
		g_snooped_types["PARTY_LEADER"] = 1
		g_snooped_types["RAID"] = 1
		g_snooped_types["RAID_LEADER"] = 1
		g_snooped_types["RAID_WARNING"] = 1
		g_snooped_types["ROLL"] = 1
	end
	
	local count = 0
	for i = #self.chat_history[name], 1, -1 do
		local e = self.chat_history[name][i]
		
		local msgtype = g_snooped_types[e.e]
		
		if msgtype then
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
				timecolor = "|cff222222"
			elseif old >= 300 then
				timecolor = "|cff444444"
			elseif old >= 60 then
				timecolor = "|cff666666"
			else
				timecolor = "|cff9999ff"
			end
			
			stamp = timecolor .. stamp .. "|r"
			
			if text ~= "" then
				text = "|n" .. text
			end
			
			local color = GetHexCode( Main.db.profile.colors[e.e] )
			
			local prefix = (Main.db.profile.snoop.partyprefix and g_prefixes[ e.e ]) or ""
			text = string.format( "%s |c%s%s%s|r", stamp, color, prefix, e.m ) .. text
			--[[if e.e == "SAY" then
				text = string.format( "%s %s", stamp, e.m ) .. text
			elseif e.e == "YELL" then
				text = string.format( "%s |c%s%s|r", stamp, e.m ) .. text
			elseif e.e == "EMOTE" then
				text = string.format( "%s |cfff18d0a%s|r", stamp, e.m ) .. text
			elseif e.e == "TEXT_EMOTE" then
				text = string.format( "%s |cfff18d0a%s|r", stamp, e.m ) .. text
			end]]
			
			count = count + 1
			if count == 10 then break end
		end
	end
	
	ListenerSnoopFrame.text:SetText( text )
end

-------------------------------------------------------------------------------
function Main:Snoop_LoadSettings()
	
	ListenerSnoopFrame:ClearAllPoints()
	local point = Main.db.profile.snoop.point
	if #point == 0 then
		ListenerSnoopFrame:SetPoint( "CENTER" )
	else
		ListenerSnoopFrame:SetPoint( point[1], UIParent, point[2], point[3], point[4] )
	end
	ListenerSnoopFrame:SetSize( Main.db.profile.snoop.width, Main.db.profile.snoop.height )
	Main:Snoop_LoadFont()
	
	if Main.db.profile.snoop.show then
		ListenerSnoopFrame:Show()
	else
		ListenerSnoopFrame:Hide()
	end
end

-------------------------------------------------------------------------------
function Main:Snoop_Show( show ) 
	self.db.profile.snoop.show = show
	if show then
		ListenerSnoopFrame:Show()
	else
		ListenerSnoopFrame:Hide()
	end
end

-------------------------------------------------------------------------------
function Main:Snoop_SetFont( font )
	self.db.profile.snoop.font.face = font
	self:Snoop_LoadFont()
end

-------------------------------------------------------------------------------
function Main:Snoop_SetFontSize( size )
	self.db.profile.snoop.font.size = size
	self:Snoop_LoadFont()
end

-------------------------------------------------------------------------------
function Main:Snoop_SetOutline( val )
	self.db.profile.snoop.font.outline = val
	self:Snoop_LoadFont()
end

-------------------------------------------------------------------------------
function Main:Snoop_SetShadow( val )
	self.db.profile.snoop.font.shadow = val
	self:Snoop_LoadFont()
end

-------------------------------------------------------------------------------
function Main:Snoop_LoadFont()
	local outline = nil
	if self.db.profile.snoop.font.outline == 2 then
		outline = "OUTLINE"
	elseif self.db.profile.snoop.font.outline == 3 then
		outline = "THICKOUTLINE"
	end
	local font = SharedMedia:Fetch( "font", self.db.profile.snoop.font.face )
	ListenerSnoopFrame.text:SetFont( font, self.db.profile.snoop.font.size, outline )
	
	if self.db.profile.snoop.font.shadow then
		
		ListenerSnoopFrame.text:SetShadowColor( 0, 0, 0, 0.8 )
		ListenerSnoopFrame.text:SetShadowOffset( 1,-1 )
	else
		
		ListenerSnoopFrame.text:SetShadowColor( 0, 0, 0, 0 )
	end
end

-------------------------------------------------------------------------------
function Main:Snoop_Unlock()
	if not ListenerSnoopFrame.editor then
		local frame = CreateFrame( "Frame", nil, ListenerSnoopFrame )
		ListenerSnoopFrame.editor = frame
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
				ListenerSnoopFrame:SetMovable( true )
				ListenerSnoopFrame:StartMoving()
			elseif button == "RightButton" then
				Main:Snoop_Lock()
			end
			
			
		end)
		
		frame:SetScript( "OnMouseUp", function()
			ListenerSnoopFrame:StopMovingOrSizing()
			ListenerSnoopFrame:SetMovable( false )
		end)
		
		sizer:SetScript( "OnMouseDown", function( self, button )
			
			if button == "LeftButton" then
				ListenerSnoopFrame:SetResizable( true )
				ListenerSnoopFrame:StartSizing( "BOTTOMRIGHT" )
			end
		end)
		
		sizer:SetScript( "OnMouseUp", function()
			ListenerSnoopFrame:StopMovingOrSizing()
			ListenerSnoopFrame:SetResizable( false )
		end)
		
	end
	self.snoop_unlocked = true
	ListenerSnoopFrame.text:SetText( 
[[Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut auctor convallis lobortis. Pellentesque ultrices dui mi, facilisis efficitur ante vehicula in. Donec a nibh varius, interdum metus quis, feugiat nulla.
Mauris viverra pretium convallis. Integer porta, orci ut scelerisque efficitur, felis est volutpat velit, sit amet ornare neque nulla id enim.
Maecenas enim leo, finibus id lectus porttitor, lobortis consequat arcu. Integer sed nisi et metus sagittis condimentum. Praesent in erat vulputate, porttitor magna nec, varius libero. 
Proin porta, erat id sagittis fermentum, elit lectus porttitor augue, eget rhoncus diam justo ut libero. Nunc non neque sapien.]] 
)
	ListenerSnoopFrame.editor:Show()
end

-------------------------------------------------------------------------------
function Main:Snoop_Lock()
	if ListenerSnoopFrame.editor then
		self.snoop_unlocked = false
		ListenerSnoopFrame.editor:Hide()
		local point, _, point2, x, y = ListenerSnoopFrame:GetPoint(1)
		self.db.profile.snoop.point = { point, point2, x, y }
		 
		self.db.profile.snoop.width  = ListenerSnoopFrame:GetWidth()
		self.db.profile.snoop.height = ListenerSnoopFrame:GetHeight()
		
		Main:Snoop_DoUpdate()
	end
end


