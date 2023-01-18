------------------------------------------------------
--GLOBALS
------------------------------------------------------
local time_since_last_buff_update = 0
local time_since_last_roster_update = 0
local current_roster = {}

local seconds_remaining_threshold_for_low_warning = 480
local check_for_weapon_oil = true

--buffs given from players
local buffs = {
    ["MotW"] = {names = {"Mark of the Wild", "Gift of the Wild"}, class = "Druid", priority = 1},
    ["Fort"] = {names = {"Power Word: Fortitude", "Prayer of Fortitude"}, class = "Priest", priority = 1},
    ["Spirit"] = {names = {"Prayer of Spirit", "Improved Divine Spirit"}, class = "Priest", priority = 2},
    ["AI"] = {names = {"Arcane Brilliance", "Arcane Intellect"}, class = "Mage", priority = 1},
    ["Wisdom"] = {names = {"Blessing of Wisdom", "Greater Blessing of Wisdom"}, class = "Paladin", priority = 1},
    ["Kings"] = {names = {"Blessing of Kings", "Greater Blessing of Kings"}, class = "Paladin", priority = 2},
    ["Salv"] = {names = {"Blessing of Salv", "Greater Blessing of Salv"}, class = "Paladin", priority = 3}
}

--consumable buffs
local consumes = {
    ["Elixir of Healing Power"] = {"Healing Power"},
    ["Elixir of Draenic Wisdom"] = {"Elixir of Draenic Wisdom"},
    ["Food Buff"] = {"Well Fed"},
    ["Rum"] = {"Rumsey Rum Black Label"}
}

--consumable item quantities
--note: healthstones are already handled by default in a special way, so don't put them in this table.
local stock = {
    ["Elixir of Healing Power"] = {item_id = 22825, min_count = 10, charges = false},
    ["Elixir of Draenic Wisdom"] = {item_id = 32067, min_count = 10, charges = false},
    ["Super Mana Pot"] = {item_id = 22832, min_count = 10, charges = false},
    ["Rumsey Rum"] = {item_id = 21151, min_count = 10, charges = false},
    ["Golden Fish Sticks"] = {item_id = 27666, min_count = 10, charges = false},
    ["Dark Rune"] = {item_id = 20520, min_count = 10, charges = false},
    ["Brilliant Mana Oil"] = {item_id = 20748, min_count = 10, charges = true},
    ["Flintwood Seed"] = {item_id = 22147, min_count = 5, charges = false},
    ["Wild Quillvine"] = {item_id = 22148, min_count = 20, charges = false}
}

------------------------------------------------------
--FRAME
------------------------------------------------------
local f = CreateFrame("Frame", "LowOrMissingBuffsFrame", UIParent)

--Layout
f:SetFrameStrata("BACKGROUND")
f:SetHeight(800)
f:SetWidth(250)
f:SetPoint("TOPLEFT", UIParent, "TOPLEFT",20,0)
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

local function update_current_roster(group_size)
    current_roster = {}
    for i=1,group_size do
        local unit_id = "raid"..i
        local raid_id = UnitInRaid(unit_id) + 1
        local _, _, group, _, class = GetRaidRosterInfo(raid_id)

        local max_groups
        if group_size <= 20 then
            max_groups = 2
        else
            max_groups = 5
        end

        if current_roster[class] == nil and group <= max_groups then
            current_roster[class] = 1
        elseif current_roster[class] ~= nil and group <= max_groups then
            current_roster[class] = current_roster[class] + 1
        end
    end
end

local function check_for_raid()
    local group_type, group_size = get_group_type_and_size()
    if group_type == "raid" then
        f:Show()
        update_current_roster(group_size)
    elseif f:IsVisible() then
        f:Hide()
    end
end

local function get_current_buffs()
    current_buffs = {}
    for i = 1,40 do
        name, _, _, _, _, expirationTime = UnitBuff("player", i)
        if name ~= nil then
            current_buffs[name] = expirationTime
        end
    end

    return current_buffs
end

local function get_buff_status(buff_info, current_buffs)
    if current_roster[buff_info.class] ~= nil then
        if buff_info.priority <= current_roster[buff_info.class] then
            for k, v in pairs(buff_info.names) do
                if current_buffs[v] then
                    return current_buffs[v]
                end
            end

            return 0
        end
    end

    return nil
end

