---
layout: post
title: "Building .gmail — The Intern / Senior / Architect Pattern for Email"
date: 2026-04-19 14:00:00 -0400
categories: [architecture, vibe-coding, skills]
tags: [ai-fleet, gmail, mcp, phishing-detection, tree-structure, future-proofing]
---

# Building `.gmail` — Email Triage You Can Actually Trust

**TL;DR:** Spent today building a Claude skill called `.gmail` that triages my inbox. Shipped it through v0.1 → v0.1.5 in five increments, each one driven by real problems found by stress-testing against actual email. Ended with 51 passing tests, a 13.8-year projected half-life, and six categories of hallucination and noise caught deterministically before they reach me.

The architecture pattern — **Intern / Senior / Architect** — is the real takeaway. Stealable for any LLM-driven workflow where you can't afford silent errors.

---

## 🎯 The problem

My Gmail has 9,609 unread emails. Most are noise. A few matter. Classic inbox triage should be automatable — but every "AI inbox assistant" I've tried either:

1. Has no structural way to verify it isn't hallucinating, OR
2. Sends things autonomously (terrifying), OR
3. Drowns under provider updates when Gmail's UI changes

I wanted something where **the AI does the grunt work, I stay in the loop, and the data outlives the AI.**

---

## 🏛️ The architecture — Intern / Senior / Architect

Borrowed from how banks handle email-class decisions. Three roles, three cadences, no single point of trust:

| Role | Who | Does | Cadence |
|---|---|---|---|
| **Intern** | Claude via Gmail MCP | Drafts replies, classifies incoming, runs signal checks | Continuous |
| **Senior** | Me | Reviews drafts, edits, hits send | Daily (5-10 min) |
| **Architect** | Claude + me monthly | Samples 10% of drafts, grades accuracy, proposes prompt tweaks | Monthly (15 min) |

**The key insight:** the Intern has no send tool. Not because policy forbids it — because the MCP surface literally doesn't expose one. "We decided not to send" is a promise. "The tool to send does not exist" is a structural guarantee. You can forget a promise; you cannot forget something that does not exist.

---

## 🌳 The three axes — tree + plugin + unix

