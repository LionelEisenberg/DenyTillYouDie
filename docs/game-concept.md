# Deny 'til You Die: Game Concept

Draft, 2026-10-23. Pieced together from the current build and the design conversation so far.

## Decided so far

- **Genre:** an incremental/idle game with a *Papers, Please*-style desk.
- **Subject:** satire of US health-insurance claim denials. You play the person doing the denying.
- **Inspection pays:** reading the paperwork and scanning patients earns more than stamping blind.
- **Ascension:** you deny 'til you die. Death ends the run and pays out a prestige currency (working name *Luigi points*, see [open question 1](#open-questions)).

Everything else in this doc is a proposal.

## Pitch

You're a claims officer at a health insurer. Claims land on your desk one at a time: a name, an age, an injury, a stack of paperwork. Approving is quick and pays almost nothing. Denying pays big but costs public goodwill, unless you can dig a technicality out of the paperwork. You grow from a clerk with a rubber stamp into an AI-powered denial machine, until public outrage catches up with you. Then the run ends, and the next one starts stronger.

## Pillars

1. **The incentives are the satire.** The cruel play is the optimal play. The game never lectures; the numbers do the talking.
2. **Attention pays.** Reading the fine print beats stamping blind. Your attention is the premium resource, and automation is the cheap one.
3. **Number go up, then you go down.** Each run is a rise, outrage ends it, and ascension makes the next rise faster.

Use these to judge new features: if a feature doesn't serve a pillar, cut it or rethink it.

## Core loop (built today)

- One claim at a time. **Approve**: 1 s cooldown, +$20, +0.05 goodwill. **Deny**: 10 s cooldown, +$500, −1 goodwill. (Standard claim at claim level 0.)
- Goodwill can go negative, but a denial that would push it below −100 is refused.
- Money buys upgrades: shorter cooldowns, multipliers, higher claim levels (each level scales money ×1.41 and goodwill ×1.26), and two claim types:
  - **Tragic:** approving wins a lot of goodwill; denying pays well but costs a lot of it.
  - **Frivolous:** cheap to deny, and approving costs you money.
- Features unlock in order: Approve only → Denials (after 5 approvals) → Upgrades tab (after 3 denials).

## The desk: inspection (proposed)

**Player goal:** find a legitimate-sounding reason to deny, because a cited denial pays more and avoids blowback.

### Paperwork grows with claim level

The way *Papers, Please* adds documents over its days, claims pick up paperwork as claim level rises:

| Claim level | New document | What you check |
|---|---|---|
| 0 | Claim form (exists today) | Injury, requested coverage |
| 1 | Insurance card | Member ID, plan, active dates |
| 2 | Provider bill | Provider, network status, billing codes |
| 3 | Medical history | Pre-existing conditions |
| 4 | Patient scan | X-ray or MRI |

### The Policy

A binder listing the current denial reasons. You buy new pages as upgrades, so you are literally buying loopholes. The reasons are real ones, played straight:

- Out-of-network provider
- Pre-existing condition
- No prior authorization
- Filed after the deadline
- Coverage lapsed
- Experimental treatment (the `EXPERIMENTAL_TREATMENT` claim type is already stubbed)
- Billing mismatch: the bill says broken arm, the scan shows a broken leg

### Citing a reason

This works like *Papers, Please*'s inspect mode. Click a piece of evidence on a document, then the Policy rule it breaks. A correct pair stamps the denial with a reason code.

### Scanning patients

The scan viewer plays the role of *Papers, Please*'s body scanner. You look over the patient's imaging for anything you can call pre-existing (an old fracture, a suspicious shadow) or proof that the injury doesn't match the claim. At higher goofiness tiers the scans get weird: a unicorn horn, a tiny black hole.

### Rewards and risks

