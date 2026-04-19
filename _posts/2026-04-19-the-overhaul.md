---
layout: post
title: "The Overhaul — From 8 Months to 14 Years in One Evening"
date: 2026-04-19 01:00:00 -0400
categories: [architecture, vibe-coding]
tags: [ai-fleet, schema-validation, durable-systems]
---

# The Overhaul

**Half-life of my AI skill fleet went from ~8 months to ~13.8 years. In one evening. With math.**

Tonight I took my personal hedge fund stack — 20 skills built ad-hoc over weeks — and applied three orthogonal design axes (tree + plugin + unix) to make it survive decades of tool churn.

This is the case study. Plus the full source is public: [github.com/DimmMak/the-overhaul](https://github.com/DimmMak/the-overhaul).

---

## 🎯 What I built

A skill fleet is just an AI agent stack. Mine has ~20 skills that do specific jobs:

- `price-desk` pulls live market prices from yfinance
- `fundamentals-desk` pulls valuation / earnings / margins
- `royal-rumble` runs a 13-legend investment committee
- `journalist` converts rumble verdicts into Howard Marks-style memos
- `accuracy-tracker` scores predictions against reality
- ... 15 more

Each worked in isolation. But the fleet was drifting. Every week it got harder to add a new skill without breaking something silently.

---

## 🚨 The three failure modes I saw

### 1. Organizational chaos (🌳 Tree)

A hardcoded list routed skills to domains. Every new skill required editing that list. Half the time I forgot. Silent drift.

### 2. No isolation contract (🎮 Plugin)

Skills could write anywhere. No enforced boundary. One rogue skill could corrupt another's data. And nothing would validate it.

### 3. Ad-hoc composition (🐧 Unix)

Some skills imported each other's code. No declared interface. Swap one out → unexpected breakage.

---

## 🏛️ The fix: three axes, three sessions

Every durable software system obeys three orthogonal axes:

```
🌳 Tree     — WHERE things live
🎮 Plugin   — WHAT they can do
🐧 Unix     — HOW they compose
```

Unix (1969) does this. macOS does this. Git does this. Kubernetes does this. They all survived because of these three.

### Session 1 — Tree (~60 min)

- Added `domain: fund | learning | general` to every SKILL.md
- Killed the hardcoded routing table — `.home map` now reads `domain:` from filesystem
- New skills auto-route the moment they're installed

**Result:** 90% → 99% on Tree axis.

### Session 2 — Plugin (~3 hrs) — the big one

- Added `capabilities:` block to every SKILL.md (declares reads / writes / calls / cannot)
- Wrote a schema validator that rejects non-compliant skills at install time
- Every install.sh now gates through the validator

**Result:** 50% → 98% on Plugin axis.

```yaml
# Example — every skill declares this now
capabilities:
  reads:
    - "yfinance API"
  writes:
    - "price-desk/data/price-log.jsonl"
  calls: []
  cannot:
    - "write outside own data folder"
    - "modify other skills"
    - "return stale cached data without timestamp"
```

### Session 3 — Unix (~60 min)

- Added `unix_contract:` block declaring data format + composability
- Audit script finds direct skill-to-skill code imports (found 2, both accepted as Unix-style CLI composition)
- All inter-skill talk now goes through files + JSON + stable CLIs

**Result:** 80% → 98% on Unix axis.

### Session 4 — Preservation (~60 min)

- Stress-test script (12 checks across all 3 axes)
- Quarterly audit cron (auto-runs every 90 days)
- Git tags at milestone (`v-2026-04-18-world-class`) for rollback
- Master architecture doc (`project_world_class_architecture.md`) for cold re-entry

**Result:** locked the gains. World-class isn't a destination — it's a cadence.

---

## 📊 The math

System survival is **multiplicative** across axes:

```
P(survive Y years) = tree^Y × plugin^Y × unix^Y
```

**Before:**
```
0.90 × 0.50 × 0.80 = 0.36 annual retention
half-life = log(0.5) / log(0.36) ≈ 0.68 years ≈ 8 months
```

**After:**
```
0.99 × 0.98 × 0.98 = 0.95 annual retention
half-life = log(0.5) / log(0.95) ≈ 13.5 years
```

**20× durability gain.** The weakest axis (Plugin at 50%) was dominating. Fixing it unlocked most of the compounding.

---

## 🎯 What I actually learned

### 1. Principles > tools

Every rule I pinned tonight — *Risk × Reward on every decision · NOT-for clauses in every description · autopsy every fumble · 3-2-1 backups · principles > implementations* — works in ANY domain. The fund fleet is just this year's substrate. The rules port.

### 2. Declared > enforced (for this scale)

I didn't build OS-level sandboxing. I built declarative contracts + schema validation at install time + quarterly drift detection. That's enough for a 20-skill fleet run by one person. Over-engineering starts where declared stops being enough.

### 3. Recursive refinement is real

Every fumble tonight got autopsied in three-part format:
1. 🔍 Mechanism in plain words
2. 🎬 Thought replay
3. 📐 One-sentence rule to prevent it

That rule got pinned to memory verbatim. Same mistake became impossible in the next session. **The system improves itself by making its own breakage-data into permanent rules.**

### 4. Plain text beats everything

My whole memory folder — 16 principles, ~2000 lines total — is plain markdown. Git-tracked. Pushed to GitHub. Survives any tool change. If Claude disappears tomorrow, the principles still guide whoever inherits this.

---

## 🧬 The one-liner

**Spaghetti fleet at 8am. Declared world-class by midnight. Locked and self-maintaining by 2am. The architecture was the product.**

---

## 📂 Full source

- [the-overhaul](https://github.com/DimmMak/the-overhaul) — case study repo with architecture docs, principles, tooling, replication blueprint
- [All repos](https://github.com/DimmMak) — the complete fleet
- [This blog](https://github.com/DimmMak/DimmMak.github.io) — sourced in plain markdown, git-tracked, 50-year durable by design

If this pattern maps to your domain — legal case tracking, medical records, VC deal flow, research libraries — the REPLICATE.md file has the blueprint. Fork it, adapt it, ship yours.

🏛️🃏🛡️🌳
