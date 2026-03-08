-- =============================================================
-- Paragon Item Passive Spell Effects
-- Custom spells, enchantments, and effect pool for the
-- passive spell system on Slot 11 (PARAGON_SLOT_TALENT_SPELL).
--
-- ID Ranges:
--   spell_dbc:               950001-950199 (passive/proc/triggered)
--   spellitemenchantment_dbc: 950001-950099 (equip/combat enchants)
--   paragon_passive_spell_pool: references enchantment IDs
-- =============================================================

-- =============================================================
-- 1. SPELL_DBC ENTRIES
-- =============================================================
-- Clean up any previous entries in our ID range
DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 950001 AND 950199;

-- -----------------------------------------
-- Category A: Passive Stat % Auras (equip)
-- Effect=6 (APPLY_AURA), Aura=137 (MOD_TOTAL_STAT_PERCENTAGE)
-- MiscValue: 0=Str, 1=Agi, 2=Sta, 3=Int, 4=Spi, -1=All
-- Attributes=64 (PASSIVE), DurationIndex=21 (infinite)
-- DieSides=1, BasePoints=value-1 (standard WoW convention)
-- -----------------------------------------
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `RangeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectMiscValue_1`,
    `EffectAura_1`, `ImplicitTargetA_1`, `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950001, 64, 21, 1, 6, 1, 2, 2, 137, 1, 1, 'Paragon: Fortitude'),    -- +3% Stamina
(950002, 64, 21, 1, 6, 1, 2, 0, 137, 1, 1, 'Paragon: Might'),         -- +3% Strength
(950003, 64, 21, 1, 6, 1, 2, 1, 137, 1, 1, 'Paragon: Grace'),         -- +3% Agility
(950004, 64, 21, 1, 6, 1, 2, 3, 137, 1, 1, 'Paragon: Brilliance'),    -- +3% Intellect
(950005, 64, 21, 1, 6, 1, 2, 4, 137, 1, 1, 'Paragon: Wisdom');        -- +3% Spirit

-- -----------------------------------------
-- Category B: Passive Health/Damage/Healing % Auras
-- Aura 230 = MOD_INCREASE_HEALTH_PERCENT
-- Aura 79  = MOD_DAMAGE_PERCENT_DONE (MiscValue=school mask, 127=all)
-- Aura 136 = MOD_HEALING_DONE_PERCENT
-- -----------------------------------------
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `RangeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectMiscValue_1`,
    `EffectAura_1`, `ImplicitTargetA_1`, `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950006, 64, 21, 1, 6, 1, 4, 0,   230, 1, 1, 'Paragon: Vitality'),      -- +5% Max Health
(950007, 64, 21, 1, 6, 1, 2, 127, 79,  1, 1, 'Paragon: Destruction'),    -- +3% All Damage
(950008, 64, 21, 1, 6, 1, 4, 127, 136, 1, 1, 'Paragon: Mending');        -- +5% Healing Done

-- -----------------------------------------
-- Category C: Passive Combat Rating Auras
-- Aura 189 = MOD_RATING
-- MiscValue = rating bitmask:
--   Hit(melee+ranged+spell)   = 32|64|128     = 224
--   Crit(melee+ranged+spell)  = 256|512|1024  = 1792
--   Haste(melee+ranged+spell) = 65536|131072|262144 = 458752
--   Dodge                     = 4
--   Parry                     = 8
--   Defense                   = 2
--   Expertise                 = 16777216
--   ArmorPen                  = 33554432
-- -----------------------------------------
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `RangeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectMiscValue_1`,
    `EffectAura_1`, `ImplicitTargetA_1`, `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950011, 64, 21, 1, 6, 1, 29, 224,     189, 1, 1, 'Paragon: Precision'),    -- +30 Hit Rating
(950012, 64, 21, 1, 6, 1, 29, 1792,    189, 1, 1, 'Paragon: Ferocity'),     -- +30 Crit Rating
(950013, 64, 21, 1, 6, 1, 29, 458752,  189, 1, 1, 'Paragon: Alacrity'),     -- +30 Haste Rating
(950014, 64, 21, 1, 6, 1, 29, 4,       189, 1, 1, 'Paragon: Evasion'),      -- +30 Dodge Rating
(950015, 64, 21, 1, 6, 1, 29, 8,       189, 1, 1, 'Paragon: Deflection'),   -- +30 Parry Rating
(950016, 64, 21, 1, 6, 1, 29, 2,       189, 1, 1, 'Paragon: Warding'),      -- +30 Defense Rating
(950017, 64, 21, 1, 6, 1, 29, 16777216, 189, 1, 1, 'Paragon: Finesse'),     -- +30 Expertise Rating
(950018, 64, 21, 1, 6, 1, 29, 33554432, 189, 1, 1, 'Paragon: Piercing');    -- +30 Armor Pen Rating

-- -----------------------------------------
-- Category D: Proc Trigger Auras (equip spells)
-- Effect=6 (APPLY_AURA), Aura=42 (PROC_TRIGGER_SPELL)
-- Attributes=64 (PASSIVE), DurationIndex=21 (infinite)
-- ProcTypeMask:
--   Melee auto attack done     = 4
--   Ranged auto attack done    = 16
--   Spell damage done (magic)  = 16384 (0x4000)
--   Melee auto attack taken    = 64 (0x40)
-- ProcChance = percent
-- EffectTriggerSpell_1 = triggered spell ID
-- -----------------------------------------
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `RangeIndex`,
    `ProcTypeMask`, `ProcChance`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`,
    `EffectAura_1`, `EffectTriggerSpell_1`, `ImplicitTargetA_1`,
    `SpellIconID`, `Name_Lang_enUS`)
