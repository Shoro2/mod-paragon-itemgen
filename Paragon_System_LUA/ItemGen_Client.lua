-- =============================================================
-- Paragon ItemGen - Client-side Tooltip Enhancement (AIO)
--
-- Displays paragon item stats, cursed status, and passive spell
-- effects in item tooltips.
--
-- Two display methods (tried in order):
--   1. AIO data: Server sends enchantment data decoded from the
--      item's PROP_ENCHANTMENT slots. Works WITHOUT client DBC
--      patching. Covers equipped + bag items.
--   2. DBC text fallback: Scans tooltip for "Paragon +" and
--      "Cursed" text from the enchantment Name_Lang_enUS field.
--      Requires client SpellItemEnchantment.dbc to be patched.
--      Covers all tooltip sources (loot, quest, vendor, etc.).
-- =============================================================

local AIO = AIO or require("AIO")
if AIO.AddAddon() then return end

-- ============================================================
-- Stat name lookup (must match ParagonStatIndex enum)
-- ============================================================

local STAT_NAMES = {
	[0]  = "Stamina",
	[1]  = "Strength",
	[2]  = "Agility",
	[3]  = "Intellect",
	[4]  = "Spirit",
	[5]  = "Dodge Rating",
	[6]  = "Parry Rating",
	[7]  = "Defense Rating",
	[8]  = "Block Rating",
	[9]  = "Hit Rating",
	[10] = "Crit Rating",
	[11] = "Haste Rating",
	[12] = "Expertise Rating",
	[13] = "Armor Penetration",
	[14] = "Spell Power",
	[15] = "Attack Power",
	[16] = "Mana Regen",
}

-- ============================================================
-- Colors
-- ============================================================

local COLOR_CURSED      = "|cff9b59b6"
local COLOR_CURSED_WARN = "|cffff4444"
local COLOR_PARAGON     = "|cff00cc66"
local COLOR_PASSIVE     = "|cffa335ee"
local COLOR_HEADER      = "|cff00ff00"
local COLOR_RESET       = "|r"

-- DBC text patterns (fallback detection)
local CURSED_TEXT    = "Cursed"
local PASSIVE_PREFIX = "Passive:"
local PARAGON_PREFIX = "Paragon +"

-- ============================================================
-- Tooltip border glow for cursed items
-- ============================================================

local BORDER_CURSED_R, BORDER_CURSED_G, BORDER_CURSED_B = 0.6, 0.2, 0.8
local BORDER_DEFAULT_R, BORDER_DEFAULT_G, BORDER_DEFAULT_B = 0.6, 0.6, 0.6
local cursedBorderActive = {}

local function SetCursedBorder(tooltip)
	tooltip:SetBackdropBorderColor(BORDER_CURSED_R, BORDER_CURSED_G, BORDER_CURSED_B, 1.0)
	cursedBorderActive[tooltip] = true
end

local function ResetTooltipBorder(tooltip)
	if cursedBorderActive[tooltip] then
		tooltip:SetBackdropBorderColor(BORDER_DEFAULT_R, BORDER_DEFAULT_G, BORDER_DEFAULT_B, 1.0)
		cursedBorderActive[tooltip] = nil
	end
end

-- ============================================================
-- AIO data cache
--
-- equipCache[invSlot]         = { staAmount, mainStatIdx, ... }
-- bagCache[container][slot]   = { ... }
-- ============================================================

local equipCache = {}
local bagCache   = {}

local ClientHandler = AIO.AddHandlers("PARAGON_ITEMGEN_CLIENT", {})

function ClientHandler.ReceiveData(player, items)
	equipCache = {}
	bagCache   = {}

	if not items then return end

	for _, e in ipairs(items) do
		local data = {
			staAmount   = e.sa,
			mainStatIdx = e.mi, mainAmount = e.ma,
			cr1Idx      = e.c1i, cr1Amount = e.c1a,
			cr2Idx      = e.c2i, cr2Amount = e.c2a,
			cursed      = e.cu,
			passiveName = e.pn,
		}

		if e.t == "E" then
			equipCache[e.s] = data
		elseif e.t == "B" then
			if not bagCache[e.b] then bagCache[e.b] = {} end
			bagCache[e.b][e.s] = data
		end
	end
end

-- ============================================================
-- Tooltip context tracking
-- ============================================================

local tooltipContext  = {}   -- [tooltip] = { type, arg1, arg2 }
local lastProcessed  = {}   -- [tooltip] = itemLink

local function SetContext(tooltip, ctxType, a1, a2)
	tooltipContext[tooltip] = { type = ctxType, a1 = a1, a2 = a2 }
end

