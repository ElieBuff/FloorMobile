---
name: qa-review
description: >
  Have the code of every implemented FloorMobile plan reviewed by the qa-reviewer agent before the user decides to
  commit: a photo of the tree before the first edit, then up to three rounds of QA on exactly the change — the agent
  builds and runs the unit tests itself, each finding is fixed (announced to the user first) or refused with the
  reason, and logged in the plan's QA journal — then a summary box for the user. Two modes, fixed in the plan's
  "QA proposé" line: simple (one agent) or enhanced (round 1 by the qa-deep workflow: five axes in parallel, each
  grave finding counter-checked). Use right after a plan is approved (the photo) and once all its steps are done (the
  QA) — unless the user said "sans QA". Also use when the user sends remarks on a QA report (one targeted round),
  asks for a QA ("lance le QA", "fais relire le code"), or asks which QA mode a plan gets.
---

# QA review — up to three rounds with the QA reviewer

The plan is approved; the main session implements it, edits visible, each file announced to the user first. Before
the user decides to commit, the `qa-reviewer` agent reviews the code of exactly this change, up to three times. It
builds and runs the unit tests itself — its shell goes through its own hook, `.claude/hooks/qa-bash-allowlist.sh`,
into a DerivedData of its own under `/tmp/floormobile-qa/` and on the `iPhone 17` simulator — and never edits
anything. The user gets a summary box and has the last word.

## When

- **Right after `ExitPlanMode` approves a plan**: the photo (step 0), before the first edit.
- **Once every step of the plan is done**: the QA (steps 1 to 5). This is the end of the feature, when the user wants
  the tests run: the QA runs them.
- Skipped when the user said "sans QA" for this plan.
- After the user has read the QA box and sent remarks: one targeted round (step 6).

The agent, this skill and the workflow are read when a conversation starts: a conversation opened before they existed
may not see them.

## Choosing the mode

Written by `plan-review` in the plan's box, checked by `plan-critic`, changed by the user with one word when they
approve the plan ("QA simple", "QA renforcé", "sans QA"):

```
> QA proposé : renforcé — <the criterion, as the plan shows it> | simple
```

**Enhanced** as soon as one criterion is true, **simple** otherwise:

- the store's on-disk shape changes: a `@Model` stored property, `FloorSchemaV1.models`, the fields of a composite
  snapshot stored in a model, a `StoredKey` (the house rule "The store's shape and existing installs");
- a file in `Core/Sync/`, `Core/Persistence/`, `Core/Auth/` or `Core/Networking/` changes;
- the BFF must change too (`../FloorPlatform`): two repositories;
- about ten files or more.

Each criterion is read in the plan's "Contrat serveur" and "Étapes", never from an impression. Enhanced costs three to
four times as many agents in round 1.

## 0. Photo before the first edit

The tree usually carries uncommitted work, staged or not, so `git diff` alone would mix it with this change. A photo is
a git tree of the whole working state, untracked files included, written through a copy of the real index: it touches
neither the files, nor the real index, nor the stash (git refuses an empty index file; the copy also re-reads only
what changed). Run it from the repository root and write the hash in the plan's "Journal QA" section:

```bash
tmp="$(mktemp)"; cp "$(git rev-parse --git-path index)" "$tmp"; GIT_INDEX_FILE="$tmp" git add -A; GIT_INDEX_FILE="$tmp" git write-tree; rm -f "$tmp"
```

`git diff <photo> <another photo>` is then exactly what changed in between. Git sees neither ignored files
(`*.local.xcconfig`, `TestCredentialsSecret.json`) nor the server repo: list the BFF files the plan changes in
`../FloorPlatform`, the QA reads them directly.

**If the photo was forgotten**: diff against HEAD, limited to the files the plan names (untracked ones from
`git status --porcelain`), write that scope in the "Journal QA", and say so in the box.

## 1. Done first

Every step of the plan is done, and the app builds (`xcodebuild … build`, welcome at every step). The tests are
written with the code; the QA runs them, so the main session does not run the suite again just before it. The plan's
"Tests" section names the suites of the feature; the QA runs every unit suite anyway (`-only-testing:FloorMobileTests`).

**The UI tests never run in the QA**: `FloorMobileUITests` signs the simulator's session out and logs in for real
against the dev Zitadel and the BFF. When the change touches launch or login, say in the box that they were not run,
and run them only on the user's explicit go.

## 2. Round 1

Take a new photo ("now"). Every round 1 receives the same inputs, and only these:

