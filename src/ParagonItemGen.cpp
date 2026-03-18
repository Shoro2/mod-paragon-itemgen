/*
 * Paragon Item Scaling Module v2
 *
 * Applies 5 enchantment slots to items based on paragon level:
 *   Slot 7:  Stamina (always)
 *   Slot 8:  Main stat (player-chosen: Str/Agi/Int/Spi)
 *   Slot 9:  Random combat rating (role-dependent pool)
 *   Slot 10: Random combat rating (role-dependent pool, no duplicate)
 *   Slot 11: Passive spell effect (cursed items only, spec-filtered, weighted random)
 *            OR "Cursed" marker label (cursed items without spec/passive)
 *
 * Passive spell effects include: stat % buffs, combat rating boosts,
 * damage/healing % increases, and proc-on-hit effects.
 * The pool is loaded from paragon_passive_spell_pool (world DB) on startup.
 *
 * Trade/Mail restrictions prevent passing paragon items to lower-level players.
 * TODO: AH restriction needs a core-level hook (CanListAuction).
 */

#include "ParagonItemGen.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "Config.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "CharacterDatabase.h"
#include "WorldDatabase.h"
#include "DBCStores.h"
#include "ObjectGuid.h"
#include <random>
#include <vector>
#include <mutex>

// ============================================================
// Configuration
// ============================================================
static bool   conf_Enable          = true;
static bool   conf_OnLoot          = true;
static bool   conf_OnCreate        = true;
static bool   conf_OnQuest         = true;
static bool   conf_OnVendor        = true;
static float  conf_ScalingFactor   = 0.5f;
static float  conf_QualityMult[6]  = { 0.0f, 0.0f, 0.5f, 0.75f, 1.0f, 1.25f };
static uint32 conf_MinParagonLevel = 1;
static uint32 conf_MinItemLevel    = 150;
static bool   conf_BlockTrade      = true;
static bool   conf_BlockMail       = true;
static float  conf_CursedChance    = 50.0f;
static float  conf_CursedMultiplier = 1.5f;
static uint32 conf_CursedVisualKit = 5765;
static bool   conf_PassiveSpellEnable  = true;
static float  conf_PassiveSpellChance  = 100.0f;

// ============================================================
// Passive Spell Pool (spec-based)
// ============================================================

struct SpecPoolEntry
{
    uint32 enchantmentId;
    std::string name;
    uint32 weight;
    uint32 minParagonLevel;
    uint32 minItemLevel;
};

// specId -> list of available spells with weights
static std::unordered_map<uint8, std::vector<SpecPoolEntry>> sSpecPools;
static std::mutex sSpecPoolMutex;

// ============================================================
// Stat name lookup for debug logging
// ============================================================

static char const* StatIndexToName(ParagonStatIndex idx)
{
    switch (idx)
    {
        case PSTAT_STAMINA:           return "Stamina";
        case PSTAT_STRENGTH:          return "Strength";
        case PSTAT_AGILITY:           return "Agility";
        case PSTAT_INTELLECT:         return "Intellect";
        case PSTAT_SPIRIT:            return "Spirit";
        case PSTAT_DODGE_RATING:      return "Dodge";
        case PSTAT_PARRY_RATING:      return "Parry";
        case PSTAT_DEFENSE_RATING:    return "Defense";
        case PSTAT_BLOCK_RATING:      return "Block";
        case PSTAT_HIT_RATING:        return "Hit";
        case PSTAT_CRIT_RATING:       return "Crit";
        case PSTAT_HASTE_RATING:      return "Haste";
        case PSTAT_EXPERTISE_RATING:  return "Expertise";
        case PSTAT_ARMOR_PENETRATION: return "ArmorPen";
        case PSTAT_SPELL_POWER:       return "SpellPower";
        case PSTAT_ATTACK_POWER:      return "AttackPower";
        case PSTAT_MANA_REGENERATION: return "ManaRegen";
        default:                      return "Unknown";
    }
}

static char const* RoleToName(ParagonRole role)
{
    switch (role)
    {
        case ROLE_TANK:   return "Tank";
        case ROLE_DPS:    return "DPS";
        case ROLE_HEALER: return "Healer";
        default:          return "Unknown";
    }
}

// ============================================================
// Combat rating pools per role
// ============================================================

static ParagonStatIndex const TANK_COMBAT_RATINGS[] = {
    PSTAT_DODGE_RATING, PSTAT_PARRY_RATING, PSTAT_DEFENSE_RATING,
    PSTAT_BLOCK_RATING, PSTAT_HIT_RATING, PSTAT_EXPERTISE_RATING
};
static constexpr uint8 TANK_COMBAT_RATINGS_COUNT = 6;

static ParagonStatIndex const MELEE_DPS_COMBAT_RATINGS[] = {
    PSTAT_CRIT_RATING, PSTAT_HASTE_RATING, PSTAT_HIT_RATING,
    PSTAT_ARMOR_PENETRATION, PSTAT_EXPERTISE_RATING, PSTAT_ATTACK_POWER
};
static constexpr uint8 MELEE_DPS_COMBAT_RATINGS_COUNT = 6;