VALUES
-- Thunderstrike: 8% on melee hit → 300 Nature damage
(950031, 64, 21, 1, 20, 8,  6, 0, 0, 42, 950101, 1, 1, 'Paragon: Thunderstrike'),
-- Vampiric Siphon: 10% on melee hit → heal 200
(950032, 64, 21, 1, 20, 10, 6, 0, 0, 42, 950102, 1, 1, 'Paragon: Vampiric Siphon'),
-- Berserker''s Fury: 8% on melee hit → +200 AP for 10s
(950033, 64, 21, 1, 20, 8,  6, 0, 0, 42, 950103, 1, 1, 'Paragon: Berserker''s Fury'),
-- Arcane Infusion: 8% on spell damage → +150 SP for 10s
(950034, 64, 21, 1, 16384, 8, 6, 0, 0, 42, 950104, 1, 1, 'Paragon: Arcane Infusion'),
-- Stoneskin: 10% on melee hit taken → absorb 500 damage for 10s
(950035, 64, 21, 1, 64, 10, 6, 0, 0, 42, 950105, 1, 1, 'Paragon: Stoneskin');

-- -----------------------------------------
-- Category E: Triggered Spells (fired by procs above)
-- These are NOT passive — they are instant cast effects.
-- -----------------------------------------

-- 950101: Thunderstrike Bolt — 300 Nature damage to enemy
-- Effect=2 (SCHOOL_DAMAGE), SchoolMask=8 (Nature)
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `RangeIndex`, `SchoolMask`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`,
    `ImplicitTargetA_1`, `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950101, 0, 1, 8, 2, 1, 299, 6, 1, 'Thunderstrike Bolt');

-- 950102: Vampiric Siphon — heal caster for 200
-- Effect=10 (HEAL)
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `RangeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`,
    `ImplicitTargetA_1`, `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950102, 0, 1, 10, 1, 199, 1, 1, 'Vampiric Siphon');

-- 950103: Berserker's Fury Buff — +200 Attack Power for 10s
-- Effect=6 (APPLY_AURA), Aura=99 (MOD_ATTACK_POWER), Duration=10s
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `RangeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`,
    `EffectAura_1`, `ImplicitTargetA_1`, `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950103, 0, 1, 1, 6, 1, 199, 99, 1, 1, 'Berserker''s Fury');

-- 950104: Arcane Infusion Buff — +150 Spell Power for 10s
-- Effect=6 (APPLY_AURA), Aura=13 (MOD_SPELL_DAMAGE_DONE/SPELL_POWER)
-- Actually: Aura=174 (MOD_SPELL_HEALING_OF_STAT_PERCENT) won't work.
-- Use Aura=79 (MOD_DAMAGE_PERCENT_DONE) with school mask for a % buff,
-- or Aura=29 (MOD_STAT) won't give SP directly.
-- Best: use flat spell power via item_mod approach or a custom aura.
-- Simplest working approach: two effects — 13 (MOD_DAMAGE_DONE) + 135 (MOD_HEALING_DONE)
-- Aura 13 = SPELL_AURA_MOD_DAMAGE_DONE, MiscValue = school mask (126 = all magic)
-- Aura 135 = SPELL_AURA_MOD_HEALING_DONE (flat healing)
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `RangeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectMiscValue_1`,
    `EffectAura_1`, `ImplicitTargetA_1`,
    `Effect_2`, `EffectDieSides_2`, `EffectBasePoints_2`, `EffectMiscValue_2`,
    `EffectAura_2`, `ImplicitTargetA_2`,
    `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950104, 0, 1, 1,
    6, 1, 149, 126, 13, 1,   -- Effect 1: +150 spell damage (all magic schools)
    6, 1, 149, 0,   135, 1,  -- Effect 2: +150 healing done
    1, 'Arcane Infusion');

-- 950105: Stoneskin Shield — absorb 500 damage for 10s
-- Effect=6 (APPLY_AURA), Aura=69 (SCHOOL_ABSORB), MiscValue=127 (all schools)
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `RangeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectMiscValue_1`,
    `EffectAura_1`, `ImplicitTargetA_1`, `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950105, 0, 1, 1, 6, 1, 499, 127, 69, 1, 1, 'Stoneskin Shield');


