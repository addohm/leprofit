-- Leprofit_Mining: smelting. Written by hand, not by tools/gen_data.py: the built-in data has no
-- smelting, so there are no recipes here. Leprofit reads them from your smelting window instead
-- (the game may call it Mining or Smelting).
Leprofit.RegisterProfession({
	name = "Mining",
	icon = "Interface\\Icons\\Trade_Mining",
	windowNames = { "Mining", "Smelting" },
	recipes = {},
})
