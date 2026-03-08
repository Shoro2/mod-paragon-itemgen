/*
 * Paragon Item Scaling - Chat Commands
 *
 * .paragon role tank|dps|healer  - Set your role (rested area only)
 * .paragon stat str|agi|int|spi  - Set your main stat (rested area only)
 * .paragon info                  - Show current role and stat
 */

#include "ParagonItemGen.h"
#include "CommandScript.h"
#include "Chat.h"
#include "Player.h"
#include "DatabaseEnv.h"

using namespace Acore::ChatCommands;

static char const* RoleToString(ParagonRole role)
{
    switch (role)
    {
        case ROLE_TANK:   return "Tank";
        case ROLE_DPS:    return "DPS";
        case ROLE_HEALER: return "Healer";
        default:          return "Unknown";
    }
}

static char const* MainStatToString(uint8 modVal)
{
    switch (modVal)
    {
        case 4: return "Strength";
        case 3: return "Agility";
        case 5: return "Intellect";
        case 6: return "Spirit";
        default: return "Unknown";
    }
}

static bool IsInRestedArea(Player* player)
{
    return player->HasPlayerFlag(PLAYER_FLAGS_RESTING);
}

static bool HandleParagonRoleCommand(ChatHandler* handler, Tail args)
{
    Player* player = handler->GetPlayer();
    if (!player)
        return false;

    if (!IsInRestedArea(player))
    {
        handler->PSendSysMessage("|cffff0000[Paragon]|r You must be in a rested area (city/inn) to change your role.");
        return true;
    }

    std::string arg(args);
    // Trim whitespace
    while (!arg.empty() && arg.front() == ' ') arg.erase(arg.begin());
    while (!arg.empty() && arg.back() == ' ') arg.pop_back();

    ParagonRole role;
    if (arg == "tank")
        role = ROLE_TANK;
    else if (arg == "dps")
        role = ROLE_DPS;
    else if (arg == "healer")
        role = ROLE_HEALER;
    else
    {
        handler->PSendSysMessage("|cffff0000[Paragon]|r Usage: .paragon role tank|dps|healer");
        return true;
    }

    // Update or insert role, preserve mainStat
    CharacterDatabase.Execute(
        "INSERT INTO character_paragon_role (characterID, role) VALUES ({}, {}) "
        "ON DUPLICATE KEY UPDATE role = {}",
        player->GetGUID().GetCounter(), static_cast<uint8>(role), static_cast<uint8>(role));

    handler->PSendSysMessage("|cff00ff00[Paragon]|r Role set to: |cffffffff{}|r. New items will use this role.",
        RoleToString(role));
    return true;
}

static bool HandleParagonStatCommand(ChatHandler* handler, Tail args)
{
    Player* player = handler->GetPlayer();
    if (!player)
        return false;

    if (!IsInRestedArea(player))
    {
        handler->PSendSysMessage("|cffff0000[Paragon]|r You must be in a rested area (city/inn) to change your main stat.");
        return true;
    }

    std::string arg(args);
    while (!arg.empty() && arg.front() == ' ') arg.erase(arg.begin());
    while (!arg.empty() && arg.back() == ' ') arg.pop_back();

    uint8 mainStatMod;
    if (arg == "str" || arg == "strength")
        mainStatMod = 4; // ITEM_MOD_STRENGTH
    else if (arg == "agi" || arg == "agility")
        mainStatMod = 3; // ITEM_MOD_AGILITY
    else if (arg == "int" || arg == "intellect")
        mainStatMod = 5; // ITEM_MOD_INTELLECT
    else if (arg == "spi" || arg == "spirit")
        mainStatMod = 6; // ITEM_MOD_SPIRIT
    else
    {
        handler->PSendSysMessage("|cffff0000[Paragon]|r Usage: .paragon stat str|agi|int|spi");
        return true;
    }

    CharacterDatabase.Execute(
        "INSERT INTO character_paragon_role (characterID, mainStat) VALUES ({}, {}) "
        "ON DUPLICATE KEY UPDATE mainStat = {}",
        player->GetGUID().GetCounter(), mainStatMod, mainStatMod);

    handler->PSendSysMessage("|cff00ff00[Paragon]|r Main stat set to: |cffffffff{}|r. New items will use this stat.",
        MainStatToString(mainStatMod));
    return true;
}

static bool HandleParagonInfoCommand(ChatHandler* handler, Tail /*args*/)
{
    Player* player = handler->GetPlayer();
    if (!player)
        return false;

    QueryResult result = CharacterDatabase.Query(
        "SELECT role, mainStat FROM character_paragon_role WHERE characterID = {}",
        player->GetGUID().GetCounter());

    if (!result)
    {
        handler->PSendSysMessage("|cffff0000[Paragon]|r No role set. Use .paragon role tank|dps|healer");
        return true;
    }

    uint8 role = (*result)[0].Get<uint8>();
    uint8 mainStatMod = (*result)[1].Get<uint8>();

    handler->PSendSysMessage("|cff00ff00[Paragon Item Scaling]|r");
    handler->PSendSysMessage("  Role: |cffffffff{}|r", RoleToString(static_cast<ParagonRole>(role)));
    handler->PSendSysMessage("  Main Stat: |cffffffff{}|r", MainStatToString(mainStatMod));

    // Show combat rating pool
    char const* poolDesc;
    switch (static_cast<ParagonRole>(role))
    {
        case ROLE_TANK:   poolDesc = "Dodge, Parry, Defense, Block, Hit, Expertise"; break;
        case ROLE_DPS:    poolDesc = "Crit, Haste, Hit, ArmorPen, Expertise, AP, SP"; break;
        case ROLE_HEALER: poolDesc = "Crit, Haste, Spell Power, MP5"; break;
        default:          poolDesc = "Unknown"; break;
    }
    handler->PSendSysMessage("  Combat Rating Pool: |cffffffff{}|r", poolDesc);

    return true;
}

// ============================================================
// CommandScript registration
// ============================================================

class ParagonItemGenCommandScript : public CommandScript
{
public:
    ParagonItemGenCommandScript() : CommandScript("ParagonItemGenCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable paragonSubCommands =
        {
            { "role", HandleParagonRoleCommand, SEC_PLAYER, Console::No },
            { "stat", HandleParagonStatCommand, SEC_PLAYER, Console::No },
            { "info", HandleParagonInfoCommand, SEC_PLAYER, Console::No },
        };

        static ChatCommandTable commandTable =
        {
            { "paragon", paragonSubCommands },
        };

        return commandTable;
    }
};

void AddParagonItemGenCommandScripts()
{
    new ParagonItemGenCommandScript();
}
