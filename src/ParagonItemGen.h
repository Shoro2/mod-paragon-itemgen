/*
 * Paragon Item Scaling Module
 * Applies bonus enchantments to items based on the player's Paragon level.
 * Items keep their stats permanently - role changes only affect new drops.
 */

#ifndef PARAGON_ITEMGEN_H
#define PARAGON_ITEMGEN_H

#include "Define.h"

// Enchantment ID layout: BASE + profileId * 1000 + statAmount
constexpr uint32 PARAGON_ENCHANT_BASE_ID = 900000;
constexpr uint32 PARAGON_ENCHANT_PROFILE_STRIDE = 1000;
constexpr uint32 PARAGON_ENCHANT_MAX_AMOUNT = 200;

// Enchantment slot used for paragon bonuses (PROP_ENCHANTMENT_SLOT_4 = 11)
constexpr uint8 PARAGON_ENCHANT_SLOT = 11;

// Stat profiles - determines which 3 stats an item receives
enum ParagonStatProfile : uint8
{
    PROFILE_STR_MELEE   = 0, // Strength + Crit + Haste
    PROFILE_AGI_MELEE   = 1, // Agility + Crit + Haste
    PROFILE_AGI_RANGED  = 2, // Agility + Crit + Hit
    PROFILE_INT_CASTER  = 3, // Intellect + Spell Power + Haste
    PROFILE_INT_HEALER  = 4, // Intellect + Spirit + Spell Power
    PROFILE_STR_TANK    = 5, // Stamina + Dodge + Parry
    PROFILE_AGI_TANK    = 6, // Stamina + Dodge + Agility
    PROFILE_MAX
};

void AddParagonItemGenScripts();

#endif // PARAGON_ITEMGEN_H
