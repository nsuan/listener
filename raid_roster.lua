
--
-- a little module for converting player names into raid groups
--

local Main = ListenerAddon

--
-- raid_groups[name] = group number
-- for cross realm, will contain keys for both name and name-realm
-- and will break if the same base name exists :)
--
Main.raid_groups = {}

function Main.UpdateRaidRoster()
	Main.raid_groups = {}
	if not IsInRaid() then return end
	
	for i = 1, GetNumGroupMembers() do
		local name, _, subgroup = GetRaidRosterInfo(i)
		local shortname = name:gsub( "-.*", "" )
		Main.raid_groups[name] = subgroup
		Main.raid_groups[shortname] = subgroup
	end
end