static ParagonStatIndex const CASTER_DPS_COMBAT_RATINGS[] = {
    PSTAT_CRIT_RATING, PSTAT_HASTE_RATING, PSTAT_HIT_RATING,
    PSTAT_SPELL_POWER, PSTAT_MANA_REGENERATION
};
static constexpr uint8 CASTER_DPS_COMBAT_RATINGS_COUNT = 5;

static ParagonStatIndex const HEALER_COMBAT_RATINGS[] = {
    PSTAT_CRIT_RATING, PSTAT_HASTE_RATING, PSTAT_SPELL_POWER,
    PSTAT_MANA_REGENERATION
};
static constexpr uint8 HEALER_COMBAT_RATINGS_COUNT = 4;

// ============================================================
// Helpers
// ============================================================

static uint32 GetEnchantmentId(ParagonStatIndex statIndex, uint32 amount)
{
    if (amount > PARAGON_ENCHANT_MAX_AMOUNT)
        amount = PARAGON_ENCHANT_MAX_AMOUNT;
    if (amount < 1)
        amount = 1;
    return PARAGON_ENCHANT_BASE_ID + static_cast<uint32>(statIndex) * PARAGON_ENCHANT_STAT_STRIDE + amount;
}

static bool IsParagonEnchantment(uint32 enchantId)
{
    // Stat enchantments (900001-917000)
    if (enchantId > PARAGON_ENCHANT_BASE_ID &&
        enchantId <= PARAGON_ENCHANT_BASE_ID + (PARAGON_ENCHANT_MAX_STAT_INDEX + 1) * PARAGON_ENCHANT_STAT_STRIDE)
        return true;

    // Cursed marker (920001)
    if (enchantId == PARAGON_ENCHANT_CURSED_ID)
        return true;

    // Passive spell enchantments (950001-950099)
    if (enchantId >= PARAGON_PASSIVE_ENCHANT_MIN && enchantId <= PARAGON_PASSIVE_ENCHANT_MAX)
        return true;

    return false;
}

static bool ItemHasParagonEnchantment(Item* item)
{
    // Check if any of our 5 slots have a paragon enchantment
    for (uint8 slot = PARAGON_SLOT_STAMINA; slot <= PARAGON_SLOT_TALENT_SPELL; ++slot)
    {
        uint32 enchId = item->GetEnchantmentId(EnchantmentSlot(slot));
        if (IsParagonEnchantment(enchId))
            return true;
    }
    return false;
}

static uint32 GetPlayerParagonLevel(Player* player)
{
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARAGON_LEVEL);
    stmt->SetData(0, player->GetSession()->GetAccountId());
    PreparedQueryResult result = CharacterDatabase.Query(stmt);

    if (!result)
    {
        LOG_DEBUG("module", "ParagonItemGen: No paragon level found for account {}",
            player->GetSession()->GetAccountId());
        return 0;
    }

    uint32 level = (*result)[0].Get<uint32>();
    LOG_DEBUG("module", "ParagonItemGen: Player {} (account {}) has paragon level {}",
        player->GetName(), player->GetSession()->GetAccountId(), level);
    return level;
}

struct PlayerRoleInfo
{
    ParagonRole role;
    ParagonStatIndex mainStat;
    bool found;
};

static PlayerRoleInfo GetPlayerRoleInfo(Player* player)
{
    PlayerRoleInfo info = { ROLE_DPS, PSTAT_STRENGTH, false };

    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARAGON_ROLE);
    stmt->SetData(0, player->GetGUID().GetCounter());
    PreparedQueryResult result = CharacterDatabase.Query(stmt);

    if (!result)
    {
        LOG_DEBUG("module", "ParagonItemGen: No role info found for character {} (guid {})",
            player->GetName(), player->GetGUID().GetCounter());
        return info;
    }

    info.role = static_cast<ParagonRole>((*result)[0].Get<uint8>());
    info.found = true;

    // Convert ITEM_MOD value back to ParagonStatIndex
    uint8 modVal = (*result)[1].Get<uint8>();
    switch (modVal)
    {
        case 4:  info.mainStat = PSTAT_STRENGTH;  break;
        case 3:  info.mainStat = PSTAT_AGILITY;   break;
        case 5:  info.mainStat = PSTAT_INTELLECT;  break;
        case 6:  info.mainStat = PSTAT_SPIRIT;     break;
        default: info.mainStat = PSTAT_STRENGTH;   break;
    }

    if (info.role >= ROLE_MAX)
        info.role = ROLE_DPS;

    LOG_DEBUG("module", "ParagonItemGen: Player {} role={} mainStat={} (modVal={})",
        player->GetName(), RoleToName(info.role), StatIndexToName(info.mainStat), modVal);
    return info;
}

