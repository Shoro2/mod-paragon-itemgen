-- =============================================================
-- Paragon ItemGen - Client-side Tooltip Enhancement (AIO)
--
-- Scans item tooltips for "Cursed" enchantment text (from slot 11)
-- and enhances the display with purple color and warning text.
-- Also colorizes "Paragon +X" stat lines.
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
-- Tooltip hooking
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
                if text == CURSED_TEXT then
                    hasCursed = true
                end
                if string.find(text, PARAGON_PREFIX, 1, true) then
                    hasParagon = true
                end
            end
        end
    end

    if not hasParagon then return end

    -- Second pass: colorize lines
    for i = 1, numLines do
        local line = _G[tooltip:GetName() .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                -- Colorize "Cursed" line
                if text == CURSED_TEXT then
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

    -- Add extra warning line for cursed items
    if hasCursed then
        tooltip:AddLine(" ")
        tooltip:AddLine(COLOR_CURSED_WARN .. "This item is cursed and soulbound." .. COLOR_RESET, 1, 0.267, 0.267, false)
    end

    tooltip:Show()
end

-- Hook both main tooltip and comparison tooltips
GameTooltip:HookScript("OnTooltipSetItem", function(self) EnhanceTooltip(self) end)
ItemRefTooltip:HookScript("OnTooltipSetItem", function(self) EnhanceTooltip(self) end)

-- Hook shopping (comparison) tooltips
for i = 1, 3 do
    local tip = _G["ShoppingTooltip" .. i]
    if tip then
        tip:HookScript("OnTooltipSetItem", function(self) EnhanceTooltip(self) end)
    end
end
