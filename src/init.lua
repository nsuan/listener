-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
-------------------------------------------------------------------------------

local VERSION = GetAddOnMetadata( "Listener", "Version" )

-------------------------------------------------------------------------------
ListenerAddon = LibStub("AceAddon-3.0"):NewAddon( "Listener", 
	             		  "AceEvent-3.0", "AceTimer-3.0" ) 

local Main = ListenerAddon

-------------------------------------------------------------------------------
Main.version  = VERSION
Main.unlocked = false

local g_init_funcs = {}
local g_load_funcs = {}

-------------------------------------------------------------------------------
function Main.AddSetup( func )
	table.insert( g_init_funcs, func )
end

-------------------------------------------------------------------------------
function Main.AddLoadCall( func )
	table.insert( g_load_funcs, func )
end

-------------------------------------------------------------------------------
function Main.Setup()
	 
	if not g_init_funcs then
		error( "Setup has already been called." )
	end
	
	for _,init in pairs( g_init_funcs ) do
		init()
	end
	
	g_init_funcs = nil
end

-------------------------------------------------------------------------------
function Main.Init_OnEnabled()
	for _,f in pairs( g_load_funcs ) do
		f()
	end
end