local function ClearState(tooltip)
	tooltipContext[tooltip] = nil
	lastProcessed[tooltip]  = nil
	ResetTooltipBorder(tooltip)
end

local function GetCachedData(tooltip)
	local ctx = tooltipContext[tooltip]
	if not ctx then return nil end

	if ctx.type == "equip" then
		return equipCache[ctx.a1]
	elseif ctx.type == "bag" then
		return bagCache[ctx.a1] and bagCache[ctx.a1][ctx.a2]
	end

	return nil
end

-- ============================================================
-- AIO-based tooltip lines
-- ============================================================

local function AddParagonLines(tooltip, data)
	if not data then return false end

	local staName  = STAT_NAMES[0]
	local mainName = STAT_NAMES[data.mainStatIdx] or "Main Stat"
	local cr1Name  = STAT_NAMES[data.cr1Idx]      or "Rating"
	local cr2Name  = STAT_NAMES[data.cr2Idx]      or "Rating"

	tooltip:AddLine(" ")

	if data.cursed then
		tooltip:AddLine(COLOR_CURSED .. ">> CURSED <<" .. COLOR_RESET, 0.608, 0.349, 0.714)
		tooltip:AddLine(COLOR_CURSED .. "+" .. data.staAmount  .. " " .. staName  .. COLOR_RESET, 0.608, 0.349, 0.714)
		tooltip:AddLine(COLOR_CURSED .. "+" .. data.mainAmount .. " " .. mainName .. COLOR_RESET, 0.608, 0.349, 0.714)
		tooltip:AddLine(COLOR_CURSED .. "+" .. data.cr1Amount  .. " " .. cr1Name  .. COLOR_RESET, 0.608, 0.349, 0.714)
		tooltip:AddLine(COLOR_CURSED .. "+" .. data.cr2Amount  .. " " .. cr2Name  .. COLOR_RESET, 0.608, 0.349, 0.714)

		if data.passiveName then
			tooltip:AddLine(COLOR_PASSIVE .. "Passive: " .. data.passiveName .. COLOR_RESET, 0.639, 0.208, 0.933)
		end

		tooltip:AddLine(" ")
		tooltip:AddLine(COLOR_CURSED_WARN .. "This item is cursed and soulbound." .. COLOR_RESET, 1, 0.267, 0.267)

		SetCursedBorder(tooltip)
	else
		tooltip:AddLine(COLOR_PARAGON .. "+" .. data.staAmount  .. " " .. staName  .. COLOR_RESET, 0.0, 0.8, 0.4)
		tooltip:AddLine(COLOR_PARAGON .. "+" .. data.mainAmount .. " " .. mainName .. COLOR_RESET, 0.0, 0.8, 0.4)
		tooltip:AddLine(COLOR_PARAGON .. "+" .. data.cr1Amount  .. " " .. cr1Name  .. COLOR_RESET, 0.0, 0.8, 0.4)
		tooltip:AddLine(COLOR_PARAGON .. "+" .. data.cr2Amount  .. " " .. cr2Name  .. COLOR_RESET, 0.0, 0.8, 0.4)

		ResetTooltipBorder(tooltip)
	end

	tooltip:Show()
	return true
end

-- ============================================================
-- DBC text-based fallback (for patched clients or
-- non-inventory tooltips like loot/quest/vendor)
-- ============================================================

local function FallbackDBCEnhance(tooltip)
	local numLines = tooltip:NumLines()
	if numLines < 1 then return false end

	local hasCursed, hasPassive, hasParagon = false, false, false

	for i = 1, numLines do
		local line = _G[tooltip:GetName() .. "TextLeft" .. i]
		if line then
			local text = line:GetText()
			if text then
				if string.find(text, CURSED_TEXT, 1, true)    then hasCursed  = true end
				if string.find(text, PASSIVE_PREFIX, 1, true)  then hasPassive = true end
				if string.find(text, PARAGON_PREFIX, 1, true)  then hasParagon = true end
			end
		end
	end

	local isCursedItem = hasCursed or hasPassive
	if not hasParagon and not isCursedItem then
		ResetTooltipBorder(tooltip)
		return false
	end

	-- Colorize existing lines
	for i = 1, numLines do
		local line = _G[tooltip:GetName() .. "TextLeft" .. i]
		if line then
			local text = line:GetText()
			if text then
				if string.find(text, CURSED_TEXT, 1, true)
					and not string.find(text, PASSIVE_PREFIX, 1, true)
					and not string.find(text, PARAGON_PREFIX, 1, true) then
					line:SetText(COLOR_CURSED .. ">> CURSED <<" .. COLOR_RESET)
					line:SetTextColor(0.608, 0.349, 0.714)

				elseif string.find(text, PASSIVE_PREFIX, 1, true) then
					line:SetText(COLOR_PASSIVE .. text .. COLOR_RESET)
					line:SetTextColor(0.639, 0.208, 0.933)

				elseif string.find(text, PARAGON_PREFIX, 1, true) then
					if isCursedItem then
						line:SetTextColor(0.608, 0.349, 0.714)
					else
						line:SetTextColor(0.0, 0.8, 0.4)
					end
				end
			end
		end
	end

	if isCursedItem then
		SetCursedBorder(tooltip)
		tooltip:AddLine(" ")
		tooltip:AddLine(COLOR_CURSED_WARN .. "This item is cursed and soulbound." .. COLOR_RESET, 1, 0.267, 0.267)
	else
		ResetTooltipBorder(tooltip)
	end

	tooltip:Show()
	return true
