-- =============================================================
-- Paragon Item Passive Spell Effects
-- Custom spells, enchantments, spec-spell assignments, and NPC
-- for the passive spell system on Slot 11 (PARAGON_SLOT_TALENT_SPELL).
--
-- ID Ranges:
--   spell_dbc:               950001-950199 (passive/proc/triggered)
--   spellitemenchantment_dbc: 950001-950099 (equip/combat enchants)
--   paragon_passive_spell_pool: spell catalog (enchantment reference)
--   paragon_spec_spell_assign: spec → spell mapping
--
-- Spec IDs (ParagonSpec enum):
--   Warrior:  Arms=1, Fury=2, Prot=3
--   Paladin:  Holy=4, Prot=5, Ret=6
--   DK:       Blood=7, Frost=8, Unholy=9
--   Shaman:   Ele=10, Enhance=11, Resto=12
--   Hunter:   BM=13, MM=14, Surv=15
--   Druid:    Balance=16, Resto=17, Feral Tank=18, Feral DPS=19
--   Rogue:    Assa=20, Combat=21, Sub=22
--   Mage:     Arcane=23, Fire=24, Frost=25
--   Warlock:  Affli=26, Demo=27, Destro=28
--   Priest:   Disc=29, Holy=30, Shadow=31
-- =============================================================


-- =============================================================
-- 1. SPELL_DBC ENTRIES
-- =============================================================
-- NOTE: The user will create these manually. The entries below are
-- example/starter spells that can be replaced or extended.
-- =============================================================

DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 950001 AND 950199;

-- Category A: Passive Stat % Auras (equip)
-- Effect=6 (APPLY_AURA), Aura=137 (MOD_TOTAL_STAT_PERCENTAGE)
-- MiscValue: 0=Str, 1=Agi, 2=Sta, 3=Int, 4=Spi, -1=All
-- Attributes=64 (PASSIVE), DurationIndex=21 (infinite)
-- DieSides=1, BasePoints=value-1 (standard WoW convention)
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `RangeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectMiscValue_1`,
    `EffectAura_1`, `ImplicitTargetA_1`, `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950001, 64, 21, 1, 6, 1, 2, 2, 137, 1, 1, 'Paragon: Fortitude'),    -- +3% Stamina
(950002, 64, 21, 1, 6, 1, 2, 0, 137, 1, 1, 'Paragon: Might'),         -- +3% Strength
(950003, 64, 21, 1, 6, 1, 2, 1, 137, 1, 1, 'Paragon: Grace'),         -- +3% Agility
(950004, 64, 21, 1, 6, 1, 2, 3, 137, 1, 1, 'Paragon: Brilliance'),    -- +3% Intellect
(950005, 64, 21, 1, 6, 1, 2, 4, 137, 1, 1, 'Paragon: Wisdom');        -- +3% Spirit

-- Category B: Passive Health/Damage/Healing % Auras
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `RangeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectMiscValue_1`,
    `EffectAura_1`, `ImplicitTargetA_1`, `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950006, 64, 21, 1, 6, 1, 4, 0,   230, 1, 1, 'Paragon: Vitality'),      -- +5% Max Health
(950007, 64, 21, 1, 6, 1, 2, 127, 79,  1, 1, 'Paragon: Destruction'),    -- +3% All Damage
(950008, 64, 21, 1, 6, 1, 4, 127, 136, 1, 1, 'Paragon: Mending');        -- +5% Healing Done

