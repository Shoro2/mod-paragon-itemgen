/*
 * Paragon Item Scaling Module
 * Applies bonus enchantments to items based on the player's Paragon level.
 *
 * Stat profiles are determined by class + talent spec:
 *   STR_MELEE:  Arms/Fury Warrior, Ret Paladin, Frost/Unholy DK
 *   AGI_MELEE:  Rogue, Enhance Shaman, Feral Druid (cat)
 *   AGI_RANGED: Hunter
 *   INT_CASTER: Mage, Warlock, Shadow Priest, Ele Shaman, Balance Druid
 *   INT_HEALER: Holy/Disc Priest, Resto Shaman, Resto Druid, Holy Paladin
 *   STR_TANK:   Prot Warrior, Prot Paladin, Blood DK
 *   AGI_TANK:   Feral Druid (bear) - defaults to AGI_MELEE for now
 *
 * Scaling formula:
 *   statAmount = ceil(paragonLevel * scalingFactor * qualityMultiplier)
 *   Capped at PARAGON_ENCHANT_MAX_AMOUNT (200)
 *
 * Trade/Mail restrictions:
 *   Items with paragon enchantments track the paragon level they were created at.
 *   Trading/mailing to players with a LOWER paragon level is blocked.
 *
 * TODO: AH restriction - AzerothCore has no CanListAuction hook.
 *       Options: (1) core patch adding a hook, (2) mark items soulbound,
 *       (3) use OnAuctionAdd to cancel and return the item.
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

// ============================================================
// Configuration (loaded from .conf after world startup)
// ============================================================
static bool  conf_Enable          = true;
static bool  conf_OnLoot          = true;
static bool  conf_OnCreate        = true;
static bool  conf_OnQuest         = true;
static bool  conf_OnVendor        = true;
static float conf_ScalingFactor   = 0.5f;
static float conf_QualityMult[6]  = { 0.0f, 0.0f, 0.5f, 0.75f, 1.0f, 1.25f };
// quality indices:                   poor  normal uncomm  rare  epic  legendary
static uint32 conf_MinParagonLevel = 1;
static uint32 conf_MinItemLevel    = 150;
static bool  conf_BlockTrade      = true;
static bool  conf_BlockMail       = true;

// ============================================================
// Spec-to-profile mapping
// Index: [classId][talentTreeTab]
// ============================================================
// Class IDs: 1=Warrior 2=Paladin 3=Hunter 4=Rogue 5=Priest
//            6=DK 7=Shaman 8=Mage 9=Warlock 11=Druid
// Tab 0/1/2 correspond to the 3 talent trees per class
static ParagonStatProfile const CLASS_SPEC_PROFILE[12][3] =
{
    // 0: unused
    { PROFILE_STR_MELEE, PROFILE_STR_MELEE, PROFILE_STR_MELEE },
    // 1: Warrior - Arms(0)/Fury(1)/Prot(2)
    { PROFILE_STR_MELEE, PROFILE_STR_MELEE, PROFILE_STR_TANK },
    // 2: Paladin - Holy(0)/Prot(1)/Ret(2)
    { PROFILE_INT_HEALER, PROFILE_STR_TANK, PROFILE_STR_MELEE },
    // 3: Hunter - BM(0)/MM(1)/Surv(2)
    { PROFILE_AGI_RANGED, PROFILE_AGI_RANGED, PROFILE_AGI_RANGED },
    // 4: Rogue - Assassin(0)/Combat(1)/Sub(2)
    { PROFILE_AGI_MELEE, PROFILE_AGI_MELEE, PROFILE_AGI_MELEE },
    // 5: Priest - Disc(0)/Holy(1)/Shadow(2)
    { PROFILE_INT_HEALER, PROFILE_INT_HEALER, PROFILE_INT_CASTER },
    // 6: Death Knight - Blood(0)/Frost(1)/Unholy(2)
    { PROFILE_STR_TANK, PROFILE_STR_MELEE, PROFILE_STR_MELEE },
    // 7: Shaman - Ele(0)/Enhance(1)/Resto(2)
    { PROFILE_INT_CASTER, PROFILE_AGI_MELEE, PROFILE_INT_HEALER },
    // 8: Mage - Arcane(0)/Fire(1)/Frost(2)
    { PROFILE_INT_CASTER, PROFILE_INT_CASTER, PROFILE_INT_CASTER },
    // 9: Warlock - Aff(0)/Demo(1)/Destro(2)
    { PROFILE_INT_CASTER, PROFILE_INT_CASTER, PROFILE_INT_CASTER },
    // 10: unused
    { PROFILE_STR_MELEE, PROFILE_STR_MELEE, PROFILE_STR_MELEE },
    // 11: Druid - Balance(0)/Feral(1)/Resto(2)
    { PROFILE_INT_CASTER, PROFILE_AGI_MELEE, PROFILE_INT_HEALER },
};

// ============================================================
// Helper functions
// ============================================================

static uint32 GetPlayerParagonLevel(Player* player)
{
    QueryResult result = CharacterDatabase.Query(
        "SELECT level FROM character_paragon WHERE accountID = {}",
        player->GetSession()->GetAccountId());

    if (!result)
        return 0;

    return (*result)[0].Get<uint32>();
}

static ParagonStatProfile GetPlayerProfile(Player* player)
{
    uint8 classId = player->getClass();
    if (classId >= 12)
        return PROFILE_STR_MELEE;

    uint8 talentTree = player->GetMostPointsTalentTree();
    if (talentTree > 2)
        talentTree = 0;

    return CLASS_SPEC_PROFILE[classId][talentTree];
}

static bool IsEligibleItem(Item* item)
{
    if (!item)
        return false;

    ItemTemplate const* proto = item->GetTemplate();
    if (!proto)
        return false;

    // Only weapons (class 2) and armor (class 4)
    if (proto->Class != ITEM_CLASS_WEAPON && proto->Class != ITEM_CLASS_ARMOR)
        return false;

    // Quality filter: uncommon(2) through legendary(5)
    if (proto->Quality < ITEM_QUALITY_UNCOMMON || proto->Quality > ITEM_QUALITY_LEGENDARY)
        return false;

    // Item level minimum
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

static uint32 GetEnchantmentId(ParagonStatProfile profile, uint32 amount)
{
    return PARAGON_ENCHANT_BASE_ID + static_cast<uint32>(profile) * PARAGON_ENCHANT_PROFILE_STRIDE + amount;
}

static bool IsParagonEnchantment(uint32 enchantId)
{
    return enchantId > PARAGON_ENCHANT_BASE_ID &&
           enchantId <= PARAGON_ENCHANT_BASE_ID + PROFILE_MAX * PARAGON_ENCHANT_PROFILE_STRIDE;
}

static bool ItemHasParagonEnchantment(Item* item)
{
    uint32 enchId = item->GetEnchantmentId(EnchantmentSlot(PARAGON_ENCHANT_SLOT));
    return IsParagonEnchantment(enchId);
}

// ============================================================
// Core: Apply paragon enchantment to an item
// ============================================================

static void ApplyParagonEnchantment(Player* player, Item* item)
{
    if (!conf_Enable || !player || !item)
        return;

    if (!IsEligibleItem(item))
        return;

    // Don't re-enchant items that already have a paragon enchantment
    if (ItemHasParagonEnchantment(item))
        return;

    uint32 paragonLevel = GetPlayerParagonLevel(player);
    if (paragonLevel < conf_MinParagonLevel)
        return;

    ParagonStatProfile profile = GetPlayerProfile(player);
    uint32 statAmount = CalculateStatAmount(paragonLevel, item->GetTemplate()->Quality);
    uint32 enchantId = GetEnchantmentId(profile, statAmount);

    // Verify the enchantment exists in the DBC store
    if (!sSpellItemEnchantmentStore.LookupEntry(enchantId))
    {
        LOG_ERROR("module", "ParagonItemGen: Enchantment ID {} not found in sSpellItemEnchantmentStore", enchantId);
        return;
    }

    // Remove existing enchantment in this slot if any
    if (item->IsEquipped())
        player->ApplyEnchantment(item, EnchantmentSlot(PARAGON_ENCHANT_SLOT), false);

    // Apply the paragon enchantment
    item->SetEnchantment(EnchantmentSlot(PARAGON_ENCHANT_SLOT), enchantId, 0, 0);

    if (item->IsEquipped())
        player->ApplyEnchantment(item, EnchantmentSlot(PARAGON_ENCHANT_SLOT), true);

    // Track in database for trade restriction enforcement
    CharacterDatabase.Execute(
        "REPLACE INTO character_paragon_item (itemGuid, paragonLevel, profileId, statAmount) VALUES ({}, {}, {}, {})",
        item->GetGUID().GetCounter(), paragonLevel, static_cast<uint8>(profile), statAmount);

    // Notify player
    ChatHandler(player->GetSession()).PSendSysMessage(
        "|cff00ff00[Paragon]|r Item enhanced with +{} stats (Paragon Level {}).",
        statAmount, paragonLevel);
}

// ============================================================
// PlayerScript: Hook into item acquisition and trade events
// ============================================================

class ParagonItemGenPlayer : public PlayerScript
{
public:
    ParagonItemGenPlayer() : PlayerScript("ParagonItemGenPlayer") { }

    // Looted items
    void OnPlayerLootItem(Player* player, Item* item, uint32 /*count*/, ObjectGuid /*lootguid*/) override
    {
        if (conf_OnLoot)
            ApplyParagonEnchantment(player, item);
    }

    // Crafted items
    void OnPlayerCreateItem(Player* player, Item* item, uint32 /*count*/) override
    {
        if (conf_OnCreate)
            ApplyParagonEnchantment(player, item);
    }

    // Quest reward items
    void OnPlayerQuestRewardItem(Player* player, Item* item, uint32 /*count*/) override
    {
        if (conf_OnQuest)
            ApplyParagonEnchantment(player, item);
    }

    // Vendor purchased items
    void OnPlayerAfterStoreOrEquipNewItem(Player* player, uint32 /*vendorslot*/, Item* item,
        uint8 /*count*/, uint8 /*bag*/, uint8 /*slot*/, ItemTemplate const* /*pProto*/,
        Creature* /*pVendor*/, VendorItem const* /*crItem*/, bool /*bStore*/) override
    {
        if (conf_OnVendor)
            ApplyParagonEnchantment(player, item);
    }

    // ========================================================
    // Trade restriction: block trading paragon items to lower-level players
    // ========================================================
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
                "|cffff0000[Paragon]|r Cannot trade this item - recipient's Paragon Level ({}) "
                "is lower than the item's Paragon Level ({}).",
                targetParagonLevel, itemParagonLevel);
            return false;
        }

        return true;
    }

    // ========================================================
    // Mail restriction: block mailing paragon items to lower-level players
    // ========================================================
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
                "|cffff0000[Paragon]|r Cannot mail this item - recipient's Paragon Level ({}) "
                "is lower than the item's Paragon Level ({}).",
                receiverParagonLevel, itemParagonLevel);
            return false;
        }

        return true;
    }

    // TODO: AH restriction - no CanListAuction hook in AzerothCore.
    // Possible solutions:
    //   1. Core patch: add a CanCreateAuction hook in AuctionHouseMgr
    //   2. AuctionHouseScript::OnAuctionAdd to cancel and return the item
    //   3. Mark paragon-enchanted items as soulbound (prevents all transfers)
};

// ============================================================
// WorldScript: Load configuration
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
            LOG_INFO("module", "ParagonItemGen: Loaded (ScalingFactor={}, MinLevel={}, MinIlvl={})",
                conf_ScalingFactor, conf_MinParagonLevel, conf_MinItemLevel);
    }
};

// ============================================================
// Script registration
// ============================================================

void AddParagonItemGenScripts()
{
    new ParagonItemGenPlayer();
    new ParagonItemGenWorld();
}
