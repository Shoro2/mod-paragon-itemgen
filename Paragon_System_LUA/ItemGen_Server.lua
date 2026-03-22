-- =============================================================
-- Paragon ItemGen - Server-side AIO Data Provider
--
-- Reads paragon enchantment data directly from items in the
-- player's inventory and sends it to the client via AIO.
-- This removes the dependency on client-side DBC patching
-- for tooltip display.
--
-- Data is sent on login and refreshed on client request.
-- The client Lua addon uses this data to build custom tooltip
-- lines showing paragon stats, cursed status, and passives.
-- =============================================================

local AIO = AIO or require("AIO")

-- ============================================================
-- Constants (must match ParagonItemGen.h)
-- ============================================================

local ENCHANT_BASE     = 900000
local ENCHANT_STRIDE   = 1000
local ENCHANT_MAX_STAT = 16
local ENCHANT_CURSED   = 920001
local PASSIVE_MIN      = 950001
local PASSIVE_MAX      = 950099

-- ============================================================
-- Passive spell name cache (loaded from world DB)
-- ============================================================

local passiveNames = {}

local function LoadPassiveNames()
	local query = WorldDBQuery("SELECT `enchantmentId`, `name` FROM `paragon_passive_spell_pool`")
	if not query then return end
	repeat
		passiveNames[query:GetUInt32(0)] = query:GetString(1)
	until not query:NextRow()
end

LoadPassiveNames()

-- ============================================================
-- Reading PROP_ENCHANTMENT slots (7-11) via raw UpdateFields
--
-- Eluna's GetEnchantmentId() only allows slots 0-6
-- (MAX_INSPECTED_ENCHANTMENT_SLOT). We use GetUInt32Value()
-- to read the enchantment IDs from the item's UpdateFields.
--
-- UpdateField layout (from UpdateFields.h):
--   ITEM_FIELD_ENCHANTMENT_1_1 = OBJECT_END + 0x0010 = 0x0016 = 22
--   Each slot occupies 3 uint32 fields (ID, duration, charges)
--   Enchantment ID for slot S = field index 22 + S * 3
--
-- PROP_ENCHANTMENT slots:
--   Slot 7  → field 43  (ITEM_FIELD_ENCHANTMENT_8_1)
--   Slot 8  → field 46  (ITEM_FIELD_ENCHANTMENT_9_1)
--   Slot 9  → field 49  (ITEM_FIELD_ENCHANTMENT_10_1)
--   Slot 10 → field 52  (ITEM_FIELD_ENCHANTMENT_11_1)
--   Slot 11 → field 55  (ITEM_FIELD_ENCHANTMENT_12_1)
-- ============================================================

local ENCH_FIELD_BASE = 22  -- ITEM_FIELD_ENCHANTMENT_1_1
local ENCH_FIELD_STEP = 3   -- fields per enchantment slot

local function GetPropEnchantId(item, enchSlot)
	return item:GetUInt32Value(ENCH_FIELD_BASE + enchSlot * ENCH_FIELD_STEP)
end

-- ============================================================
-- Enchantment decoding
-- ============================================================

local function IsParagonStatEnchant(enchId)
	return enchId > ENCHANT_BASE
		and enchId <= ENCHANT_BASE + (ENCHANT_MAX_STAT + 1) * ENCHANT_STRIDE
end

local function DecodeStatEnchant(enchId)
	if not IsParagonStatEnchant(enchId) then
		return nil, 0
	end
	local offset = enchId - ENCHANT_BASE
	local statIdx = math.floor(offset / ENCHANT_STRIDE)
	local amount  = offset % ENCHANT_STRIDE
	return statIdx, amount
end

local function BuildItemData(item)
	-- Slot 7 must contain a paragon stat enchant (stamina)
	local slot7 = GetPropEnchantId(item, 7)
	if not IsParagonStatEnchant(slot7) then
		return nil
	end

	local _, staAmt   = DecodeStatEnchant(slot7)
	local mi, mainAmt = DecodeStatEnchant(GetPropEnchantId(item, 8))
	local c1i, c1Amt  = DecodeStatEnchant(GetPropEnchantId(item, 9))
	local c2i, c2Amt  = DecodeStatEnchant(GetPropEnchantId(item, 10))

	local slot11 = GetPropEnchantId(item, 11)
	local cursed = false
	local passiveName = nil

	if slot11 == ENCHANT_CURSED then
		cursed = true
	elseif slot11 >= PASSIVE_MIN and slot11 <= PASSIVE_MAX then
		cursed = true
		passiveName = passiveNames[slot11] or ("Enchantment #" .. slot11)
	end

	return {
		sa  = staAmt,
		mi  = mi,  ma = mainAmt,
		c1i = c1i, c1a = c1Amt,
		c2i = c2i, c2a = c2Amt,
		cu  = cursed,
		pn  = passiveName
	}
end

-- ============================================================
-- Inventory scan → client-coordinate mapping
--
-- Server (Eluna GetItemByPos):
--   bag=255, slot=0-18   → equipped        → client "E", invSlot=slot+1
--   bag=255, slot=23-38  → backpack        → client "B", bag=0, slot=slot-22
--   bag=19-22, slot=0-N  → extra bags 1-4  → client "B", bag=bag-18, slot=slot+1
-- ============================================================

local function SendParagonItemData(player)
	local items = {}

	-- Equipment (server 0-18 → client invSlot 1-19)
	for slot = 0, 18 do
		local item = player:GetItemByPos(255, slot)
		if item then
			local d = BuildItemData(item)
			if d then
				d.t = "E"
				d.s = slot + 1
				items[#items + 1] = d
			end
		end
	end

	-- Backpack (server slot 23-38 → client container 0, slot 1-16)
	for slot = 23, 38 do
		local item = player:GetItemByPos(255, slot)
		if item then
			local d = BuildItemData(item)
			if d then
				d.t = "B"
				d.b = 0
				d.s = slot - 22
				items[#items + 1] = d
			end
		end
	end

	-- Extra bags (server bag 19-22 → client container 1-4)
	for bag = 19, 22 do
		for slot = 0, 35 do
			local item = player:GetItemByPos(bag, slot)
			if item then
				local d = BuildItemData(item)
				if d then
					d.t = "B"
					d.b = bag - 18
					d.s = slot + 1
					items[#items + 1] = d
				end
			end
		end
	end

	AIO.Handle(player, "PARAGON_ITEMGEN_CLIENT", "ReceiveData", items)
end

-- ============================================================
-- AIO handler: client requests a data refresh
-- ============================================================

local ServerHandler = AIO.AddHandlers("PARAGON_ITEMGEN_SERVER", {})

function ServerHandler.RequestRefresh(player)
	SendParagonItemData(player)
end

-- ============================================================
-- Send data automatically on player login
-- ============================================================

RegisterPlayerEvent(3, function(event, player) -- PLAYER_EVENT_ON_LOGIN
	SendParagonItemData(player)
end)