static ParagonStatIndex const* GetCombatRatingPool(ParagonRole role,
    ParagonStatIndex mainStat, uint8& outCount)
{
    switch (role)
    {
        case ROLE_TANK:
            outCount = TANK_COMBAT_RATINGS_COUNT;
            return TANK_COMBAT_RATINGS;
        case ROLE_DPS:
            // Split by main stat: Int/Spi = caster, Str/Agi = melee
            if (mainStat == PSTAT_INTELLECT || mainStat == PSTAT_SPIRIT)
            {
                outCount = CASTER_DPS_COMBAT_RATINGS_COUNT;
                return CASTER_DPS_COMBAT_RATINGS;
            }
            outCount = MELEE_DPS_COMBAT_RATINGS_COUNT;
            return MELEE_DPS_COMBAT_RATINGS;
        case ROLE_HEALER:
            outCount = HEALER_COMBAT_RATINGS_COUNT;
            return HEALER_COMBAT_RATINGS;
        default:
            outCount = MELEE_DPS_COMBAT_RATINGS_COUNT;
            return MELEE_DPS_COMBAT_RATINGS;
    }
}

static void PickTwoRandomRatings(ParagonRole role, ParagonStatIndex mainStat,
    ParagonStatIndex& out1, ParagonStatIndex& out2)
{
    uint8 poolSize = 0;
    ParagonStatIndex const* pool = GetCombatRatingPool(role, mainStat, poolSize);

    // Thread-local RNG
    static thread_local std::mt19937 rng(std::random_device{}());

    std::uniform_int_distribution<int> dist1(0, poolSize - 1);
    uint8 idx1 = static_cast<uint8>(dist1(rng));
    out1 = pool[idx1];

    // Pick second, different from first
    if (poolSize <= 1)
    {
        out2 = out1;
        return;
    }

    uint8 idx2;
    do {
        idx2 = dist1(rng);
    } while (idx2 == idx1);
    out2 = pool[idx2];
}

// ============================================================
// Passive Spell Pool: Load and Roll
// ============================================================

static void LoadPassiveSpellPool()
{
    std::lock_guard<std::mutex> lock(sSpecPoolMutex);
    sSpecPools.clear();

    // JOIN the assignment table with the pool catalog to get per-spec entries
    WorldDatabasePreparedStatement* stmt = WorldDatabase.GetPreparedStatement(WORLD_SEL_PARAGON_SPEC_SPELL_ASSIGN);
    PreparedQueryResult result = WorldDatabase.Query(stmt);

    if (!result)
    {
        LOG_WARN("module", "ParagonItemGen: No spec-spell assignments found (paragon_spec_spell_assign empty or no matching pool entries)!");
        return;
    }

    uint32 totalEntries = 0;
    do
    {
        Field* fields = result->Fetch();
        uint8  specId        = fields[0].Get<uint8>();
        uint32 enchantmentId = fields[1].Get<uint32>();
        std::string name     = fields[2].Get<std::string>();
        uint32 weight        = fields[3].Get<uint32>();
        uint32 minPLevel     = fields[4].Get<uint32>();
        uint32 minILevel     = fields[5].Get<uint32>();

        if (specId == 0 || specId >= SPEC_MAX)
        {
            LOG_ERROR("module", "ParagonItemGen: Invalid specId {} in paragon_spec_spell_assign, skipping.", specId);
            continue;
        }

        if (!sSpellItemEnchantmentStore.LookupEntry(enchantmentId))
        {
            LOG_ERROR("module", "ParagonItemGen: Enchantment {} not found in DBC for spec {}, skipping.",
                enchantmentId, specId);
            continue;
        }

        sSpecPools[specId].push_back({ enchantmentId, name, weight, minPLevel, minILevel });
        ++totalEntries;
    } while (result->NextRow());

    LOG_INFO("module", "ParagonItemGen: Loaded {} spec-spell assignments across {} specs.",
        totalEntries, sSpecPools.size());
}

static ParagonSpec GetPlayerSpec(Player* player)
{
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARAGON_SPEC);
    stmt->SetData(0, player->GetGUID().GetCounter());
    PreparedQueryResult result = CharacterDatabase.Query(stmt);

    if (!result)
        return SPEC_NONE;

    uint8 specId = (*result)[0].Get<uint8>();
    if (specId >= SPEC_MAX)
        return SPEC_NONE;

    return static_cast<ParagonSpec>(specId);
}

// Returns 0 if no eligible passive spell found
static uint32 RollPassiveSpellEnchantment(ParagonSpec spec, uint32 paragonLevel, uint32 itemLevel)
{
    if (!conf_PassiveSpellEnable || spec == SPEC_NONE)
        return 0;

    // Check if this item gets a passive spell at all
    if (conf_PassiveSpellChance < 100.0f)
    {
        static thread_local std::mt19937 rng(std::random_device{}());
        std::uniform_real_distribution<float> dist(0.0f, 100.0f);
        if (dist(rng) >= conf_PassiveSpellChance)
            return 0;
    }

    // Build eligible list from this spec's pool
    std::vector<std::pair<uint32, uint32>> eligible; // enchantmentId, weight
    uint32 totalWeight = 0;

    {
        std::lock_guard<std::mutex> lock(sSpecPoolMutex);
        auto it = sSpecPools.find(static_cast<uint8>(spec));
        if (it == sSpecPools.end())
        {
            LOG_DEBUG("module", "ParagonItemGen: No spell pool for spec {} ({})",
                ParagonSpecName(spec), static_cast<uint8>(spec));
            return 0;
        }

        for (auto const& entry : it->second)
        {
            if (paragonLevel < entry.minParagonLevel)
                continue;
            if (itemLevel < entry.minItemLevel)
                continue;

            eligible.push_back({ entry.enchantmentId, entry.weight });
            totalWeight += entry.weight;
        }
    }

    if (eligible.empty() || totalWeight == 0)
    {
        LOG_DEBUG("module", "ParagonItemGen: No eligible passive spells for spec={}, pLevel={}, iLevel={}",
            ParagonSpecName(spec), paragonLevel, itemLevel);
        return 0;
    }

    // Weighted random selection
    static thread_local std::mt19937 rng(std::random_device{}());
    std::uniform_int_distribution<uint32> dist(1, totalWeight);
    uint32 roll = dist(rng);

    uint32 cumulative = 0;
    for (auto const& [enchId, weight] : eligible)
    {
        cumulative += weight;
        if (roll <= cumulative)
        {
            LOG_DEBUG("module", "ParagonItemGen: Rolled passive spell enchantment {} for spec {} (roll={}/{})",
                enchId, ParagonSpecName(spec), roll, totalWeight);
            return enchId;
        }
    }

    return eligible.back().first;
}

