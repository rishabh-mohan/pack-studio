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
- **Starts from a template:** a new pack begins as the bundled Workshop example, with study
  books generated for every subject.
- **Saves as you edit**, then loads the whole pack with the real game engine and tells you
  whether it still works.
- **Advanced:** everything else (events, rules, mechanics) can still be edited as structured
  data under "Advanced".

## Layout

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
and plain paper otherwise.

## Licence

No licence has been chosen yet.
