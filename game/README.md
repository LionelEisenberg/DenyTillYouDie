# Deny 'til You Die (MVP)

*Papers, Please*, but you work for a health insurer. Patients come to your window with paperwork. Deny their claims and you earn a commission; approve them and it comes out of your pay. Every denial makes the public angrier. Each morning the company gives you a new way to say no. At night you pay rent, food, heat and your family's medical bills, which go through your own employer.

Seven days, about 35 minutes, seven endings. Design: [docs/superpowers/specs/2026-11-03-deny-til-you-die-mvp-design.md](../docs/superpowers/specs/2026-11-03-deny-til-you-die-mvp-design.md).

## Play

1. Open the Godot 4.7 project manager, choose **Import**, and select `game/project.godot`.
2. Press **F5** (Run Project).

| Control | Does |
|---|---|
| Mouse | Drag papers, click buttons. Click a speech bubble to finish the line. |
| **NEXT!**, **Enter** or **N** | Call the next patient (END SHIFT once the line is empty) |
| **INSPECT** or **Space** | Inspect mode: click a rule in the rulebook, then the field that breaks it |
| **Tab** / **Shift+Tab** | Turn the manual's pages (not while inspecting) |
| **APPROVE / DENY** | Stamp the claim (final) |
| **Esc** | Leave inspect mode; otherwise open the break menu: volume, mute, fullscreen, reduce motion, how to play, quit to title |
| **M** | Mute (a note on screen says so) |
| **F11** | Toggle fullscreen |

The game autosaves each morning; **Continue** on the title screen resumes that morning. A click or any key except Esc, M, F11 and modifier keys skips the morning's day card. Settings are saved to `user://settings.cfg`.

After an ending, **RETRY DAY n** replays the last morning on file, and the last page counts how many of the seven outcomes you have seen.

## How a shift works

- Day 1 opens with two training patients: a coach outlines what to click, one step at a time. **SKIP TRAINING** turns it off.
- Read the claim form, member card and (from day 4) the itemized bill and (from day 5) the medical history. Scripted patients sometimes bring a paper of their own. The manual's tabs hold the rules, today's memo and the reference lists; the tab that is new today is marked.
- Each stamp shows what it would pay or cost you and how much discontent it adds.
- If something breaks a rule in your rulebook, cite it: INSPECT, click the rule, click the evidence. A cited denial pays full commission. A citation that finds nothing costs a $2 compliance fee.
- You can deny without citing. It pays half, and if the claim had no valid reason the member may win on appeal, costing you a legal fee.
- Approving a claim that had valid grounds earns a citation: two warnings a day, then fines.
- From day 2 Claims Integrity sets a daily denial target (55%, rising to 67% on day 7). Meeting it adds a $10 bonus to that night's pay.
- Discontent rises with denials (more for urgent and critical claims, and for children). It triggers a protest at 30%, a regulator audit at 55%, and a congressional hearing at 80%. At 100% the company fires you as a scapegoat.

| Day | New rule |
|---|---|
| 1 | R-01 Coverage lapsed |
| 2 | R-02 Out-of-network provider (Network tab) |
| 3 | R-03 Clerical mismatch |
| 4 | R-04 No prior authorization (itemized bill, Prior Auth tab) |
| 5 | R-05 Pre-existing condition (medical history) |
| 6 | R-06 Excluded service (Exclusions tab) |
| 7 | R-07 DenyBot, which denies anything at double the public cost |

## How a night works

- The ledger shows the day's pay line by line, a carbon copy of every ruling, and the bills. Rent is mandatory; everything else is a choice.
- Bills: food, heat, medicine for anyone sick, Mom's heart pills (from night 2) and Riley's controller inhaler (from night 4). The plan covers neither prescription.
- Nights 2, 4, 5 and 6 bring one household event, such as a broken furnace, a denied dentist bill or a pharmacy coupon. Skipping some of them has consequences, which the bill says.
- Two nights in a row without food, heat or a prescription make someone sick. Someone sick dies after two nights without medicine. Each family row says what tonight's choices will do before you sleep.

## Develop

Everything is GDScript. Rules live in pure classes under `core/` and content under `content/`. The UI is built in code under `ui/` and `screens/`. Numbers to tune are in `core/economy.gd`.

```bash
# Unit, flow and input tests (headless). Prints ALL TESTS PASSED.
godot --headless --path game --script res://tests/run_tests.gd

# Balance: plays 200 campaigns per strategy and prints outcomes.
godot --headless --path game --script res://tests/balance_sim.gd

# Screenshots of every screen (needs a real window). Also run it at 1600x900.
godot --path game --resolution 1920x1080 --script res://tests/screenshot_tour.gd -- <out_dir>
```

Run `godot --headless --path game --import` once after adding a new `class_name` script.

Current balance (200 runs each, after the 2026-11-03 improvement pass). The simulated household buys medicine first, a prescription once it has been missed a night, food or heat when someone is already hungry or cold, and the night's household event when tomorrow's rent stays covered. Family sick-nights counts the nights family members spend sick, per run.

| Strategy | Outcome | Family sick-nights |
|---|---|---|
| Cite every valid reason, approve the rest | Reaches day 7 in 99% of runs, ~66% discontent; promoted ~24%, so it usually just misses promotion | 0.01 |
| Same, plus DenyBot on day 7 | Promoted ~38%, scapegoated ~19% | 0.01 |
| Quota chaser: cite everything, deny a clean routine claim blind only when the day's target would slip out of reach, DenyBot on day 7 | Earns the target bonus 4.6 nights of 5; promoted ~59%, scapegoated ~41% | 0.00 |
| Kind: use the two free warnings, cite the rest | Survives ~87%, ~11% discontent; loses 0.24 family members a run | 3.75 |
| Guess citations without reading | Evicted ~82%: the $2 fee makes brute force a losing game | 1.31 |
| Approve everything | Evicted around day 3 | 2.48 |
| Deny everything blind | Scapegoated around the night of day 5, after all three discontent events | 0.11 |

A household that pays every bill spends about $136 a week on the prescriptions and household events.

## Credits

Pixel font: MatchupPro, from the original prototype's assets. Portraits, sounds, room tone, hold music, cursors and everything else are generated in code.
