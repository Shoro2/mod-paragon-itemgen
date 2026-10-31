/*
 * Paragon Item Scaling - the Cursed Altar
 *
 * Players sacrifice CURSED items at the altar object (go_paragon_cursed_altar, entry 921010):
 *   - the item's passive (slot 11 enchantment 950001-950999) goes into the ACCOUNT-wide collection
 *     (account_paragon_passive_collection; the collection does nothing by itself),
 *   - the player is paid Cursed Essence (item 920300) by the item's quality.
 * A cursed item with only the plain "Cursed" marker (920001) pays but unlocks nothing.
 *
 * With Cursed Essence and Tainted Heartstones (item 920301) the player BINDS a passive of the collection:
 * an item from the bags is re-rolled as a cursed item at the current Paragon level with exactly that passive
 * in slot 11. Only passives that are in the collection AND in a spec pool of the player's class can be bound.
 *
 * Commands (SEC_PLAYER):
 *   .paragon altar sync                      sends the window's data (works anywhere)
 *   .paragon altar sacrifice <bag> <slot>    at the altar only
 *   .paragon altar bind <bag> <slot> <ench>  at the altar only
 *
 * Positions use the CLIENT's container numbering (ResolveBagSlot is the one place that converts):
 *   bag 0     = the backpack, slot 1..16
 *   bag 1..4  = the four equipped bags, slot 1..size
 * Slots are 1-BASED, exactly what GetContainerItemInfo(bag, slot) takes.
 *
 * Server -> client, addon whisper from the player to himself, prefix PIGALT (ItemGen_Altar_Client.lua), every
 * message under 250 bytes. List kinds hold several records separated by '~', fields by ',' (names are stripped
 * of ; , ~ | tab and newline):
 *   O                                          open the window (the altar object was used); data follows
 *   B;<atAltar 0/1>;<essence>;<classId>;<heartstones>
 *                                              begin a data set: at the altar, Cursed Essence balance, the
 *                                              player's class (CLASS_*), Tainted Heartstone balance
 *   S;<rec>~<rec>...                           sacrifice candidates (cursed items in the bags), a rec is
 *                                              bag,slot,itemEntry,quality,enchId,yield,known,spellId,name
 *                                              (enchId 920001 = plain Cursed marker, spellId 0 and no name;
 *                                              known 1 = in the collection; spell and name from the catalog)
 *   T;<rec>~<rec>...                           bind targets (eligible items in the bags), a rec is
 *                                              bag,slot,itemEntry,quality,essenceCost,heartstoneCost
 *   P;<rec>~<rec>...                           the class pool, then the account's RETIRED passives, a rec is
 *                                              enchId,spellId,specMask,unlocked,retired,name
 *                                              (specMask: bit n-1 = ParagonSpec n holds the passive. retired 1 =
 *                                              collected but in no spec pool of the player's class any more: specMask
 *                                              0, unlocked 1, shown in the window, never bindable)
 *   E                                          end of the data set
 *   R;<ok 0/1>;<text>                          the answer to the last action
 */

