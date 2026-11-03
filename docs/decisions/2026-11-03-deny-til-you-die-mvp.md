# Deny 'til You Die MVP — decisions

Settled in one round of 10 questions on 2026-11-03. Everything else is the builder's call, recorded in the [design spec](../superpowers/specs/2026-11-03-deny-til-you-die-mvp-design.md).

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Game shape | *Papers, Please*-style day-by-day campaign. No idle, automation or prestige. | The user's brief describes days, rules unlocking over time and approve/deny at a desk. | The campaign is fun and we want replay hooks. |
| Denying | Cite the evidence: click the offending field, then the rule it breaks. Blind denials allowed but risky. | Inspect mode is the heart of *Papers, Please*. | Playtests show citing is a chore. |
| Money | Denials earn commission, approvals cost you. Nightly household ledger: rent, food, heat, and your family's medical bills, insured by your own employer. | *Papers, Please*'s family pressure, turned on the adjuster. | |
| Length | 7 days, about 35 minutes. | Room for 6–7 denial rules and an ending. | |
| Public discontent | Thresholds fire events that change the next shift. At 100% you're scapegoated and fired (game over). | The user wants discontent to rise with denials; events make it matter. | |
| Tone | Grim, grounded, deadpan. Real denial tactics played straight. Denied patients can die offscreen (obituaries, letters). Corporate-voice humor. Fictional companies, no real people. | User choice. | |
| Look | Drab *Papers, Please* desk: muted palette, pixel font, booth window with procedural faces, draggable paper documents. Built in Godot, no external art. | User choice. | An artist joins. |
| Extras | Morning newspaper, memos from management, scripted moral cases (one per day). **Not** recurring patients. | User choice. | |
| Pacing | Fixed number of patients per day, **no shift clock**. | User choice (overrode the recommended clock). | Players stall or brute-force citations. |
| Ending | The final patient on day 7 is you. Your ruling plus your record picks the ending. | Title drop. | |

## Open / deferred
- Windows export — **assumed** none: only 4.3 and 4.4.1 export templates are installed, not 4.7.2. Run from the Godot 4.7 editor.
- Old project in `deny-'til-you-die/` — **assumed** left untouched; the new game lives in `game/`.
- Music — **assumed** none. Synthesized sound effects only.
- Settings menu, rebinding and localization — **assumed** out of scope for the MVP.
