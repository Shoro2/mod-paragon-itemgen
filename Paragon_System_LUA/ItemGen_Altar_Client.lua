-- =============================================================
-- Paragon ItemGen - Cursed Altar window (client side, AIO addon, WoW 3.3.5a)
--
-- The server half is src/ParagonItemGenAltar.cpp. The window shows what the server sends and sends the click as a
-- chat command; the server decides every sacrifice and bind, so a greyed button is only a convenience.
--
-- Server -> client: addon whisper from the player to himself, prefix PIGALT, "<kind>;<body>":
--   O                                         open the window (the altar object was used)
--   B;<atAltar>;<essence>;<classId>;<heartstones>
--   S;<rec>~<rec>...   bag,slot,itemEntry,quality,enchId,yield,known,spellId,name     (sacrifice candidates)
--   T;<rec>~<rec>...   bag,slot,itemEntry,quality,essenceCost,heartstoneCost           (bind targets)
--   P;<rec>~<rec>...   enchId,spellId,specMask,unlocked,retired,name                   (class pool + retired)
--   E                                         end of a data set (B ... E)
--   R;<ok>;<text>                             the answer to the last action
-- Client -> server (chat commands): .paragon altar sync | sacrifice <bag> <slot> | bind <bag> <slot> <enchId>
-- bag 0 = backpack, 1-4 = bags; slot counts from 1 (what GetContainerItemInfo takes).
--
-- Opens with /altar, the altar object, or ParagonAltar_Open() (the /fl hub calls that).
-- =============================================================

local AIO = AIO or require("AIO")
if AIO.AddAddon() then return end

-- AIO can run this file twice in one UI session; the frames are built once.
if ParagonAltar_Loaded then return end
ParagonAltar_Loaded = true

-- FLUI (fl-lua-scripts AIO_UI/) draws the window in the player's theme.
local FLUI = assert(FLUI, "the Cursed Altar needs AIO_UI/FLUI_Client.lua loaded first")

local PREFIX = "PIGALT"
local CURSED_MARKER = 920001
local TOKEN_ITEM = 920300
local MATERIAL_ITEM = 920301

local FRAME_W, FRAME_H = 680, 560
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ESSENCE_ICON = "Interface\\Icons\\Spell_Shadow_SoulLeech_3"
local MATERIAL_ICON = "Interface\\Icons\\INV_Misc_Gem_Bloodstone_01"
local POLL_SECONDS = 10      -- the altar distance is re-read while the window is open
local DEBOUNCE_SECONDS = 0.4 -- bag changes ask for fresh data after this long

local COLOR_PURPLE = "|cffb36bff"
local COLOR_GOLD = "|cffffd100"
local COLOR_GREEN = "|cff40ff40"
local COLOR_RED = "|cffff5050"
local COLOR_GREY = "|cff909090"

-- ParagonSpec enum (ParagonItemGen.h), 1-31
local SPEC_NAMES = {
	[1] = "Warrior: Arms", [2] = "Warrior: Fury", [3] = "Warrior: Protection",
	[4] = "Paladin: Holy", [5] = "Paladin: Protection", [6] = "Paladin: Retribution",
	[7] = "Death Knight: Blood", [8] = "Death Knight: Frost", [9] = "Death Knight: Unholy",
	[10] = "Shaman: Elemental", [11] = "Shaman: Enhancement", [12] = "Shaman: Restoration",
	[13] = "Hunter: Beast Mastery", [14] = "Hunter: Marksmanship", [15] = "Hunter: Survival",
	[16] = "Druid: Balance", [17] = "Druid: Restoration", [18] = "Druid: Feral (Tank)", [19] = "Druid: Feral (DPS)",
	[20] = "Rogue: Assassination", [21] = "Rogue: Combat", [22] = "Rogue: Subtlety",
	[23] = "Mage: Arcane", [24] = "Mage: Fire", [25] = "Mage: Frost",
	[26] = "Warlock: Affliction", [27] = "Warlock: Demonology", [28] = "Warlock: Destruction",
	[29] = "Priest: Discipline", [30] = "Priest: Holy", [31] = "Priest: Shadow",
}

-- CLASS_* id -> its ParagonSpec numbers
local CLASS_SPECS = {
	[1] = { 1, 2, 3 },        -- warrior
	[2] = { 4, 5, 6 },        -- paladin
	[3] = { 13, 14, 15 },     -- hunter
	[4] = { 20, 21, 22 },     -- rogue
	[5] = { 29, 30, 31 },     -- priest
	[6] = { 7, 8, 9 },        -- death knight
	[7] = { 10, 11, 12 },     -- shaman
	[8] = { 23, 24, 25 },     -- mage
	[9] = { 26, 27, 28 },     -- warlock
	[11] = { 16, 17, 18, 19 },-- druid
}

--[[----------------------------------------------------------------------
	State
------------------------------------------------------------------------]]

local data = { loaded = false, atAltar = false, essence = 0, materials = 0, classId = 0, sac = {}, tar = {}, pool = {} }
local building -- the data set being received (B ... E)
local wantOpen = false
local statusText, statusOk = "", true
local selSac, selTar, selPassive -- "bag:slot" keys and an enchantment id
local pendingSac, pendingBind -- what the open confirmation is about
local currentTab = "sacrifice"
local lastSync = 0

local RefreshAll -- defined with the panels

--[[----------------------------------------------------------------------
	Small helpers
------------------------------------------------------------------------]]

