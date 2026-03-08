-- =============================================================
-- Paragon Item Passive Spell Effects
-- Custom spells, enchantments, spec-spell assignments, and NPC
-- for the passive spell system on Slot 11 (PARAGON_SLOT_TALENT_SPELL).
--
-- ID Ranges:
--   spell_dbc:               900001-900999 (passive/proc/triggered)
--   spellitemenchantment_dbc: 950001-950999 (equip/combat enchants)
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


-- Paragon Passive Spell: +20% Strength (enchID=950001, spellID=900000)

-- spellitemenchantment_dbc: Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL)
INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(950001, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 900000, 0, 0, '+20% Strength', 0, 0, 0, 0, 0, 0, 0);

-- paragon_passive_spell_pool: spell catalog entry
INSERT INTO `paragon_passive_spell_pool` (`enchantmentId`, `spellId`, `name`, `category`, `minParagonLevel`, `minItemLevel`) VALUES
(950001, 900000, '+20% Strength', 0, 1, 0);

-- paragon_spec_spell_assign: Arms, Fury, WarProt, ProtPala, Ret, Blood, DKFrost, Unholy
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(1, 950001, 100), (2, 950001, 100), (3, 950001, 100), (5, 950001, 100),
(6, 950001, 100), (7, 950001, 100), (8, 950001, 100), (9, 950001, 100);


-- Paragon Passive Spell: +20% Intellect (enchID=950002, spellID=900001)

-- spellitemenchantment_dbc: Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL)
INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(950002, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 900001, 0, 0, '+20% Intellect', 0, 0, 0, 0, 0, 0, 0);

-- paragon_passive_spell_pool: spell catalog entry
INSERT INTO `paragon_passive_spell_pool` (`enchantmentId`, `spellId`, `name`, `category`, `minParagonLevel`, `minItemLevel`) VALUES
(950002, 900001, '+20% Intellect', 0, 1, 0);

-- paragon_spec_spell_assign: HolyPala, Ele, Enhance, RestoSham, Balance, RestoDru, Arcane, Fire, MageFrost, Affli, Demo, Destro, Disc, HolyPri, Shadow
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(4, 950002, 100), (10, 950002, 100), (11, 950002, 100), (12, 950002, 100),
(16, 950002, 100), (17, 950002, 100), (23, 950002, 100), (24, 950002, 100),
(25, 950002, 100), (26, 950002, 100), (27, 950002, 100), (28, 950002, 100),
(29, 950002, 100), (30, 950002, 100), (31, 950002, 100);


-- Paragon Passive Spell: +20 % Agility (enchID=950003, spellID=900002)

-- spellitemenchantment_dbc: Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL)
INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(950003, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 900002, 0, 0, '+20 % Agility', 0, 0, 0, 0, 0, 0, 0);

-- paragon_passive_spell_pool: spell catalog entry
INSERT INTO `paragon_passive_spell_pool` (`enchantmentId`, `spellId`, `name`, `category`, `minParagonLevel`, `minItemLevel`) VALUES
(950003, 900002, '+20 % Agility', 0, 1, 0);

-- paragon_spec_spell_assign: Enhance, BM, MM, Surv, FeralTank, FeralDPS, Assa, Combat, Sub
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(11, 950003, 100), (13, 950003, 100), (14, 950003, 100), (15, 950003, 100),
(18, 950003, 100), (19, 950003, 100), (20, 950003, 100), (21, 950003, 100),
(22, 950003, 100);


-- Paragon Passive Spell: +20% Spirit (enchID=950004, spellID=900003)

-- spellitemenchantment_dbc: Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL)
INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(950004, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 900003, 0, 0, '+20% Spirit', 0, 0, 0, 0, 0, 0, 0);

-- paragon_passive_spell_pool: spell catalog entry
INSERT INTO `paragon_passive_spell_pool` (`enchantmentId`, `spellId`, `name`, `category`, `minParagonLevel`, `minItemLevel`) VALUES
(950004, 900003, '+20% Spirit', 0, 1, 0);

-- paragon_spec_spell_assign: RestoSham, RestoDru, Disc, HolyPri, Shadow
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(12, 950004, 100), (17, 950004, 100), (29, 950004, 100), (30, 950004, 100),
(31, 950004, 100);


-- Paragon Passive Spell: +20% Stamina (enchID=950005, spellID=900004)

-- spellitemenchantment_dbc: Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL)
INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(950005, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 900004, 0, 0, '+20% Stamina', 0, 0, 0, 0, 0, 0, 0);

-- paragon_passive_spell_pool: spell catalog entry
INSERT INTO `paragon_passive_spell_pool` (`enchantmentId`, `spellId`, `name`, `category`, `minParagonLevel`, `minItemLevel`) VALUES
(950005, 900004, '+20% Stamina', 0, 1, 0);

-- paragon_spec_spell_assign: WarProt, ProtPala, Blood, DKFrost, FeralTank
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(3, 950005, 100), (5, 950005, 100), (7, 950005, 100), (8, 950005, 100),
(18, 950005, 100);


-- Paragon Passive Spell: +10% All Stats (enchID=950006, spellID=900005)

-- spellitemenchantment_dbc: Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL)
INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(950006, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 900005, 0, 0, '+10% All Stats', 0, 0, 0, 0, 0, 0, 0);

-- paragon_passive_spell_pool: spell catalog entry
INSERT INTO `paragon_passive_spell_pool` (`enchantmentId`, `spellId`, `name`, `category`, `minParagonLevel`, `minItemLevel`) VALUES
(950006, 900005, '+10% All Stats', 0, 1, 0);

