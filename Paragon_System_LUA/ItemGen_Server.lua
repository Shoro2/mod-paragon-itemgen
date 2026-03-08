-- =============================================================
-- Paragon ItemGen - Server-side AIO Registration
--
-- This script registers the client addon (ItemGen_Client.lua)
-- with AIO so it gets sent to connecting players.
--
-- The actual cursed item detection happens client-side by
-- scanning tooltip text for the "Cursed" enchantment name
-- (applied via slot 11 DBC entry ID 920001).
-- =============================================================

local AIO = AIO or require("AIO")

-- AIO.AddAddon() in ItemGen_Client.lua handles client registration.
-- This file ensures the server loads the AIO module.