local function Split(s, sep)
	local out, pos = {}, 1
	while true do
		local i = string.find(s, sep, pos, true)
		if not i then
			out[#out + 1] = string.sub(s, pos)
			break
		end
		out[#out + 1] = string.sub(s, pos, i - 1)
		pos = i + string.len(sep)
	end
	return out
end

local function QualityColor(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

local function Key(rec)
	return rec.bag .. ":" .. rec.slot
end

local function HasSpec(mask, spec)
	return math.floor(mask / (2 ^ (spec - 1))) % 2 == 1
end

local function SpellIcon(spellId)
	if spellId and spellId > 0 then
		local _, _, tex = GetSpellInfo(spellId)
		if tex then return tex end
	end
	return UNKNOWN_ICON
end

local function PassiveName(p)
	if p.name and p.name ~= "" then return p.name end
	if p.spellId and p.spellId > 0 then
		local n = GetSpellInfo(p.spellId)
		if n then return n end
	end
	return "Passive #" .. tostring(p.ench)
end

-- A passive is a custom class spell (mod-custom-spells): its icon is the stock spell it modifies, and a small badge
-- ("+9", "+50%", "ALL" ...) says what changes. FLSpellBadge comes from CustomSpells_Badge_Client.lua, the texts from
-- the server (FL_SpellBadges); without either the icons stay plain, so the window never depends on them.
local function SetBadge(owner, spellId, anchor)
	if FLSpellBadge then FLSpellBadge.Set(owner, spellId, anchor) end
end

local function BadgeText(spellId)
	if FLSpellBadge then return FLSpellBadge.Text(spellId) end
	return ""
end

-- icon, name, link, still-the-same-item for a synced bag record
local function ItemInfo(rec)
	local tex = GetContainerItemInfo(rec.bag, rec.slot)
	local link = GetContainerItemLink(rec.bag, rec.slot)
	local entry = link and tonumber(string.match(link, "item:(%d+)"))
	local name
	if link then name = GetItemInfo(link) end
	if not name then name = GetItemInfo(rec.entry) end
	if not tex then tex = select(10, GetItemInfo(rec.entry)) end
	return tex or UNKNOWN_ICON, name or ("Item " .. rec.entry), link, entry == rec.entry
end

local function SendCommand(text)
	SendChatMessage(text, "SAY")
end

local function RequestSync(open)
	if open then wantOpen = true end
	local now = GetTime()
	if not open and now - lastSync < 0.3 then return end
	lastSync = now
	SendCommand(".paragon altar sync")
end

--[[----------------------------------------------------------------------
	The window
------------------------------------------------------------------------]]

local frame = FLUI.Window("ParagonAltarFrame", {
	width = FRAME_W, height = FRAME_H, point = { "CENTER", 0, 20 },
	title = "Cursed Altar", icon = ESSENCE_ICON,
})

local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
subtitle:SetPoint("TOP", 0, -(FLUI.HEADER + 2))
subtitle:SetText("Sacrifice cursed items, collect their passives, bind them to new items.")

-- Content area (the three panels)
local AREA_X, AREA_TOP, AREA_BOTTOM = 26, -118, 84
local AREA_W = FRAME_W - 2 * AREA_X
local AREA_H = FRAME_H + AREA_TOP - AREA_BOTTOM

-- Footer: balances, altar state, status line
local footerEssIcon = frame:CreateTexture(nil, "ARTWORK")
footerEssIcon:SetSize(18, 18)
footerEssIcon:SetPoint("BOTTOMLEFT", 30, 48)
footerEssIcon:SetTexture(ESSENCE_ICON)
local footerEss = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
footerEss:SetPoint("LEFT", footerEssIcon, "RIGHT", 5, 0)

local footerMatIcon = frame:CreateTexture(nil, "ARTWORK")
footerMatIcon:SetSize(18, 18)
footerMatIcon:SetPoint("LEFT", footerEss, "RIGHT", 24, 0)
footerMatIcon:SetTexture(MATERIAL_ICON)
local footerMat = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
footerMat:SetPoint("LEFT", footerMatIcon, "RIGHT", 5, 0)

local footerAltar = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
footerAltar:SetPoint("BOTTOMRIGHT", -32, 52)
footerAltar:SetJustifyH("RIGHT")

local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
status:SetPoint("BOTTOMLEFT", 30, 24)
status:SetPoint("BOTTOMRIGHT", -30, 24)
status:SetJustifyH("LEFT")

-- Tooltips on the two balances
local function BalanceTip(owner, itemId, label, fallback)
	owner:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetHyperlink("item:" .. itemId)
		if GameTooltip:NumLines() == 0 then
			GameTooltip:AddLine(label, 1, 0.82, 0)
			GameTooltip:AddLine(fallback, 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	owner:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
local essHit = CreateFrame("Frame", nil, frame)
essHit:SetPoint("TOPLEFT", footerEssIcon, "TOPLEFT")
essHit:SetPoint("BOTTOMRIGHT", footerEss, "BOTTOMRIGHT")
essHit:EnableMouse(true)
BalanceTip(essHit, TOKEN_ITEM, "Cursed Essence", "Paid for a sacrificed cursed item. Spent on binding a passive.")
local matHit = CreateFrame("Frame", nil, frame)
matHit:SetPoint("TOPLEFT", footerMatIcon, "TOPLEFT")
matHit:SetPoint("BOTTOMRIGHT", footerMat, "BOTTOMRIGHT")
matHit:EnableMouse(true)
BalanceTip(matHit, MATERIAL_ITEM, "Tainted Heartstone", "Taken from the last boss of a level-80 dungeon, raid or Procedural Dungeon.")

--[[----------------------------------------------------------------------
	Building blocks: a scrolling list and an icon button pool
------------------------------------------------------------------------]]

-- A scroll list of rows. fill(row, d) writes a row, onClick(d) selects, onEnter(row, d) shows the tooltip.
local listCounter = 0
local function NewList(parent, w, h, rowH, fill, onClick, onEnter)
	listCounter = listCounter + 1
	local name = "ParagonAltarList" .. listCounter
	local L = { rows = {}, data = {}, w = w, rowH = rowH }

	L.scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
	L.scroll:SetSize(w, h)
	L.content = CreateFrame("Frame", name .. "Content", L.scroll)
	L.content:SetSize(w, 10)
	L.scroll:SetScrollChild(L.content)

	L.empty = L.content:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	L.empty:SetPoint("TOPLEFT", 8, -10)
	L.empty:SetWidth(w - 16)
	L.empty:SetJustifyH("LEFT")

	local function NewRow(i)
		local r = CreateFrame("Button", nil, L.content)
		r:SetSize(w, rowH)
		r:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
		FLUI.Hover(r)

		r.sel = FLUI.Selection(r)
		r.sel:Hide()

		r.line = FLUI.Line(r, true, "BACKGROUND")
		r.line:SetHeight(1)
		r.line:SetPoint("BOTTOMLEFT", 0, 0)
		r.line:SetPoint("BOTTOMRIGHT", 0, 0)

		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(rowH - 8, rowH - 8)
		r.icon:SetPoint("LEFT", 4, 0)

		r.right = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		r.right:SetPoint("RIGHT", -6, 0)
		r.right:SetJustifyH("RIGHT")

		r.name = r:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
		r.name:SetJustifyH("LEFT")
		r.name:SetWidth(w - rowH - 8 - 120)

		r.sub = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
		r.sub:SetJustifyH("LEFT")
		r.sub:SetWidth(w - rowH - 8 - 120)

		r:SetScript("OnClick", function(self)
			if self.d and onClick then
				PlaySound("igMainMenuOptionCheckBoxOn")
				onClick(self.d)
			end
		end)
		r:SetScript("OnEnter", function(self)
			if self.d and onEnter then onEnter(self, self.d) end
		end)
		r:SetScript("OnLeave", function() GameTooltip:Hide() end)
		L.rows[i] = r
		return r
	end

	-- items: array of records; selected: the key of the selected record (d.key)
	function L:Set(items, emptyText, selected)
		for _, r in ipairs(self.rows) do r:Hide(); r.d = nil end
		local n = 0
		for _, d in ipairs(items) do
			n = n + 1
			local r = self.rows[n] or NewRow(n)
			r.d = d
			fill(r, d)
			if selected and d.key == selected then r.sel:Show() else r.sel:Hide() end
			r:Show()
		end
		if n == 0 then
			self.empty:SetText(emptyText or "")
			self.empty:Show()
		else
			self.empty:Hide()
		end
		self.content:SetHeight(math.max(n * self.rowH, 10))
	end

	return L
end

-- A pool of square icon buttons (spell icons) with a tooltip and a click
local function NewIconPool(parent, size)
	local P = { buttons = {}, size = size }

	function P:Get(i, onEnter, onClick)
		local b = self.buttons[i]
		if b then return b end
		b = CreateFrame("Button", nil, parent)
		b:SetSize(size, size)
		b.tex = b:CreateTexture(nil, "ARTWORK")
		b.tex:SetAllPoints()
		b.sel = b:CreateTexture(nil, "OVERLAY")
		b.sel:SetTexture("Interface\\Buttons\\CheckButtonHilight")
		b.sel:SetBlendMode("ADD")
		b.sel:SetPoint("TOPLEFT", -6, 6)
		b.sel:SetPoint("BOTTOMRIGHT", 6, -6)
		b.sel:Hide()
		b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		b:SetScript("OnEnter", function(self) if self.d and onEnter then onEnter(self, self.d) end end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		b:SetScript("OnClick", function(self) if self.d and onClick then onClick(self.d) end end)
		self.buttons[i] = b
		return b
	end

	function P:HideAll()
		for _, b in ipairs(self.buttons) do b:Hide(); b.d = nil end
	end

	return P
end

-- Paints one passive onto an icon button: colour when unlocked, desaturated when locked
local function PaintPassive(b, p)
	b.d = p
	b.tex:SetTexture(SpellIcon(p.spellId))
	SetBadge(b, p.spellId, b.tex)
	if p.unlocked then
		b.tex:SetDesaturated(nil)
		b.tex:SetVertexColor(1, 1, 1)
	else
		b.tex:SetDesaturated(1)
		b.tex:SetVertexColor(0.55, 0.55, 0.55)
	end
end

local function PassiveTip(owner, p)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	if p.spellId and p.spellId > 0 and GetSpellInfo(p.spellId) then
		GameTooltip:SetHyperlink("spell:" .. p.spellId)
	else
		GameTooltip:AddLine(PassiveName(p), 0.64, 0.21, 0.93)
		GameTooltip:AddLine("(This client has no spell record for it.)", 0.6, 0.6, 0.6, true)
	end
	GameTooltip:AddLine(" ")
	if p.retired then
		GameTooltip:AddLine("Collected - retired: no longer available to your class.", 0.7, 0.7, 0.7, true)
	elseif p.unlocked then
		GameTooltip:AddLine("Unlocked. Bind it to an item at the altar.", 0.25, 1, 0.25, true)
	else
		GameTooltip:AddLine("Locked. Sacrifice a cursed item that carries it.", 1, 0.4, 0.4, true)
	end
	GameTooltip:Show()
end

--[[----------------------------------------------------------------------
	Tabs
------------------------------------------------------------------------]]

local TABS = {
	{ id = "sacrifice", name = "Sacrifice" },
	{ id = "collection", name = "Collection" },
	{ id = "bind", name = "Bind" },
}
local panels, tabButtons = {}, {}

for i, t in ipairs(TABS) do
	local p = CreateFrame("Frame", nil, frame)
	p:SetPoint("TOPLEFT", AREA_X, AREA_TOP)
	p:SetSize(AREA_W, AREA_H)
	p:Hide()
	panels[t.id] = p
end

local function SelectTab(id)
	currentTab = id
	for _, t in ipairs(TABS) do
		if t.id == id then
			panels[t.id]:Show()
		else
			panels[t.id]:Hide()
		end
		tabButtons[t.id]:SetSelected(t.id == id)
	end
	if RefreshAll then RefreshAll() end
end

for i, t in ipairs(TABS) do
	local b = FLUI.Button(frame, t.name, 120, 24)
	b:SetPoint("TOPLEFT", AREA_X + (i - 1) * 126, -88)
	b:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		SelectTab(t.id)
	end)
	tabButtons[t.id] = b
end

--[[----------------------------------------------------------------------
	Panel 1: Sacrifice
------------------------------------------------------------------------]]

local sacPanel = panels.sacrifice
local SAC_LIST_W = 380
local SAC_DETAIL_X = SAC_LIST_W + 40

local function PassiveOfSac(rec)
	return { ench = rec.ench, spellId = rec.spellId, name = rec.pname, unlocked = rec.known }
end

local sacList = NewList(sacPanel, SAC_LIST_W, AREA_H - 4, 44,
	function(r, d) -- fill
		local icon, name, _, same = ItemInfo(d)
		r.icon:SetTexture(icon)
		r.name:SetText(name)
		r.name:SetTextColor(QualityColor(d.quality))
		if d.ench == CURSED_MARKER then
			r.sub:SetText(COLOR_GREY .. "Plain curse - unlocks no passive|r")
		else
			local p = PassiveOfSac(d)
			r.sub:SetText(string.format("|T%s:14:14:0:0|t %s%s|r%s", SpellIcon(d.spellId), COLOR_PURPLE,
				PassiveName(p), BadgeText(d.spellId)))
		end
		local badge
		if d.ench == CURSED_MARKER then
			badge = ""
		elseif d.known then
			badge = COLOR_GREY .. "known|r"
		else
			badge = COLOR_GREEN .. "NEW|r"
		end
		r.right:SetText(string.format("%s\n%s+%d|r |T%s:12:12:0:0|t", badge, COLOR_GOLD, d.yield, ESSENCE_ICON))
		if not same then r:SetAlpha(0.5) else r:SetAlpha(1) end
	end,
	function(d) -- click
		selSac = d.key
		RefreshAll()
	end,
	function(r, d) -- tooltip: the item itself
		GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
		GameTooltip:SetBagItem(d.bag, d.slot)
		GameTooltip:Show()
	end)
sacList.scroll:SetPoint("TOPLEFT", 0, -2)

local sacDetail = FLUI.Panel(sacPanel)
sacDetail:SetPoint("TOPLEFT", SAC_DETAIL_X, -2)
sacDetail:SetPoint("BOTTOMRIGHT", 0, 0)

local sacItemIcon = sacDetail:CreateTexture(nil, "ARTWORK")
sacItemIcon:SetSize(40, 40)
sacItemIcon:SetPoint("TOPLEFT", 12, -12)
local sacItemName = sacDetail:CreateFontString(nil, "ARTWORK", "GameFontNormal")
sacItemName:SetPoint("TOPLEFT", sacItemIcon, "TOPRIGHT", 8, -2)
sacItemName:SetPoint("RIGHT", -10, 0)
sacItemName:SetJustifyH("LEFT")
local sacItemSub = sacDetail:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
sacItemSub:SetPoint("TOPLEFT", sacItemName, "BOTTOMLEFT", 0, -4)
sacItemSub:SetJustifyH("LEFT")

local sacPassiveIcon = CreateFrame("Button", nil, sacDetail)
sacPassiveIcon:SetSize(36, 36)
sacPassiveIcon:SetPoint("TOPLEFT", 14, -72)
sacPassiveIcon.tex = sacPassiveIcon:CreateTexture(nil, "ARTWORK")
sacPassiveIcon.tex:SetAllPoints()
sacPassiveIcon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
sacPassiveIcon:SetScript("OnEnter", function(self) if self.d then PassiveTip(self, self.d) end end)
sacPassiveIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
local sacPassiveName = sacDetail:CreateFontString(nil, "ARTWORK", "GameFontNormal")
sacPassiveName:SetPoint("TOPLEFT", sacPassiveIcon, "TOPRIGHT", 8, -2)
sacPassiveName:SetPoint("RIGHT", -10, 0)
sacPassiveName:SetJustifyH("LEFT")
sacPassiveName:SetTextColor(0.64, 0.21, 0.93)
local sacPassiveBadge = sacDetail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sacPassiveBadge:SetPoint("TOPLEFT", sacPassiveName, "BOTTOMLEFT", 0, -4)
sacPassiveBadge:SetJustifyH("LEFT")

local sacYield = sacDetail:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
sacYield:SetPoint("TOPLEFT", 14, -126)
sacYield:SetPoint("RIGHT", -10, 0)
sacYield:SetJustifyH("LEFT")

local sacHint = sacDetail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sacHint:SetPoint("BOTTOMLEFT", 12, 48)
sacHint:SetPoint("BOTTOMRIGHT", -12, 48)
sacHint:SetJustifyH("LEFT")
sacHint:SetJustifyV("BOTTOM")
sacHint:SetHeight(60)

local sacButton = FLUI.Button(sacDetail, "Sacrifice", 150, 26)
sacButton:SetPoint("BOTTOM", 0, 14)

StaticPopupDialogs["PARAGONALTAR_SACRIFICE"] = {
	text = "Destroy %s for %s Cursed Essence?\n\nThis cannot be undone.",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		if pendingSac then
			SendCommand(string.format(".paragon altar sacrifice %d %d", pendingSac.bag, pendingSac.slot))
		end
	end,
	OnHide = function() pendingSac = nil end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

sacButton:SetScript("OnClick", function()
	for _, d in ipairs(data.sac) do
		if d.key == selSac then
			local _, name, link = ItemInfo(d)
			pendingSac = d
			StaticPopup_Show("PARAGONALTAR_SACRIFICE", link or name, tostring(d.yield))
			return
		end
	end
end)

local function RefreshSacrifice()
	local items = {}
	for _, d in ipairs(data.sac) do
		d.key = Key(d)
		items[#items + 1] = d
	end

	-- keep a still valid selection, else take the first one
	local found
	for _, d in ipairs(items) do if d.key == selSac then found = d end end
	if not found then
		found = items[1]
		selSac = found and found.key or nil
	end

	sacList:Set(items, data.loaded and "You carry no cursed items." or "Loading ...", selSac)

	if not found then
		sacItemIcon:SetTexture(nil)
		sacItemName:SetText("")
		sacItemSub:SetText("")
		sacPassiveIcon:Hide()
		sacPassiveName:SetText("")
		sacPassiveBadge:SetText("")
		sacYield:SetText("")
		sacHint:SetText(COLOR_GREY .. "Cursed items are rare drops. Put them in your bags and come back.|r")
		sacButton:Disable()
		return
	end

	local icon, name, _, same = ItemInfo(found)
	sacItemIcon:SetTexture(icon)
	sacItemName:SetText(name)
	sacItemName:SetTextColor(QualityColor(found.quality))
	sacItemSub:SetText(_G["ITEM_QUALITY" .. found.quality .. "_DESC"] or "")

	if found.ench == CURSED_MARKER then
		sacPassiveIcon:Hide()
		sacPassiveName:SetText("Plain curse")
		sacPassiveBadge:SetText(COLOR_GREY .. "This item carries no passive.|r")
	else
		local p = PassiveOfSac(found)
		sacPassiveIcon:Show()
		sacPassiveIcon.tex:SetTexture(SpellIcon(found.spellId))
		SetBadge(sacPassiveIcon, found.spellId, sacPassiveIcon.tex)
		sacPassiveIcon.d = p
		sacPassiveName:SetText(PassiveName(p))
		sacPassiveBadge:SetText(found.known and (COLOR_GREY .. "Already in your collection|r")
			or (COLOR_GREEN .. "NEW - added to your collection|r"))
	end
	sacYield:SetText(string.format("Yield: %s%d|r |T%s:14:14:0:0|t Cursed Essence", COLOR_GOLD, found.yield, ESSENCE_ICON))

	if not data.atAltar then
		sacHint:SetText(COLOR_RED .. "Stand at the Cursed Altar to sacrifice.|r")
		sacButton:Disable()
	elseif not same then
		sacHint:SetText(COLOR_GREY .. "The bags changed - refreshing ...|r")
		sacButton:Disable()
	else
		sacHint:SetText(COLOR_GREY .. "The item is destroyed. Its passive stays in your account's collection.|r")
		sacButton:Enable()
	end
end

--[[----------------------------------------------------------------------
	Panel 2: Collection
------------------------------------------------------------------------]]

local colPanel = panels.collection
local COL_ICON, COL_GAP = 34, 5

local colTotal = colPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
colTotal:SetPoint("TOPLEFT", 4, -2)

local colScroll = CreateFrame("ScrollFrame", "ParagonAltarCollectionScroll", colPanel, "UIPanelScrollFrameTemplate")
colScroll:SetPoint("TOPLEFT", 0, -26)
colScroll:SetSize(AREA_W - 28, AREA_H - 30)
local colContent = CreateFrame("Frame", "ParagonAltarCollectionContent", colScroll)
colContent:SetSize(AREA_W - 28, 10)
colScroll:SetScrollChild(colContent)

local colEmpty = colContent:CreateFontString(nil, "ARTWORK", "GameFontDisable")
colEmpty:SetPoint("TOPLEFT", 6, -8)
colEmpty:SetWidth(AREA_W - 60)
colEmpty:SetJustifyH("LEFT")

local colHeaders = {}
local colPool = NewIconPool(colContent, COL_ICON)

local function ColHeader(i)
	if not colHeaders[i] then
		local g = colContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		colHeaders[i] = g
	end
	return colHeaders[i]
end

local function GoToBind(p)
	if p.unlocked and not p.retired then
		selPassive = p.ench
		SelectTab("bind")
	end
end

local function RefreshCollection()
	for _, g in ipairs(colHeaders) do g:Hide() end
	colPool:HideAll()

	local total, unlocked = 0, 0
	for _, p in ipairs(data.pool) do
		if not p.retired then
			total = total + 1
			if p.unlocked then unlocked = unlocked + 1 end
		end
	end
	local retiredList = {}
	for _, p in ipairs(data.pool) do
		if p.retired then retiredList[#retiredList + 1] = p end
	end

	colTotal:SetText(string.format("Collected: %s%d / %d|r passives of your class%s", COLOR_GOLD, unlocked, total,
		#retiredList > 0 and string.format("  (+%d retired)", #retiredList) or ""))

	if not data.loaded then
		colEmpty:SetText("Loading ...")
		colEmpty:Show()
		colContent:SetHeight(40)
		return
	elseif total == 0 and #retiredList == 0 then
		colEmpty:SetText("Your class has no passives yet.")
		colEmpty:Show()
		colContent:SetHeight(40)
		return
	end
	colEmpty:Hide()

	local perRow = math.max(1, math.floor((AREA_W - 28) / (COL_ICON + COL_GAP)))
	local y, headerIdx, buttonIdx = 0, 0, 0

	local function Group(label, list)
		headerIdx = headerIdx + 1
		local g = ColHeader(headerIdx)
		g:ClearAllPoints()
		g:SetPoint("TOPLEFT", 4, -y)
		g:SetText(label)
		g:Show()
		y = y + 22
		for k, p in ipairs(list) do
			buttonIdx = buttonIdx + 1
			local b = colPool:Get(buttonIdx, PassiveTip, GoToBind)
			local col, row = (k - 1) % perRow, math.floor((k - 1) / perRow)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", 4 + col * (COL_ICON + COL_GAP), -(y + row * (COL_ICON + COL_GAP)))
			PaintPassive(b, p)
			b.sel:Hide()
			b:Show()
		end
		y = y + math.ceil(#list / perRow) * (COL_ICON + COL_GAP) + 8
	end

	for _, spec in ipairs(CLASS_SPECS[data.classId] or {}) do
		local list, got = {}, 0
		for _, p in ipairs(data.pool) do
			if not p.retired and HasSpec(p.mask, spec) then
				list[#list + 1] = p
				if p.unlocked then got = got + 1 end
			end
		end
		if #list > 0 then
			Group(string.format("%s   %s%d / %d|r", SPEC_NAMES[spec] or ("Spec " .. spec), COLOR_GOLD, got, #list), list)
		end
	end

	if #retiredList > 0 then
		Group(string.format("Retired   %s%d|r  %s(collected, no longer bindable)|r", COLOR_GOLD, #retiredList, COLOR_GREY), retiredList)
	end

	colContent:SetHeight(math.max(y, 10))
end

--[[----------------------------------------------------------------------
	Panel 3: Bind
------------------------------------------------------------------------]]

local bindPanel = panels.bind
local BIND_LIST_W = 300
local BIND_ICON, BIND_GAP = 36, 5

local function CostText(d)
	local essColor = data.essence >= d.cost and COLOR_GOLD or COLOR_RED
	local matColor = data.materials >= d.mat and COLOR_GOLD or COLOR_RED
	return string.format("%s%d|r |T%s:12:12:0:0|t\n%s%d|r |T%s:12:12:0:0|t", essColor, d.cost, ESSENCE_ICON,
		matColor, d.mat, MATERIAL_ICON)
end

local bindList = NewList(bindPanel, BIND_LIST_W, AREA_H - 104, 40,
	function(r, d)
		local icon, name, _, same = ItemInfo(d)
		r.icon:SetTexture(icon)
		r.name:SetText(name)
		r.name:SetTextColor(QualityColor(d.quality))
		r.name:SetWidth(BIND_LIST_W - 40 - 8 - 70)
		r.sub:SetText(COLOR_GREY .. (_G["ITEM_QUALITY" .. d.quality .. "_DESC"] or "") .. "|r")
		r.right:SetText(CostText(d))
		if not same then r:SetAlpha(0.5) else r:SetAlpha(1) end
	end,
	function(d)
		selTar = d.key
		RefreshAll()
	end,
	function(r, d)
		GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
		GameTooltip:SetBagItem(d.bag, d.slot)
		GameTooltip:Show()
	end)
bindList.scroll:SetPoint("TOPLEFT", 0, -24)

local bindListTitle = bindPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
bindListTitle:SetPoint("TOPLEFT", 4, -2)
bindListTitle:SetText("1. Pick an item from your bags")

local BIND_PASSIVE_X = BIND_LIST_W + 44
local bindPassiveTitle = bindPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
bindPassiveTitle:SetPoint("TOPLEFT", BIND_PASSIVE_X, -2)
bindPassiveTitle:SetText("2. Pick an unlocked passive")

local bindPassiveScroll = CreateFrame("ScrollFrame", "ParagonAltarBindScroll", bindPanel, "UIPanelScrollFrameTemplate")
bindPassiveScroll:SetPoint("TOPLEFT", BIND_PASSIVE_X, -24)
bindPassiveScroll:SetSize(AREA_W - BIND_PASSIVE_X - 28, AREA_H - 104)
local bindPassiveContent = CreateFrame("Frame", "ParagonAltarBindContent", bindPassiveScroll)
bindPassiveContent:SetSize(AREA_W - BIND_PASSIVE_X - 28, 10)
bindPassiveScroll:SetScrollChild(bindPassiveContent)
local bindPassiveEmpty = bindPassiveContent:CreateFontString(nil, "ARTWORK", "GameFontDisable")
bindPassiveEmpty:SetPoint("TOPLEFT", 6, -8)
bindPassiveEmpty:SetWidth(AREA_W - BIND_PASSIVE_X - 50)
bindPassiveEmpty:SetJustifyH("LEFT")

local bindPool = NewIconPool(bindPassiveContent, BIND_ICON)

local bindSummary = bindPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
bindSummary:SetPoint("BOTTOMLEFT", 4, 34)
bindSummary:SetPoint("BOTTOMRIGHT", -170, 34)
bindSummary:SetJustifyH("LEFT")
bindSummary:SetJustifyV("TOP")
bindSummary:SetHeight(40)

local bindHint = bindPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
bindHint:SetPoint("BOTTOMLEFT", 4, 6)
bindHint:SetPoint("BOTTOMRIGHT", -170, 6)
bindHint:SetJustifyH("LEFT")

local bindButton = FLUI.Button(bindPanel, "Bind", 150, 26)
bindButton:SetPoint("BOTTOMRIGHT", 0, 12)

StaticPopupDialogs["PARAGONALTAR_BIND"] = {
	text = "Bind %s?\n\n%s\n\nThe item is re-rolled as a cursed item: its current Paragon enchantments are replaced.",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		if pendingBind then
			SendCommand(string.format(".paragon altar bind %d %d %d", pendingBind.bag, pendingBind.slot, pendingBind.ench))
		end
	end,
	OnHide = function() pendingBind = nil end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

local function FindByKey(list, key)
	for _, d in ipairs(list) do
		if d.key == key then return d end
	end
end

local function FindPassive(ench)
	for _, p in ipairs(data.pool) do
		if p.ench == ench and not p.retired then return p end
	end
end

bindButton:SetScript("OnClick", function()
	local t, p = FindByKey(data.tar, selTar), FindPassive(selPassive)
	if not t or not p then return end
	local _, name, link = ItemInfo(t)
	pendingBind = { bag = t.bag, slot = t.slot, ench = p.ench }
	StaticPopup_Show("PARAGONALTAR_BIND", link or name,
		string.format("Passive: %s\nCost: %d Cursed Essence, %d Tainted Heartstones", PassiveName(p), t.cost, t.mat))
end)

local function RefreshBind()
	-- targets
	local items = {}
	for _, d in ipairs(data.tar) do
		d.key = Key(d)
		items[#items + 1] = d
	end
	if not FindByKey(items, selTar) then
		selTar = items[1] and items[1].key or nil
	end
	bindList:Set(items, data.loaded and "No items in your bags can be bound." or "Loading ...", selTar)

	-- passives: only unlocked ones of the class pool
	bindPool:HideAll()
	local unlockedList = {}
	for _, p in ipairs(data.pool) do
		if p.unlocked and not p.retired then unlockedList[#unlockedList + 1] = p end
	end
	if not FindPassive(selPassive) or not (FindPassive(selPassive) or {}).unlocked then
		selPassive = nil
	end
	local perRow = math.max(1, math.floor((AREA_W - BIND_PASSIVE_X - 28) / (BIND_ICON + BIND_GAP)))
	for k, p in ipairs(unlockedList) do
		local b = bindPool:Get(k,
			PassiveTip,
			function(d)
				selPassive = d.ench
				RefreshAll()
			end)
		local col, row = (k - 1) % perRow, math.floor((k - 1) / perRow)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 4 + col * (BIND_ICON + BIND_GAP), -(4 + row * (BIND_ICON + BIND_GAP)))
		PaintPassive(b, p)
		if p.ench == selPassive then b.sel:Show() else b.sel:Hide() end
		b:Show()
	end
	if #unlockedList == 0 then
		bindPassiveEmpty:SetText(data.loaded and "Nothing unlocked yet. Sacrifice cursed items that carry passives; they appear here."
			or "Loading ...")
		bindPassiveEmpty:Show()
	else
		bindPassiveEmpty:Hide()
	end
	bindPassiveContent:SetHeight(math.max(math.ceil(#unlockedList / perRow) * (BIND_ICON + BIND_GAP) + 8, 10))

	-- summary and the button
	local t, p = FindByKey(data.tar, selTar), FindPassive(selPassive)
	local reason
	if not t then
		reason = "Pick an item."
	elseif not p then
		reason = "Pick a passive."
	elseif not data.atAltar then
		reason = "Stand at the Cursed Altar to bind."
	elseif data.essence < t.cost then
		reason = "Not enough Cursed Essence."
	elseif data.materials < t.mat then
		reason = "Not enough Tainted Heartstones."
	end

	if t and p then
		local _, name = ItemInfo(t)
		bindSummary:SetText(string.format("%s  +  %s%s|r\nCost: %s%d|r |T%s:13:13:0:0|t   %s%d|r |T%s:13:13:0:0|t",
			name, COLOR_PURPLE, PassiveName(p), data.essence >= t.cost and COLOR_GOLD or COLOR_RED, t.cost, ESSENCE_ICON,
			data.materials >= t.mat and COLOR_GOLD or COLOR_RED, t.mat, MATERIAL_ICON))
	elseif t then
		bindSummary:SetText(string.format("Cost: %s%d|r |T%s:13:13:0:0|t   %s%d|r |T%s:13:13:0:0|t",
			data.essence >= t.cost and COLOR_GOLD or COLOR_RED, t.cost, ESSENCE_ICON,
			data.materials >= t.mat and COLOR_GOLD or COLOR_RED, t.mat, MATERIAL_ICON))
	else
		bindSummary:SetText("")
	end

	if reason then
		bindHint:SetText(COLOR_RED .. reason .. "|r")
		bindButton:Disable()
	else
		bindHint:SetText(COLOR_GREY .. "Re-rolls the item as a cursed item (150% stats, soulbound).|r")
		bindButton:Enable()
	end
end

--[[----------------------------------------------------------------------
	Footer and refresh
------------------------------------------------------------------------]]

local function RefreshFooter()
	footerEss:SetText(string.format("%s%d|r Cursed Essence", COLOR_GOLD, data.essence))
	footerMat:SetText(string.format("%s%d|r Tainted Heartstones", COLOR_GOLD, data.materials))
	if not data.loaded then
		footerAltar:SetText("")
	elseif data.atAltar then
		footerAltar:SetText(COLOR_GREEN .. "At the Cursed Altar|r")
	else
		footerAltar:SetText(COLOR_RED .. "Not at the altar|r " .. COLOR_GREY .. "(sacrificing and binding need it)|r")
	end
	if statusOk then
		status:SetTextColor(0.4, 1, 0.4)
	else
		status:SetTextColor(1, 0.45, 0.35)
	end
	status:SetText(statusText)
end

RefreshAll = function()
	RefreshFooter()
	if currentTab == "sacrifice" then
		RefreshSacrifice()
	elseif currentTab == "collection" then
		RefreshCollection()
	else
		RefreshBind()
	end
end

--[[----------------------------------------------------------------------
	Server -> client
------------------------------------------------------------------------]]

local function ParseRecords(body, build)
	local out = {}
	for _, rec in ipairs(Split(body, "~")) do
		if rec ~= "" then
			local f = Split(rec, ",")
			local d = build(f)
			if d then out[#out + 1] = d end
		end
	end
	return out
end

local function Append(dst, src)
	for _, d in ipairs(src) do dst[#dst + 1] = d end
end

local function OnMessage(message)
	local kind = string.sub(message, 1, 1)
	local body = string.sub(message, 3)

	if kind == "O" then
		wantOpen = true
	elseif kind == "B" then
		local f = Split(body, ";")
		building = {
			loaded = true,
			atAltar = f[1] == "1",
			essence = tonumber(f[2]) or 0,
			classId = tonumber(f[3]) or 0,
			materials = tonumber(f[4]) or 0,
			sac = {}, tar = {}, pool = {},
		}
	elseif kind == "S" and building then
		Append(building.sac, ParseRecords(body, function(f)
			return {
				bag = tonumber(f[1]), slot = tonumber(f[2]), entry = tonumber(f[3]), quality = tonumber(f[4]) or 1,
				ench = tonumber(f[5]) or 0, yield = tonumber(f[6]) or 0, known = f[7] == "1",
				spellId = tonumber(f[8]) or 0, pname = f[9],
			}
		end))
	elseif kind == "T" and building then
		Append(building.tar, ParseRecords(body, function(f)
			return {
				bag = tonumber(f[1]), slot = tonumber(f[2]), entry = tonumber(f[3]), quality = tonumber(f[4]) or 1,
				cost = tonumber(f[5]) or 0, mat = tonumber(f[6]) or 0,
			}
		end))
	elseif kind == "P" and building then
		Append(building.pool, ParseRecords(body, function(f)
			return {
				ench = tonumber(f[1]), spellId = tonumber(f[2]) or 0, mask = tonumber(f[3]) or 0,
				unlocked = f[4] == "1", retired = f[5] == "1", name = f[6],
			}
		end))
	elseif kind == "E" then
		if building then
			data = building
			building = nil
		end
		if wantOpen then
			wantOpen = false
			frame:Show()
			SelectTab(currentTab)
		elseif frame:IsShown() then
			RefreshAll()
		end
	elseif kind == "R" then
		local ok, text = string.match(body, "^(%d);(.*)$")
		statusOk = ok == "1"
		statusText = text or ""
		if frame:IsShown() then RefreshFooter() end
	end
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:RegisterEvent("BAG_UPDATE")
local refreshIn
listener:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
	if event == "BAG_UPDATE" then
		if frame:IsShown() then refreshIn = DEBOUNCE_SECONDS end
		return
	end
	if prefix ~= PREFIX or channel ~= "WHISPER" or sender ~= UnitName("player") then
		return
	end
	OnMessage(message)
end)

-- the debounced bag refresh and the slow altar-distance poll
local poll = 0
listener:SetScript("OnUpdate", function(self, elapsed)
	if not frame:IsShown() then return end
	if refreshIn then
		refreshIn = refreshIn - elapsed
		if refreshIn <= 0 then
			refreshIn = nil
			RequestSync(false)
		end
	end
	poll = poll + elapsed
	if poll >= POLL_SECONDS then
		poll = 0
		RequestSync(false)
	end
end)

--[[----------------------------------------------------------------------
	Opening
------------------------------------------------------------------------]]

frame:SetScript("OnHide", function()
	StaticPopup_Hide("PARAGONALTAR_SACRIFICE")
	StaticPopup_Hide("PARAGONALTAR_BIND")
	GameTooltip:Hide()
	refreshIn = nil
end)

frame:SetScript("OnShow", function()
	poll = 0
	statusText = ""
	statusOk = true
	RefreshAll()
end)

-- The /fl hub calls this.
function ParagonAltar_Open()
	RequestSync(true)
end

SLASH_PARAGONALTAR1 = "/altar"
SlashCmdList["PARAGONALTAR"] = function()
	ParagonAltar_Open()
end

-- the first tab is lit before the first open
SelectTab(currentTab)
