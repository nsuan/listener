-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2016)
-------------------------------------------------------------------------------

local Listener = ListenerAddon
Listener.Locale = {}
local L = Listener.Locale

-------------------------------------------------------------------------------
setmetatable( L, { 

	-- Normally, the key is the translation in english. 
	-- If a value isn't found, just return the key.
	__index = function( table, key ) 
		return key 
	end;
	
	-- When treating the L table like a function, it can accept arguments
	-- that will replace {1}, {2}, etc in the text.
	__call = function( table, key, ... )
		key = table[key] -- first we get the translation
		
		local args = {...}
		for i = 1, #args do
			local text = select( i, ... )
			key = key:gsub( key, "{" .. i .. "}", args[i] )
		end
		return key
	end;
})

-- remove excess whitespace and newlines, and convert "\n" to newline
local function tidystring( str )

	return (str:gsub( "%s+", " " ):match("^%s*(.-)%s*$"):gsub("\\n","\n"))
end

-------------------------------------------------------------------------------
--L["Version:"] =                          -- Version string for help

--L["read"]     =                          -- Chat command
--L["add"]      =                          -- Chat command
--L["remove"]   =                          -- Chat command
--L["clear"]    =                          -- Chat command
--L["list"]     =                          -- Chat command
--L["Specify name or target someone."] =   -- Error message

--L["Player list: "]        =              -- When listing players.
--L["Cleared all players."] =              -- When resetting player list.
--L["Removed: "]            =              -- When removing a player.
--L["Not listening: "]      =              -- When trying to remove a player.
--L["Added: "]              =              -- When adding a player.
--L["Already listening: "]  =              -- When trying to add a player.

-------------------------------------------------------------------------------
L.help_listenerframe = tidystring [[
	This is Listener's chatbox. You can filter out players by holding shift and right-clicking them.
    The green button in the upper left corner can add them back. Hold shift to drag and resize this window.
    You can toggle this window by clicking the minimap button.
	See the information on the Curse.com page for more information.
]]

L.help_snooper = tidystring [[
	This is the "snooper" display. When you mouseover or target someone, their recent chat history will show up in here.
	It's for helping keep track of what a player is saying.
	Move and drag this to where you want and then right click to lock it in place.
	You can adjust the settings by right clicking the minimap icon and going to Snooper.
]]