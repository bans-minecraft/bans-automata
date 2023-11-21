-- A table of ores
--
-- This table lists the ores that I found in the creative block list. This should probably be
-- sufficient. We may want to increase this table with additional blocks like `minecraft:andesite`
-- (useful for Create builds).
local ORES_LIST = {
  "create:deepslate_zinc_ore",
  "create:zinc_ore",
  "mekanism:deepslate_fluorite_ore",
  "mekanism:deepslate_lead_ore",
  "mekanism:deepslate_osmium_ore",
  "mekanism:deepslate_tin_ore",
  "mekanism:deepslate_uranium_ore",
  "mekanism:fluorite_ore",
  "mekanism:lead_ore",
  "mekanism:osmium_ore",
  "mekanism:tin_ore",
  "mekanism:uranium_ore",
  "minecraft:amethyst_block",
  "minecraft:budding_amethyst",
  "minecraft:coal_block",
  "minecraft:coal_ore",
  "minecraft:copper_block",
  "minecraft:copper_ore",
  "minecraft:deepslate_coal_ore",
  "minecraft:deepslate_copper_ore",
  "minecraft:deepslate_diamond_ore",
  "minecraft:deepslate_emerald_ore",
  "minecraft:deepslate_gold_ore",
  "minecraft:deepslate_iron_ore",
  "minecraft:deepslate_lapis_ore",
  "minecraft:deepslate_redstone_ore",
  "minecraft:diamond_block",
  "minecraft:diamond_ore",
  "minecraft:emerald_ore",
  "minecraft:gold_block",
  "minecraft:gold_ore",
  "minecraft:iron_block",
  "minecraft:iron_ore",
  "minecraft:lapis_ore",
  "minecraft:nether_gold_ore",
  "minecraft:nether_quartz_ore",
  "minecraft:netherite_block",
  "minecraft:raw_copper_block",
  "minecraft:raw_gold_block",
  "minecraft:raw_iron_block",
  "minecraft:redstone_ore",
  "thermal:apatite_ore",
  "thermal:cinnabar_ore",
  "thermal:deepslate_apatite_ore",
  "thermal:deepslate_cinnabar_ore",
  "thermal:deepslate_lead_ore",
  "thermal:deepslate_nickel_ore",
  "thermal:deepslate_niter_ore",
  "thermal:deepslate_silver_ore",
  "thermal:deepslate_sulfur_ore",
  "thermal:deepslate_tin_ore",
  "thermal:lead_ore",
  "thermal:nickel_ore",
  "thermal:niter_ore",
  "thermal:silver_ore",
  "thermal:sulfur_ore",
  "thermal:tin_ore",
}

local ORES = {}
for _, name in ipairs(ORES_LIST) do
  ORES[name] = true
end

local M = {}

M.isOre = function(info)
  return ORES[info.name] ~= nil
end

return M