static bool IsEligibleItem(Item* item)
{
    if (!item)
        return false;

    ItemTemplate const* proto = item->GetTemplate();
    if (!proto)
        return false;

    if (proto->Class != ITEM_CLASS_WEAPON && proto->Class != ITEM_CLASS_ARMOR)
    {
        LOG_DEBUG("module", "ParagonItemGen: Item {} (entry {}) rejected - class {} is not weapon/armor",
            item->GetGUID().GetCounter(), proto->ItemId, proto->Class);
        return false;
    }

    if (proto->Quality < ITEM_QUALITY_UNCOMMON || proto->Quality > ITEM_QUALITY_LEGENDARY)
    {
        LOG_DEBUG("module", "ParagonItemGen: Item {} (entry {}) rejected - quality {} not in range [{}, {}]",
            item->GetGUID().GetCounter(), proto->ItemId, proto->Quality,
            ITEM_QUALITY_UNCOMMON, ITEM_QUALITY_LEGENDARY);
        return false;
    }

    if (proto->ItemLevel < conf_MinItemLevel)
    {
        LOG_DEBUG("module", "ParagonItemGen: Item {} (entry {}) rejected - itemLevel {} < minItemLevel {}",
            item->GetGUID().GetCounter(), proto->ItemId, proto->ItemLevel, conf_MinItemLevel);
        return false;
    }

    LOG_DEBUG("module", "ParagonItemGen: Item {} (entry {}) is eligible - class={}, quality={}, ilvl={}",
        item->GetGUID().GetCounter(), proto->ItemId, proto->Class, proto->Quality, proto->ItemLevel);
    return true;
}

static uint32 CalculateStatAmount(uint32 paragonLevel, uint8 quality)
{
    if (quality > 5)
        quality = 5;

    float amount = static_cast<float>(paragonLevel) * conf_ScalingFactor * conf_QualityMult[quality];
    uint32 result = static_cast<uint32>(std::ceil(amount));

    if (result > PARAGON_ENCHANT_MAX_AMOUNT)
        result = PARAGON_ENCHANT_MAX_AMOUNT;
    if (result < 1)
        result = 1;

    LOG_DEBUG("module", "ParagonItemGen: CalculateStatAmount: paragonLevel={}, quality={}, scalingFactor={}, qualityMult={}, result={}",
        paragonLevel, quality, conf_ScalingFactor, conf_QualityMult[quality], result);
    return result;
}

static uint32 RollStatAmount(uint32 maxAmount)
{
    if (maxAmount <= 1)
        return 1;

    static thread_local std::mt19937 rng(std::random_device{}());
    std::uniform_int_distribution<int> dist(1, static_cast<int>(maxAmount));
    return static_cast<uint32>(dist(rng));
}

static bool RollCursed()
{
    if (conf_CursedChance <= 0.0f)
        return false;

    static thread_local std::mt19937 rng(std::random_device{}());
    std::uniform_real_distribution<float> dist(0.0f, 100.0f);
    return dist(rng) < conf_CursedChance;
}

static void ApplySlotEnchantment(Player* player, Item* item, uint8 slot, uint32 enchantId)
{
    if (!sSpellItemEnchantmentStore.LookupEntry(enchantId))
    {
        LOG_ERROR("module", "ParagonItemGen: Enchantment ID {} not found in DBC store! "
            "Ensure spellitemenchantment_dbc entries are loaded.", enchantId);
        return;
    }

    if (item->IsEquipped())
        player->ApplyEnchantment(item, EnchantmentSlot(slot), false);

    item->SetEnchantment(EnchantmentSlot(slot), enchantId, 0, 0);

    if (item->IsEquipped())
        player->ApplyEnchantment(item, EnchantmentSlot(slot), true);

    LOG_DEBUG("module", "ParagonItemGen: Applied enchantment {} to slot {} on item {} (entry {})",
        enchantId, slot, item->GetGUID().GetCounter(), item->GetEntry());
}

// ============================================================
// Core: Apply paragon enchantments to an item
// ============================================================