This is the durability model from [the-overhaul](https://github.com/DimmMak/the-overhaul):

### Tree axis (where things live)

Every directory answers **exactly one question**:

```
gmail/
├── SKILL.md         → what's the front door?
├── ARCHITECTURE.md  → why is it shaped this way?
├── SCHEMA.md        → what contracts do the files keep?
├── config/          → what rules govern behavior?
├── prompts/         → how does the LLM talk?
├── scripts/         → what executes?
│   └── lib/         → what do scripts share?
├── logs/            → what happened?
├── tests/           → does it still work?
└── install.sh       → how does it install?
```

One question per directory = no ambiguity about where new files go. That's the forensic bar.

### Plugin axis (what capabilities)

SKILL.md frontmatter declares what the skill can and cannot touch:

```yaml
capabilities:
  reads:
    - gmail-mcp (search_threads, get_thread, list_drafts, list_labels)
    - config/rules.json
    - logs/*.jsonl
  writes:
    - gmail-mcp (create_draft, create_label)
    - logs/*.jsonl (append only)
  cannot:
    - send email (MCP has no send tool — structural guarantee)
    - delete email
    - modify received emails
    - reach non-Gmail inboxes
```

### Unix axis (how it composes)

Every log entry is JSONL with a `schema_version` field. Future skills can consume the output without parsing logic baked into `.gmail`:

```yaml
unix_contract:
  data_format: "JSONL"
  schema_version: "0.1"
  composable_with:
    - linkedin-outreach
    - accuracy-tracker
    - royal-rumble
```

Combined survival math: 0.99 × 0.98 × 0.98 = **94.1% year-1 survival → ~13.8 year half-life.**

---

## 🔬 The stress-testing loop

This was the real unlock today. Instead of building everything and hoping, I shipped small and let reality find the holes.

### v0.1 — scaffold

Tree structure, 7 invariants (I1 churn isolation, I2 append-only logs, I3 single source of truth, I4 schema versioning, I5 structural no-send, I6 idempotency, I7 graceful degradation), six starting categories. 23 tests. Shipped.

### v0.1.1 — ran it on my real inbox, found two bugs

Running `.gmail triage` surfaced 2 stale GitHub Actions failure emails — both for builds that succeeded minutes later. My triage had no way to tell that the success had superseded the failure.

**Fix #1 — dedupe layer:** `scripts/lib/dedupe.py`. Alerts with the same resource key (sender + normalized subject stem) within a time window collapse to most-recent-wins. The stem normalization strips leading status verbs ("Run failed:" / "Run succeeded:") so failure + success on the same workflow collapse together. Earlier entries get `status: superseded` with a `superseded_by` pointer.

**Fix #2 — verbatim quote enforcement:** the draft prompt already told the Intern to quote the replied-to line verbatim, but instruction ≠ enforcement. Added `scripts/lib/quote_verify.py` that checks the `quoted_line` is a normalized substring of the email body. If not, the draft's confidence is capped to 1 and a `⚠️ QUOTE UNVERIFIED` warning is prefixed into the draft body for the human reviewer to see.

### v0.1.2 — phishing detection layer

Six deterministic signal checks in `scripts/lib/phishing.py`:

| Signal | Score | Detects |
|---|---|---|
| `brand_spoof` | 0.7 | Display name claims a brand; sender SLD doesn't match |
| `suspicious_tld` | 0.3 | `.ru` `.tk` `.ml` `.xyz` etc. |
| `url_shorteners` | 0.25-0.55 | bit.ly, tinyurl, goo.gl, t.co |
| `urgency_plus_money` | 0.5 | Urgency + money-ask phrases co-occur |
| `name_mismatch` | 0.2 | Email greets you by a name you don't answer to |
| `opaque_subdomain` | 0.1 | Known ESP prefixes (em-, e\d+, track-) |

Pure functions, stdlib only, 24 tests. Building it, the stress test **found two bugs in my own implementation**:

1. My brand-spoof check was fooled by `paypal-secure.tk` because substring match after hyphen-strip said `paypal` ∈ `paypalsecuretk`. Fixed by extracting the registrable SLD (handles `.co.uk` too) and requiring exact SLD match.

2. My opaque-subdomain regex over-fired on `travel.*` and bare `mail` prefix. Tightened to require a known ESP prefix with an explicit digit or hyphen separator.

Both caught by running the module on real inbox senders, not synthetic cases.

### v0.1.5 — the T1 block: observability and self-diagnosis

Applied Risk × Reward × Effort tiering to a gap analysis:

```
T1  1  Wire phishing     🟢 reversible   🟢 dead→live
T1  2  stats.py          🟢 read-only    🟢 observable
T1  3  status subcmd     🟢 read-only    🟢 diagnosable
───
T2  4  Log archiving     🟢 rotation     🟡 perf runway
T2  5  README.md         🟢 docs only    🟡 repo entry
```

Shipped T1 in order:

**`.gmail triage` now runs phishing on every thread.** Hard safety gate: if `total_score >= 0.5`, the email is forced to `flagged_for_human` no matter what the classifier wanted to do.

**`.gmail stats`** — reads all JSONL logs, produces a markdown report: triage volume, category breakdown, review decisions, phishing signal hit rates, log health with rotation warnings at 5k / 10k lines.

**`.gmail status`** — 7 health checks (symlink, rules.json validity, log integrity, module imports, I5 no-send invariant, schema version parity, last triage age). Exit nonzero on failure — CI-friendly.

---

## 📐 The meta-pattern — committing to tree structure as a first principle

Mid-way through the build I pinned a new principle to memory: **`principle_tree_structure_always`**. The rule:

> Every structure is a tree. Single root. Parent → child only. No cycles. No cross-links except at documented mount points. Never flat beyond 5 files. Never graph. Never hybrid.

Why now: every skill I build from here forward inherits the durability math. Tree composes at O(1) at the root; graphs compose at O(N²). The future of small-scale AI systems is tree-first because LLMs reason about code the same way humans do — top-down, recursive descent.

Full principle doc lives in my [claude-memory repo](https://github.com/DimmMak/claude-memory).

---

## 🔬 What I learned today

1. **Real inbox > synthetic test data.** Every time I ran against actual email, the stress test caught bugs that synthetic cases missed. Two bugs in my own phishing checker. One bug in my initial dedupe stem normalization. All invisible until real data hit them.

2. **"Stress test" is the protocol, not the event.** Build → run against reality → find the hole → fix → repeat. Every version bump today started with a real-world failure, not a brainstorm.

3. **The `cannot:` block is load-bearing.** Listing what the skill won't do protects future-you from feature creep. "Send" isn't in there because it would require adding a tool that doesn't exist. That's stronger than any policy.

4. **Tree structure scales better than you think.** The skill went from 27 files (v0.1) to 30 (v0.1.5) without a single directory reshuffle. Each new file had exactly one place to live.

5. **Tiering saves time the moment you commit to it.** The Risk × Reward × Effort table took 30 seconds to render. It spared me ~45 minutes of building the two T2 items that aren't needed yet.

---

## 🛡️ What `.gmail` is NOT

This is not:
- An autonomous email agent (MCP has no send tool — structural, not policy)
- A Gmail replacement (all actions happen in Gmail proper)
- A provider lock-in (logs are plain JSONL on my disk, survive any Gmail outage)
- A replacement for human judgment (every draft is human-approved before send)

---

## 🎯 What's next

T2 items flip to T1 when their trigger conditions hit:
- **Log archiving** → when `wc -l logs/drafts.jsonl` passes 5000
- **README.md** → when the repo goes public

Upcoming experiments:
- Wire `.gmail` output into `accuracy-tracker` so outreach → call → paid pipeline is fully measurable
- Extend the Intern / Senior / Architect pattern to LinkedIn outreach (`linkedin-outreach` is next)
- Package the pattern itself as a reusable scaffold for future skills

---

## 📚 The stack

- Claude via Gmail MCP (read + draft, no send)
- Stdlib Python only (zero runtime dependencies — future-proofing)
- JSONL for all logs (future-proofing — readable in 50 years)
- Schema versioning on every entry (future-proofing — migrations are additive)
- Symlink install pattern (matches fleet-wide convention)

---

## 🧬 The one-sentence lesson

> **A skill isn't done when it works — it's done when you can measure it, diagnose it, teach it, and rotate its data without touching the code.** The Intern / Senior / Architect pattern is the organizing principle; tree structure is the substrate; stress-testing against real data is the only way to find the bugs that matter.

If you're building LLM-driven workflows and you can't afford silent errors, steal this pattern. The half-life math actually works.

🌳🔒🃏
