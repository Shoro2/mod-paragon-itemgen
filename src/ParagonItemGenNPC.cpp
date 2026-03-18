/*
 * Paragon Item Scaling - Spec Selection NPC
 *
 * Gossip NPC that lets players choose their talent specialization.
 * The spec determines which passive spells can roll on Slot 11.
 * Auto-detects the player's class and shows the available specs.
 *
 * NPC Entry: PARAGON_SPEC_NPC_ENTRY (900100)
 */

#include "ParagonItemGen.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "DatabaseEnv.h"
#include "CharacterDatabase.h"
#include "Chat.h"

// ============================================================
// Spec name lookup (shared via header declaration)
// ============================================================

char const* ParagonSpecName(ParagonSpec spec)
{
    switch (spec)
    {
        case SPEC_WARRIOR_ARMS:     return "Arms";
        case SPEC_WARRIOR_FURY:     return "Fury";
        case SPEC_WARRIOR_PROT:     return "Protection";
        case SPEC_PALADIN_HOLY:     return "Holy";
        case SPEC_PALADIN_PROT:     return "Protection";
        case SPEC_PALADIN_RET:      return "Retribution";
        case SPEC_DK_BLOOD:         return "Blood";
        case SPEC_DK_FROST:         return "Frost";
        case SPEC_DK_UNHOLY:        return "Unholy";
        case SPEC_SHAMAN_ELE:       return "Elemental";
        case SPEC_SHAMAN_ENHANCE:   return "Enhancement";
        case SPEC_SHAMAN_RESTO:     return "Restoration";
        case SPEC_HUNTER_BM:        return "Beast Mastery";
        case SPEC_HUNTER_MM:        return "Marksmanship";
        case SPEC_HUNTER_SURV:      return "Survival";
        case SPEC_DRUID_BALANCE:    return "Balance";
        case SPEC_DRUID_RESTO:      return "Restoration";
        case SPEC_DRUID_FERAL_TANK: return "Feral (Tank)";
        case SPEC_DRUID_FERAL_DPS:  return "Feral (DPS)";
        case SPEC_ROGUE_ASSA:       return "Assassination";
        case SPEC_ROGUE_COMBAT:     return "Combat";
        case SPEC_ROGUE_SUB:        return "Subtlety";
        case SPEC_MAGE_ARCANE:      return "Arcane";
        case SPEC_MAGE_FIRE:        return "Fire";
        case SPEC_MAGE_FROST:       return "Frost";
        case SPEC_WARLOCK_AFFLI:    return "Affliction";
        case SPEC_WARLOCK_DEMO:     return "Demonology";
        case SPEC_WARLOCK_DESTRO:   return "Destruction";
        case SPEC_PRIEST_DISC:      return "Discipline";
        case SPEC_PRIEST_HOLY:      return "Holy";
        case SPEC_PRIEST_SHADOW:    return "Shadow";
        default:                    return "None";
    }
}

// ============================================================
// Spec options per class
// ============================================================

struct ClassSpecInfo
{
    ParagonSpec specs[4];
    uint8 count;
};

static ClassSpecInfo GetClassSpecs(uint8 playerClass)
{
    switch (playerClass)
    {
        case CLASS_WARRIOR:
            return { { SPEC_WARRIOR_ARMS, SPEC_WARRIOR_FURY, SPEC_WARRIOR_PROT }, 3 };
        case CLASS_PALADIN:
            return { { SPEC_PALADIN_HOLY, SPEC_PALADIN_PROT, SPEC_PALADIN_RET }, 3 };
        case CLASS_HUNTER:
            return { { SPEC_HUNTER_BM, SPEC_HUNTER_MM, SPEC_HUNTER_SURV }, 3 };
        case CLASS_ROGUE:
            return { { SPEC_ROGUE_ASSA, SPEC_ROGUE_COMBAT, SPEC_ROGUE_SUB }, 3 };
        case CLASS_PRIEST:
            return { { SPEC_PRIEST_DISC, SPEC_PRIEST_HOLY, SPEC_PRIEST_SHADOW }, 3 };
        case CLASS_DEATH_KNIGHT:
            return { { SPEC_DK_BLOOD, SPEC_DK_FROST, SPEC_DK_UNHOLY }, 3 };
        case CLASS_SHAMAN:
            return { { SPEC_SHAMAN_ELE, SPEC_SHAMAN_ENHANCE, SPEC_SHAMAN_RESTO }, 3 };
        case CLASS_MAGE:
            return { { SPEC_MAGE_ARCANE, SPEC_MAGE_FIRE, SPEC_MAGE_FROST }, 3 };
        case CLASS_WARLOCK:
            return { { SPEC_WARLOCK_AFFLI, SPEC_WARLOCK_DEMO, SPEC_WARLOCK_DESTRO }, 3 };
        case CLASS_DRUID:
            return { { SPEC_DRUID_BALANCE, SPEC_DRUID_RESTO, SPEC_DRUID_FERAL_TANK, SPEC_DRUID_FERAL_DPS }, 4 };
        default:
            return { { SPEC_NONE }, 0 };
    }
}