| Decision | Money | Goodwill | Cooldown | Afterwards |
|---|---|---|---|---|
| Approve | Small | Small gain | Short | — |
| Cited denial (correct reason) | Base + bonus | Normal cost for the claim type | None, since legal review isn't needed | — |
| Blind denial (no reason) | Base | Normal cost | Legal review (today's 10 s) | May come back as an appeal |
| Mis-cited denial (wrong reason) | Base | Extra cost | Legal review | Likely appeal |
| Approving a claim that had a valid reason | Small | Small gain | Short | A Memo from Management and a fine |

- **The public doesn't read fine print.** The goodwill cost follows the claim type, not the citation. Citations make denials safer and more profitable, but they don't make them popular. This keeps citing from wiping out the goodwill game.
- **Not every claim has a reason.** Clean claims force the real choice: approve, or deny blind and take the risk.
- **Memos from Management** are *Papers, Please*'s citations turned around: you get written up for being kind.
- **Cited-denial bonus: ×2 money.** Starting value. Test: once the Policy has three or more rules, testers should inspect roughly 30–80% of claims. If almost everyone inspects everything, lower the bonus. If almost nobody inspects, raise it.

**Riskiest assumption.** Players will choose to inspect in a game that also lets them idle.
- *Impact:* inspection is the hook that separates this from a plain clicker.
- *If wrong:* inspection becomes a chore players skip, and the game collapses into a clicker with flavor text.
- *Validate:* a paper prototype with 10 claims and 3 Policy rules. Watch whether testers inspect without being told to, and how long each claim takes.

**Build order.** This is several features in one, so start with the smallest slice: the claim form plus the insurance card, three Policy rules, and citing. Add memos next, then the scanner.

**First playtest questions**
- Can a new player find a valid reason on their first inspected claim without a tutorial?
- Do experienced players earn noticeably more per minute by inspecting?
- Can players click every evidence/rule pair until one sticks? (Proposed fix: a wrong pair counts as a mis-cite.)
- Can someone watching tell why a denial paid what it did?

## Automation: the idle layer (proposed)

- **Interns** process standard claims on their own. They only stamp blind.
- **Claims software, then AI** (the existing "$5M + 5 AI" objective) brings huge throughput, but some share of AI denials are wrongful, which feeds outrage and appeals. That share is a tuning knob and a satire beat.
- **Your desk stays the premium lane.** The highest-value claims (tragic, high level) route to you.
- Over a run you go from reading every claim to supervising a denial machine, and the machine's mistakes are what finally bring the outrage down on you.

## Goodwill and outrage (proposed)

- Keep the existing goodwill meter: above zero is goodwill, below zero is outrage.
- Crossing outrage thresholds fires events through the stubbed `START_EVENT` and `TRIGGER_EVENT` hooks: protests, a news cycle, a congressional hearing. Each has a mechanical effect, such as a temporary payout freeze or a forced batch of approvals.
- Each event arrives as a newspaper front page, the way *Papers, Please* reports your choices between days.

## Ascension (core decided, details proposed)

- **The fuse.** Today's −100 floor becomes *critical outrage*. Instead of refusing denials there, the Deny button becomes the **final denial**, and pressing it ends the run. You choose when to go, the same way ascending in *Cookie Clicker* or resetting for angel investors in *AdVenture Capitalist* is the player's call.
- **Automation stops denying at critical outrage,** so only the player can end the run. An idle death would feel arbitrary.
- **Payout:** prestige points scale with the money you extracted during the run, with diminishing returns (starting shape: √ of money extracted this run). Money is recommended over outrage, because it keeps goodwill management meaningful to the end. See open question 2.
- **The death happens offscreen,** on a front page: your obituary below the fold, your successor's appointment above it. You play the successor, and the company carries on without missing you.
- **Keeps:** feature unlocks and objective progress, so the tutorial gates only happen once.
- **Resets:** money, goodwill, claim level, the upgrade tree, Policy pages.
- **Prestige points buy:** a starting budget, permanent multipliers, extra starting Policy pages, earlier interns and AI, a higher starting claim level.
- **First death after about 45–60 minutes of play.** Starting value. Test: pass if at least 70% of testers reach their first death and want another run. If most quit before it, shorten. If the death feels abrupt or unearned, lengthen.

| Run state | Entered when | Left when |
|---|---|---|
| Running | A new run starts | Goodwill reaches −100 |
| Critical outrage | Goodwill reaches −100 | Back to Running if approvals lift goodwill above −100, or Dead on the final denial |
| Dead | The final denial | The player continues from the front page |
| Ascension | Death | The player spends points and starts the next run |

## First run arc (proposed)

This maps the planned objectives onto the systems above:

1. Approve 5 claims → Denials unlock (built)
2. Deny 3 claims → Upgrades tab (built)
3. $5k → 100 goodwill → $25k + 250 goodwill → 500 goodwill → $100k → $1M. Inspection pieces and interns unlock along the way.
4. Trigger Public Outrage: your first critical outrage, which teaches the final denial and the first ascension.
5. Second life: $5M + 5 AI, then $25M. The automation era.

## Tone (proposed)

- Deadpan bureaucratic satire on the surface, absurd underneath: insurers like *GoFundYourself Health Co.* and upgrades like "Kindly Crushing Dreams".
- Goofiness (four tiers of claim content, from mundane to cosmic) steps up once per ascension. The first life is grounded and grim, and each death makes the world weirder, which also keeps repeat runs fresh. See open question 4.

## Current build vs. this doc

| Area | Status |
|---|---|
| Claim generation (4 goofiness tiers, 3 claim types), approve/deny, cooldowns | Built |
| Money and goodwill with the −100 floor | Built |
| Feature unlocks (Denials, Upgrades tab, Tragic, Frivolous) | Built |
| Upgrade tree (12 upgrades), autosave and load | Built |
| Objectives | 2 of 11 defined |
| Events, goofiness progression, Experimental Treatment claims | Stubbed (enum values, no behavior) |
| Claim number, coverage, notes, related claims | Placeholder values |
| Nav tabs 3–5 | Placeholders |
| Inspection, Policy, scanner, memos, automation, outrage events, ascension, newspaper | Not started |

## Open questions

1. **What to call the prestige currency, and how the death is shown.** The working name *Luigi points* is the clearest joke, but it ties the reward to a real killing and a real, named person. That's the element most likely to get the game rejected or pulled from storefronts. Alternatives: *Golden Parachute*, *Legacy*.
2. **What prestige points scale with:** money extracted (recommended) or outrage caused.
3. **What money is.** Your commission, or company profit? If it's profit, approvals should cost the payout. That's sharper satire, but the approve-only opening would need a starting budget.
4. **When goofiness rises:** per ascension (proposed), within a run, or as a player setting.
5. **Cooldowns once inspection exists:** keep the denial cooldown only for blind denials (proposed), or drop cooldowns and let reading time be the throttle.
6. **Offline progress:** does automation keep working while the game is closed?
7. **Unused bits:** what were nav tabs 3–5, the village icon and the stack-of-papers texture meant for?

## Ideas parking lot (not yet proposed)

- **Delay** as a third stamp: park a claim in the backlog to earn interest on money you haven't paid out yet, while outrage builds and the claimant may give up. (Delay, deny, defend.)
- **Appeals desk:** denied claims come back with new documents, and mis-cited denials can turn into lawsuits.
- **Shifts:** a *Papers, Please*-style day structure with an end-of-shift summary.