- the user's request, **word for word**: every message that defined it, answers to questions included;
- the plan's path (its review journal included);
- the photo before and the photo now;
- the suites the plan names;
- the paths the plan changes outside the photo, or "aucun".

Never the developer's reasoning: the QA judges the code as a colleague discovering the change.

- **Simple**: launch the agent in the foreground, `subagent_type: "qa-reviewer"`, the prompt headed `Tour 1`. Keep its
  id: rounds 2 and 3 resume this same agent.
- **Enhanced**: run the `qa-deep` workflow (`Workflow` with `name: "qa-deep"`) with
  `args: { request, planPath, before, after, suites: [...], outside: [...] }`. It returns `{ report, refuted,
  missingLenses, lenses }`: `report` is the round-1 report, in the agent's output shape. A missing axis means no
  VALIDÉ: relaunch the run with `resumeFromRunId` (the finished agents come back from the cache).

Do not build or run tests in the main session while the QA runs: two `xcodebuild` at once fight over the simulator.

## 3. Handle each finding

For every finding, decide:

- **Fix it**: announce the fix to the user — the file and what changes — and write it only once they agree, one file
  at a time (the user's rule in FloorMobile: they correct placement and naming before the write). A fix they reject
  becomes a refusal, with their reason.
- **Refuse it**, with the reason: a fact from the code, an instruction from the user, a `floor-dev` rule, a house
  rule, or the plan's scope.

Do not fix everything to reach VALIDÉ, and do not refuse to save work: a refusal that cannot be justified is a fix. A
DÉSACCORD, a product or on-screen design choice, or a « non confirmée » finding you cannot settle from the code goes to
the user. Build after the fixes.

Log the round in the plan's "Journal QA", one line per finding, and end the round with a new photo:

```
Photo avant : c8baf0f…
Tour 1 — À CORRIGER (renforcé) — photo de fin : 4ce978e…
- Q1.1 [IMPORTANT] corrigé : la liste reprend .cardList() au lieu de recopier ses modificateurs (ClientsView.swift).
- Q1.2 [SUGGESTION] refusé : ClientRow sert déjà les deux listes, il n'y a rien à extraire.
```

## 4. Rounds 2 and 3

The agent receives `Tour <n>`, the "Journal QA", and the photos of the fixes only (the end of the previous round →
now). It follows its findings, builds and runs the suites of the code the fixes touched, and raises nothing new unless
BLOQUANT or IMPORTANT.

- **Simple**: resume the same agent with `SendMessage`.
- **Enhanced**: round 2 launches one new `qa-reviewer`, with the round-1 report in its prompt; round 3 resumes it.

Stop when the verdict is **VALIDÉ**, or after round 3, whatever the verdict. **Never a fourth round.** What is still
open goes to the user.

## 5. Present

Fill the box at the end of your message, in plain words, one line per point:

```
> QA : <n> tour(s), <simple | renforcé>, <VALIDÉ | non validé après 3 tours>
> - Corrigé : <what the fixes changed>
> - Refusé : <finding — reason>
> - Écarté par la contre-vérification (renforcé) : <finding — evidence>
> - Non confirmé (renforcé) : <finding — fixed, refused, or for the user to settle>
> - À arbitrer par toi : <disagreements, product or design choices, BLOQUANT/IMPORTANT still open — or « rien »>
> - Build et tests : <the build and the unit suites the QA ran last, and their result; « tests UI non lancés »>
```

Then leave the commit to the user: the QA never commits, and neither does this skill (never on `main`).

## 6. After the user's remarks

The user's remarks on the box are decisions. Apply them (announced, file by file), then:

- **Form only** (a comment's wording, a name): no QA round.
- **Substance**: one targeted round. Resume the same agent with `SendMessage`: `Tour ciblé`, the remarks word for word,
  the photos of what changed. It cannot contest a decision; it can report a serious consequence as `[À SAVOIR]`.

**One round only, never a loop.** Fix what it finds when the fix does not touch a user decision, log the round, update
the box with one more line:

```
> - Relecture de tes changements : <rien à signaler | ce qui a été corrigé | conséquence à connaître>
```

## When the QA fails

If the agent or the workflow errors out, or answers outside its format, retry once (for the workflow, resume the run).
A build the QA cannot run (the iPhone 17 simulator gone after an Xcode update, a locked DerivedData) is reported as
such, never worked around: the hook names the commands to update. If it fails again, present the work anyway with
`> QA : non fait — <raison>`, so the user knows.