-- paragon_spec_spell_assign: Arms, Fury, WarProt, HolyPala, ProtPala, Ret, Blood, DKFrost, Unholy, Ele, Enhance, RestoSham, BM, MM, Surv, Balance, RestoDru, FeralTank, FeralDPS, Assa, Combat, Sub, Arcane, Fire, MageFrost, Affli, Demo, Destro, Disc, HolyPri, Shadow
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(1, 950006, 80), (2, 950006, 80), (3, 950006, 80), (4, 950006, 80),
(5, 950006, 80), (6, 950006, 80), (7, 950006, 80), (8, 950006, 80),
(9, 950006, 80), (10, 950006, 80), (11, 950006, 80), (12, 950006, 80),
(13, 950006, 80), (14, 950006, 80), (15, 950006, 80), (16, 950006, 80),
(17, 950006, 80), (18, 950006, 80), (19, 950006, 80), (20, 950006, 80),
(21, 950006, 80), (22, 950006, 80), (23, 950006, 80), (24, 950006, 80),
(25, 950006, 80), (26, 950006, 80), (27, 950006, 80), (28, 950006, 80),
(29, 950006, 80), (30, 950006, 80), (31, 950006, 80);


-- Paragon Passive Spell: +50% Mortal Strike Damage (enchID=950007, spellID=900100)

-- spellitemenchantment_dbc: Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL)
INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(950007, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 900100, 0, 0, '+50% Mortal Strike Damage', 0, 0, 0, 0, 0, 0, 0);

-- paragon_passive_spell_pool: spell catalog entry
INSERT INTO `paragon_passive_spell_pool` (`enchantmentId`, `spellId`, `name`, `category`, `minParagonLevel`, `minItemLevel`) VALUES
(950007, 900100, '+50% Mortal Strike Damage', 0, 1, 0);

-- paragon_spec_spell_assign: Arms
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(1, 950007, 10);


-- Paragon Passive Spell: -2 sec Mortal Strike CD (enchID=950008, spellID=900101)

-- spellitemenchantment_dbc: Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL)
INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(950008, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 900101, 0, 0, '-2 sec Mortal Strike CD', 0, 0, 0, 0, 0, 0, 0);

-- paragon_passive_spell_pool: spell catalog entry
INSERT INTO `paragon_passive_spell_pool` (`enchantmentId`, `spellId`, `name`, `category`, `minParagonLevel`, `minItemLevel`) VALUES
(950008, 900101, '-2 sec Mortal Strike CD', 0, 1, 0);

-- paragon_spec_spell_assign: Arms
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(1, 950008, 10);


-- Paragon Passive Spell: +50% Overpower Damage (enchID=950009, spellID=900102)

-- spellitemenchantment_dbc: Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL)
INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(950009, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 900102, 0, 0, '+50% Overpower Damage', 0, 0, 0, 0, 0, 0, 0);

-- paragon_passive_spell_pool: spell catalog entry
INSERT INTO `paragon_passive_spell_pool` (`enchantmentId`, `spellId`, `name`, `category`, `minParagonLevel`, `minItemLevel`) VALUES
(950009, 900102, '+50% Overpower Damage', 0, 1, 0);

-- paragon_spec_spell_assign: Arms
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(1, 950009, 10);


-- Paragon Passive Spell: Mortal Strike +9 Targets (enchID=950010, spellID=900103)

-- spellitemenchantment_dbc: Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL)
INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(950010, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 900103, 0, 0, 'Mortal Strike +9 Targets', 0, 0, 0, 0, 0, 0, 0);

-- paragon_passive_spell_pool: spell catalog entry
INSERT INTO `paragon_passive_spell_pool` (`enchantmentId`, `spellId`, `name`, `category`, `minParagonLevel`, `minItemLevel`) VALUES
(950010, 900103, 'Mortal Strike +9 Targets', 0, 1, 0);

-- paragon_spec_spell_assign: Arms
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(1, 950010, 10);


-- Paragon Passive Spell: Overpower + 9 Targets (enchID=950011, spellID=900104)

-- spellitemenchantment_dbc: Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL)
INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(950011, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 900104, 0, 0, 'Overpower + 9 Targets', 0, 0, 0, 0, 0, 0, 0);

-- paragon_passive_spell_pool: spell catalog entry
INSERT INTO `paragon_passive_spell_pool` (`enchantmentId`, `spellId`, `name`, `category`, `minParagonLevel`, `minItemLevel`) VALUES
(950011, 900104, 'Overpower + 9 Targets', 0, 1, 0);

-- paragon_spec_spell_assign: Arms
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(1, 950011, 10);


-- Paragon Passive Spell: Spell: Critical Exectution (enchID=950012, spellID=900105)

-- spellitemenchantment_dbc: Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL)
INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(950012, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 900105, 0, 0, 'Spell: Critical Exectution', 0, 0, 0, 0, 0, 0, 0);

-- paragon_passive_spell_pool: spell catalog entry
INSERT INTO `paragon_passive_spell_pool` (`enchantmentId`, `spellId`, `name`, `category`, `minParagonLevel`, `minItemLevel`) VALUES
(950012, 900105, 'Spell: Critical Exectution', 0, 1, 0);

-- paragon_spec_spell_assign: Arms, Fury
INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES
(1, 950012, 5), (2, 950012, 5);
