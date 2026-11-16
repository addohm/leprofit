# Changelog

All notable changes to leprofit. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- 0.1.0 (2026-11-16, not yet tried in game):
  - The core addon: the Crafts tab ranks crafts by profit (lowest buyout or
    market value, less the cut and undercut, less materials at the cheaper
    of buying and crafting), with notes on where to learn each recipe and
    how many crafts pay it back, and a materials panel for n crafts. Losses,
    "doesn't sell" items and recipes with no known source are hidden by
    default; Known only lists just the recipes you know.
  - Doesn't sell asks before hiding an item, and Options lists the hidden
    items with Unhide and Unhide all.
  - Opening Leprofit opens your profession window too, so it reads your
    recipes; learning a recipe marks it known straight away.
  - Finding out why: `/leprofit why <item>` prints the whole sum; the
    materials panel shows each material's price and where it's from; the
    "Not listed" line counts losses and crafts without a price apart; an
    empty list says when your recipes haven't been read yet.
  - Auctionator's record of vendor prices counts as a vendor price.
  - The Market column (TSM's market value) is off by default, since TSM
    doesn't seem to run on Forever; Options turns it on.
  - The Options tab, `/leprofit`, the minimap button and addon menu entry,
    and a button on the profession window. Settings are per character.
  - Recording of known recipes from the profession window, and of material
    prices and patterns at vendors.
  - The Blacksmithing module: 506 recipes, 86 trainer costs and 32 patterns
    from the source addon's data.
  - Tools: the Windows install script, the release zip script, the module
    data generator, and tests with a fake client.

- Standard docs: README, CLAUDE, CHANGELOG, DEPLOY, SECURITY and ROADMAP (2026-11-16).
- Filled the docs in with what's known; open questions are marked TODO
  (2026-11-16).
- the source addon 1.2.0 as a gitignored reference copy, used with its author's
  permission (2026-11-16).
- The agreed design in ROADMAP.md, and what leprofit is in README.md and
  CLAUDE.md (2026-11-16).
