/*
 * Paragon Item Scaling Module v2
 *
 * Item enchantment slots:
 *   PROP_ENCHANTMENT_SLOT_0 (7):  Stamina (always)
 *   PROP_ENCHANTMENT_SLOT_1 (8):  Main stat (player choice: Str/Agi/Int/Spi)
 *   PROP_ENCHANTMENT_SLOT_2 (9):  Random combat rating (role-based)
 *   PROP_ENCHANTMENT_SLOT_3 (10): Random combat rating (role-based)
 *   PROP_ENCHANTMENT_SLOT_4 (11): Passive spell effect (spec-based)
 *
 * Roles: Tank(0), DPS(1), Healer(2)
 * Role + main stat can only be changed in rested areas.
 * Spec determines which passive spells can roll on Slot 11.
 */

#ifndef PARAGON_ITEMGEN_H
#define PARAGON_ITEMGEN_H

#include "Define.h"

// Enchantment ID layout: BASE + statIndex * 1000 + amount
constexpr uint32 PARAGON_ENCHANT_BASE_ID       = 900000;
constexpr uint32 PARAGON_ENCHANT_STAT_STRIDE    = 1000;
constexpr uint32 PARAGON_ENCHANT_MAX_AMOUNT     = 200;
constexpr uint32 PARAGON_ENCHANT_MAX_STAT_INDEX = 16;
constexpr uint32 PARAGON_ENCHANT_CURSED_ID      = 920001;

// Enchantment slots used (PROP_ENCHANTMENT_SLOT_0 through _4)
constexpr uint8 PARAGON_SLOT_STAMINA       = 7;  // PROP_ENCHANTMENT_SLOT_0
constexpr uint8 PARAGON_SLOT_MAINSTAT      = 8;  // PROP_ENCHANTMENT_SLOT_1
constexpr uint8 PARAGON_SLOT_COMBAT_RATING1 = 9;  // PROP_ENCHANTMENT_SLOT_2
constexpr uint8 PARAGON_SLOT_COMBAT_RATING2 = 10; // PROP_ENCHANTMENT_SLOT_3
constexpr uint8 PARAGON_SLOT_TALENT_SPELL  = 11; // PROP_ENCHANTMENT_SLOT_4

// Passive spell enchantment ID range (spellitemenchantment_dbc)
constexpr uint32 PARAGON_PASSIVE_ENCHANT_MIN = 950001;
constexpr uint32 PARAGON_PASSIVE_ENCHANT_MAX = 950099;

// NPC entry for spec selection gossip
constexpr uint32 PARAGON_SPEC_NPC_ENTRY = 900100;

// Role bitmask for passive spell pool filtering (legacy, kept for combat ratings)
constexpr uint8 PARAGON_ROLE_MASK_TANK   = 1;
constexpr uint8 PARAGON_ROLE_MASK_DPS    = 2;
constexpr uint8 PARAGON_ROLE_MASK_HEALER = 4;

// ============================================================
// Talent Specializations
// ============================================================
// Each class has 3 specs (druid has 4: feral tank + feral dps).
// Spec determines which passive spells can roll on items.
// Player selects spec via gossip NPC.
// ============================================================

enum ParagonSpec : uint8
{
    SPEC_NONE               = 0,

    // Warrior (CLASS_WARRIOR = 1)
    SPEC_WARRIOR_ARMS       = 1,
    SPEC_WARRIOR_FURY       = 2,
    SPEC_WARRIOR_PROT       = 3,

    // Paladin (CLASS_PALADIN = 2)
    SPEC_PALADIN_HOLY       = 4,
    SPEC_PALADIN_PROT       = 5,
    SPEC_PALADIN_RET        = 6,

    // Death Knight (CLASS_DEATH_KNIGHT = 6)
    SPEC_DK_BLOOD           = 7,
    SPEC_DK_FROST           = 8,
    SPEC_DK_UNHOLY          = 9,

    // Shaman (CLASS_SHAMAN = 7)
    SPEC_SHAMAN_ELE         = 10,
    SPEC_SHAMAN_ENHANCE     = 11,
    SPEC_SHAMAN_RESTO       = 12,

    // Hunter (CLASS_HUNTER = 3)
    SPEC_HUNTER_BM          = 13,
    SPEC_HUNTER_MM          = 14,
    SPEC_HUNTER_SURV        = 15,

    // Druid (CLASS_DRUID = 11)
    SPEC_DRUID_BALANCE      = 16,
    SPEC_DRUID_RESTO        = 17,
    SPEC_DRUID_FERAL_TANK   = 18,
    SPEC_DRUID_FERAL_DPS    = 19,

    // Rogue (CLASS_ROGUE = 4)
    SPEC_ROGUE_ASSA         = 20,
    SPEC_ROGUE_COMBAT       = 21,
    SPEC_ROGUE_SUB          = 22,

    // Mage (CLASS_MAGE = 8)
    SPEC_MAGE_ARCANE        = 23,
    SPEC_MAGE_FIRE          = 24,
    SPEC_MAGE_FROST         = 25,

    // Warlock (CLASS_WARLOCK = 9)
    SPEC_WARLOCK_AFFLI      = 26,
    SPEC_WARLOCK_DEMO       = 27,
    SPEC_WARLOCK_DESTRO     = 28,

    // Priest (CLASS_PRIEST = 5)
    SPEC_PRIEST_DISC        = 29,
    SPEC_PRIEST_HOLY        = 30,
    SPEC_PRIEST_SHADOW      = 31,

    SPEC_MAX
};

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

// Player roles (used for combat rating pools on slots 9-10)
enum ParagonRole : uint8
{
    ROLE_TANK   = 0,
    ROLE_DPS    = 1,
    ROLE_HEALER = 2,
    ROLE_MAX
};

// Shared helper: spec name lookup (defined in ParagonItemGenNPC.cpp)
char const* ParagonSpecName(ParagonSpec spec);

void AddParagonItemGenScripts();
void AddParagonItemGenCommandScripts();
void AddParagonItemGenNPCScripts();

#endif // PARAGON_ITEMGEN_H