-- Category C: Passive Combat Rating Auras (Aura 189 = MOD_RATING)
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `RangeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectMiscValue_1`,
    `EffectAura_1`, `ImplicitTargetA_1`, `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950011, 64, 21, 1, 6, 1, 29, 224,      189, 1, 1, 'Paragon: Precision'),    -- +30 Hit Rating
(950012, 64, 21, 1, 6, 1, 29, 1792,     189, 1, 1, 'Paragon: Ferocity'),     -- +30 Crit Rating
(950013, 64, 21, 1, 6, 1, 29, 458752,   189, 1, 1, 'Paragon: Alacrity'),     -- +30 Haste Rating
(950014, 64, 21, 1, 6, 1, 29, 4,        189, 1, 1, 'Paragon: Evasion'),      -- +30 Dodge Rating
(950015, 64, 21, 1, 6, 1, 29, 8,        189, 1, 1, 'Paragon: Deflection'),   -- +30 Parry Rating
(950016, 64, 21, 1, 6, 1, 29, 2,        189, 1, 1, 'Paragon: Warding'),      -- +30 Defense Rating
(950017, 64, 21, 1, 6, 1, 29, 16777216, 189, 1, 1, 'Paragon: Finesse'),      -- +30 Expertise Rating
(950018, 64, 21, 1, 6, 1, 29, 33554432, 189, 1, 1, 'Paragon: Piercing');     -- +30 Armor Pen Rating

-- Category D: Proc Trigger Auras (equip spells with PROC_TRIGGER_SPELL)
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `RangeIndex`,
    `ProcTypeMask`, `ProcChance`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`,
    `EffectAura_1`, `EffectTriggerSpell_1`, `ImplicitTargetA_1`,
    `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950031, 64, 21, 1, 20, 8,  6, 0, 0, 42, 950101, 1, 1, 'Paragon: Thunderstrike'),
(950032, 64, 21, 1, 20, 10, 6, 0, 0, 42, 950102, 1, 1, 'Paragon: Vampiric Siphon'),
(950033, 64, 21, 1, 20, 8,  6, 0, 0, 42, 950103, 1, 1, 'Paragon: Berserker''s Fury'),
(950034, 64, 21, 1, 16384, 8, 6, 0, 0, 42, 950104, 1, 1, 'Paragon: Arcane Infusion'),
(950035, 64, 21, 1, 64, 10, 6, 0, 0, 42, 950105, 1, 1, 'Paragon: Stoneskin');

-- Category E: Triggered Spells (fired by procs — NOT passive)
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `RangeIndex`, `SchoolMask`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`,
    `ImplicitTargetA_1`, `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950101, 0, 1, 8, 2, 1, 299, 6, 1, 'Thunderstrike Bolt');

INSERT INTO `spell_dbc` (`ID`, `Attributes`, `RangeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`,
    `ImplicitTargetA_1`, `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950102, 0, 1, 10, 1, 199, 1, 1, 'Vampiric Siphon');

INSERT INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `RangeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`,
    `EffectAura_1`, `ImplicitTargetA_1`, `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950103, 0, 1, 1, 6, 1, 199, 99, 1, 1, 'Berserker''s Fury');

INSERT INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `RangeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectMiscValue_1`,
    `EffectAura_1`, `ImplicitTargetA_1`,
    `Effect_2`, `EffectDieSides_2`, `EffectBasePoints_2`, `EffectMiscValue_2`,
    `EffectAura_2`, `ImplicitTargetA_2`,
    `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950104, 0, 1, 1,
    6, 1, 149, 126, 13, 1,
    6, 1, 149, 0,   135, 1,
    1, 'Arcane Infusion');

INSERT INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `RangeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectMiscValue_1`,
    `EffectAura_1`, `ImplicitTargetA_1`, `SpellIconID`, `Name_Lang_enUS`)
VALUES
(950105, 0, 1, 1, 6, 1, 499, 127, 69, 1, 1, 'Stoneskin Shield');


-- =============================================================
-- 2. SPELLITEMENCHANTMENT_DBC ENTRIES
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
-- Proc enchantments
(950031, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950031, 0, 0, 'Thunderstrike',         0, 0, 0, 0, 0, 0, 0),
(950032, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950032, 0, 0, 'Vampiric Siphon',       0, 0, 0, 0, 0, 0, 0),
(950033, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950033, 0, 0, 'Berserker''s Fury',     0, 0, 0, 0, 0, 0, 0),
(950034, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950034, 0, 0, 'Arcane Infusion',       0, 0, 0, 0, 0, 0, 0),
(950035, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 950035, 0, 0, 'Stoneskin',             0, 0, 0, 0, 0, 0, 0);


-- =============================================================
-- 3. PASSIVE SPELL POOL (spell catalog)
-- =============================================================
-- Defines available passive spells and their properties.
-- This table is the "what exists" catalog.
-- The "who gets what" is in paragon_spec_spell_assign.
-- =============================================================