end

-- ============================================================
-- Main tooltip enhancement entry point
-- ============================================================

local function EnhanceTooltip(tooltip)
	local _, itemLink = tooltip:GetItem()
	if not itemLink then return end

	if lastProcessed[tooltip] == itemLink then return end
	lastProcessed[tooltip] = itemLink

	-- Method 1: AIO-based data (works without client DBC)
	local data = GetCachedData(tooltip)
	if data then
		AddParagonLines(tooltip, data)
		return
	end

	-- Method 2: DBC text-based fallback (works with patched client)
	FallbackDBCEnhance(tooltip)
end

-- ============================================================
-- Tooltip hooking
-- ============================================================

local function HookTooltip(tooltip)
	-- Bag items: capture (container, slot) for cache lookup
	if tooltip.SetBagItem then
		hooksecurefunc(tooltip, "SetBagItem", function(self, bag, slot)
			SetContext(self, "bag", bag, slot)
			EnhanceTooltip(self)
		end)
	end

	-- Equipped items: capture inventory slot
	if tooltip.SetInventoryItem then
		hooksecurefunc(tooltip, "SetInventoryItem", function(self, unit, slot)
			if unit == "player" then
				SetContext(self, "equip", slot)
			else
				SetContext(self, "other")
			end
			EnhanceTooltip(self)
		end)
	end

	-- Trade items from own inventory (same as bag)
	if tooltip.SetTradePlayerItem then
		hooksecurefunc(tooltip, "SetTradePlayerItem", function(self)
			SetContext(self, "other")
			EnhanceTooltip(self)
		end)
	end

	-- All other tooltip sources (loot, quest, vendor, etc.)
	-- No position data available → relies on DBC fallback
	local OTHER_METHODS = {
		"SetLootItem", "SetLootRollItem", "SetMerchantItem",
		"SetQuestItem", "SetQuestLogItem", "SetTradeTargetItem",
		"SetHyperlink", "SetAuctionItem", "SetAuctionSellItem",
		"SetGuildBankItem", "SetInboxItem", "SetSendMailItem",
		"SetTradeSkillItem", "SetCraftItem",
	}

	for _, method in ipairs(OTHER_METHODS) do
		if tooltip[method] then
			hooksecurefunc(tooltip, method, function(self)
				SetContext(self, "other")
				EnhanceTooltip(self)
			end)
		end
	end

	-- Clear state on hide/clear
	if tooltip.HookScript then
		tooltip:HookScript("OnTooltipCleared", function(self)
			ClearState(self)
		end)
		tooltip:HookScript("OnHide", function(self)
			ClearState(self)
		end)
	end
end

HookTooltip(GameTooltip)
HookTooltip(ItemRefTooltip)

for i = 1, 3 do
	local tip = _G["ShoppingTooltip" .. i]
	if tip then HookTooltip(tip) end
end

-- ============================================================
-- Auto-refresh: request updated data when inventory changes
-- ============================================================

local refreshFrame   = CreateFrame("Frame")
local refreshPending = false
local refreshDelay   = 0

refreshFrame:RegisterEvent("BAG_UPDATE")
refreshFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
refreshFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

refreshFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_ENTERING_WORLD" then
		refreshDelay = 2
	else
		refreshDelay = 0.5
	end
	refreshPending = true
	self:SetScript("OnUpdate", function(frame, elapsed)
		refreshDelay = refreshDelay - elapsed
		if refreshDelay <= 0 then
			refreshPending = false
			frame:SetScript("OnUpdate", nil)
			AIO.Handle("PARAGON_ITEMGEN_SERVER", "RequestRefresh")
		end
	end)
end)

-- ============================================================
DEFAULT_CHAT_FRAME:AddMessage("|cff9b59b6[Paragon ItemGen]|r Tooltip enhancement loaded.")
