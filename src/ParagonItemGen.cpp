/*
 * Paragon Item Scaling Module v2
 *
 * Applies 4 enchantment slots to items based on paragon level:
 *   Slot 7:  Stamina (always)
 *   Slot 8:  Main stat (player-chosen: Str/Agi/Int/Spi)
 *   Slot 9:  Random combat rating (role-dependent pool)
 *   Slot 10: Random combat rating (role-dependent pool, no duplicate)
 *   Slot 11: Talent spell (TODO: placeholder for custom spells)
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
#include "DBCStores.h"
#include "ObjectGuid.h"
#include <random>

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

// ============================================================
// Combat rating pools per role
// ============================================================

static ParagonStatIndex const TANK_COMBAT_RATINGS[] = {
    PSTAT_DODGE_RATING, PSTAT_PARRY_RATING, PSTAT_DEFENSE_RATING,
    PSTAT_BLOCK_RATING, PSTAT_HIT_RATING, PSTAT_EXPERTISE_RATING
};
static constexpr uint8 TANK_COMBAT_RATINGS_COUNT = 6;

static ParagonStatIndex const DPS_COMBAT_RATINGS[] = {
    PSTAT_CRIT_RATING, PSTAT_HASTE_RATING, PSTAT_HIT_RATING,
    PSTAT_ARMOR_PENETRATION, PSTAT_EXPERTISE_RATING, PSTAT_ATTACK_POWER,
    PSTAT_SPELL_POWER
};
static constexpr uint8 DPS_COMBAT_RATINGS_COUNT = 7;

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
    return enchantId > PARAGON_ENCHANT_BASE_ID &&
           enchantId <= PARAGON_ENCHANT_BASE_ID + (PARAGON_ENCHANT_MAX_STAT_INDEX + 1) * PARAGON_ENCHANT_STAT_STRIDE;
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
    QueryResult result = CharacterDatabase.Query(
        "SELECT level FROM character_paragon WHERE accountID = {}",
        player->GetSession()->GetAccountId());

    if (!result)
        return 0;

    return (*result)[0].Get<uint32>();
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

    QueryResult result = CharacterDatabase.Query(
        "SELECT role, mainStat FROM character_paragon_role WHERE characterID = {}",
        player->GetGUID().GetCounter());

    if (!result)
        return info;

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

    return info;
}

static ParagonStatIndex const* GetCombatRatingPool(ParagonRole role, uint8& outCount)
{
    switch (role)
    {
        case ROLE_TANK:
            outCount = TANK_COMBAT_RATINGS_COUNT;
            return TANK_COMBAT_RATINGS;
        case ROLE_DPS:
            outCount = DPS_COMBAT_RATINGS_COUNT;
            return DPS_COMBAT_RATINGS;
        case ROLE_HEALER:
            outCount = HEALER_COMBAT_RATINGS_COUNT;
            return HEALER_COMBAT_RATINGS;
        default:
            outCount = DPS_COMBAT_RATINGS_COUNT;
            return DPS_COMBAT_RATINGS;
    }
}

static void PickTwoRandomRatings(ParagonRole role, ParagonStatIndex& out1, ParagonStatIndex& out2)
{
    uint8 poolSize = 0;
    ParagonStatIndex const* pool = GetCombatRatingPool(role, poolSize);

    // Thread-local RNG
    static thread_local std::mt19937 rng(std::random_device{}());

    std::uniform_int_distribution<uint8> dist1(0, poolSize - 1);
    uint8 idx1 = dist1(rng);
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

static bool IsEligibleItem(Item* item)
{
    if (!item)
        return false;

    ItemTemplate const* proto = item->GetTemplate();
    if (!proto)
        return false;

    if (proto->Class != ITEM_CLASS_WEAPON && proto->Class != ITEM_CLASS_ARMOR)
        return false;

    if (proto->Quality < ITEM_QUALITY_UNCOMMON || proto->Quality > ITEM_QUALITY_LEGENDARY)
        return false;

    if (proto->ItemLevel < conf_MinItemLevel)
        return false;

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

    return result;
}

static void ApplySlotEnchantment(Player* player, Item* item, uint8 slot, uint32 enchantId)
{
    if (!sSpellItemEnchantmentStore.LookupEntry(enchantId))
    {
        LOG_ERROR("module", "ParagonItemGen: Enchantment ID {} not found", enchantId);
        return;
    }

    if (item->IsEquipped())
        player->ApplyEnchantment(item, EnchantmentSlot(slot), false);

    item->SetEnchantment(EnchantmentSlot(slot), enchantId, 0, 0);

    if (item->IsEquipped())
        player->ApplyEnchantment(item, EnchantmentSlot(slot), true);
}

// ============================================================
// Core: Apply paragon enchantments to an item
// ============================================================

static void ApplyParagonEnchantment(Player* player, Item* item)
{
    if (!conf_Enable || !player || !item)
        return;

    if (!IsEligibleItem(item))
        return;

    if (ItemHasParagonEnchantment(item))
        return;

    uint32 paragonLevel = GetPlayerParagonLevel(player);
    if (paragonLevel < conf_MinParagonLevel)
        return;

    PlayerRoleInfo roleInfo = GetPlayerRoleInfo(player);
    if (!roleInfo.found)
    {
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cffff0000[Paragon]|r Set your role first with: .paragon role tank|dps|healer");
        return;
    }

    uint32 statAmount = CalculateStatAmount(paragonLevel, item->GetTemplate()->Quality);

    // Slot 0 (7): Stamina - always
    ApplySlotEnchantment(player, item, PARAGON_SLOT_STAMINA,
        GetEnchantmentId(PSTAT_STAMINA, statAmount));

    // Slot 1 (8): Main stat - player choice
    ApplySlotEnchantment(player, item, PARAGON_SLOT_MAINSTAT,
        GetEnchantmentId(roleInfo.mainStat, statAmount));

    // Slot 2 (9) & Slot 3 (10): Random combat ratings from role pool
    ParagonStatIndex cr1, cr2;
    PickTwoRandomRatings(roleInfo.role, cr1, cr2);

    ApplySlotEnchantment(player, item, PARAGON_SLOT_COMBAT_RATING1,
        GetEnchantmentId(cr1, statAmount));
    ApplySlotEnchantment(player, item, PARAGON_SLOT_COMBAT_RATING2,
        GetEnchantmentId(cr2, statAmount));

    // Slot 4 (11): Talent spell - TODO: placeholder for custom spells
    // Will be implemented when custom spells are created

    // Track in DB for trade restrictions
    CharacterDatabase.Execute(
        "REPLACE INTO character_paragon_item (itemGuid, paragonLevel, role, mainStat, combatRating1, combatRating2, statAmount) "
        "VALUES ({}, {}, {}, {}, {}, {}, {})",
        item->GetGUID().GetCounter(), paragonLevel,
        static_cast<uint8>(roleInfo.role), static_cast<uint8>(roleInfo.mainStat),
        static_cast<uint8>(cr1), static_cast<uint8>(cr2), statAmount);

    ChatHandler(player->GetSession()).PSendSysMessage(
        "|cff00ff00[Paragon]|r Item enhanced with +{} stats (Paragon Level {}).",
        statAmount, paragonLevel);
}

// ============================================================
// PlayerScript: Item acquisition and trade restriction hooks
// ============================================================

class ParagonItemGenPlayer : public PlayerScript
{
public:
    ParagonItemGenPlayer() : PlayerScript("ParagonItemGenPlayer") { }

    void OnPlayerLootItem(Player* player, Item* item, uint32 /*count*/, ObjectGuid /*lootguid*/) override
    {
        if (conf_OnLoot)
            ApplyParagonEnchantment(player, item);
    }

    void OnPlayerCreateItem(Player* player, Item* item, uint32 /*count*/) override
    {
        if (conf_OnCreate)
            ApplyParagonEnchantment(player, item);
    }

    void OnPlayerQuestRewardItem(Player* player, Item* item, uint32 /*count*/) override
    {
        if (conf_OnQuest)
            ApplyParagonEnchantment(player, item);
    }

    void OnPlayerAfterStoreOrEquipNewItem(Player* player, uint32 /*vendorslot*/, Item* item,
        uint8 /*count*/, uint8 /*bag*/, uint8 /*slot*/, ItemTemplate const* /*pProto*/,
        Creature* /*pVendor*/, VendorItem const* /*crItem*/, bool /*bStore*/) override
    {
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

        QueryResult result = CharacterDatabase.Query(
            "SELECT paragonLevel FROM character_paragon_item WHERE itemGuid = {}",
            tradedItem->GetGUID().GetCounter());

        if (!result)
            return true;

        uint32 itemParagonLevel = (*result)[0].Get<uint32>();

        Player* tradeTarget = player->GetTrader();
        if (!tradeTarget)
            return true;

        uint32 targetParagonLevel = GetPlayerParagonLevel(tradeTarget);

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

        QueryResult itemResult = CharacterDatabase.Query(
            "SELECT paragonLevel FROM character_paragon_item WHERE itemGuid = {}",
            item->GetGUID().GetCounter());

        if (!itemResult)
            return true;

        uint32 itemParagonLevel = (*itemResult)[0].Get<uint32>();

        QueryResult charResult = CharacterDatabase.Query(
            "SELECT cp.level FROM character_paragon cp "
            "INNER JOIN characters c ON c.account = cp.accountID "
            "WHERE c.guid = {}",
            receiverGuid.GetCounter());

        uint32 receiverParagonLevel = 0;
        if (charResult)
            receiverParagonLevel = (*charResult)[0].Get<uint32>();

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
    ParagonItemGenWorld() : WorldScript("ParagonItemGenWorld") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
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

        if (conf_Enable)
            LOG_INFO("module", "ParagonItemGen: Loaded (Scaling={}, MinPLevel={}, MinIlvl={})",
                conf_ScalingFactor, conf_MinParagonLevel, conf_MinItemLevel);
    }
};

void AddParagonItemGenScripts()
{
    new ParagonItemGenPlayer();
    new ParagonItemGenWorld();
}