#include "ParagonItemGen.h"
#include "Bag.h"
#include "Chat.h"
#include "CharacterDatabase.h"
#include "CommandScript.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "GameObjectScript.h"
#include "Item.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldPacket.h"
#include "WorldScript.h"
#include "WorldSession.h"
#include <algorithm>
#include <string>
#include <unordered_set>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    constexpr char const* ALTAR_PREFIX = "PIGALT";
    constexpr std::size_t ALTAR_MAX_PAYLOAD = 220;   // prefix (6) + tab (1) + payload stays well under 250
    constexpr std::size_t ALTAR_MAX_NAME = 40;

    // ParagonItemGen.Altar.* (OnAfterConfigLoad below); index = item quality, only 2..5 pay or cost
    struct AltarConfig
    {
        bool   enable = true;
        float  range = 10.0f;
        uint32 yield[6] = { 0, 0, 1, 5, 10, 1000 };
        uint32 cost[6] = { 0, 0, 10, 30, 100, 300 };
        uint32 materialCost[6] = { 0, 0, 1, 2, 5, 10 };
    };

    AltarConfig sAltarConf;

    uint32 QualityValue(uint32 const (&table)[6], uint32 quality)
    {
        return quality < 6 ? table[quality] : 0;
    }

    // ------------------------------------------------------------
    // Addon messages
    // ------------------------------------------------------------

    std::string Sanitize(std::string text)
    {
        for (char& c : text)
            if (c == ';' || c == ',' || c == '~' || c == '|' || c == '\t' || c == '\n' || c == '\r')
                c = ' ';
        return text;
    }

    void SendAddon(Player* player, std::string const& payload)
    {
        WorldSession* session = player->GetSession();
        if (!session)
            return;

        WorldPacket data;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player->GetGUID(), player->GetGUID(),
            std::string(ALTAR_PREFIX) + '\t' + payload, 0);
        session->SendPacket(&data);
    }

    // A list kind over as many messages as it takes.
    void SendRecords(Player* player, char kind, std::vector<std::string> const& records)
    {
        std::string payload;
        for (std::string const& record : records)
        {
            if (!payload.empty() && payload.size() + 1 + record.size() > ALTAR_MAX_PAYLOAD)
            {
                SendAddon(player, payload);
                payload.clear();
            }

            if (payload.empty())
                payload = std::string(1, kind) + ';' + record;
            else
                payload += '~' + record;
        }

        if (!payload.empty())
            SendAddon(player, payload);
    }

    // The answer to an action: the window's status line and a chat line.
    void Reply(ChatHandler* handler, Player* player, bool ok, std::string const& text)
    {
        SendAddon(player, Acore::StringFormat("R;{};{}", ok ? 1 : 0, Sanitize(text)));
        handler->SendSysMessage(Acore::StringFormat("{}[Cursed Altar]|r {}", ok ? "|cff8b00ff" : "|cffff0000", text));
    }

    // ------------------------------------------------------------
    // Positions and bag walking
    // ------------------------------------------------------------

    // Client numbering (bag 0 = backpack, 1..4 = bags, slot 1-based) -> the core's (bag, slot). The ONE place.
    bool ResolveBagSlot(Player* player, uint32 bag, uint32 slot, uint8& coreBag, uint8& coreSlot)
    {
        if (slot < 1)
            return false;

        if (bag == 0)
        {
            uint32 const packSize = uint32(INVENTORY_SLOT_ITEM_END) - uint32(INVENTORY_SLOT_ITEM_START);
            if (slot > packSize)
                return false;

            coreBag = INVENTORY_SLOT_BAG_0;
            coreSlot = uint8(uint32(INVENTORY_SLOT_ITEM_START) + slot - 1);
            return true;
        }

        if (bag <= 4)
        {
            uint8 const bagPos = uint8(uint32(INVENTORY_SLOT_BAG_START) + bag - 1);
            Bag* container = player->GetBagByPos(bagPos);
            if (!container || slot > container->GetBagSize())
                return false;

            coreBag = bagPos;
            coreSlot = uint8(slot - 1);
            return true;
        }

        return false;
    }

    // fn(clientBag, clientSlot, item) for every item in the backpack and the equipped bags.
    template <typename Fn>
    void ForEachBagItem(Player* player, Fn&& fn)
    {
        for (uint8 pos = INVENTORY_SLOT_ITEM_START; pos < INVENTORY_SLOT_ITEM_END; ++pos)
            if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, pos))
                fn(uint32(0), uint32(pos - INVENTORY_SLOT_ITEM_START + 1), item);

        for (uint8 bagPos = INVENTORY_SLOT_BAG_START; bagPos < INVENTORY_SLOT_BAG_END; ++bagPos)
        {
            Bag* container = player->GetBagByPos(bagPos);
            if (!container)
                continue;

            for (uint32 slot = 0; slot < container->GetBagSize(); ++slot)
                if (Item* item = container->GetItemByPos(uint8(slot)))
                    fn(uint32(bagPos - INVENTORY_SLOT_BAG_START + 1), slot + 1, item);
        }
    }

    bool AtAltar(Player* player)
    {
        return sAltarConf.enable && player->FindNearestGameObject(PARAGON_ALTAR_GO_ENTRY, sAltarConf.range, true) != nullptr;
    }

    uint32 SlotElevenEnchant(Item* item)
    {
        return item->GetEnchantmentId(EnchantmentSlot(PARAGON_SLOT_TALENT_SPELL));
    }

    // ------------------------------------------------------------
    // The collection (characters DB; every value is an integer)
    // ------------------------------------------------------------

    std::unordered_set<uint32> LoadCollection(uint32 accountId)
    {
        std::unordered_set<uint32> collection;
        if (QueryResult result = CharacterDatabase.Query(
            "SELECT `enchantmentId` FROM `account_paragon_passive_collection` WHERE `accountId` = {}", accountId))
        {
            do
            {
                collection.insert((*result)[0].Get<uint32>());
            } while (result->NextRow());
        }
        return collection;
    }

    // DirectExecute: the sync that follows reads the row right back.
    void AddToCollection(uint32 accountId, uint32 enchantId)
    {
        CharacterDatabase.DirectExecute(
            "INSERT INTO `account_paragon_passive_collection` (`accountId`, `enchantmentId`) VALUES ({}, {}) "
            "ON DUPLICATE KEY UPDATE `sacrificed` = `sacrificed` + 1", accountId, enchantId);
    }

    // ------------------------------------------------------------
    // The window's data
    // ------------------------------------------------------------

    void SendSync(Player* player)
    {
        WorldSession* session = player->GetSession();
        if (!session)
            return;

        std::unordered_set<uint32> const collection = LoadCollection(session->GetAccountId());

        SendAddon(player, Acore::StringFormat("B;{};{};{};{}", AtAltar(player) ? 1 : 0,
            player->GetItemCount(PARAGON_ALTAR_TOKEN_ITEM), uint32(player->getClass()),
            player->GetItemCount(PARAGON_ALTAR_MATERIAL_ITEM)));

        std::vector<std::string> sacrifices;
        std::vector<std::string> targets;
        ForEachBagItem(player, [&](uint32 bag, uint32 slot, Item* item)
        {
            ItemTemplate const* proto = item->GetTemplate();
            if (!proto)
                return;

            uint32 const enchantId = SlotElevenEnchant(item);
            if (enchantId == PARAGON_ENCHANT_CURSED_ID || ParagonItemGenIsPassiveEnchant(enchantId))
            {
                uint32 const yield = QualityValue(sAltarConf.yield, proto->Quality);
                if (yield)
                {
                    uint32 spellId = 0;
                    std::string passiveName;
                    if (enchantId != PARAGON_ENCHANT_CURSED_ID)
                    {
                        spellId = ParagonItemGenPassiveSpell(enchantId);
                        passiveName = Sanitize(ParagonItemGenPassiveName(enchantId));
                        if (passiveName.size() > ALTAR_MAX_NAME)
                            passiveName.resize(ALTAR_MAX_NAME);
                    }
                    sacrifices.push_back(Acore::StringFormat("{},{},{},{},{},{},{},{},{}", bag, slot, item->GetEntry(),
                        proto->Quality, enchantId, yield, collection.count(enchantId) ? 1 : 0, spellId, passiveName));
                }
            }

            if (ParagonItemGenIsEligibleItem(item))
            {
                uint32 const cost = QualityValue(sAltarConf.cost, proto->Quality);
                if (cost)
                    targets.push_back(Acore::StringFormat("{},{},{},{},{},{}", bag, slot, item->GetEntry(),
                        proto->Quality, cost, QualityValue(sAltarConf.materialCost, proto->Quality)));
            }
        });
        SendRecords(player, 'S', sacrifices);
        SendRecords(player, 'T', targets);

        std::vector<ParagonClassPassive> pool;
        ParagonItemGenGetClassPassives(player->getClass(), pool);
        std::vector<std::string> passives;
        passives.reserve(pool.size());
        for (ParagonClassPassive const& passive : pool)
        {
            std::string name = Sanitize(passive.name);
            if (name.size() > ALTAR_MAX_NAME)
                name.resize(ALTAR_MAX_NAME);
            passives.push_back(Acore::StringFormat("{},{},{},{},0,{}", passive.enchantmentId, passive.spellId,
                passive.specMask, collection.count(passive.enchantmentId) ? 1 : 0, name));
        }

        // Collected passives the class pool does not list (retired by removing their assignment rows, or of
        // another class): shown, never bindable. Their catalog row still names them.
        std::unordered_set<uint32> inPool;
        for (ParagonClassPassive const& passive : pool)
            inPool.insert(passive.enchantmentId);

        std::vector<uint32> retired;
        for (uint32 enchantId : collection)
            if (!inPool.count(enchantId))
                retired.push_back(enchantId);
        std::sort(retired.begin(), retired.end());

        for (uint32 enchantId : retired)
        {
            std::string name = Sanitize(ParagonItemGenPassiveName(enchantId));
            if (name.size() > ALTAR_MAX_NAME)
                name.resize(ALTAR_MAX_NAME);
            passives.push_back(Acore::StringFormat("{},{},0,1,1,{}", enchantId, ParagonItemGenPassiveSpell(enchantId), name));
        }
        SendRecords(player, 'P', passives);

        SendAddon(player, "E");
    }

    // ------------------------------------------------------------
    // Actions
    // ------------------------------------------------------------

    // The item at a client position, or nullptr with the reason in `reason`.
    Item* FindBagItem(Player* player, uint32 bag, uint32 slot, std::string& reason)
    {
        uint8 coreBag = 0;
        uint8 coreSlot = 0;
        if (!ResolveBagSlot(player, bag, slot, coreBag, coreSlot))
        {
            reason = "There is no such bag slot.";
            return nullptr;
        }

        Item* item = player->GetItemByPos(coreBag, coreSlot);
        if (!item || item->GetOwnerGUID() != player->GetGUID())
        {
            reason = "That slot is empty.";
            return nullptr;
        }

        if (item->IsEquipped())
        {
            reason = "Take the item off first.";
            return nullptr;
        }

        if (item->IsInTrade())
        {
            reason = "That item is in a trade.";
            return nullptr;
        }

        return item;
    }

    bool HandleAltarSync(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        SendSync(player);
        return true;
    }

    // The same data as text in the chat - for a player without the window, a GM, and the test bots (whose
    // scenarios read system messages, not addon whispers)
    bool HandleAltarList(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        handler->PSendSysMessage("[Cursed Altar] at altar {}, Cursed Essence {}, Tainted Heartstones {}",
            AtAltar(player) ? 1 : 0, player->GetItemCount(PARAGON_ALTAR_TOKEN_ITEM),
            player->GetItemCount(PARAGON_ALTAR_MATERIAL_ITEM));

        std::unordered_set<uint32> const collection = LoadCollection(player->GetSession()->GetAccountId());
        ForEachBagItem(player, [&](uint32 bag, uint32 slot, Item* item)
        {
            ItemTemplate const* proto = item->GetTemplate();
            if (!proto)
                return;

            uint32 const enchantId = SlotElevenEnchant(item);
            if (enchantId == PARAGON_ENCHANT_CURSED_ID || ParagonItemGenIsPassiveEnchant(enchantId))
                handler->PSendSysMessage("[Cursed Altar] sacrifice bag {} slot {}: item {} enchant {}{}", bag, slot,
                    item->GetEntry(), enchantId, collection.count(enchantId) ? " (known)" : "");
            if (ParagonItemGenIsEligibleItem(item))
                handler->PSendSysMessage("[Cursed Altar] target bag {} slot {}: item {}", bag, slot, item->GetEntry());
        });

        for (uint32 enchantId : collection)
            handler->PSendSysMessage("[Cursed Altar] collected {}", enchantId);
        return true;
    }

    // GM: puts a passive into the selected player's account collection without a sacrifice (testers, test bots)
    bool HandleAltarUnlock(ChatHandler* handler, uint32 enchantId)
    {
        Player* target = handler->getSelectedPlayerOrSelf();
        if (!target)
            return false;

        if (!ParagonItemGenIsPassiveEnchant(enchantId) || ParagonItemGenPassiveName(enchantId).empty())
        {
            handler->PSendSysMessage("[Cursed Altar] {} is not a passive of the pool.", enchantId);
            return true;
        }

        AddToCollection(target->GetSession()->GetAccountId(), enchantId);
        handler->PSendSysMessage("[Cursed Altar] {} unlocked for {}'s account: {}", enchantId, target->GetName(),
            ParagonItemGenPassiveName(enchantId));
        SendSync(target);
        return true;
    }

    bool HandleAltarSacrifice(ChatHandler* handler, uint32 bag, uint32 slot)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        std::string reason;
        if (!sAltarConf.enable)
            reason = "The altar is silent.";
        else if (!AtAltar(player))
            reason = "You must stand at the Cursed Altar.";

        Item* item = reason.empty() ? FindBagItem(player, bag, slot, reason) : nullptr;
        if (!item)
        {
            Reply(handler, player, false, reason);
            SendSync(player);
            return true;
        }

        ItemTemplate const* proto = item->GetTemplate();
        uint32 const enchantId = SlotElevenEnchant(item);
        uint32 const yield = proto ? QualityValue(sAltarConf.yield, proto->Quality) : 0;
        if (!proto || (enchantId != PARAGON_ENCHANT_CURSED_ID && !ParagonItemGenIsPassiveEnchant(enchantId)))
            reason = "Only cursed items can be sacrificed.";
        else if (!yield)
            reason = "The altar does not want an item of that quality.";
        else if (!sObjectMgr->GetItemTemplate(PARAGON_ALTAR_TOKEN_ITEM))
            reason = "The altar has nothing to give (Cursed Essence is not installed).";

        ItemPosCountVec dest;
        if (reason.empty() && player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, PARAGON_ALTAR_TOKEN_ITEM, yield) != EQUIP_ERR_OK)
            reason = "You cannot carry the Cursed Essence.";

        if (!reason.empty())
        {
            Reply(handler, player, false, reason);
            SendSync(player);
            return true;
        }

        uint32 const accountId = player->GetSession()->GetAccountId();
        uint32 const itemGuid = item->GetGUID().GetCounter();
        std::string const itemName = proto->Name1;
        bool const isPassive = ParagonItemGenIsPassiveEnchant(enchantId);
        bool const known = isPassive && LoadCollection(accountId).count(enchantId) > 0;
        std::string passiveName = isPassive ? ParagonItemGenPassiveName(enchantId) : std::string();
        if (isPassive && passiveName.empty())
            passiveName = Acore::StringFormat("passive {}", enchantId);

        player->DestroyItem(item->GetBagSlot(), item->GetSlot(), true);   // item is dangling from here on
        item = nullptr;
        CharacterDatabase.Execute("DELETE FROM `character_paragon_item` WHERE `itemGuid` = {}", itemGuid);

        player->AddItem(PARAGON_ALTAR_TOKEN_ITEM, yield);
        if (isPassive)
            AddToCollection(accountId, enchantId);

        LOG_INFO("module", "ParagonItemGen: altar sacrifice by {} (account {}): {} (item guid {}), enchantment {}, {} Cursed Essence",
            player->GetName(), accountId, itemName, itemGuid, enchantId, yield);

        std::string text = Acore::StringFormat("{} crumbles into {} Cursed Essence.", itemName, yield);
        if (isPassive)
            text += known ? Acore::StringFormat(" Passive already known: {}.", passiveName)
                          : Acore::StringFormat(" New passive unlocked: {}.", passiveName);
        else
            text += " The plain curse unlocks no passive.";
        Reply(handler, player, true, text);
        SendSync(player);
        return true;
    }

    bool HandleAltarBind(ChatHandler* handler, uint32 bag, uint32 slot, uint32 enchantId)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        std::string reason;
        if (!sAltarConf.enable)
            reason = "The altar is silent.";
        else if (!AtAltar(player))
            reason = "You must stand at the Cursed Altar.";

        Item* item = reason.empty() ? FindBagItem(player, bag, slot, reason) : nullptr;
        ItemTemplate const* proto = item ? item->GetTemplate() : nullptr;

        // The passive: unlocked on this account AND in a spec pool of the player's class
        if (reason.empty())
        {
            std::vector<ParagonClassPassive> pool;
            ParagonItemGenGetClassPassives(player->getClass(), pool);
            auto it = std::find_if(pool.begin(), pool.end(), [enchantId](ParagonClassPassive const& passive)
            {
                return passive.enchantmentId == enchantId;
            });

            if (it == pool.end())
                reason = "That passive does not belong to your class.";
            else if (!LoadCollection(player->GetSession()->GetAccountId()).count(enchantId))
                reason = "That passive is not in your collection yet.";
        }

        // Everything the roll needs, BEFORE anything is taken (kill switch, eligible item, Paragon level, role)
        if (reason.empty())
            ParagonItemGenCheckAltarBind(player, item, enchantId, reason);   // false: `reason` says why

        uint32 cost = 0;
        uint32 materialCost = 0;
        if (reason.empty())
        {
            cost = QualityValue(sAltarConf.cost, proto->Quality);
            materialCost = QualityValue(sAltarConf.materialCost, proto->Quality);
            if (!cost)
                reason = "The altar cannot bind an item of that quality.";
            else if (!sObjectMgr->GetItemTemplate(PARAGON_ALTAR_TOKEN_ITEM) ||
                (materialCost && !sObjectMgr->GetItemTemplate(PARAGON_ALTAR_MATERIAL_ITEM)))
                reason = "The altar has nothing to take (its currencies are not installed).";
            else if (player->GetItemCount(PARAGON_ALTAR_TOKEN_ITEM) < cost)
                reason = Acore::StringFormat("You need {} Cursed Essence.", cost);
            else if (materialCost && player->GetItemCount(PARAGON_ALTAR_MATERIAL_ITEM) < materialCost)
                reason = Acore::StringFormat("You need {} Tainted Heartstones.", materialCost);
        }

        if (!reason.empty())
        {
            Reply(handler, player, false, reason);
            SendSync(player);
            return true;
        }

        std::string const itemName = proto->Name1;
        if (!ParagonItemGenRollCursedWithPassive(player, item, enchantId))
        {
            Reply(handler, player, false, "The binding failed. Nothing was taken.");
            SendSync(player);
            return true;
        }

        // The roll succeeded: only now are the prices taken
        player->DestroyItemCount(PARAGON_ALTAR_TOKEN_ITEM, cost, true);
        if (materialCost)
            player->DestroyItemCount(PARAGON_ALTAR_MATERIAL_ITEM, materialCost, true);

        std::string passiveName = ParagonItemGenPassiveName(enchantId);
        if (passiveName.empty())
            passiveName = Acore::StringFormat("passive {}", enchantId);

        LOG_INFO("module", "ParagonItemGen: altar bind by {} (account {}): {} gets enchantment {}, {} Cursed Essence + {} Tainted Heartstones",
            player->GetName(), player->GetSession()->GetAccountId(), itemName, enchantId, cost, materialCost);

        Reply(handler, player, true, Acore::StringFormat("{} is bound to {} for {} Cursed Essence and {} Tainted Heartstones.",
            itemName, passiveName, cost, materialCost));
        SendSync(player);
        return true;
    }
}

