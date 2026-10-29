# Pack Studio

An Android editor for making content packs for [d30mode](https://github.com/rishabh-mohan/d31):
the locations, traits, characters, items, books, calendar and starting point of a campaign,
edited through forms instead of raw data. It shares a packs folder with d30mode, so a pack
made here shows up in the game after it restarts.

## What it does

- **Forms for each kind of content:** Pack info, Locations (with their actions), Traits,
  Characters, Items and Books. Choices use plain names and say what they do; descriptions
  respect what the game can show; dates are typed as `YYYY/MM/DD`; pictures are picked from
  the phone and copied into the pack.
- **Events:** make your own events with a form: when and where one happens, then lines,
  choices and rewards one after another. Turn on **Advanced effects** to let a choice's
  answers give or take gold, stamina, points, items and traits, or move the player or open
  a place. A set day can wait for a time of day. A collapsible list with tick boxes
  copies in events from the original game as starting points (connected events come
  together), when a local catalog is bundled; see below.
- **Starts from a template:** a new pack begins as the bundled Workshop example, with study
  books generated for every subject and a ten-level student table (each level +1 study
  efficiency). Older packs without the table get it when opened.
- **Saves as you edit**, then loads the whole pack with the real game engine and tells you
  whether it still works.
- **Per-pack color schemes:** choose Peach, Ocean, Forest, Lavender, Rose or Slate,
  or customize icon, background, panel, accent and text colors. The palette is saved
  in `pack.json` and used by d30mode's mode card and game interface.
- **Advanced:** everything else (rules, mechanics, event scenes the form does not cover) can
  still be edited as structured data under "Advanced".

## Layout

Book-completion rewards run in d30mode, outside Pack Studio. One reward table is shared by
every pack and ships with d30mode; a pack's own `book_rewards.json` is ignored, and items a
pack lacks are left out of the table. Pack Studio has no reward section and loads no table.
The feature has no ad requirement.

| Path | What it is |
|---|---|
| `apps/pack_studio` | The Flutter app (Android only) |
| `packages/d30_engine` | The game's pure-Dart engine, used to check that packs load |
| `fixtures/` | `workshop` (the new-pack template) and `lantern` (one complete event) |

## Build and test

```
cd apps/pack_studio
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

```
cd packages/d30_engine
dart test
```

The app needs "All files access" on first use, because d30mode's packs folder is
`Android/media/dev.d30mode.d30mode/packs`.

## Not included

Art from the game this tool targets is not part of this repository. The home screen shows a
placeholder background from `apps/pack_studio/assets/placeholder/desk.png` if you supply one,
and plain paper otherwise. The original game's events are likewise not in the repository: the
dropdown of them appears only when a local, git-ignored catalog is present at
`apps/pack_studio/assets/kss16_events/`, and everything else works without it.

## Licence

No licence has been chosen yet.