static void ApplyParagonEnchantment(Player* player, Item* item)
{
    if (!conf_Enable || !player || !item)
    {
        LOG_DEBUG("module", "ParagonItemGen: ApplyParagonEnchantment early exit - enable={}, player={}, item={}",
            conf_Enable, player != nullptr, item != nullptr);
        return;
    }

    LOG_DEBUG("module", "ParagonItemGen: Attempting enchantment for player {} on item entry {} (guid {})",
        player->GetName(), item->GetEntry(), item->GetGUID().GetCounter());

    if (!IsEligibleItem(item))
        return;

    if (ItemHasParagonEnchantment(item))
    {
        LOG_DEBUG("module", "ParagonItemGen: Item {} already has paragon enchantment, skipping",
            item->GetGUID().GetCounter());
        return;
    }

    uint32 paragonLevel = GetPlayerParagonLevel(player);
    if (paragonLevel < conf_MinParagonLevel)
    {
        LOG_DEBUG("module", "ParagonItemGen: Player {} paragon level {} < minimum {}, skipping",
            player->GetName(), paragonLevel, conf_MinParagonLevel);
        return;
    }

    PlayerRoleInfo roleInfo = GetPlayerRoleInfo(player);
    if (!roleInfo.found)
    {
        LOG_DEBUG("module", "ParagonItemGen: Player {} has no role set, skipping",
            player->GetName());
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cffff0000[Paragon]|r Set your role first with: .paragon role tank|dps|healer");
        return;
    }

    uint32 maxStatAmount = CalculateStatAmount(paragonLevel, item->GetTemplate()->Quality);

    // Check for cursed roll (1% chance by default)
    bool isCursed = RollCursed();

    // Slot 2 (9) & Slot 3 (10): Random combat ratings from role pool
    ParagonStatIndex cr1, cr2;
    PickTwoRandomRatings(roleInfo.role, roleInfo.mainStat, cr1, cr2);

    uint32 staAmount, mainAmount, cr1Amount, cr2Amount;

    if (isCursed)
    {
        // Cursed: all stats at 150% of max (capped at PARAGON_ENCHANT_MAX_AMOUNT)
        uint32 cursedAmount = static_cast<uint32>(std::ceil(
            static_cast<float>(maxStatAmount) * conf_CursedMultiplier));
        if (cursedAmount > PARAGON_ENCHANT_MAX_AMOUNT)
            cursedAmount = PARAGON_ENCHANT_MAX_AMOUNT;
        if (cursedAmount < 1)
            cursedAmount = 1;

        staAmount = cursedAmount;
        mainAmount = cursedAmount;
        cr1Amount = cursedAmount;
        cr2Amount = cursedAmount;

        LOG_INFO("module", "ParagonItemGen: CURSED roll for player {} on item {} (entry {})! "
            "All stats set to {} ({}% of max {})",
            player->GetName(), item->GetGUID().GetCounter(), item->GetEntry(),
            cursedAmount, static_cast<int>(conf_CursedMultiplier * 100), maxStatAmount);
    }
    else
    {
        // Normal: each stat rolls randomly from 1 to max
        staAmount = RollStatAmount(maxStatAmount);
        mainAmount = RollStatAmount(maxStatAmount);
        cr1Amount = RollStatAmount(maxStatAmount);
        cr2Amount = RollStatAmount(maxStatAmount);

        LOG_DEBUG("module", "ParagonItemGen: Random rolls for player {} - "
            "Sta={}, Main={}, CR1={}, CR2={} (max={})",
            player->GetName(), staAmount, mainAmount, cr1Amount, cr2Amount, maxStatAmount);
    }

    // Check if item has random properties ("of the Bear" etc.) that will be overwritten
    if (item->GetItemRandomPropertyId() != 0)
    {
        LOG_DEBUG("module", "ParagonItemGen: Item {} (entry {}) has random property ID {}, "
            "paragon enchantments will override PROP_ENCHANTMENT slots",
            item->GetGUID().GetCounter(), item->GetEntry(), item->GetItemRandomPropertyId());
    }

    // Slot 0 (7): Stamina - always
    uint32 staEnchId = GetEnchantmentId(PSTAT_STAMINA, staAmount);
    LOG_DEBUG("module", "ParagonItemGen: Slot {} (Stamina): enchantId={}, amount={}",
        PARAGON_SLOT_STAMINA, staEnchId, staAmount);
    ApplySlotEnchantment(player, item, PARAGON_SLOT_STAMINA, staEnchId);

    // Slot 1 (8): Main stat - player choice
    uint32 mainEnchId = GetEnchantmentId(roleInfo.mainStat, mainAmount);
    LOG_DEBUG("module", "ParagonItemGen: Slot {} (MainStat={}): enchantId={}, amount={}",
        PARAGON_SLOT_MAINSTAT, StatIndexToName(roleInfo.mainStat), mainEnchId, mainAmount);
    ApplySlotEnchantment(player, item, PARAGON_SLOT_MAINSTAT, mainEnchId);

    // Slot 2 (9) & Slot 3 (10): Random combat ratings
    uint32 cr1EnchId = GetEnchantmentId(cr1, cr1Amount);
    uint32 cr2EnchId = GetEnchantmentId(cr2, cr2Amount);
    LOG_DEBUG("module", "ParagonItemGen: Slot {} (CR1={}): enchantId={}, Slot {} (CR2={}): enchantId={}",
        PARAGON_SLOT_COMBAT_RATING1, StatIndexToName(cr1), cr1EnchId,
        PARAGON_SLOT_COMBAT_RATING2, StatIndexToName(cr2), cr2EnchId);

    ApplySlotEnchantment(player, item, PARAGON_SLOT_COMBAT_RATING1, cr1EnchId);
    ApplySlotEnchantment(player, item, PARAGON_SLOT_COMBAT_RATING2, cr2EnchId);

    // Slot 4 (11): Passive spell effect (cursed only) OR cursed marker
    uint32 passiveEnchantId = 0;
    ParagonSpec playerSpec = GetPlayerSpec(player);

    if (isCursed)
    {
        // Cursed items: try to roll a passive spell for slot 11
        passiveEnchantId = RollPassiveSpellEnchantment(
            playerSpec, paragonLevel, item->GetTemplate()->ItemLevel);

        if (passiveEnchantId)
        {
            // Cursed with passive: slot 11 gets the passive spell enchantment
            ApplySlotEnchantment(player, item, PARAGON_SLOT_TALENT_SPELL, passiveEnchantId);
            LOG_DEBUG("module", "ParagonItemGen: Applied passive spell enchantment {} to cursed item {} for player {}",
                passiveEnchantId, item->GetGUID().GetCounter(), player->GetName());
        }
        else
        {
            // Cursed without passive: slot 11 gets the cursed marker label
            ApplySlotEnchantment(player, item, PARAGON_SLOT_TALENT_SPELL, PARAGON_ENCHANT_CURSED_ID);
        }

        if (!item->IsSoulBound())
            item->SetBinding(true);

        // Play shadow visual on the player
        player->SendPlaySpellVisual(conf_CursedVisualKit);
    }
    // Normal items: no passive spell, slot 11 left empty

    // Use cursed amount for DB tracking when cursed, max otherwise
    uint32 dbStatAmount = isCursed ? staAmount : maxStatAmount;

    // Track in DB for trade restrictions
    CharacterDatabasePreparedStatement* trackStmt = CharacterDatabase.GetPreparedStatement(CHAR_REP_PARAGON_ITEM);
    trackStmt->SetData(0, item->GetGUID().GetCounter());
    trackStmt->SetData(1, paragonLevel);
    trackStmt->SetData(2, static_cast<uint8>(roleInfo.role));
    trackStmt->SetData(3, static_cast<uint8>(roleInfo.mainStat));
    trackStmt->SetData(4, static_cast<uint8>(cr1));
    trackStmt->SetData(5, static_cast<uint8>(cr2));
    trackStmt->SetData(6, dbStatAmount);
    trackStmt->SetData(7, isCursed ? static_cast<uint8>(1) : static_cast<uint8>(0));
    trackStmt->SetData(8, passiveEnchantId);
    CharacterDatabase.Execute(trackStmt);

    LOG_INFO("module", "ParagonItemGen: Enhanced item {} (entry {}) for player {} - "
        "PLevel={}, Role={}, MainStat={}, CR1={}, CR2={}, Sta={}, Main={}, CR1Amt={}, CR2Amt={}, Cursed={}",
        item->GetGUID().GetCounter(), item->GetEntry(), player->GetName(),
        paragonLevel, RoleToName(roleInfo.role), StatIndexToName(roleInfo.mainStat),
        StatIndexToName(cr1), StatIndexToName(cr2),
        staAmount, mainAmount, cr1Amount, cr2Amount, isCursed);

    if (isCursed && passiveEnchantId)
    {
        // Find the name of the passive spell from the spec pool
        std::string passiveName = "Unknown";
        {
            std::lock_guard<std::mutex> lock(sSpecPoolMutex);
            auto it = sSpecPools.find(static_cast<uint8>(playerSpec));
            if (it != sSpecPools.end())
            {
                for (auto const& entry : it->second)
                {
                    if (entry.enchantmentId == passiveEnchantId)
                    {
                        passiveName = entry.name;
                        break;
                    }
                }
            }
        }
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cff8b00ff[Paragon]|r |cffff0000CURSED!|r Item enhanced with +{} stats ({}%% of max, Paragon Level {}). Passive: |cffa335ee{}|r",
            staAmount, static_cast<int>(conf_CursedMultiplier * 100), paragonLevel, passiveName);
    }
    else if (isCursed)
    {
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cff8b00ff[Paragon]|r |cffff0000CURSED!|r Item enhanced with +{} stats ({}%% of max, Paragon Level {}).",
            staAmount, static_cast<int>(conf_CursedMultiplier * 100), paragonLevel);
    }
    else
    {
        std::string specHint = "";
        if (playerSpec == SPEC_NONE)
            specHint = " | |cffff8000Set your spec at the Paragon Artificer NPC for passive spells on cursed items!|r";

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cff00ff00[Paragon]|r Item enhanced (Paragon Level {}). Sta: +{}, Main: +{}, CR1: +{}, CR2: +{}{}",
            paragonLevel, staAmount, mainAmount, cr1Amount, cr2Amount, specHint);
    }

    if (item->GetItemRandomPropertyId() != 0)
    {
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cff00ff00[Paragon]|r Random properties on this item have been replaced by Paragon enchantments.");
    }
}