local function get_consume_status(buff_info, current_buffs)
    for k, v in pairs(buff_info) do
        if current_buffs[v] then
            return current_buffs[v]
        end
    end

    return 0
end

local function check_buffs(current_buffs, text)
    for key, buff_info in pairs(buffs) do
        local buff_status = get_buff_status(buff_info, current_buffs)
        if buff_status ~= nil then
            if buff_status == 0 then
                text = text.."Missing "..key.."\n"
            elseif buff_status < seconds_remaining_threshold_for_low_warning then
                text = text.."Low on "..key.."\n"
            end
        end
    end

    return text
end

local function check_weapon_oil(text)
    has_oil, oil_expiration = GetWeaponEnchantInfo()
    if oil_expiration == nil then
        text = text.."Missing Weapon Oil\n"
    elseif oil_expiration/1000 < seconds_remaining_threshold_for_low_warning then
        text = text.."Low on Weapon Oil\n"
    end

    return text
end

local function check_consumes(current_buffs)
    local text = ""
    for key, buff_set in pairs(consumes) do
        local buff_status = get_consume_status(buff_set, current_buffs)
        if buff_status == 0 then
            text = text.."Missing "..key.."\n"
        elseif buff_status < seconds_remaining_threshold_for_low_warning then
            text = text.."Low on "..key.."\n"
        end
    end

    return text
end

local function check_stock()
    local text = ""
    for key, stock_info in pairs(stock) do
        item_count = GetItemCount(stock_info.item_id, false, stock_info.charges)

        if item_count == 0 then
            text = text.."Out of "..key.."\n"
        elseif item_count < stock_info.min_count then
            text = text.."Only "..item_count.." "..key.." remaining\n"
        end
    end

    return text
end

local function hs_text_maker(item_id)
    local text = ""
    if GetItemCount(item_id) > 0 then
        text = text.."+++"
    else
        text = text.."---"
    end
    return text
end

local function check_hs()
    local text = ""

    local lock_count = current_roster["Warlock"]
    if lock_count ~= nil then
        text = text.."Lock count: "..lock_count.."\n"
        text = text.."R0: "..hs_text_maker(22103).."  "
        text = text.."R1: "..hs_text_maker(22104).."  "
        text = text.."R2: "..hs_text_maker(22105)
    end

    return text
end

local function update_buff_text()
    local current_buffs = get_current_buffs()

    local text = check_buffs(current_buffs, "")
    if text ~= "" then
        text = "------------------------------------\nLow/Missing Buffs\n------------------------------------\n"..text.."\n"
    end

    local consumes_text = check_consumes(current_buffs)
    if check_for_weapon_oil then
        consumes_text = check_weapon_oil(consumes_text)
    end
    if consumes_text ~= "" then
        text = text.."------------------------------------\nLow/Missing Consumes\n------------------------------------\n"..consumes_text.."\n"
    end

    local stock_text = check_stock()
    if stock_text ~= "" then
        text = text.."------------------------------------\nLow Stock\n------------------------------------\n"..stock_text.."\n"
    end

    local hs_text = check_hs()
    if hs_text ~= "" then
        text = text.."------------------------------------\nHealthstones\n------------------------------------\n"..hs_text
    end

    f.text:SetText(text)
end

local function MyAddon_OnUpdate(self, elapsed)
    time_since_last_buff_update = time_since_last_buff_update + elapsed
    time_since_last_roster_update = time_since_last_roster_update + elapsed

    if (time_since_last_buff_update > 1) then
        update_buff_text()
        time_since_last_buff_update = 0
    end

    if (time_since_last_roster_update > 10) then
        check_for_raid()
        time_since_last_roster_update = 0
    end
end

------------------------------------------------------
--EVENTS
------------------------------------------------------
f:SetScript("OnUpdate", MyAddon_OnUpdate)

local events = {};
function events:RAID_ROSTER_UPDATE(...)
    check_for_raid()
end

function events:PLAYER_LOGIN(...)
    check_for_raid()
end

function events:PLAYER_REGEN_DISABLED(...)
    if f:IsVisible() then
        f:Hide()
    end
end

function events:PLAYER_REGEN_ENABLED(...)
    check_for_raid()
end

f:SetScript("OnEvent", function(self, event, ...)
	events[event](self, ...); -- call one of the functions above
end);
for k, v in pairs(events) do
	f:RegisterEvent(k); -- Register all events for which handlers have been defined
end
