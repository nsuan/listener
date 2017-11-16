--
-- The Probe is a module that tracks who is targeted or moused over.
--

local Main = ListenerAddon

local g_probe_target = nil
local g_probe_guid   = nil
local g_probe_time   = 0
local g_probe_frame

-- Time until the probe is reset when not touching anyone.
local PROBE_TIMEOUT = 0.5

-------------------------------------------------------------------------------
function Main.GetProbed()
	return g_probe_target, g_probe_guid
end

-------------------------------------------------------------------------------
-- Update function (called periodically).
--
function Main.UpdateProbe()
	
	local unit, unitname, unitguid
	if UnitExists( "target" ) then 
		unit = "target"
	elseif UnitExists( "mouseover" ) then
		unit = "mouseover"
	end
	
	if not UnitIsPlayer( unit ) then unit = nil end
	if unit then 
		unitname = Main.FullName( unit )
		unitguid = UnitGUID( unit )
	end

	if unitname then
		-- reset the timer if we have a valid unit
		g_probe_time = GetTime()
	end
	
	if not unitname then
		if GetTime() < g_probe_time + PROBE_TIMEOUT then
			unitname = g_probe_target
			unitguid = g_probe_guid
		end
	end
	
	if g_probe_target == unitname then 
		return -- already a match
	end
	
	g_probe_target = unitname
	g_probe_guid   = unitguid
	Main.OnProbeChanged()
	
end

-------------------------------------------------------------------------------
-- Put anything in here that you want to change when the probed target
-- changes.
function Main.OnProbeChanged()
	-- update snooper
	-- update active window
	
	for _,f in pairs( Main.frames ) do
		f:UpdateProbe()
	end
	--Main.active_frame:UpdateProbe()
end

-------------------------------------------------------------------------------
function Main.SetupProbe()
	if g_probe_frame then error( "Tried to recreate probe frame." ) end
	g_probe_frame = CreateFrame("Frame")
	g_probe_frame:SetScript( "OnUpdate", function()
		Main.UpdateProbe()
	end)
	g_probe_frame:Show()
end