// ============================================================
// PlayerScript: Item acquisition and trade restriction hooks
// ============================================================

class ParagonItemGenPlayer : public PlayerScript
{
public:
    ParagonItemGenPlayer() : PlayerScript("ParagonItemGenPlayer",
    {
        PLAYERHOOK_ON_LOOT_ITEM,
        PLAYERHOOK_ON_CREATE_ITEM,
        PLAYERHOOK_ON_QUEST_REWARD_ITEM,
        PLAYERHOOK_ON_AFTER_STORE_OR_EQUIP_NEW_ITEM,
        PLAYERHOOK_CAN_SET_TRADE_ITEM,
        PLAYERHOOK_CAN_SEND_MAIL
    }) { }

    void OnPlayerLootItem(Player* player, Item* item, uint32 /*count*/, ObjectGuid /*lootguid*/) override
    {
        LOG_DEBUG("module", "ParagonItemGen: [OnLoot] Player {} looted item entry {} (conf_OnLoot={})",
            player->GetName(), item ? item->GetEntry() : 0, conf_OnLoot);
        if (conf_OnLoot)
            ApplyParagonEnchantment(player, item);
    }

    void OnPlayerCreateItem(Player* player, Item* item, uint32 /*count*/) override
    {
        LOG_DEBUG("module", "ParagonItemGen: [OnCreate] Player {} created item entry {} (conf_OnCreate={})",
            player->GetName(), item ? item->GetEntry() : 0, conf_OnCreate);
        if (conf_OnCreate)
            ApplyParagonEnchantment(player, item);
    }

