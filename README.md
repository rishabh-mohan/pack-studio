# Pack Studio

Working name for a desktop editor that creates and edits content packs for
[d30mode](../d30mode) (events, items, traits, characters, locations, colleges,
art) and hands them to the game to play. Status: **planning only — no code yet.**

This folder was split out of d30mode on 2026-10-26 so the editor can be built
as its own project. d30mode stays the runtime and the source of truth for the
pack format; when `docs/` and d30mode's code disagree, the code wins.

## Layout

| Path | What it is |
|---|---|
| [docs/](docs/README.md) | The foundation: product brief, architecture, pack contract, event authoring, assets, validation, install/test, open questions, starter JSON Schemas |
| [fixtures/](fixtures) | `workshop` (copy of d30mode's example pack: the "new pack" template) and `lantern` (workshop plus one complete event); see docs/09 |
| [reference/d30mode-docs/](reference/d30mode-docs) | Snapshots of d30mode's `PACK-FORMAT.md`, `MODULAR-PACKS.md`, `EVENT-PRESENTATION.md` (the docs link to these) |
| [packages/d30_engine/](packages/d30_engine) | **Pure-Dart engine package** (17 files, ~9k lines, no Flutter, no `dart:io`) extracted from d30mode `lib/engine/` on 2026-10-26. Runs under plain `dart test`; its tests load [fixtures/workshop](fixtures/workshop) and pass (8). Only change from d30mode's copy: `SetupOwnership.fromAccount` and the account imports were dropped (they need the Flutter-bound account store) |
| [reference/d30mode-tests/](reference/d30mode-tests) | d30mode's `engine_test.dart` (200-run seeded simulation) and `custom_pack_test.dart`, still Flutter-style; port to the package as needed |

## Not copied (deliberately)

- KSS packs and art (`packs/kss16`, `packs/kss20`, `assets/images`): content
  rights, local-use only. See docs/01-PRODUCT-BRIEF.md.
- The four Flutter-bound engine files (`account_store`, `content_source`,
  `record_store`, `save_store`) and all game UI: they stay in d30mode.
- Save/account/History/D-Day docs: runtime concerns unrelated to authoring.
## Keeping in step with d30mode

The engine package and doc snapshots are frozen at 2026-10-26. d30mode still
has its own copy of these files under `lib/engine/`; nothing depends on
`d30_engine` yet. Until d30mode switches to it (path dependency, drop the
duplicated files, keep a small `SetupOwnership.fromAccount` extension in the
app), changes to the loader must be mirrored by hand (diff before building).
Test packs headlessly with `cd packages/d30_engine && dart test`.

## Start here

1. docs/09-BUILD-PLAN.md (the order of work), then 01-PRODUCT-BRIEF.md → 02-ARCHITECTURE.md
2. docs/08-OPEN-QUESTIONS.md — decisions blocking the first line of code
3. docs/03-PACK-CONTRACT.md and 04-EVENT-AUTHORING.md when building editors
