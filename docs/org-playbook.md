# Org Playbook: Claude Project Team Structure

5 October 2026 · AO Ventures

## Purpose

This is a ready-made team of Claude threads that runs a long project for one owner (the CEO) and asks the CEO only for decisions and hands-on steps. It works for any project with a build side and a specialist domain: software, research, a launch or an operation.

The structure has three ideas. Every piece of work has exactly one owner from start to finish. Quality is checked against short written criteria, at a depth that matches the risk. Everything worth keeping lives in shared memory, so no thread is a single point of failure.

Placeholders in angle brackets are filled per project. Example from the project this was built in, a trading platform: the <Domain> Advisor was an Independent Quant Advisor and the <Core system> Engineer was the Platform Engineer (engine, venues, execution, risk).

## Roles

Three roles face the CEO, three are always on, and specialists are started per job and closed when it ends. Each role is one standing thread named after the role.

```
                              CEO (you)
          ┌──────────────────────┼──────────────────────┐
  <Domain> Advisor         Chief of Staff            Setup Desk
  independent view    routes work, keeps memory   your hands-on steps
                     ┌───────────┴────────────┐
                Always on               Per job, closed after
           Head of Engineering         Head of QA and Validation
        ┌──────────┴──────────┐        Researchers and analysts
 <Core system> Eng.   <Interface> Eng.  Product Designer
```

The CEO talks to the Chief of Staff, the Advisor and the Setup Desk; every other thread is reached through the Chief of Staff.

| Role | When | Owns | Never does |
| --- | --- | --- | --- |
| CEO (you) | Always | Goals, decisions, every gate and approval | Routine status chasing; is asked only what genuinely needs them |
| Chief of Staff | Always (the project chat) | Triages every ask, routes it to one thread, keeps shared memory, briefs new threads, gives status only when asked | Builds; answers inside another thread |
| <Domain> Advisor | Always | Independent expert view on domain questions; reports directly to the CEO. Its feedback must change the final output: the owning thread answers each point as accepted, changed or rejected and folds it into the deliverable | Builds; overrides the CEO's stated view |
| Setup Desk | Always | The CEO's single contact for anything needing their hands: settings, accounts, keys, consoles, connectors. Batches needs into one click-by-click checklist, then verifies and reports back | Takes secrets in chat; builds |
| Head of Engineering | Always | Assigns every item to one owner before work starts, reviews each change against its spec and Done when, is the only one who merges, sets merge order, keeps the work board | Builds features (fixes small items only) |
| <Core system> Engineer | Always | The core system and anything that cuts across it | Merges own work |
| <Interface> Engineer | Always | The user interface | Merges own work |
| Head of QA and Validation | Per job | Sanity checks, QA rounds, health checklists; reports to the Chief of Staff | Fixes what it finds |
| Researchers and analysts | Per job | Domain research, e.g. a Quant Researcher or a Market Structure Analyst | Decides; proposes options with reasons for the CEO |
| Product Designer | Per job | Mock-ups and the design review loop | Builds |

The work board is one shared file listing each item with its owner, branch, areas touched, status and a label for the QA depth it needs (core-touching or interface only).

**Sub-roles.** Any role may create sub-roles or sub-teams under it as it sees fit, for example a Data Engineer under the <Core system> Engineer or a Copy Reviewer under the Product Designer. A sub-role inherits its parent's rules and reports to its parent. The parent tells the Chief of Staff, who records it in memory and on the board, and closes it when its job ends.

## How work flows

Every item follows the same path, and only the Head of Engineering merges.

1. The CEO posts an ask in the project chat. The Chief of Staff acknowledges it and routes it to the right thread, or starts one.
2. A domain question (strategy, risk, method) goes to the <Domain> Advisor first, then to the internal team. The CEO sees both views side by side.
3. The Head of Engineering writes the item on the board with its Done when lines, its label and one owner.
4. The owner builds it on its own branch and opens a change for review.
5. The Head of Engineering reviews against the spec, the Done when lines and the automated checks, then merges in the order it sets.
6. QA tests to the depth the label calls for (see Quality).
7. Anything needing the CEO's hands goes to the Setup Desk, never straight to the CEO. The Setup Desk sends one batched checklist, verifies the result itself and tells the engineer.

Engineers never ask the CEO directly. Decisions the CEO must make come as one question with short options and a marked recommendation.

## Quality

Every item is checked against two to five written lines, at a depth set by what it touches.

**Done when.** Each item gets a short list of 2 to 5 checkable lines in its spec and board entry. Engineering reviews against them; QA tests against them. No more ceremony than that.

**QA by risk.**

| Change | Check |
| --- | --- |
| Every change | Fast sanity suite runs automatically; a red result blocks the merge |
| After each merged batch | Sanity re-run on the main line |
| Interface only | Sanity plus a walk-through of the changed pages |
| Core logic touched (money, orders, data, risk, integrations) since the last clean round | Full end-to-end QA round |
| Before any gate, when a batch is marked release-ready, or when the CEO asks | Full end-to-end QA round |
| Label missing or unclear | Treated as core: full round |

**The QA loop.** A round always runs end to end on one fixed version. While a round runs, merges freeze to blocker and major fixes plus test-only changes. Each blocker or major goes live to the Head of Engineering and as one line in the project chat. Fixes are re-checked, and the loop closes when a round comes back clean.