-- =============================================================
-- 2. SPELLITEMENCHANTMENT_DBC ENTRIES
-- =============================================================
-- Each passive spell gets an enchantment entry that applies it on equip.
-- Effect type 3 = ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL (applied while equipped)
-- Effect type 1 = ITEM_ENCHANTMENT_TYPE_COMBAT_SPELL (proc on combat, but we
--                 handle procs via the spell itself, so use type 3 for all)
-- EffectArg_1 = spell ID
-- =============================================================

DELETE FROM `spellitemenchantment_dbc` WHERE `ID` BETWEEN 950001 AND 950099;

INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`,
    `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`,
    `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`,
    `EffectArg_1`, `EffectArg_2`, `EffectArg_3`,
    `Name_Lang_enUS`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`,
    `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
-- Stat % passives
(950001, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950001, 0, 0, '+3% Stamina',           0, 0, 0, 0, 0, 0, 0),
(950002, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950002, 0, 0, '+3% Strength',          0, 0, 0, 0, 0, 0, 0),
(950003, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950003, 0, 0, '+3% Agility',           0, 0, 0, 0, 0, 0, 0),
(950004, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950004, 0, 0, '+3% Intellect',         0, 0, 0, 0, 0, 0, 0),
(950005, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950005, 0, 0, '+3% Spirit',            0, 0, 0, 0, 0, 0, 0),
-- Health/Damage/Healing passives
(950006, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950006, 0, 0, '+5% Max Health',        0, 0, 0, 0, 0, 0, 0),
(950007, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950007, 0, 0, '+3% All Damage',        0, 0, 0, 0, 0, 0, 0),
(950008, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950008, 0, 0, '+5% Healing Done',      0, 0, 0, 0, 0, 0, 0),
-- Combat Rating passives
(950011, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950011, 0, 0, '+30 Hit Rating',        0, 0, 0, 0, 0, 0, 0),
(950012, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950012, 0, 0, '+30 Crit Rating',       0, 0, 0, 0, 0, 0, 0),
(950013, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950013, 0, 0, '+30 Haste Rating',      0, 0, 0, 0, 0, 0, 0),
(950014, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950014, 0, 0, '+30 Dodge Rating',      0, 0, 0, 0, 0, 0, 0),
(950015, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950015, 0, 0, '+30 Parry Rating',      0, 0, 0, 0, 0, 0, 0),
(950016, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950016, 0, 0, '+30 Defense Rating',    0, 0, 0, 0, 0, 0, 0),
(950017, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950017, 0, 0, '+30 Expertise Rating',  0, 0, 0, 0, 0, 0, 0),
(950018, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950018, 0, 0, '+30 Armor Pen Rating',  0, 0, 0, 0, 0, 0, 0),
-- Proc enchantments (still type 3 = equip spell; the spell itself handles procs)
(950031, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950031, 0, 0, 'Thunderstrike',         0, 0, 0, 0, 0, 0, 0),
(950032, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950032, 0, 0, 'Vampiric Siphon',       0, 0, 0, 0, 0, 0, 0),
(950033, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950033, 0, 0, 'Berserker''s Fury',     0, 0, 0, 0, 0, 0, 0),
(950034, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950034, 0, 0, 'Arcane Infusion',       0, 0, 0, 0, 0, 0, 0),
(950035, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950035, 0, 0, 'Stoneskin',             0, 0, 0, 0, 0, 0, 0);


-- =============================================================
-- 3. PASSIVE SPELL POOL TABLE
-- =============================================================
-- Defines which passive effects can roll on items, with weights
-- and role filtering. Loaded by C++ on server startup.
--
-- category: 0 = stat_pct, 1 = health/dmg/heal_pct, 2 = rating, 3 = proc
-- roleMask: bitmask — 1=Tank, 2=DPS, 4=Healer (7=all)
-- =============================================================

CREATE TABLE IF NOT EXISTS `paragon_passive_spell_pool` (
    `id` int unsigned NOT NULL AUTO_INCREMENT,
    `enchantmentId` int unsigned NOT NULL COMMENT 'spellitemenchantment_dbc ID',
    `spellId` int unsigned NOT NULL DEFAULT 0 COMMENT 'spell_dbc ID (reference only)',
    `name` varchar(64) NOT NULL DEFAULT '',
    `category` tinyint unsigned NOT NULL DEFAULT 0 COMMENT '0=stat_pct, 1=health/dmg/heal, 2=rating, 3=proc',
    `roleMask` tinyint unsigned NOT NULL DEFAULT 7 COMMENT 'Bitmask: 1=Tank, 2=DPS, 4=Healer',
    `weight` int unsigned NOT NULL DEFAULT 100 COMMENT 'Relative weight for random selection',
    `minParagonLevel` int unsigned NOT NULL DEFAULT 1 COMMENT 'Minimum paragon level to roll this effect',
    `minItemLevel` int unsigned NOT NULL DEFAULT 0 COMMENT 'Minimum item level to roll this effect',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_enchantment` (`enchantmentId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Clear and repopulate
DELETE FROM `paragon_passive_spell_pool`;

INSERT INTO `paragon_passive_spell_pool`
    (`enchantmentId`, `spellId`, `name`, `category`, `roleMask`, `weight`, `minParagonLevel`, `minItemLevel`)
VALUES
-- Stat % passives (category 0)
(950001, 950001, 'Fortitude',       0, 7, 100, 1,   0),   -- +3% Stamina (all roles)
(950002, 950002, 'Might',           0, 3, 100, 1,   0),   -- +3% Strength (Tank+DPS)
(950003, 950003, 'Grace',           0, 2, 100, 1,   0),   -- +3% Agility (DPS only)
(950004, 950004, 'Brilliance',      0, 6, 100, 1,   0),   -- +3% Intellect (DPS+Healer)
(950005, 950005, 'Wisdom',          0, 4, 100, 1,   0),   -- +3% Spirit (Healer only)

-- Health/Damage/Healing % passives (category 1)
(950006, 950006, 'Vitality',        1, 7, 80,  5,   0),   -- +5% Max Health (all, rarer)
(950007, 950007, 'Destruction',     1, 2, 80,  5,   0),   -- +3% All Damage (DPS)
(950008, 950008, 'Mending',         1, 4, 80,  5,   0),   -- +5% Healing Done (Healer)

-- Combat Rating passives (category 2)
(950011, 950011, 'Precision',       2, 7, 100, 1,   0),   -- +30 Hit Rating (all)
(950012, 950012, 'Ferocity',        2, 6, 100, 1,   0),   -- +30 Crit Rating (DPS+Healer)
(950013, 950013, 'Alacrity',        2, 6, 100, 1,   0),   -- +30 Haste Rating (DPS+Healer)
(950014, 950014, 'Evasion',         2, 1, 100, 1,   0),   -- +30 Dodge Rating (Tank)
(950015, 950015, 'Deflection',      2, 1, 100, 1,   0),   -- +30 Parry Rating (Tank)
(950016, 950016, 'Warding',         2, 1, 100, 1,   0),   -- +30 Defense Rating (Tank)
(950017, 950017, 'Finesse',         2, 3, 100, 1,   0),   -- +30 Expertise (Tank+DPS)
(950018, 950018, 'Piercing',        2, 2, 100, 1,   0),   -- +30 Armor Pen (DPS)

-- Proc effects (category 3) — require higher paragon level
(950031, 950031, 'Thunderstrike',   3, 3, 60, 10, 200),   -- Nature dmg proc (Tank+DPS)
(950032, 950032, 'Vampiric Siphon', 3, 7, 60, 10, 200),   -- Heal on hit proc (all)
(950033, 950033, 'Berserker''s Fury', 3, 2, 60, 10, 200), -- +AP proc (DPS)
(950034, 950034, 'Arcane Infusion', 3, 6, 60, 10, 200),   -- +SP proc (DPS+Healer)
(950035, 950035, 'Stoneskin',       3, 1, 60, 10, 200);   -- Absorb proc (Tank)