// ============================================================
// The altar object: opens the window, no gossip menu
// ============================================================
class go_paragon_cursed_altar : public GameObjectScript
{
public:
    go_paragon_cursed_altar() : GameObjectScript("go_paragon_cursed_altar") { }

    bool OnGossipHello(Player* player, GameObject* /*altar*/) override
    {
        if (!sAltarConf.enable)
        {
            ChatHandler(player->GetSession()).SendSysMessage("|cffff0000[Cursed Altar]|r The altar is silent.");
            return true;
        }

        SendAddon(player, "O");
        SendSync(player);
        return true;
    }
};

// ============================================================
// Commands: .paragon altar sync | sacrifice | bind
// (merged into the `.paragon` table of ParagonItemGenCommands.cpp by the core)
// ============================================================
class ParagonItemGenAltarCommandScript : public CommandScript
{
public:
    ParagonItemGenAltarCommandScript() : CommandScript("ParagonItemGenAltarCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable altarSubCommands =
        {
            { "sync",      HandleAltarSync,      SEC_PLAYER, Console::No },
            { "list",      HandleAltarList,      SEC_PLAYER, Console::No },
            { "unlock",    HandleAltarUnlock,    SEC_GAMEMASTER, Console::No },
            { "sacrifice", HandleAltarSacrifice, SEC_PLAYER, Console::No },
            { "bind",      HandleAltarBind,      SEC_PLAYER, Console::No },
        };

        static ChatCommandTable paragonSubCommands =
        {
            { "altar", altarSubCommands },
        };

        static ChatCommandTable commandTable =
        {
            { "paragon", paragonSubCommands },
        };

        return commandTable;
    }
};