DROP TABLE IF EXISTS `paragon_passive_spell_pool`;
CREATE TABLE `paragon_passive_spell_pool` (
    `enchantmentId` int unsigned NOT NULL COMMENT 'spellitemenchantment_dbc ID',
    `spellId` int unsigned NOT NULL DEFAULT 0 COMMENT 'spell_dbc ID (reference only)',
    `name` varchar(64) NOT NULL DEFAULT '',
    `category` tinyint unsigned NOT NULL DEFAULT 0 COMMENT '0=stat_pct, 1=health/dmg/heal, 2=rating, 3=proc',
    `minParagonLevel` int unsigned NOT NULL DEFAULT 1 COMMENT 'Minimum paragon level to roll this effect',
    `minItemLevel` int unsigned NOT NULL DEFAULT 0 COMMENT 'Minimum item level to roll this effect',
    PRIMARY KEY (`enchantmentId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `paragon_passive_spell_pool` (`enchantmentId`, `spellId`, `name`, `category`, `minParagonLevel`, `minItemLevel`) VALUES
-- Stat % passives
(950001, 950001, 'Fortitude',        0, 1,   0),  -- +3% Stamina
(950002, 950002, 'Might',            0, 1,   0),  -- +3% Strength
(950003, 950003, 'Grace',            0, 1,   0),  -- +3% Agility
(950004, 950004, 'Brilliance',       0, 1,   0),  -- +3% Intellect
(950005, 950005, 'Wisdom',           0, 1,   0),  -- +3% Spirit
-- Health/Damage/Healing %
(950006, 950006, 'Vitality',         1, 5,   0),  -- +5% Max Health
(950007, 950007, 'Destruction',      1, 5,   0),  -- +3% All Damage
(950008, 950008, 'Mending',          1, 5,   0),  -- +5% Healing Done
-- Combat Ratings
(950011, 950011, 'Precision',        2, 1,   0),  -- +30 Hit Rating
(950012, 950012, 'Ferocity',         2, 1,   0),  -- +30 Crit Rating
(950013, 950013, 'Alacrity',         2, 1,   0),  -- +30 Haste Rating
(950014, 950014, 'Evasion',          2, 1,   0),  -- +30 Dodge Rating
(950015, 950015, 'Deflection',       2, 1,   0),  -- +30 Parry Rating
(950016, 950016, 'Warding',          2, 1,   0),  -- +30 Defense Rating
(950017, 950017, 'Finesse',          2, 1,   0),  -- +30 Expertise Rating
(950018, 950018, 'Piercing',         2, 1,   0),  -- +30 Armor Pen Rating
-- Proc effects
(950031, 950031, 'Thunderstrike',    3, 10, 200), -- Nature dmg proc
(950032, 950032, 'Vampiric Siphon',  3, 10, 200), -- Heal on hit proc
(950033, 950033, 'Berserker''s Fury', 3, 10, 200), -- +AP proc
(950034, 950034, 'Arcane Infusion',  3, 10, 200), -- +SP proc
(950035, 950035, 'Stoneskin',        3, 10, 200); -- Absorb proc


-- =============================================================
-- 4. SPEC → SPELL ASSIGNMENT TABLE
-- =============================================================
-- Maps talent specializations to available passive spells.
-- Each row = "spec X can roll spell Y with weight Z".
-- This is the table you edit to control which specs get which spells.
--
-- To add a new spell to a spec:
--   INSERT INTO paragon_spec_spell_assign (specId, enchantmentId, weight)
--   VALUES (<specId>, <enchantmentId>, <weight>);
--
-- Weight is relative within each spec's pool.
-- Higher weight = more likely to roll.
-- =============================================================

DROP TABLE IF EXISTS `paragon_spec_spell_assign`;
CREATE TABLE `paragon_spec_spell_assign` (
    `specId` tinyint unsigned NOT NULL COMMENT 'ParagonSpec enum (1-31)',
    `enchantmentId` int unsigned NOT NULL COMMENT 'spellitemenchantment_dbc ID from pool',
    `weight` int unsigned NOT NULL DEFAULT 100 COMMENT 'Relative roll weight within this spec',
    PRIMARY KEY (`specId`, `enchantmentId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- Example assignments (starter data)
-- You will replace/extend this with your own assignments.
--
-- Spec IDs:
--   1=Arms, 2=Fury, 3=WarProt, 4=HolyPala, 5=ProtPala, 6=Ret,
--   7=Blood, 8=DKFrost, 9=Unholy, 10=Ele, 11=Enhance, 12=RestoSham,
--   13=BM, 14=MM, 15=Surv, 16=Balance, 17=RestoDru, 18=FeralTank,
--   19=FeralDPS, 20=Assa, 21=Combat, 22=Sub, 23=Arcane, 24=Fire,
--   25=MageFrost, 26=Affli, 27=Demo, 28=Destro, 29=Disc, 30=HolyPri,
--   31=Shadow
-- =============================================================

-- Warrior Arms (1): Strength, Hit, Crit, Expertise, ArmorPen, Destruction, Berserker, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(1, 950001, 100), (1, 950002, 100), (1, 950011, 100), (1, 950012, 100),
(1, 950017, 100), (1, 950018, 100), (1, 950007, 80),
(1, 950033, 60), (1, 950031, 60);

-- Warrior Fury (2): Strength, Hit, Crit, Haste, Expertise, ArmorPen, Destruction, Berserker, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(2, 950001, 100), (2, 950002, 100), (2, 950011, 100), (2, 950012, 100),
(2, 950013, 100), (2, 950017, 100), (2, 950018, 100), (2, 950007, 80),
(2, 950033, 60), (2, 950031, 60);

-- Warrior Prot (3): Stamina, Strength, Dodge, Parry, Defense, Hit, Expertise, Vitality, Stoneskin
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(3, 950001, 120), (3, 950002, 100), (3, 950014, 100), (3, 950015, 100),
(3, 950016, 100), (3, 950011, 100), (3, 950017, 100), (3, 950006, 80),
(3, 950035, 60), (3, 950032, 60);

-- Paladin Holy (4): Intellect, Spirit, Crit, Haste, MP5, Mending, Vampiric Siphon
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(4, 950001, 100), (4, 950004, 100), (4, 950005, 100), (4, 950012, 100),
(4, 950013, 100), (4, 950008, 80), (4, 950032, 60);

-- Paladin Prot (5): Stamina, Strength, Dodge, Parry, Defense, Hit, Expertise, Vitality, Stoneskin
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(5, 950001, 120), (5, 950002, 100), (5, 950014, 100), (5, 950015, 100),
(5, 950016, 100), (5, 950011, 100), (5, 950017, 100), (5, 950006, 80),
(5, 950035, 60), (5, 950032, 60);

-- Paladin Ret (6): Strength, Hit, Crit, Haste, Expertise, ArmorPen, Destruction, Berserker, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(6, 950001, 100), (6, 950002, 100), (6, 950011, 100), (6, 950012, 100),
(6, 950013, 100), (6, 950017, 100), (6, 950018, 100), (6, 950007, 80),
(6, 950033, 60), (6, 950031, 60);

-- DK Blood (7): Stamina, Strength, Dodge, Parry, Defense, Hit, Expertise, Vitality, Stoneskin
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(7, 950001, 120), (7, 950002, 100), (7, 950014, 100), (7, 950015, 100),
(7, 950016, 100), (7, 950011, 100), (7, 950017, 100), (7, 950006, 80),
(7, 950035, 60), (7, 950032, 60);

-- DK Frost (8): Strength, Hit, Crit, Haste, Expertise, ArmorPen, Destruction, Berserker, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(8, 950001, 100), (8, 950002, 100), (8, 950011, 100), (8, 950012, 100),
(8, 950013, 100), (8, 950017, 100), (8, 950018, 100), (8, 950007, 80),
(8, 950033, 60), (8, 950031, 60);

-- DK Unholy (9): Strength, Hit, Crit, Haste, Expertise, ArmorPen, Destruction, Berserker, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(9, 950001, 100), (9, 950002, 100), (9, 950011, 100), (9, 950012, 100),
(9, 950013, 100), (9, 950017, 100), (9, 950018, 100), (9, 950007, 80),
(9, 950033, 60), (9, 950031, 60);

-- Shaman Ele (10): Intellect, Spirit, Hit, Crit, Haste, Destruction, Arcane Infusion
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(10, 950001, 100), (10, 950004, 100), (10, 950005, 80), (10, 950011, 100),
(10, 950012, 100), (10, 950013, 100), (10, 950007, 80), (10, 950034, 60);

-- Shaman Enhance (11): Strength, Agility, Hit, Crit, Haste, Expertise, ArmorPen, Destruction, Berserker, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(11, 950001, 100), (11, 950002, 80), (11, 950003, 100), (11, 950011, 100),
(11, 950012, 100), (11, 950013, 100), (11, 950017, 100), (11, 950018, 80),
(11, 950007, 80), (11, 950033, 60), (11, 950031, 60);

-- Shaman Resto (12): Intellect, Spirit, Crit, Haste, Mending, Vampiric Siphon
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(12, 950001, 100), (12, 950004, 100), (12, 950005, 100), (12, 950012, 100),
(12, 950013, 100), (12, 950008, 80), (12, 950032, 60);

-- Hunter BM (13): Agility, Hit, Crit, Haste, ArmorPen, Destruction, Berserker, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(13, 950001, 100), (13, 950003, 100), (13, 950011, 100), (13, 950012, 100),
(13, 950013, 100), (13, 950018, 100), (13, 950007, 80),
(13, 950033, 60), (13, 950031, 60);

-- Hunter MM (14): Agility, Hit, Crit, Haste, ArmorPen, Destruction, Berserker, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(14, 950001, 100), (14, 950003, 100), (14, 950011, 100), (14, 950012, 100),
(14, 950013, 100), (14, 950018, 100), (14, 950007, 80),
(14, 950033, 60), (14, 950031, 60);

-- Hunter Surv (15): Agility, Hit, Crit, Haste, Expertise, ArmorPen, Destruction, Berserker, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(15, 950001, 100), (15, 950003, 100), (15, 950011, 100), (15, 950012, 100),
(15, 950013, 100), (15, 950017, 100), (15, 950018, 100), (15, 950007, 80),
(15, 950033, 60), (15, 950031, 60);

-- Druid Balance (16): Intellect, Spirit, Hit, Crit, Haste, Destruction, Arcane Infusion
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(16, 950001, 100), (16, 950004, 100), (16, 950005, 80), (16, 950011, 100),
(16, 950012, 100), (16, 950013, 100), (16, 950007, 80), (16, 950034, 60);

-- Druid Resto (17): Intellect, Spirit, Crit, Haste, Mending, Vampiric Siphon
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(17, 950001, 100), (17, 950004, 100), (17, 950005, 100), (17, 950012, 100),
(17, 950013, 100), (17, 950008, 80), (17, 950032, 60);

-- Druid Feral Tank (18): Stamina, Agility, Dodge, Defense, Hit, Expertise, Vitality, Stoneskin
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(18, 950001, 120), (18, 950003, 100), (18, 950014, 100), (18, 950016, 100),
(18, 950011, 100), (18, 950017, 100), (18, 950006, 80),
(18, 950035, 60), (18, 950032, 60);

-- Druid Feral DPS (19): Agility, Hit, Crit, Haste, Expertise, ArmorPen, Destruction, Berserker, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(19, 950001, 100), (19, 950003, 100), (19, 950011, 100), (19, 950012, 100),
(19, 950013, 100), (19, 950017, 100), (19, 950018, 100), (19, 950007, 80),
(19, 950033, 60), (19, 950031, 60);

-- Rogue Assa (20): Agility, Hit, Crit, Haste, Expertise, ArmorPen, Destruction, Berserker, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(20, 950001, 100), (20, 950003, 100), (20, 950011, 100), (20, 950012, 100),
(20, 950013, 100), (20, 950017, 100), (20, 950018, 100), (20, 950007, 80),
(20, 950033, 60), (20, 950031, 60);

-- Rogue Combat (21): Agility, Hit, Crit, Haste, Expertise, ArmorPen, Destruction, Berserker, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(21, 950001, 100), (21, 950003, 100), (21, 950011, 100), (21, 950012, 100),
(21, 950013, 100), (21, 950017, 100), (21, 950018, 100), (21, 950007, 80),
(21, 950033, 60), (21, 950031, 60);

-- Rogue Sub (22): Agility, Hit, Crit, Haste, Expertise, ArmorPen, Destruction, Berserker, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(22, 950001, 100), (22, 950003, 100), (22, 950011, 100), (22, 950012, 100),
(22, 950013, 100), (22, 950017, 100), (22, 950018, 100), (22, 950007, 80),
(22, 950033, 60), (22, 950031, 60);

-- Mage Arcane (23): Intellect, Spirit, Hit, Crit, Haste, Destruction, Arcane Infusion
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(23, 950001, 100), (23, 950004, 100), (23, 950005, 80), (23, 950011, 100),
(23, 950012, 100), (23, 950013, 100), (23, 950007, 80), (23, 950034, 60);

-- Mage Fire (24): Intellect, Hit, Crit, Haste, Destruction, Arcane Infusion, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(24, 950001, 100), (24, 950004, 100), (24, 950011, 100), (24, 950012, 100),
(24, 950013, 100), (24, 950007, 80), (24, 950034, 60), (24, 950031, 60);

-- Mage Frost (25): Intellect, Hit, Crit, Haste, Destruction, Arcane Infusion
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(25, 950001, 100), (25, 950004, 100), (25, 950011, 100), (25, 950012, 100),
(25, 950013, 100), (25, 950007, 80), (25, 950034, 60);

-- Warlock Affli (26): Intellect, Spirit, Hit, Crit, Haste, Destruction, Arcane Infusion
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(26, 950001, 100), (26, 950004, 100), (26, 950005, 80), (26, 950011, 100),
(26, 950012, 100), (26, 950013, 100), (26, 950007, 80), (26, 950034, 60);

-- Warlock Demo (27): Intellect, Spirit, Hit, Crit, Haste, Destruction, Arcane Infusion
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(27, 950001, 100), (27, 950004, 100), (27, 950005, 80), (27, 950011, 100),
(27, 950012, 100), (27, 950013, 100), (27, 950007, 80), (27, 950034, 60);

-- Warlock Destro (28): Intellect, Hit, Crit, Haste, Destruction, Arcane Infusion, Thunderstrike
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(28, 950001, 100), (28, 950004, 100), (28, 950011, 100), (28, 950012, 100),
(28, 950013, 100), (28, 950007, 80), (28, 950034, 60), (28, 950031, 60);

-- Priest Disc (29): Intellect, Spirit, Crit, Haste, Mending, Vampiric Siphon
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(29, 950001, 100), (29, 950004, 100), (29, 950005, 100), (29, 950012, 100),
(29, 950013, 100), (29, 950008, 80), (29, 950032, 60);

-- Priest Holy (30): Intellect, Spirit, Crit, Haste, Mending, Vampiric Siphon
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(30, 950001, 100), (30, 950004, 100), (30, 950005, 100), (30, 950012, 100),
(30, 950013, 100), (30, 950008, 80), (30, 950032, 60);

-- Priest Shadow (31): Intellect, Spirit, Hit, Crit, Haste, Destruction, Arcane Infusion
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(31, 950001, 100), (31, 950004, 100), (31, 950005, 80), (31, 950011, 100),
(31, 950012, 100), (31, 950013, 100), (31, 950007, 80), (31, 950034, 60);


-- =============================================================
-- 5. NPC CREATURE TEMPLATE
-- =============================================================
-- Gossip NPC for spec selection. Spawn with: .npc add 900100
-- ScriptName must match the CreatureScript class name.
-- =============================================================

DELETE FROM `creature_template` WHERE `entry` = 900100;
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`,
    `faction`, `npcflag`, `unit_class`, `type`, `ScriptName`)
VALUES (900100, 'Paragon Artificer', 'Talent Specialization', 80, 80,
    35, 1, 1, 7, 'ParagonSpecNPC');
