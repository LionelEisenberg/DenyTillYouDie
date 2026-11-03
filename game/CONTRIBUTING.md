# Working on Deny 'til You Die

How the code is organized, the conventions it follows, and the traps already found. Read this before changing anything.

## Architecture

| Folder | What lives there | Rule |
|---|---|---|
| `core/` | Game rules: claims, rule checker, generator, economy, shift and night logic, news writer, endings, run state, dates, `Fmt` (money, plurals, name lists) | Pure static functions or `RefCounted`. No nodes, no scenes, no autoload access. Everything here is unit-tested headless. |
| `content/` | Tables and text: procedures, diagnoses, providers, names, rules, patient lines, news pools, scripted cases | Data plus tiny helpers. |
| `ui/` | Widgets built in code: documents, field rows, rulebook, portraits, stamps, meters, palette and theme | Each widget is a `class_name` script. No game rules. |
| `screens/` | One `ScreenBase` per screen, plus `main.gd`, the enum state machine that swaps them | Screens call `GameState`; they emit `done(payload)` and `main.gd` decides what's next. |
| `autoload/` | `GameState` (the run, today's claims, save/load) and `Sfx` (synthesized sounds) | Keep autoloads thin; rules belong in `core/`. |
| `tests/` | Custom headless runner, unit/flow/input tests, balance simulation, screenshot tour | See Testing. |

Data flow for one patient: `GameState.begin_day()` generates `claims_today` → the desk shows a `Claim` through `Paperwork` documents → a citation is checked by `RuleChecker.check_citation` → the stamp calls `GameState.decide()` → `ShiftLogic.apply_decision` updates money, discontent and stats → at night `NightLogic.close_shift` and `apply_ledger` resolve appeals, deaths, family, events and write tomorrow's paper and memo.

Signals go up, calls go down. There is no global event bus.

## Conventions

- **Static typing everywhere:** typed variables, typed arrays, return types. Tabs for indentation, two blank lines between functions.
- **UI is built in code.** Use `UiTheme.label()`, `UiTheme.para()` (wrapping), `UiTheme.button()`, `UiTheme.rect()`, `UiTheme.flat_box()` and `UiTheme.paper_box()`. Colors come from `Palette`, never ad-hoc hex values in widgets.
- **Font sizes are 16, 24, 32, 48 or 96 only** (`UiTheme.SIZE_*`). MatchupPro's design pixel is 1/16 em, so 16/32/48/96 land on whole pixels at 1:1. `UiTheme.fit_font_to_scale()` turns antialiasing off at whole-number canvas scales (crisp pixels) and on at fractional ones (the default 1600x900 window), where unsmoothed pixel text turns into blobs. Evidence text (bill lines, history dates, treatment) is 24 px so it stays readable when scaled down.
- **Glyphs:** MatchupPro has ASCII plus é. No em dashes, ™, curly quotes, ÷, arrows or bullets in game text. `test_content.gd::test_font_covers_all_game_text` fails if one sneaks in.
- **Mouse:** decorative nodes use `MOUSE_FILTER_IGNORE`. A `DocumentView` drags from event-local positions; its `FieldRow`s pass clicks through unless inspect mode is on.
- **Keyboard:** desk buttons take no focus (`FOCUS_NONE`), because Space is both inspect and `ui_accept`. Menu screens grab focus in `on_shown()`, which `main.gd` calls after the fade-in, never in `_ready()`: a key pressed during a fade must not press a button the player hasn't seen. The fade blocks the mouse while it's visible.
- **Money and plurals:** format money with `Fmt.money()` (`UiTheme.money()` delegates to it), counts with `Fmt.plural()`, name lists with `Fmt.join_names()`.
- **Containers reset child rotation and scale.** To tilt something inside a container, put it in a plain `Control` holder.
- **Determinism:** randomness comes from `RandomNumberGenerator`s seeded from the run seed (plus day and purpose), so a reload replays the same day.
- **Never name an enum `Expression`.** It collides with a built-in class (`PortraitView` uses `Mood`).

## Tone

Grim, grounded, deadpan. Real insurance tactics played straight. Humor lives only in the corporate and media voice: memos, slogans, the paper. Patients speak plainly and briefly. No character announces that denying claims is wrong. No real people, companies or events, and no real-world violence. Deaths happen offscreen (obituaries, letters).

## Testing

```bash
# from the repo root
godot --headless --path game --import                              # after adding a class_name script
godot --headless --path game --script res://tests/run_tests.gd     # all tests; prints ALL TESTS PASSED
godot --headless --path game --script res://tests/run_tests.gd -- desk   # only tests whose name contains "desk"
godot --headless --path game --script res://tests/balance_sim.gd   # economy outcomes per strategy
godot --path game --resolution 1920x1080 --script res://tests/screenshot_tour.gd -- <out_dir>
```

- A test file is `tests/test_*.gd`, `extends RefCounted`, with `var t: TestContext` and `func test_*()` methods. Use `t.ok`, `t.eq`, `t.near`. Optional `before_each()`/`after_each()`. Tests may `await`.
- Any engine or script error raised during a test fails it (an `OS.add_logger` Logger catches them).
- Tests that save use `gs.save_path_override = TestContext.save_path()`, a per-process path, so suites can run in parallel.
- Screens have a `fast` flag that skips waits and tweens; tests set it.
- Pushing mouse events: the headless window is 64x64, so convert canvas positions with `tree.root.get_final_transform() * (control.get_global_transform_with_canvas() * local_pos)`. See `test_desk_input.gd`.
- A script passed with `--script` is compiled before autoloads exist, so it can't reference `GameState` by name. Load such code at runtime (that's why `screenshot_tour.gd` loads `tour_runner.gd`).
- `.godot/` is gitignored. Commit the `.uid` and `.import` files Godot generates.

## Balance

Every number lives in `core/economy.gd`. After changing anything that moves money or discontent, run `balance_sim.gd` and check the README's balance table still holds.