// ============================================================
// Configuration
// ============================================================
class ParagonItemGenAltarWorld : public WorldScript
{
public:
    ParagonItemGenAltarWorld() : WorldScript("ParagonItemGenAltarWorld", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        sAltarConf.enable = sConfigMgr->GetOption<bool>("ParagonItemGen.Altar.Enable", true);
        sAltarConf.range  = sConfigMgr->GetOption<float>("ParagonItemGen.Altar.Range", 10.0f);

        sAltarConf.yield[2] = sConfigMgr->GetOption<uint32>("ParagonItemGen.Altar.Yield.Uncommon", 1);
        sAltarConf.yield[3] = sConfigMgr->GetOption<uint32>("ParagonItemGen.Altar.Yield.Rare", 5);
        sAltarConf.yield[4] = sConfigMgr->GetOption<uint32>("ParagonItemGen.Altar.Yield.Epic", 10);
        sAltarConf.yield[5] = sConfigMgr->GetOption<uint32>("ParagonItemGen.Altar.Yield.Legendary", 1000);

        sAltarConf.cost[2] = sConfigMgr->GetOption<uint32>("ParagonItemGen.Altar.Cost.Uncommon", 10);
        sAltarConf.cost[3] = sConfigMgr->GetOption<uint32>("ParagonItemGen.Altar.Cost.Rare", 30);
        sAltarConf.cost[4] = sConfigMgr->GetOption<uint32>("ParagonItemGen.Altar.Cost.Epic", 100);
        sAltarConf.cost[5] = sConfigMgr->GetOption<uint32>("ParagonItemGen.Altar.Cost.Legendary", 300);

        sAltarConf.materialCost[2] = sConfigMgr->GetOption<uint32>("ParagonItemGen.Altar.MaterialCost.Uncommon", 1);
        sAltarConf.materialCost[3] = sConfigMgr->GetOption<uint32>("ParagonItemGen.Altar.MaterialCost.Rare", 2);
        sAltarConf.materialCost[4] = sConfigMgr->GetOption<uint32>("ParagonItemGen.Altar.MaterialCost.Epic", 5);
        sAltarConf.materialCost[5] = sConfigMgr->GetOption<uint32>("ParagonItemGen.Altar.MaterialCost.Legendary", 10);

        LOG_INFO("module", "ParagonItemGen: Altar config - Enable={}, Range={}, Yield=[{}, {}, {}, {}], Cost=[{}, {}, {}, {}], MaterialCost=[{}, {}, {}, {}]",
            sAltarConf.enable, sAltarConf.range,
            sAltarConf.yield[2], sAltarConf.yield[3], sAltarConf.yield[4], sAltarConf.yield[5],
            sAltarConf.cost[2], sAltarConf.cost[3], sAltarConf.cost[4], sAltarConf.cost[5],
            sAltarConf.materialCost[2], sAltarConf.materialCost[3], sAltarConf.materialCost[4], sAltarConf.materialCost[5]);
    }
};

void AddParagonItemGenAltarScripts()
{
    new go_paragon_cursed_altar();
    new ParagonItemGenAltarCommandScript();
    new ParagonItemGenAltarWorld();
}
