# Deny 'til You Die (MVP)

*Papers, Please*, but you work for a health insurer. Patients come to your window with paperwork. Deny their claims and you earn a commission; approve them and it comes out of your pay. Every denial makes the public angrier. Each morning the company gives you a new way to say no. At night you pay rent, food, heat and your family's medical bills, which go through your own employer.

Seven days, about 35 minutes, five endings. Design: [docs/superpowers/specs/2026-11-03-deny-til-you-die-mvp-design.md](../docs/superpowers/specs/2026-11-03-deny-til-you-die-mvp-design.md).

## Play

1. Open the Godot 4.7 project manager, choose **Import**, and select `game/project.godot`.
2. Press **F5** (Run Project).

| Control | Does |
|---|---|
| Mouse | Drag papers, click buttons |
| **NEXT!** | Call the next patient |
| **INSPECT** or **Space** | Inspect mode: click a rule in the rulebook, then the field that breaks it |
| **Esc** | Leave inspect mode |
| **APPROVE / DENY** | Stamp the claim (final) |
| **F11** | Toggle fullscreen |

The game autosaves each morning; **Continue** on the title screen resumes that morning.

## How a shift works

- Read the claim form, member card and (from day 4) the itemized bill and (from day 5) the medical history.
- If something breaks a rule in your rulebook, cite it: INSPECT, click the rule, click the evidence. A cited denial pays full commission. A citation that finds nothing costs a $2 compliance fee.
- You can deny without citing. It pays half, and if the claim had no valid reason the member may win on appeal, costing you a legal fee.
- Approving a claim that had valid grounds earns a citation: two warnings a day, then fines.
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

## Develop

Everything is GDScript. Rules live in pure classes under `core/` and content under `content/`. The UI is built in code under `ui/` and `screens/`. Numbers to tune are in `core/economy.gd`.

```bash
# Unit, flow and input tests (headless). Prints ALL TESTS PASSED.
godot --headless --path game --script res://tests/run_tests.gd

# Balance: plays 200 campaigns per strategy and prints outcomes.
godot --headless --path game --script res://tests/balance_sim.gd

# Screenshots of every screen (needs a real window).
godot --path game --resolution 1920x1080 --script res://tests/screenshot_tour.gd -- <out_dir>
```

Run `godot --headless --path game --import` once after adding a new `class_name` script.

Current balance (200 runs each):

| Strategy | Outcome |
|---|---|
| Cite every valid reason, approve the rest | Always reaches day 7, ~67% discontent; usually just misses promotion |
| Same, plus DenyBot on day 7 | Promoted ~38%, scapegoated ~18% |
| Kind: use the two free warnings, cite the rest | Survives ~87%, ~12% discontent |
| Guess citations without reading | Evicted ~70%: the $2 fee makes brute force a losing game |
| Approve everything | Evicted around day 3 |
| Deny everything blind | Scapegoated on the night of day 5, after all three discontent events |

## Credits

Pixel font: MatchupPro, from the original prototype's assets. Portraits, sounds and everything else are generated in code.
