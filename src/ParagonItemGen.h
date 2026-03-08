/*
 * Paragon Item Scaling Module v2
 *
 * Item enchantment slots:
 *   PROP_ENCHANTMENT_SLOT_0 (7):  Stamina (always)
 *   PROP_ENCHANTMENT_SLOT_1 (8):  Main stat (player choice: Str/Agi/Int/Spi)
 *   PROP_ENCHANTMENT_SLOT_2 (9):  Random combat rating (role-based)
 *   PROP_ENCHANTMENT_SLOT_3 (10): Random combat rating (role-based)
 *   PROP_ENCHANTMENT_SLOT_4 (11): Talent spell (role-based, TODO: custom spells)
 *
 * Roles: Tank(0), DPS(1), Healer(2)
 * Role + main stat can only be changed in rested areas.
 */

#ifndef PARAGON_ITEMGEN_H
#define PARAGON_ITEMGEN_H

#include "Define.h"

// Enchantment ID layout: BASE + statIndex * 1000 + amount
constexpr uint32 PARAGON_ENCHANT_BASE_ID       = 900000;
constexpr uint32 PARAGON_ENCHANT_STAT_STRIDE    = 1000;
constexpr uint32 PARAGON_ENCHANT_MAX_AMOUNT     = 200;
constexpr uint32 PARAGON_ENCHANT_MAX_STAT_INDEX = 16;

// Enchantment slots used (PROP_ENCHANTMENT_SLOT_0 through _4)
constexpr uint8 PARAGON_SLOT_STAMINA       = 7;  // PROP_ENCHANTMENT_SLOT_0
constexpr uint8 PARAGON_SLOT_MAINSTAT      = 8;  // PROP_ENCHANTMENT_SLOT_1
constexpr uint8 PARAGON_SLOT_COMBAT_RATING1 = 9;  // PROP_ENCHANTMENT_SLOT_2
constexpr uint8 PARAGON_SLOT_COMBAT_RATING2 = 10; // PROP_ENCHANTMENT_SLOT_3
constexpr uint8 PARAGON_SLOT_TALENT_SPELL  = 11; // PROP_ENCHANTMENT_SLOT_4

// Stat indices (maps to enchantment IDs)
enum ParagonStatIndex : uint8
{
    PSTAT_STAMINA           = 0,  // ITEM_MOD 7
    PSTAT_STRENGTH          = 1,  // ITEM_MOD 4
    PSTAT_AGILITY           = 2,  // ITEM_MOD 3
    PSTAT_INTELLECT         = 3,  // ITEM_MOD 5
    PSTAT_SPIRIT            = 4,  // ITEM_MOD 6
    PSTAT_DODGE_RATING      = 5,  // ITEM_MOD 13
    PSTAT_PARRY_RATING      = 6,  // ITEM_MOD 14
    PSTAT_DEFENSE_RATING    = 7,  // ITEM_MOD 12
    PSTAT_BLOCK_RATING      = 8,  // ITEM_MOD 15
    PSTAT_HIT_RATING        = 9,  // ITEM_MOD 31
    PSTAT_CRIT_RATING       = 10, // ITEM_MOD 32
    PSTAT_HASTE_RATING      = 11, // ITEM_MOD 36
    PSTAT_EXPERTISE_RATING  = 12, // ITEM_MOD 37
    PSTAT_ARMOR_PENETRATION = 13, // ITEM_MOD 44
    PSTAT_SPELL_POWER       = 14, // ITEM_MOD 45
    PSTAT_ATTACK_POWER      = 15, // ITEM_MOD 38
    PSTAT_MANA_REGENERATION = 16, // ITEM_MOD 43
    PSTAT_MAX
};

// Player roles
enum ParagonRole : uint8
{
    ROLE_TANK   = 0,
    ROLE_DPS    = 1,
    ROLE_HEALER = 2,
    ROLE_MAX
};

void AddParagonItemGenScripts();
void AddParagonItemGenCommandScripts();

#endif // PARAGON_ITEMGEN_H