    void OnPlayerQuestRewardItem(Player* player, Item* item, uint32 /*count*/) override
    {
        LOG_DEBUG("module", "ParagonItemGen: [OnQuest] Player {} quest reward item entry {} (conf_OnQuest={})",
            player->GetName(), item ? item->GetEntry() : 0, conf_OnQuest);
        if (conf_OnQuest)
            ApplyParagonEnchantment(player, item);
    }

    void OnPlayerAfterStoreOrEquipNewItem(Player* player, uint32 /*vendorslot*/, Item* item,
        uint8 /*count*/, uint8 /*bag*/, uint8 /*slot*/, ItemTemplate const* /*pProto*/,
        Creature* /*pVendor*/, VendorItem const* /*crItem*/, bool /*bStore*/) override
    {
        LOG_DEBUG("module", "ParagonItemGen: [OnVendor] Player {} vendor item entry {} (conf_OnVendor={})",
            player->GetName(), item ? item->GetEntry() : 0, conf_OnVendor);
        if (conf_OnVendor)
            ApplyParagonEnchantment(player, item);
    }

    // Trade restriction
    bool OnPlayerCanSetTradeItem(Player* player, Item* tradedItem, uint8 /*tradeSlot*/) override
    {
        if (!conf_BlockTrade || !tradedItem)
            return true;

        if (!ItemHasParagonEnchantment(tradedItem))
            return true;

        CharacterDatabasePreparedStatement* itemStmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARAGON_ITEM_LEVEL);
        itemStmt->SetData(0, tradedItem->GetGUID().GetCounter());
        PreparedQueryResult result = CharacterDatabase.Query(itemStmt);

        if (!result)
            return true;

        uint32 itemParagonLevel = (*result)[0].Get<uint32>();

        Player* tradeTarget = player->GetTrader();
        if (!tradeTarget)
            return true;

        uint32 targetParagonLevel = GetPlayerParagonLevel(tradeTarget);

        LOG_DEBUG("module", "ParagonItemGen: [Trade] Player {} -> {} item {} (itemPLevel={}, targetPLevel={})",
            player->GetName(), tradeTarget->GetName(), tradedItem->GetEntry(),
            itemParagonLevel, targetParagonLevel);

        if (targetParagonLevel < itemParagonLevel)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cffff0000[Paragon]|r Cannot trade - recipient Paragon Level ({}) < item Paragon Level ({}).",
                targetParagonLevel, itemParagonLevel);
            return false;
        }

        return true;
    }

    // Mail restriction
    bool OnPlayerCanSendMail(Player* player, ObjectGuid receiverGuid, ObjectGuid /*mailbox*/,
        std::string& /*subject*/, std::string& /*body*/, uint32 /*money*/, uint32 /*COD*/,
        Item* item) override
    {
        if (!conf_BlockMail || !item)
            return true;

        if (!ItemHasParagonEnchantment(item))
            return true;

        CharacterDatabasePreparedStatement* itemStmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARAGON_ITEM_LEVEL);
        itemStmt->SetData(0, item->GetGUID().GetCounter());
        PreparedQueryResult itemResult = CharacterDatabase.Query(itemStmt);

        if (!itemResult)
            return true;

        uint32 itemParagonLevel = (*itemResult)[0].Get<uint32>();

        CharacterDatabasePreparedStatement* charStmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARAGON_LEVEL_BY_CHAR);
        charStmt->SetData(0, receiverGuid.GetCounter());
        PreparedQueryResult charResult = CharacterDatabase.Query(charStmt);

        uint32 receiverParagonLevel = 0;
        if (charResult)
            receiverParagonLevel = (*charResult)[0].Get<uint32>();

        LOG_DEBUG("module", "ParagonItemGen: [Mail] Player {} -> guid {} item {} (itemPLevel={}, receiverPLevel={})",
            player->GetName(), receiverGuid.GetCounter(), item->GetEntry(),
            itemParagonLevel, receiverParagonLevel);

        if (receiverParagonLevel < itemParagonLevel)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cffff0000[Paragon]|r Cannot mail - recipient Paragon Level ({}) < item Paragon Level ({}).",
                receiverParagonLevel, itemParagonLevel);
            return false;
        }

        return true;
    }

    // TODO: AH restriction - no CanListAuction hook in AzerothCore
};

