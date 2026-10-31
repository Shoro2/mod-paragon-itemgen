/*
 * Paragon Item Scaling Module v2
 *
 * Item enchantment slots:
 *   PROP_ENCHANTMENT_SLOT_0 (7):  Stamina (always)
 *   PROP_ENCHANTMENT_SLOT_1 (8):  Main stat (player choice: Str/Agi/Int/Spi)
 *   PROP_ENCHANTMENT_SLOT_2 (9):  Random combat rating (role-based)
 *   PROP_ENCHANTMENT_SLOT_3 (10): Random combat rating (role-based)
 *   PROP_ENCHANTMENT_SLOT_4 (11): Passive spell effect (cursed items, spec-based) or Cursed marker
 *
 * Roles: Tank(0), DPS(1), Healer(2)
 * Role + main stat can only be changed in rested areas.
 * Spec determines which passive spells can roll on Slot 11.
 */

#ifndef PARAGON_ITEMGEN_H
#define PARAGON_ITEMGEN_H

#include "Define.h"
#include <string>
#include <vector>

// Enchantment ID layout: BASE + statIndex * 1000 + amount
constexpr uint32 PARAGON_ENCHANT_BASE_ID       = 900000;
constexpr uint32 PARAGON_ENCHANT_STAT_STRIDE    = 1000;
constexpr uint32 PARAGON_ENCHANT_MAX_AMOUNT     = 666;
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
constexpr uint32 PARAGON_PASSIVE_ENCHANT_MAX = 950999;

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

class Item;
class Player;

// For other modules (mod-ptr-template): what the Paragon Artificer and
// `.paragon role|stat` store for a character - the role, the main stat
// (PSTAT_STRENGTH, _AGILITY, _INTELLECT or _SPIRIT) and the spec.
struct ParagonRollProfile
{
    ParagonRole role;
    ParagonStatIndex mainStat;
    ParagonSpec spec;
};

// Stores `profile` as the character's role, main stat and spec (what later
// rolls on loot, crafts, quest rewards and purchases use); no rested-area
// check, unlike the commands.
void ParagonItemGenSetProfile(Player* player, ParagonRollProfile const& profile);

// Rolls the Paragon enchantments on `item` as a CURSED roll at the player's
// Paragon level, with `profile` (nullptr: the character's stored profile).
// `quiet` drops the chat line and the visual per item. Respects the kill
// switch (ParagonItemGen.CursedChance = 0: a normal roll). False when the
// item is not eligible or already rolled, or the player has no Paragon
// level or no profile.
bool ParagonItemGenRollCursed(Player* player, Item* item,
    ParagonRollProfile const* profile, bool quiet);

// Shared helper: spec name lookup (defined in ParagonItemGenNPC.cpp)
char const* ParagonSpecName(ParagonSpec spec);

// ============================================================
// Cursed Altar (ParagonItemGenAltar.cpp; the roll and the pool live in ParagonItemGen.cpp)
// ============================================================

// Currency tokens (class 10 items with a CurrencyTypes record) and the altar object.
constexpr uint32 PARAGON_ALTAR_TOKEN_ITEM    = 920300;  // "Cursed Essence": paid for a sacrifice, spent on a bind
constexpr uint32 PARAGON_ALTAR_MATERIAL_ITEM = 920301;  // "Tainted Heartstone": the second price of a bind
constexpr uint32 PARAGON_ALTAR_GO_ENTRY      = 921010;  // "Cursed Altar" (go_paragon_cursed_altar)

// One passive of a class pool: the enchantment (slot 11), the spell it carries (icon, tooltip),
// the pool name and the specs of that class whose pool holds it (bit n-1 = ParagonSpec n).
struct ParagonClassPassive
{
    uint32 enchantmentId;
    uint32 spellId;
    std::string name;
    uint32 specMask;
};

// The class (CLASS_*) a spec belongs to; 0 for SPEC_NONE and out-of-range values.
uint8 ParagonSpecClass(ParagonSpec spec);

// The class pool: every passive in at least one spec pool of `classId`, sorted by enchantment id.
// Empty for a class without specs.
void ParagonItemGenGetClassPassives(uint8 classId, std::vector<ParagonClassPassive>& out);

// The catalog name of a passive (paragon_passive_spell_pool, whether or not a spec still lists it - a retired
// passive keeps its catalog row); empty when the catalog has none.
std::string ParagonItemGenPassiveName(uint32 enchantId);

// The spell a passive carries (paragon_passive_spell_pool.spellId); 0 when the catalog has none.
uint32 ParagonItemGenPassiveSpell(uint32 enchantId);

// Whether the item may carry Paragon enchantments at all (weapon/armor, uncommon to legendary, item level).
bool ParagonItemGenIsEligibleItem(Item* item);

// True for the passive-spell enchantment range (950001-950999) - the slot 11 values that carry a passive.
bool ParagonItemGenIsPassiveEnchant(uint32 enchantId);

// Everything a bind needs from the roll BEFORE anything is taken: the kill switch, an unequipped
// eligible item, the Paragon level and the stored role. False with the reason in `reason`.
bool ParagonItemGenCheckAltarBind(Player* player, Item* item, uint32 passiveEnchantId, std::string& reason);

// Re-rolls `item` as a CURSED item at the player's Paragon level with exactly `passiveEnchantId` in
// slot 11: slots 7-11 are cleared first, then rolled like any cursed roll (all stats at the cursed
// multiplier, soulbound). The old enchantments are restored when the roll fails. The item must be
// unequipped. Run ParagonItemGenCheckAltarBind first; this checks again.
bool ParagonItemGenRollCursedWithPassive(Player* player, Item* item, uint32 passiveEnchantId);

void AddParagonItemGenScripts();
void AddParagonItemGenCommandScripts();
void AddParagonItemGenNPCScripts();
void AddParagonItemGenAltarScripts();

#endif // PARAGON_ITEMGEN_H
