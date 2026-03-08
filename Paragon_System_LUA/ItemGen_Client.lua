-- =============================================================
-- Paragon ItemGen - Client-side Tooltip Enhancement (AIO)
--
-- Scans item tooltips for "Cursed" enchantment text (from slot 11)
-- and enhances the display with purple color and warning text.
-- Also colorizes "Paragon +X" stat lines.
-- Adds a purple glow border to cursed item tooltips.
-- =============================================================

local AIO = AIO or require("AIO")
if AIO.AddAddon() then return end

-- ============================================================
-- Constants
-- ============================================================

local CURSED_TEXT       = "Cursed"
local PARAGON_PREFIX    = "Paragon +"
local COLOR_CURSED      = "|cff9b59b6"   -- purple
local COLOR_CURSED_WARN = "|cffff4444"   -- red
local COLOR_PARAGON     = "|cff00cc66"   -- green
local COLOR_RESET       = "|r"

-- ============================================================
-- Tooltip border glow for cursed items
-- ============================================================

-- Purple glow color for cursed item tooltip borders
local BORDER_CURSED_R, BORDER_CURSED_G, BORDER_CURSED_B = 0.6, 0.2, 0.8
local BORDER_CURSED_ALPHA = 1.0

-- Default tooltip border color (standard WoW tooltip border)
local BORDER_DEFAULT_R, BORDER_DEFAULT_G, BORDER_DEFAULT_B = 0.6, 0.6, 0.6
local BORDER_DEFAULT_ALPHA = 1.0

-- Track which tooltips currently have a cursed border applied
local cursedBorderActive = {}

local function SetCursedBorder(tooltip)
    tooltip:SetBackdropBorderColor(BORDER_CURSED_R, BORDER_CURSED_G, BORDER_CURSED_B, BORDER_CURSED_ALPHA)
    cursedBorderActive[tooltip] = true
end

local function ResetTooltipBorder(tooltip)
    if cursedBorderActive[tooltip] then
        tooltip:SetBackdropBorderColor(BORDER_DEFAULT_R, BORDER_DEFAULT_G, BORDER_DEFAULT_B, BORDER_DEFAULT_ALPHA)
        cursedBorderActive[tooltip] = nil
    end
end

-- ============================================================
-- Tooltip enhancement logic
-- ============================================================

local function EnhanceTooltip(tooltip)
    local numLines = tooltip:NumLines()
    if numLines < 1 then return end

    local hasCursed = false
    local hasParagon = false

    -- First pass: detect cursed and paragon lines
    for i = 1, numLines do
        local line = _G[tooltip:GetName() .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                if string.find(text, CURSED_TEXT, 1, true) then
                    hasCursed = true
                end
                if string.find(text, PARAGON_PREFIX, 1, true) then
                    hasParagon = true
                end
            end
        end
    end

    if not hasParagon then
        ResetTooltipBorder(tooltip)
        return
    end

    -- Second pass: colorize lines
    for i = 1, numLines do
        local line = _G[tooltip:GetName() .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                -- Colorize "Cursed" line
                if string.find(text, CURSED_TEXT, 1, true) and not string.find(text, PARAGON_PREFIX, 1, true) then
                    line:SetText(COLOR_CURSED .. ">> CURSED <<" .. COLOR_RESET)
                    line:SetTextColor(0.608, 0.349, 0.714) -- purple
                -- Colorize paragon stat lines
                elseif string.find(text, PARAGON_PREFIX, 1, true) then
                    if hasCursed then
                        line:SetTextColor(0.608, 0.349, 0.714) -- purple for cursed
                    else
                        line:SetTextColor(0.0, 0.8, 0.4) -- green for normal
                    end
                end
            end
        end
    end

    -- Apply purple border glow for cursed items
    if hasCursed then
        SetCursedBorder(tooltip)
        tooltip:AddLine(" ")
        tooltip:AddLine(COLOR_CURSED_WARN .. "This item is cursed and soulbound." .. COLOR_RESET, 1, 0.267, 0.267, false)
    else
        ResetTooltipBorder(tooltip)
    end

    tooltip:Show()
end

-- ============================================================
-- Tooltip hooking via hooksecurefunc
--
-- HookScript("OnTooltipSetItem") may not fire reliably in AIO
-- context. Instead, we post-hook the individual Set* methods
-- that populate item tooltips, which is more reliable.
-- ============================================================

-- Track last processed tooltip item to avoid re-processing
-- when multiple Set* methods fire for the same tooltip display
local lastProcessed = {}

local function SafeEnhance(tooltip)
    local _, itemLink = tooltip:GetItem()
    if not itemLink then return end

    -- Avoid re-processing the same item on the same tooltip
    if lastProcessed[tooltip] == itemLink then return end
    lastProcessed[tooltip] = itemLink

    EnhanceTooltip(tooltip)
end

local function ClearTooltipState(tooltip)
    lastProcessed[tooltip] = nil
    ResetTooltipBorder(tooltip)
end

-- List of GameTooltip methods that display item information
local ITEM_METHODS = {
    "SetBagItem",
    "SetInventoryItem",
    "SetLootItem",
    "SetLootRollItem",
    "SetMerchantItem",
    "SetQuestItem",
    "SetQuestLogItem",
    "SetTradePlayerItem",
    "SetTradeTargetItem",
    "SetHyperlink",
    "SetAuctionItem",
    "SetAuctionSellItem",
    "SetGuildBankItem",
    "SetInboxItem",
    "SetSendMailItem",
    "SetTradeSkillItem",
    "SetCraftItem",
}

local function HookTooltip(tooltip)
    for _, method in ipairs(ITEM_METHODS) do
        if tooltip[method] then
            hooksecurefunc(tooltip, method, function(self)
                SafeEnhance(self)
            end)
        end
    end

    -- Clear state when tooltip is hidden or cleared
    if tooltip.HookScript then
        tooltip:HookScript("OnTooltipCleared", function(self)
            ClearTooltipState(self)
        end)
        tooltip:HookScript("OnHide", function(self)
            ClearTooltipState(self)
        end)
    end
end

-- Hook main tooltips
HookTooltip(GameTooltip)
HookTooltip(ItemRefTooltip)

-- Hook shopping (comparison) tooltips
for i = 1, 3 do
    local tip = _G["ShoppingTooltip" .. i]
    if tip then
        HookTooltip(tip)
    end
end

-- Debug: confirm addon loaded
DEFAULT_CHAT_FRAME:AddMessage("|cff9b59b6[Paragon ItemGen]|r Tooltip enhancement loaded.")