// ============================================================
// WorldScript: Configuration
// ============================================================

class ParagonItemGenWorld : public WorldScript
{
public:
    ParagonItemGenWorld() : WorldScript("ParagonItemGenWorld",
    {
        WORLDHOOK_ON_AFTER_CONFIG_LOAD,
        WORLDHOOK_ON_STARTUP
    }) { }

    void OnStartup() override
    {
        LoadPassiveSpellPool();
    }

    void OnAfterConfigLoad(bool reload) override
    {
        // Reload the passive spell pool on config reload
        if (reload)
            LoadPassiveSpellPool();

        conf_Enable          = sConfigMgr->GetOption<bool>("ParagonItemGen.Enable", true);
        conf_OnLoot          = sConfigMgr->GetOption<bool>("ParagonItemGen.OnLoot", true);
        conf_OnCreate        = sConfigMgr->GetOption<bool>("ParagonItemGen.OnCreate", true);
        conf_OnQuest         = sConfigMgr->GetOption<bool>("ParagonItemGen.OnQuest", true);
        conf_OnVendor        = sConfigMgr->GetOption<bool>("ParagonItemGen.OnVendor", true);
        conf_ScalingFactor   = sConfigMgr->GetOption<float>("ParagonItemGen.ScalingFactor", 0.5f);
        conf_MinParagonLevel = sConfigMgr->GetOption<uint32>("ParagonItemGen.MinParagonLevel", 1);
        conf_MinItemLevel    = sConfigMgr->GetOption<uint32>("ParagonItemGen.MinItemLevel", 150);
        conf_BlockTrade      = sConfigMgr->GetOption<bool>("ParagonItemGen.BlockTrade", true);
        conf_BlockMail       = sConfigMgr->GetOption<bool>("ParagonItemGen.BlockMail", true);

        conf_QualityMult[2]  = sConfigMgr->GetOption<float>("ParagonItemGen.QualityMult.Uncommon", 0.5f);
        conf_QualityMult[3]  = sConfigMgr->GetOption<float>("ParagonItemGen.QualityMult.Rare", 0.75f);
        conf_QualityMult[4]  = sConfigMgr->GetOption<float>("ParagonItemGen.QualityMult.Epic", 1.0f);
        conf_QualityMult[5]  = sConfigMgr->GetOption<float>("ParagonItemGen.QualityMult.Legendary", 1.25f);

        conf_CursedChance     = sConfigMgr->GetOption<float>("ParagonItemGen.CursedChance", 1.0f);
        conf_CursedMultiplier = sConfigMgr->GetOption<float>("ParagonItemGen.CursedMultiplier", 1.5f);
        conf_CursedVisualKit  = sConfigMgr->GetOption<uint32>("ParagonItemGen.CursedVisualKit", 5765);

        conf_PassiveSpellEnable = sConfigMgr->GetOption<bool>("ParagonItemGen.PassiveSpell.Enable", true);
        conf_PassiveSpellChance = sConfigMgr->GetOption<float>("ParagonItemGen.PassiveSpell.Chance", 100.0f);

        LOG_INFO("module", "ParagonItemGen: Config loaded - Enable={}, OnLoot={}, OnCreate={}, OnQuest={}, OnVendor={}, "
            "Scaling={}, MinPLevel={}, MinIlvl={}, BlockTrade={}, BlockMail={}, "
            "QMult=[Uncommon={}, Rare={}, Epic={}, Legendary={}], "
            "CursedChance={}%, CursedMult={}x, CursedVisual={}, "
            "PassiveSpell={}, PassiveChance={}%",
            conf_Enable, conf_OnLoot, conf_OnCreate, conf_OnQuest, conf_OnVendor,
            conf_ScalingFactor, conf_MinParagonLevel, conf_MinItemLevel, conf_BlockTrade, conf_BlockMail,
            conf_QualityMult[2], conf_QualityMult[3], conf_QualityMult[4], conf_QualityMult[5],
            conf_CursedChance, conf_CursedMultiplier, conf_CursedVisualKit,
            conf_PassiveSpellEnable, conf_PassiveSpellChance);
    }
};

void AddParagonItemGenScripts()
{
    new ParagonItemGenPlayer();
    new ParagonItemGenWorld();
}
