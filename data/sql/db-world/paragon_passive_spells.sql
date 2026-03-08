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
