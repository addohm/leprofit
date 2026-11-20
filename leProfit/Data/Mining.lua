-- leProfit: smelting (Mining). Written by hand, not by tools/gen_data.py: the built-in data has no
-- smelting, so there are no recipes here. leProfit reads them from your smelting window instead
-- (the game may call it Mining or Smelting).
local _, ns = ...
ns.RegisterProfession({
	name = "Mining",
	icon = "Interface\\Icons\\Trade_Mining",
	windowNames = { "Mining", "Smelting" },
	recipes = {},
})
