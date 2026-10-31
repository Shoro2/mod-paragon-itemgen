-- =============================================================
-- Paragon ItemGen - Cursed Altar: the account-wide passive collection
-- A passive (slot 11 enchantment 950001-950999) joins the collection when a cursed item that carries it is
-- sacrificed at the altar. The collection has no effect by itself; it is the list of passives a player may bind
-- to an item at the altar (src/ParagonItemGenAltar.cpp).
-- =============================================================

CREATE TABLE IF NOT EXISTS `account_paragon_passive_collection` (
  `accountId` int unsigned NOT NULL,
  `enchantmentId` int unsigned NOT NULL COMMENT 'spellitemenchantment_dbc ID of the passive, 950001-950999',
  `firstUnlocked` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `sacrificed` int unsigned NOT NULL DEFAULT 1 COMMENT 'how many items carrying it were sacrificed',
  PRIMARY KEY (`accountId`, `enchantmentId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
