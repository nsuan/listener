-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
-------------------------------------------------------------------------------
 
-- the amazing help interface

local Main = ListenerAddon
local L    = Main.Locale

local g_help_list = {}

function Main.HelpNote_OnClose( self )
	Main.db.global.help[ self.id ] = true
end

function Main.HelpNote_Setup( note, id, text ) 
	note.id = id
	note:SetPoint( "CENTER", 0, 50 )
	note.text:SetText( text )
	note:SetHeight( note.text:GetStringHeight() + 22 ) 
	note:Show()
end


-------------------------------------------------------------------------------
-- Add a help element to the system.
--
-- @param frame  Frame to attach the help note to.
-- @param id     ID of this help note.
-- @param onload Function to run if this help is loaded.
--
local function AddHelp( frame, id, onload )

	if Main.db.global.help[id] then return end -- this help was already shown
	
	if frame.helpnote then
		frame.helpnote:Show()
		return
	end
	
	local note = CreateFrame( "ListenerHelpNote", nil, frame ) 
	
	-- see translations for text help_<id>
	note:Setup( id, L["help_" .. id] )
	frame.helpnote = note
	if onload then onload() end
end

-------------------------------------------------------------------------------
function Main.Help_Init()
	
	-- see locale for text
	
	AddHelp( ListenerFrame1, "listenerframe" ) 
	AddHelp( ListenerSnoopFrame, "snooper", function()
		Main.Snoop.Unlock()
	end)
end

-------------------------------------------------------------------------------
-- Reset and show help notes again.
--
function Main.Help_Reset()
	Main.db.global.help = {}
end

Main.AddLoadCall( function()
	Main.Help_Init()
end)