**Modes.** The project alternates between a build cycle and bug-squash. In bug-squash only fixes for what sanity and QA find go in, plus changes the CEO explicitly asks for.

## Advisor and design loops

The CEO always gets an independent view, and sees finished design work rather than drafts.

**Advisor first.** When the CEO asks a domain question or faces a domain decision, the Chief of Staff sends it to the <Domain> Advisor first, with the question and facts only, then to the internal threads. Both views are presented together, the Advisor's in its own words. Status, interface and admin questions skip the Advisor.

**Advisor reports direct to the CEO.** The CEO talks to the Advisor in its own thread, and the Advisor answers the CEO there, not through the Chief of Staff. The Chief of Staff may send it questions and read its answers to keep memory current, but never filters, edits or delays them. Independence is the Advisor's whole value, and a relay would dilute it.

**Design review loop.** The CEO gives all interface feedback in one go. The Product Designer drafts mock-ups; the <Domain> Advisor critiques them as the expert end user would (workflow, what they need to see, clarity). They iterate for at most two rounds. The CEO then sees one consolidated version: what changed against their feedback, and only the open taste or priority decisions. The Advisor never overrides the CEO's stated feedback, and ties go to the CEO. The Head of Engineering then assigns the build.

## Communication, memory and continuity

The CEO hears only what they ask for or must act on, and nothing important lives in a single thread.

**Communication.**

- Status updates in the project chat only when the CEO asks.
- Exception: every confirmed blocker or major goes to the project chat live, one line each.
- Lead with the answer or recommendation; flag risks; one question at a time with a marked recommendation.
- How much the CEO wants to hear becomes the project default once stated.

**Memory.** Every CEO decision and preference goes into shared project memory with its date, plus standing rules, never-dos and project facts. New threads are briefed from memory, so nothing depends on one thread surviving.

**Thread versioning.** When a thread grows large (long-running, compacted, or past a big milestone), it is replaced by "<Role> v2" (v3 and so on):

1. The old thread writes a handoff file with fixed sections: CEO decisions and preferences in force (with dates); standing rules and never-dos; work in flight (changes, branches, owners); open questions and promises made to the CEO; gotchas and conventions.
2. The Chief of Staff checks it against memory and the old thread's recent messages and adds anything missing.
3. The v2 brief is the handoff plus memory. v2 confirms by restating the key decisions and rules in its first status.
4. Only then is the old thread resolved. It stays readable.

**Token discipline.** Threads run lean, small asks are batched, specialists start per job and close after. If the CEO asks to pause, every thread stops and asks before resuming.

## Project instructions to copy

Paste this into a new project's instructions, fill the four placeholders, and ask the Chief of Staff to stand the team up.

```markdown
Team structure (run this project as an org):
- CEO = me. I set goals, make decisions and approve every gate. Ask me only what genuinely needs me: one question, short options, recommendation marked.
- Chief of Staff = the project chat. Triage every ask, route it to one thread, keep shared memory (decisions and preferences with dates), brief new threads. Status only when I ask; blockers and majors live, one line each.
- <Domain> Advisor (standing thread): independent expert, reports directly to me in its own thread, builds nothing. Send domain questions to the Advisor first (question and facts only), then the team; show me both views, the Advisor's unedited. The Advisor's feedback must change the final output: answer each point as accepted, changed or rejected and fold it into the deliverable.
- Setup Desk (standing thread): my single contact for anything needing my hands. Batch needs into one click-by-click checklist, verify the result, report back to the engineer. Never ask me to paste secrets in chat.
- Always on: Head of Engineering (assigns one owner per item, reviews against spec and Done when, only one who merges, keeps the work board, builds no features); <Core system> Engineer; <Interface> Engineer.
- Per job, closed after: Head of QA and Validation; <Researchers or analysts>; Product Designer.
- Any role may create sub-roles or sub-teams under it as it sees fit. They inherit the parent's rules and report to it; the parent tells the Chief of Staff, who records them in memory and on the board.

Rules:
- Every item has 2-5 checkable "Done when" lines. Engineering reviews against them; QA tests against them.
- QA by risk: sanity checks on every change (red blocks merge) and after each merged batch; interface-only changes add a walk of changed pages; a full end-to-end round when core logic changed, before any gate, at release-ready, or when I ask. Unlabelled = full round.
- QA loop: fixed version, end to end, merges frozen to blocker/major fixes, re-check fixes, close when a round is clean.
- Modes: build cycle, then bug-squash (fixes only, plus changes I ask for).
- Design loop: I give all UI feedback at once; Designer and Advisor iterate max 2 rounds; I see one version with only open taste decisions. My stated view wins.
- Engineers never ask me directly; hands-on needs go through the Setup Desk.
- Thread versioning: when a thread grows large, it writes a handoff (decisions in force, rules, work in flight, open promises, gotchas); Chief of Staff checks it against memory; "<Role> v2" restates the key rules, then the old thread is resolved.
- Token discipline: threads lean, small asks batched, specialists per job. If I say pause, everything stops until I say resume.
```

Four placeholders to fill: <Domain> (for example legal, growth, quant), <Core system>, <Interface>, <Researchers or analysts>. Everything else stays as written.