// ============================================================
// Gossip NPC
// ============================================================

enum GossipActions
{
    GOSSIP_ACTION_SPEC_BASE = 1000, // action = GOSSIP_ACTION_SPEC_BASE + specId
};

class ParagonSpecNPC : public CreatureScript
{
public:
    ParagonSpecNPC() : CreatureScript("ParagonSpecNPC") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        // Get current spec
        ParagonSpec currentSpec = SPEC_NONE;
        CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARAGON_SPEC);
        stmt->SetData(0, player->GetGUID().GetCounter());
        PreparedQueryResult result = CharacterDatabase.Query(stmt);

        if (result)
            currentSpec = static_cast<ParagonSpec>((*result)[0].Get<uint8>());

        // Show current spec
        if (currentSpec != SPEC_NONE)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat(
                "Current spec: {} (changing only affects NEW items)",
                ParagonSpecName(currentSpec)), 0, 0);
        }
        else
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                "You have no spec set. Choose one to enable passive spell effects on items.", 0, 0);
        }

        // Show specs for this class
        ClassSpecInfo classSpecs = GetClassSpecs(player->getClass());

        for (uint8 i = 0; i < classSpecs.count; ++i)
        {
            ParagonSpec spec = classSpecs.specs[i];
            std::string label;

            if (spec == currentSpec)
                label = Acore::StringFormat("|cff00ff00> {} (active)|r", ParagonSpecName(spec));
            else
                label = Acore::StringFormat("Set spec: {}", ParagonSpecName(spec));

            AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
                label, 0, GOSSIP_ACTION_SPEC_BASE + spec);
        }

        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* /*creature*/, uint32 /*sender*/, uint32 action) override
    {
        CloseGossipMenuFor(player);

        // Info item (action 0) — just close
        if (action == 0)
            return true;

        // Validate action is a spec selection
        if (action < GOSSIP_ACTION_SPEC_BASE + 1 || action >= GOSSIP_ACTION_SPEC_BASE + SPEC_MAX)
            return true;

        ParagonSpec selectedSpec = static_cast<ParagonSpec>(action - GOSSIP_ACTION_SPEC_BASE);

        // Validate this spec belongs to the player's class
        ClassSpecInfo classSpecs = GetClassSpecs(player->getClass());
        bool validSpec = false;
        for (uint8 i = 0; i < classSpecs.count; ++i)
        {
            if (classSpecs.specs[i] == selectedSpec)
            {
                validSpec = true;
                break;
            }
        }

        if (!validSpec)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cffff0000[Paragon]|r Invalid spec for your class.");
            return true;
        }

        // Save to DB
        CharacterDatabasePreparedStatement* specStmt = CharacterDatabase.GetPreparedStatement(CHAR_REP_PARAGON_SPEC);
        specStmt->SetData(0, player->GetGUID().GetCounter());
        specStmt->SetData(1, static_cast<uint8>(selectedSpec));
        CharacterDatabase.Execute(specStmt);

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cff00ff00[Paragon]|r Spec set to: |cffffffff{}|r. New items will use this spec for passive spell effects.",
            ParagonSpecName(selectedSpec));

        LOG_INFO("module", "ParagonItemGen: Player {} set spec to {} ({})",
            player->GetName(), ParagonSpecName(selectedSpec), static_cast<uint8>(selectedSpec));

        return true;
    }
};

void AddParagonItemGenNPCScripts()
{
    new ParagonSpecNPC();
}
