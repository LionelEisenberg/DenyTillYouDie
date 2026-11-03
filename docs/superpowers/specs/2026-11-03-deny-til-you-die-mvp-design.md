# Deny 'til You Die — MVP design

2026-11-03. Supersedes the idle/ascension direction in [game-concept.md](../../game-concept.md) for this build. Decisions the user made are in the [decision record](../../decisions/2026-11-03-deny-til-you-die-mvp.md); everything marked *(builder's call)* was decided without them.

## Intent

*Papers, Please*, but you are a health-insurance claims adjuster. Patients come to your window with paperwork. You approve or deny. Denying pays you; approving costs you. Public discontent rises with every denial. Each day the company hands you a new way to deny coverage. At home, your family needs rent, food, heat and medicine, and their medical claims go through your own employer.

The satire is in the incentives: the cruel play is the profitable play, and the game never lectures. The numbers, the memos and the morning paper do the talking.

**Success:** a player can open the project in Godot 4.7, press Play, and get through a 7-day campaign (about 35 minutes) to one of five endings, understanding why each denial paid what it did.

### Goals
- A complete, playable 7-day campaign with a tutorialized day 1.
- *Papers, Please*'s core feel: read documents, cross-check them against a rulebook, cite a discrepancy, stamp.
- One new denial rule per day, so the space of deniable claims grows.
- A night ledger with real pressure (family health, eviction).
- Morning newspaper and management memos that react to what you did.
- One hand-written moral case per day, and the day-7 twist where the last patient is you.

### Non-goals
- Idle mechanics, automation, upgrades, prestige.
- A shift clock (the user chose a fixed patient count per day).
- Patients who return to the window (the user deselected recurring patients). Consequences show up in the paper and memos only.
- Music, settings menu, key rebinding, localization, a Windows export.

### Anti-goals (failure even if it works)
- Preachy or winking. No character tells the player denial is bad. Deadpan corporate voice throughout.
- Referencing real people, real companies, or real-world violence.
- Citation by brute force: clicking every field/rule pair until one sticks must cost something.
- Unreadable documents. This is a reading game; text must be crisp and legible at 1080p.

## World

- **Employer:** Benevolence Mutual. Slogan: *"We care.\*"* Footnote: *\*Terms, conditions and exclusions apply.*
- **Boss:** R. Hargrove, Regional Director, Claims Integrity. Signs every memo.
- **Newspaper:** *The Daily Ledger*.
- **You:** Adjuster #4471. You type your name on the employment agreement at the start; it appears on your own claim on day 7. Default if blank: "J. Doe".
- **Family:** Partner (Sam), Child (Riley), Mother. Gender-neutral names; no pronouns needed.
- **Calendar:** Day 1 is Monday 03/02/2026; day 7 is Sunday 03/08/2026. "Benevolence Mutual operates seven days a week. Illness doesn't take weekends off, and neither do we." Dates are shown MM/DD/YYYY.

## Day structure

```
Title → Employment agreement (name) → [Day loop ×7] → Ending
Day loop: Morning paper (days 2–7) → Memo → Shift (N patients) → Night ledger
```

Patients per day: 5, 6, 7, 7, 8, 8, then 7 plus you on day 7 (49 total).

Game over can interrupt the loop at the night check (eviction, or discontent ≥ 100%, revealed on the next morning's front page).

**Day 7 has no night ledger** *(builder's call)*. Your own claim is the last thing that happens; the ending follows immediately. Day-7 pay only shows up in the end-screen stats, appeals from day 7 are never resolved, and the family epilogue uses the state after night 6. Eviction cannot override a day-7 ending.

## The desk (shift screen)

Layout, left to right:

- **Top bar:** day and date, patient count ("Patient 3 of 7"), discontent meter (0–100%), today's pay so far.
- **Booth (left column):** the window. The patient's procedural portrait, a speech bubble, and a **NEXT!** button that calls the next patient (*Papers, Please*'s loudspeaker).
- **Desk (the rest):** paper documents the player drags around and overlaps. A stamp tray (APPROVE, DENY) and an INSPECT toggle sit along the bottom edge.
- **Hint strip:** contextual one-line hints, used heavily on day 1.

### Documents

Documents slide onto the desk when a patient arrives and leave after the stamp. Every field on every document is clickable in inspect mode, so which fields are clickable gives nothing away.

| Document | From day | Fields |
|---|---|---|
| Claim form (BM-1500) | 1 | Claim #, patient name, date of birth, member ID, provider, date of service, diagnosis, treatment summary, amount, priority (ROUTINE / URGENT / CRITICAL), prior auth # (from day 4) |
| Insurance card | 1 | Name, member ID, date of birth, plan, member since, coverage through |
| Rulebook | 1 | Pages: procedure, denial rules (clickable rows), then reference pages as they unlock: network directory (day 2), prior-authorization list (day 4), exclusions list (day 6), DenyBot (day 7) |
| Itemized bill | 4 | Provider, date of service, 2–4 line items (procedure, body part, cost), total |
| Medical history | 5 | Name, date of birth, 2–4 dated entries |

The rulebook stays on the desk across patients; the other documents are per patient.

### Denial rules

One per day. Codes appear on the DENIED stamp.

| Day | Code | Rule | Violation | Evidence the player can click |
|---|---|---|---|---|
| 1 | R-01 | Coverage lapsed | Card's *coverage through* is before the claim's *date of service* | Card coverage-through, or claim date of service |
| 2 | R-02 | Out-of-network provider | Claim provider is not in the network directory | Claim provider (or bill provider) |
| 3 | R-03 | Clerical mismatch | Name, member ID or date of birth differs between claim and card | Either mismatched field |
| 4 | R-04 | No prior authorization | A billed procedure is on the prior-auth list and the claim's prior auth # is blank | Claim prior-auth field, or that bill line |
| 5 | R-05 | Pre-existing condition | A history entry for the claimed condition is dated before the card's *member since* | That history entry |
| 6 | R-06 | Excluded service | A bill line is on the exclusions list | That bill line |
| 7 | R-07 | Algorithmic determination (DenyBot™) | Always applies | A RUN DENYBOT button on the rulebook page; no evidence needed |

Violations are computed from the claim data by pure rule-checker functions, not stored as flags, so accidental violations count too. The generator aims for a target share of **randomly generated** claims with at least one citable violation: 40% on day 1, then 50, 55, 60, 60, 65, 65%. The rest are clean. Scripted cases always carry a valid reason and sit on top of that target *(builder's call)*.

R-07 never counts as a "valid reason" for citations on approval or for appeal checks; otherwise every day-7 approval would be fined and every blind denial would be safe.

### Inspect and cite

1. Toggle INSPECT (button, or Space). Clickable items get a hover outline.
2. Select a rule row in the rulebook and a field on any document, in either order.
3. **Valid:** both items outlined in red, a red line joins them, and the banner reads `VIOLATION: Coverage lapsed (R-01)`. The DENY stamp now carries that code. Inspect mode turns off.
4. **Invalid:** "No violation found." Costs a **$2 compliance review fee**, which stops brute force.

### Decisions

Stamping is final. After the stamp, the patient reacts (line and expression), the documents leave, and the player presses NEXT!.

| Decision | Pay | Discontent | Afterwards |
|---|---|---|---|
| Cited denial | Commission | + by priority | — |
| Blind denial (no citation) | Half commission | + by priority | If the claim had **no** valid reason: 50% chance it's appealed and overturned that night (−$20 legal fee, +2% discontent). If it had one, legal backs you. |
| Approve, claim was clean | Approval deduction | − by priority | — |
| Approve, claim had a citable violation | Approval deduction | − by priority | A citation slip prints immediately. The first two each day are warnings; after that, −$10 each. |

Starting values, to be tuned by simulation:

| Priority | Commission (cited) | Blind | Approval deduction | Discontent if denied | Discontent if approved |
|---|---|---|---|---|---|
| Routine | $15 | $7 | −$5 | +2 | −1 |
| Urgent | $25 | $12 | −$10 | +4 | −2 |
| Critical | $40 | $20 | −$15 | +7 | −3 |

Patients under 16 multiply discontent from denial by 1.5. DenyBot denials count as cited but double the discontent.

Immediate feedback: floating `+$25` / `−$10` / `+4%` near the top bar on each decision.

### Patients

Generated from a seeded RNG (seed per run and day, so a reload replays the same day):

- Name (diverse first and last name lists), age 1–90, date of birth matching the age.
- A diagnosis from a table. Each entry has a condition key (for pre-existing checks), body part, priority, 2–4 procedures with costs, and flags (`prior_auth`, `excluded`).
- Portrait features seeded from the patient.
- An arrival line chosen by priority (parent's voice if under 16) and a reaction line chosen by priority and decision. Grim and plain: "I've paid my premiums for eleven years." / "..." / "Oh, thank God."

If denied, critical patients have a 40% chance and urgent patients a 10% chance of dying offscreen; deaths appear as obituaries in the next morning's paper and add +4% discontent each.

### Scripted moral cases

One per day, inserted at a fixed slot. Each is valid to deny under that day's new rule.

| Day | Patient | Case | Outcome hooks |
|---|---|---|---|
| 1 | Walt Brennan, 58 | Heart attack. Card lapsed three days earlier: "My premium payment bounced while I was in the ICU." | Denied: obituary next morning, then a letter from his daughter with the memo. |
| 2 | Lily Navarro, 7 | Leukemia, treated at the only pediatric oncology center in the state, which is out of network. Her father speaks. | Denied: "Fundraiser for 7-year-old stalls at $3,210." Approved: company stock dips 0.4% "on higher-than-expected claims costs." |
| 3 | Dale Pruitt, 44 | Your coworker from Desk 12. Appendectomy. The hospital spelled his name "Dail". | Denied: memo notes Dale has transferred to another floor. |
| 4 | Eleanor Hargrove, 79 | Your boss's mother. Hip replacement, no prior auth. Sticky note: "Handle this one personally. —R.H." | Approving is **not** a citation. Denied: next memo docks you $40 for "attitude". Approved: "Thank you. This conversation never happened." |
| 5 | Priya Raman, 31 | Pregnancy complications. History: pregnancy confirmed before her enrollment date. | Denied: paper runs a short piece on pregnancy exclusions. |
| 6 | Marcus Bell, 52 | Stage IV colon cancer. Requests an experimental immunotherapy that's on the exclusions list. "It's the only thing left." | Denied: obituary in the day-7 paper. |
| 7 | You | See [Endings](#endings). | |

## Public discontent

Starts at 10%. Changes as above, plus −2% each night ("the public forgets"). Crossing a threshold for the first time fires an event: it leads the next morning's paper and changes the next shift.

| Threshold | Event | Next-shift effect |
|---|---|---|
| 30% | Protest outside headquarters | Every denial adds +1% extra discontent |
| 55% | Investigative report | Regulator audit: blind denials of claims with no valid reason are always overturned |
| 80% | Congressional hearing announced | "Compassion Day": approvals cost nothing and lower discontent twice as much |
| 100% | Scapegoated | Game over |

## Night ledger

A paper ledger sheet.

- **Income:** base pay $30, commissions, approval deductions, citation fines, compliance fees, legal fees from overturned appeals.
- **Expenses:** rent $30 (mandatory), food $15, heat $10, medicine $25 per sick family member (checkboxes, all checked by default when affordable).
- **Family:** status per member (Healthy, Hungry, Cold, Sick, Dead).
- **Rules:** unpaid food for two nights in a row → sick; same for heat. Sick and no medicine for two nights → dies. Medicine cures. Dead members cost nothing.
- **Scripted:** night 3, Riley has an asthma attack. The ledger shows the hospital bill was denied by Benevolence Mutual under R-05 (pre-existing condition); Riley is sick and needs medicine.
- **Eviction:** if savings minus rent is below $0, game over.
- Starting savings: $50.

## Morning paper and memo

**Paper (days 2–7):** masthead, date, one lead headline, 2–3 smaller items. Lead priority: threshold event, then scripted outcome, then a generic headline for the current discontent band. Smaller items: obituaries of patients who died after denial, the Benevolence Mutual stock price (up with yesterday's denial rate), and a flavor item from a pool.

**Memo (every day):** from R. Hargrove. Announces the new rule and adds its rulebook page, reports yesterday's citations, overturned appeals and fines, explains any event effect for today, and carries scripted notes. Day 1's memo is the tutorial: the job, R-01, how to inspect and cite, what blind denials risk, that approvals cost you, and that rent is due tonight.

Letters from family (a denied scripted patient's relative) appear as a second page after the memo.

## Endings

| Ending | Trigger | Outcome |
|---|---|---|
| Scapegoated | Discontent ≥ 100% at a night check, or after your own claim on day 7 | Front page: "Benevolence Mutual fires 'rogue' adjuster [Name]." Stock rises. Your replacement's targets are 10% higher. |
| Evicted | Can't cover rent at a night check | Classified notice; you and your family are out. |
| Fired | Day 7: you approve your own claim | Conflict of interest. Coverage rescinded retroactively. You're alive, unemployed, and owe the full bill. |
| Employee of the Month | Day 7: you deny your own claim and your denial rate is below 60% | You die. Posthumous Employee of the Month; a plaque by the break room. |
| Promoted | Day 7: you deny your own claim and your denial rate is 60% or higher | Promoted to Regional Director. The Executive Plan covers everything. Your first directive raises the denial target. |

**Denial rate** = claims denied ÷ claims processed, over the whole run, excluding your own claim. The promotion line (starting at 60%) is tuned by the balance simulation so a player who cites every valid reason and approves everything else lands *just below* it, and has to push past it with DenyBot or blind denials *(builder's call)*: following the rules is not enough to be promoted.

**Your claim (day 7, last patient):** you collapsed and were taken to the nearest ER, which is out of network (R-02). Your history shows hypertension noted at your pre-employment physical, before your member-since date (R-05). Amount: about $61,000. The window shows your own portrait (seeded from your name), pale. No dialogue, just "...".

Each ending screen shows a front page, a short epilogue that mentions your family's state, and run stats: claims processed, denied, approved, deaths in the paper, money earned, final discontent.

## Save

Autosave at the start of each morning. The title screen offers Continue (resumes that morning) and New Game. One save slot *(builder's call)*.

## Look and feel

- Muted *Papers, Please* palette: olive and slate background, beige paper, desaturated red for DENY, desaturated green for APPROVE, near-black ink.
- A pixel font, crisp at 1080p. The existing project's fonts may be reused if one is a pixel font *(builder's call)*.
- Portraits drawn in code from chunky blocks: head shape, skin tone, hair, eyes, mouth, glasses, clothing, age cues. Expressions: neutral, worried, relieved, devastated.
- Stamps land with a quick scale-in, a thud and a small shake.
- Synthesized sound effects (stamp, paper, bell, buzzer). No music.

## Architecture (builder's calls)

- **Godot 4.7, GDScript with static types, Compatibility renderer** (a 2D UI game gains nothing from Forward+). The new project lives in `game/`, with a `.gitignore` for `.godot/`. The old project is untouched.
- **Pure logic in `RefCounted` classes** with no scene dependencies: claim generator, rule checker, economy, night resolver, news/memo writer, ending resolver. These run headless under test.
- **One `GameState` autoload** owns run state (day, money, discontent, family, stats, flags) and save/load. A small `Sfx` autoload synthesizes sounds.
- **Content as GDScript constants** (diagnoses, procedures, providers, names, lines, scripted cases, newspaper pools) in `class_name` scripts. Rejected: `.tres` Resources per item. They're nicer for Inspector editing, but hand-authoring hundreds of entries as `.tres` without the editor is slow and error-prone. Revisit if a designer joins.
- **Screen flow as an enum state machine in a `Main` scene** that swaps one screen at a time (title, agreement, paper, memo, desk, ledger, ending). Rejected: node-based state machines, which are overkill for a linear loop.
- **UI built in code.** Screens and widgets are script classes that build their Control trees with containers; only `main.tscn` exists as a scene. Rejected: large hand-written `.tscn` layouts, which are fragile to author without the editor. Cost: layouts are less tweakable in the editor.
- **Signals up, calls down.** Documents emit `evidence_clicked(key)`, the rulebook emits `rule_clicked(id)`, and the desk coordinates. No global event bus.

## Testing

- A headless test runner (`godot --headless --script`) with plain asserts: generator consistency, every rule checker on positive and negative cases, citation validation, economy deltas, night resolution, endings, save/load round trip.
- A balance simulation that plays the full campaign with scripted strategies (approve everything, deny everything blind, cite-or-approve, cite-or-blind-deny-routine) and prints savings, discontent and ending per strategy. Tune until cite-or-approve survives with discontent around 60–85%, deny-everything gets scapegoated around day 4, and approve-everything is evicted around day 4–5.
- Screenshot passes of every screen, rendered in a real window, to check layout and legibility.

## Left to the builder
- Exact layout coordinates, document sizes, fonts and palette values.
- All content writing within the tone above.
- Final tuning of every number in this document.
