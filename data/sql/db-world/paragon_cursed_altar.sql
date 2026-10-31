-- =============================================================
-- Paragon ItemGen - Cursed Altar (world database)
--
--   items    920300 Cursed Essence      paid for a sacrifice, spent on a bind
--            920301 Tainted Heartstone  the second price of a bind (how it drops is separate work)
--   object   921010 Cursed Altar        type 10 (goober), ScriptName go_paragon_cursed_altar, opens the window
--   spawn    8921011 in the Hall of the Guardian (map 736)
--   command  .paragon altar sync | sacrifice | bind
--
-- Both items are CURRENCY TOKENS exactly like the Procedural Dungeon remnants (mod_pdungeon_currency.sql): class 10,
-- BagFamily 8192 (BAG_FAMILY_MASK_CURRENCY_TOKENS), Flags 2048, stackable 2147483647. ObjectMgr::LoadItemTemplates
-- STRIPS the BagFamily bit at startup unless sCurrencyTypesStore.LookupEntry(ItemId) finds a record, and that lookup
-- is by ItemID, which only the CurrencyTypes.dbc FILE satisfies (the currencytypes_dbc rows below are keyed on ID and
-- are the checked-in copy of the same records). So the FILE needs the two records as well:
--   ID 366 / ItemID 920300 / CategoryID 43 / BitIndex 52
--   ID 367 / ItemID 920301 / CategoryID 43 / BitIndex 53
-- in the server's Data\dbc\CurrencyTypes.dbc AND the client patch (the Currency tab is drawn from the client's own copy).
-- Without them the tokens land in the bags instead of the Currency tab.
--
-- Idempotent: every DELETE takes only this file's rows, by id.
-- =============================================================

-- 1. The two currency items
DELETE FROM `item_template` WHERE `entry` IN (920300, 920301);

INSERT INTO `item_template`
    (`entry`, `class`, `subclass`, `name`, `displayid`, `Quality`, `Flags`,
     `BagFamily`, `BuyCount`, `BuyPrice`, `SellPrice`, `InventoryType`,
     `ItemLevel`, `RequiredLevel`, `maxcount`, `stackable`, `bonding`,
     `Material`, `sheath`, `Description`) VALUES
    (920300, 10, 0, 'Cursed Essence',     23291, 4, 2048, 8192, 1, 0, 0, 0, 80, 0, 0, 2147483647, 1, 2, 0,
     'Offered at the Cursed Altar in the Hall of the Guardian.'),
    (920301, 10, 0, 'Tainted Heartstone', 56465, 4, 2048, 8192, 1, 0, 0, 0, 80, 0, 0, 2147483647, 1, 2, 0,
     'Taken from the last boss of a level-80 dungeon, raid or Procedural Dungeon.');

-- 2. Their CurrencyTypes records (the checked-in copy; see the header for the FILE half)
DELETE FROM `currencytypes_dbc` WHERE `ItemID` IN (920300, 920301);
DELETE FROM `currencytypes_dbc` WHERE `ID` IN (366, 367);

INSERT INTO `currencytypes_dbc` (`ID`, `ItemID`, `CategoryID`, `BitIndex`) VALUES
    (366, 920300, 43, 52),
    (367, 920301, 43, 53);

-- 3. The altar object: a plain clickable goober (no lock, no quest, no event, no page, no spell); the script opens
--    the window on use and returns true, so the goober's own effects never run.
DELETE FROM `gameobject_template` WHERE `entry` = 921010;
INSERT INTO `gameobject_template`
    (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`,
     `Data0`, `Data1`, `Data2`, `Data3`, `ScriptName`, `VerifiedBuild`) VALUES
    (921010, 10, 2616, 'Cursed Altar', '', '', '', 1,
     0, 0, 0, 0, 'go_paragon_cursed_altar', 12340);

DELETE FROM `gameobject_template_addon` WHERE `entry` = 921010;
INSERT INTO `gameobject_template_addon` (`entry`, `faction`, `flags`, `mingold`, `maxgold`) VALUES
    (921010, 35, 0, 0, 0);

-- 4. The altar in the Hall of the Guardian (map 736), facing 0 (rotation = the quaternion of that orientation)
DELETE FROM `gameobject` WHERE `guid` = 8921011 AND `id` = 921010;
INSERT INTO `gameobject`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`,
     `position_x`, `position_y`, `position_z`, `orientation`,
     `rotation0`, `rotation1`, `rotation2`, `rotation3`,
     `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`, `Comment`) VALUES
    (8921011, 921010, 736, 0, 0, 1, 1,
     504.0, 533.8, 1212.89, 0,
     0, 0, 0, 1,
     0, 100, 1, '', 12340, 'Cursed Altar (mod-paragon-itemgen)');

-- 5. The chat commands behind the window (SEC_PLAYER)
DELETE FROM `command` WHERE `name` IN ('paragon altar sync', 'paragon altar sacrifice', 'paragon altar bind');
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('paragon altar sync', 0, 'Syntax: .paragon altar sync\r\nSends the Cursed Altar window its data: the cursed items in your bags, the items you can bind, your collection and the Cursed Essence and Tainted Heartstone balances. Works anywhere.'),
('paragon altar sacrifice', 0, 'Syntax: .paragon altar sacrifice $bag $slot\r\nAt the Cursed Altar: destroys the cursed item at that position (bag 0 = backpack, 1-4 = bags; slot counts from 1), adds its passive to your account collection and pays Cursed Essence by its quality.'),
('paragon altar bind', 0, 'Syntax: .paragon altar bind $bag $slot $enchantmentId\r\nAt the Cursed Altar: re-rolls the item at that position as a cursed item with the chosen passive from your collection (it must be in the pool of your class). Costs Cursed Essence and Tainted Heartstones by the item\'s quality.');
