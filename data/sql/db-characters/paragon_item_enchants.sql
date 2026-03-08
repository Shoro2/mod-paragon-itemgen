-- =============================================================
-- Paragon Item Scaling - Role and Main Stat Storage
-- Stores each character's chosen role and main stat for item gen.
-- Role can only be changed in a rested area.
-- =============================================================

CREATE TABLE IF NOT EXISTS `character_paragon_role` (
  `characterID` int unsigned NOT NULL,
  `role` tinyint unsigned NOT NULL DEFAULT 1 COMMENT '0=Tank, 1=DPS, 2=Healer',
  `mainStat` tinyint unsigned NOT NULL DEFAULT 4 COMMENT 'ITEM_MOD: 3=Agi, 4=Str, 5=Int, 6=Spi',
  PRIMARY KEY (`characterID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Item tracking for trade/mail restrictions
CREATE TABLE IF NOT EXISTS `character_paragon_item` (
  `itemGuid` int unsigned NOT NULL,
  `paragonLevel` int unsigned NOT NULL DEFAULT 0,
  `role` tinyint unsigned NOT NULL DEFAULT 0,
  `mainStat` tinyint unsigned NOT NULL DEFAULT 0,
  `combatRating1` tinyint unsigned NOT NULL DEFAULT 0,
  `combatRating2` tinyint unsigned NOT NULL DEFAULT 0,
  `statAmount` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`itemGuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
