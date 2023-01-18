------------------------------------------------------
--GLOBALS
------------------------------------------------------
local time_since_last_update = 0

local seconds_remaining_threshold_for_low_warning = 480
local buffs = {"Mark of the Wild", "Gift of the Wild"}
local buff_needers = {}

------------------------------------------------------
--FRAME
------------------------------------------------------
local f = CreateFrame("Frame", "RaidersMissingMyBuffFrame", UIParent)

--Layout
f:SetFrameStrata("BACKGROUND")
f:SetHeight(500)
f:SetWidth(300)
f:SetPoint("TOPLEFT", UIParent, "TOPLEFT",270,0)
f.background = f:CreateTexture(nil, "BACKGROUND")
f.background:SetTexture(0,0,0,0)
f.background:SetAllPoints()

--Text
f.text = f:CreateFontString(nil, "ARTWORK")
f.text:SetFont("Interface\\AddOns\\MecBuffChecker\\media\\skurri.ttf", 16)
f.text:SetPoint("LEFT", f, "LEFT")
f.text:SetJustifyH("LEFT")
f.text:SetTextColor(1,1,1,1)
f.text:SetShadowColor(0, 0, 0, 1)
f.text:SetShadowOffset(1, -1)
f.text:SetPoint("TOP", 0, -2)

------------------------------------------------------
--FUNCTIONS
------------------------------------------------------
local function is_in_list(tbl, val)
	--checks if a given table contains a given value
    for index, value in pairs(tbl) do
        if value == val then
            return true
        end
    end
    return false
end

function pairs_order_by_values_desc(tab)
    local keys = {}
    for k in pairs(tab) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b) return tab[a] < tab[b] end)
    local j = 0
    return function()
        j = j + 1
        local k = keys[j]
        if k ~= nil then
            return k, tab[k]
        end
    end
end

local function get_group_type_and_size()
	local party_size = GetNumPartyMembers()
	local raid_size = GetNumRaidMembers()

	if party_size == 0 and raid_size == 0 then
		return "solo", 1
	elseif party_size >= 1 and raid_size == 0 then
		return "party", party_size
	elseif raid_size >= 1 then
		return "raid", raid_size
	end
end

local function needs_buff(unit)
    for i = 1,40 do
        buff_name, _, _, _, _, expiration_time = UnitBuff(unit, i)
        if buff_name ~= nil then
            if is_in_list(buffs, buff_name) and expiration_time == nil then
                return false
            elseif is_in_list(buffs, buff_name) and expiration_time <= seconds_remaining_threshold_for_low_warning then
                return true
            elseif is_in_list(buffs, buff_name) and expiration_time > seconds_remaining_threshold_for_low_warning then
                return false
            end
        end
    end

    if #buffs > 0 then return true else return false end
end

local function update_buff_needers(group_size)
    buff_needers = {}
    for i=1,group_size do
        local unit_id = "raid"..i
        local raid_id = UnitInRaid(unit_id) + 1
        local name, _, group, _, _, _, _, online = GetRaidRosterInfo(raid_id)

        local max_groups
        if group_size <= 20 then
            max_groups = 2
        else
            max_groups = 5
        end

        if  name ~= nil and group <= max_groups then -- and online == 1 then
            if needs_buff(unit_id) then
                buff_needers[name] = group
            end
        end
    end
end

local function set_text()
    local text = ""

    for k, v in pairs_order_by_values_desc(buff_needers) do
        text = text.."\nG"..v..": "..k
    end

    if text ~= "" then
        text = "------------------------------------\nMissing MotW\n------------------------------------"..text
    end

    f.text:SetText(text)
end

local function update_buff_text()
    local group_type, group_size = get_group_type_and_size()
    if group_type == "raid" then
        f:Show()
        update_buff_needers(group_size)
        set_text()
    elseif f:IsVisible() then
        f:Hide()
    end
end

local function MyAddon_OnUpdate(self, elapsed)
    time_since_last_update = time_since_last_update + elapsed

    if (time_since_last_update > 1) then
        update_buff_text()
        time_since_last_update = 0
    end
end

------------------------------------------------------
--EVENTS
------------------------------------------------------
f:SetScript("OnUpdate", MyAddon_OnUpdate)

local events = {};
function events:RAID_ROSTER_UPDATE(...)
    update_buff_text()
end

function events:PLAYER_LOGIN(...)
    update_buff_text()
end

f:SetScript("OnEvent", function(self, event, ...)
	events[event](self, ...); -- call one of the functions above
end);
for k, v in pairs(events) do
	f:RegisterEvent(k); -- Register all events for which handlers have been defined
end
