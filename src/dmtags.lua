local Main = ListenerAddon
Main.DMTags = {}
local Me = Main.DMTags
local SharedMedia = LibStub("LibSharedMedia-3.0")

Me.unitframes = {}
Me.tags       = {}
Me.last_update = 0

local CUTOFF_TIME = 3600 -- 1 hour

-- colors:
-- blue -> gray -> darker gray -> red | orange
-- blue is new message
-- orange is the response priority (oldest message)

-------------------------------------------------------------------------------
function Me.Setup()
	Me.frame = CreateFrame( "Frame" )
	Me.roster_dirty = true
	Me.LoadFont()
	
	if not Main.db.char.dmtags then
		Me.frame:Hide()
	end
	
	Me.frame:SetScript( "OnUpdate", function()
		Me.Update()
	end)
end

-------------------------------------------------------------------------------
function Me.LoadFont()
	local font = SharedMedia:Fetch( "font", Main.db.profile.dmtags.font.face )
	ListenerDMTagFont:SetFont( font, Main.db.profile.dmtags.font.size )
	ListenerDMTagFont:SetShadowColor( 0,0,0,0 )
end

-------------------------------------------------------------------------------
function Me.Enable( enabled )
	Main.db.char.dmtags = enabled
	if enabled then
		Me.roster_dirty = true
		Me.last_update = 0
		Me.frame:Show()
	else
		Me.frame:Hide()
		
		-- cleanup tags here.
		Me.StartTagging()
		Me.StopTagging()
		
	end
end

-------------------------------------------------------------------------------
function Me.HookFrames()
	local frame = nil
	
	local list = {}
	
	while true do
		frame = EnumerateFrames( frame )
		if not frame then break end
		
		if frame:IsVisible() and frame:HasScript( "OnClick" ) 
		   and frame:GetScript( "OnClick" ) == SecureUnitButton_OnClick then
		   
			local unit = frame:GetAttribute( "unit" )
			if unit then
				if unit:match( "raid[0-9]+" ) or unit:match( "party[1-9]" ) then
					local name = Main.FullName( unit )
					
					if name then
						if not list[name] then
							list[name] = {
								frames = {}
								
							}
						end
						
						table.insert( list[name].frames, frame )
					end
				end
			end
			--thanks Semler!
			
		end
	end
	
	Me.unitframes = list
	-- [name] = { 
	--   frames = { frames ... }
	--
end

function Me.OnDoubleClick( self )
	if not self.player then return end
	
	-- when the user double clicks one of the tags
	-- it sets highlight on all of the entries of the tag
	
	local time = time()
	local chat = Main.chat_history[ self.player ]
	if chat then
		for i = #chat, 1, -1 do
			local e = chat[i]
			if Main.frames[2].listen_events[e.e] then
				-- only mark messages at least 3 seconds old.
				if e.t >= time - CUTOFF_TIME and e.t < time - 3 then
					e.h = true
				end
			end
		end
	end
	
	for _,f in pairs( Main.frames ) do
		f:UpdateHighlight()
	end
	
	Me.last_update = 0
end

-------------------------------------------------------------------------------
local function ToNumber2( expr )
	return tonumber( expr ) or 0
end
local function Hexc( hex )
	return {ToNumber2("0x"..hex:sub(1,2))/255, ToNumber2("0x"..hex:sub(3,4))/255, ToNumber2("0x"..hex:sub(5,6))/255, ToNumber2("0x"..hex:sub(7,8))/255}
end

-------------------------------------------------------------------------------
function Me.StartTagging()
	Me.next_tag = 1
end

function Me.Tag( frame, name, time, orange )
	local tag = Me.tags[Me.next_tag]
	if not tag then
		tag = CreateFrame( "ListenerDMTag", "ListenerDMTag" .. Me.next_tag, UIParent )
		tag:SetScript( "OnDoubleClick", Me.OnDoubleClick )
		Me.tags[Me.next_tag] = tag
	end
	Me.next_tag = Me.next_tag + 1
	
	local color
	if orange then
		color = Hexc "f67502FF"
	elseif time < 90 then
		color = Hexc "1574cdFF"
	elseif time < 180 then
		color = Hexc "999999FF"
	elseif time < 300 then
		color = Hexc "888888FF"
	elseif time < 450 then
		color = Hexc "777777FF"
	elseif time < 600 then
		color = Hexc "666666FF"
	else
		color = Hexc "e32727FF"
	end
	
	local text
	if time < 60 then
		text = "<1m"
	else
		text = tostring(math.floor( time / 60 + 0.5 )) .. "m"
	end
	
	tag:Show()
	tag.player = name
	tag:SetText( text, color )
	tag:Attach( frame )
end

function Me.DoneTagging()
	for i = Me.next_tag, #Me.tags do
		Me.tags[i]:Hide()
	end
end

-------------------------------------------------------------------------------
function Me.Update()
	if Me.roster_dirty then
		-- rehook frames
		C_Timer.After( 1, function()
			Me.HookFrames()
		end)
		Me.roster_dirty = false
	end

	if GetTime() < Me.last_update + 1 then
		return
	end
	
	Me.last_update = GetTime()
	
	Me.StartTagging()
	
	local times = {}
	local time = time()
	
	local oldest_time = time+1
	local oldest_name = nil
	
	for name, _ in pairs( Me.unitframes ) do
		local chat = Main.chat_history[ name ]
		if chat then
			local oldest = time
			
			for i = #chat, 1, -1 do
				local e = chat[i]
				if not e.h and not e.p and Main.frames[2].listen_events[e.e] then
					if e.t < time - CUTOFF_TIME then
						break
					end
					if e.t < oldest then
						oldest = e.t
					end
				end
			end
			times[name] = oldest
			
			if oldest < oldest_time then
				oldest_time = oldest
				oldest_name = name
			end
		end
	end
	
	for name, unitdata in pairs( Me.unitframes ) do
	
		local t = times[name]
		if t then
			t = time - t
			if t > 0 then
				
				for _, f in pairs( unitdata.frames) do
					Me.Tag( f, name, t, name == oldest_name )
				end
			end
		end
	end
	
	Me.DoneTagging()
end
