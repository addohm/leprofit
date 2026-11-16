# Roadmap

What's done for leprofit, and what's next. Update it in the same commit as the
change.

## Done

- Standard docs (2026-11-16).

## Design (agreed 2026-11-16)

Modelled on the source addon (a levelling planner), but for profit.

- **Profit per craft** = auction price x (1 - cut) - materials. The cut is 5%
  by default, undercut 0; both are settings. The deposit is left out.
- **Prices:** lowest buyout and market value side by side, ranked by lowest
  buyout (a setting switches it). Auctionator, then TSM; market value needs
  TSM. Vendor prices for materials as in the source addon.
- **Materials** cost the cheaper of buying and crafting them. Materials you
  own count at their market price; a second figure shows the gold you'd
  actually spend after what you hold.
- **Recipes:** the ones you know, and ones you could buy. Those show the
  pattern's price, where to buy it, and how many crafts pay it back.
- **Only crafts that make an item** (no enchants on gear).
- **Selling:** crafts at 0 or negative profit are hidden (a setting shows
  them). Items with no auction listing seen for some days are flagged, and
  you can mark an item as "doesn't sell" to hide it.
- **Recipe data:** the source addon's built-in data, split into the modules, plus
  what you record playing. No in-game sharing, no share website.
- **Modules:** a core addon (pricing, window, settings) plus one addon per
  profession, ticked per character in the AddOns list: Alchemy,
  Blacksmithing, Cooking, Enchanting, Engineering, First Aid, Leatherworking,
  Tailoring. Each character sees only its own professions.
- **Window:** its own window, in leboof's style (dark panel, gold border, flat
  tabs). Tabs: Crafts (ranked list; click a row for its materials, a craft
  count and Send to Auctionator), Shopping, Options.
- **Opening it:** `/leprofit`, a minimap button and the addon menu, and a
  button on the profession window.
- **Settings** are per character.
- **Tools** as in leboof: an install script for the Windows PC, a release
  script that zips the addons, and tests that run here.

## Next

1. Check Forever's auction house cut (faction and neutral) and that
   Auctionator and TSM run on Forever.
2. First build: core + the Blacksmithing module, Crafts tab only, with the
   install, release and test tools.

## Ideas

TODO: things that might be worth doing later.
