-- =============================================================
-- Paragon Item Scaling - Item Enchantment Tracking
-- Tracks which items have paragon enchantments and the
-- paragon level at which they were enchanted.
-- Used for trade/mail/AH restriction enforcement.
-- =============================================================

CREATE TABLE IF NOT EXISTS `character_paragon_item` (
  `itemGuid` int unsigned NOT NULL,
  `paragonLevel` int unsigned NOT NULL DEFAULT 0,
  `profileId` tinyint unsigned NOT NULL DEFAULT 0,
  `statAmount` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`itemGuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
