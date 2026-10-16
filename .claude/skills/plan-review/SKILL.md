---
name: plan-review
description: >
  Have every plan written in plan mode challenged by the plan-critic agent before the user sees it: up to three
  rounds of review, each finding accepted (the plan changes) or refused (with the reason) and logged in the plan's
  review journal, then the final plan presented with a summary of the debate. Use in plan mode, every time, right
  before ExitPlanMode — unless the user said "sans relecture" for this plan. Also use when the user sends remarks on
  a presented plan (one targeted round on what changed), or asks to have a plan re-read ("fais relire le plan",
  "relance la relecture").
---

# Plan review — three rounds with the plan critic

The user asks for a feature in plan mode. Before they see the plan, the `plan-critic` agent challenges it, up to
three times. The user then gets the final plan and a summary of what the review changed, refused, or left for them
to decide. They have the last word.

## When

- In plan mode, every plan, just before `ExitPlanMode`.
- Skipped when the user said "sans relecture" for this plan.
- After the user has seen the plan and sent remarks: one targeted round on what changed (step 6), not the full loop.

## 1. Write the plan

Explore — the app, and the `../FloorPlatform/floor/mobile/bff` routes the feature reads or writes — and ask the user
about genuine ambiguities first (the critic cannot answer them). Then write the plan in the plan file plan mode gives
you, in French, with these sections:

```
# <Fonctionnalité>

> Relecture : <rempli à l'étape 5>
> QA proposé : <renforcé — critère | simple>

## Objectif
## Contexte vérifié          ce que le plan suppose de l'app et du BFF, avec les chemins ouverts
## Contrat serveur           routes du BFF utilisées, forme des réponses, modification serveur nécessaire ou non
## Conception                les choix et leur raison ; pour chaque nouveau type, l'API native envisagée et
                             pourquoi elle ne suffit pas
## Étapes                    pour chaque étape : fichiers, types et vues (dossier, nom, rôle)
## Écran                     états vide / chargement / erreur, chaînes localisées, accessibilité
## Tests                     écrits avec le code, lancés en fin de fonctionnalité ; les suites de la
                             fonctionnalité (-only-testing:FloorMobileTests/<Suite>)
## Hors périmètre
## Journal de relecture
```

Name each type and view with its folder (`Features/<Feature>/Data|Models|Views`, `Core/…`, `DesignSystem/<Component>/`):
the critic judges placement from that. Say which existing components are reused, and which new ones are created.

The "QA proposé" line applies the rule of `.claude/skills/qa-review/SKILL.md` (Choosing the mode): enhanced with the
criterion the plan shows (the store's shape changes, `Core/` Sync, Persistence, Auth or Networking touched, the BFF
changes too, about ten files), simple otherwise. The "Tests" section names the suites of the feature: once the plan is
implemented, the QA builds and runs every unit suite itself, those included.

## 2. Round 1

Launch the critic in the foreground — the next step depends on its answer:

- `subagent_type: "plan-critic"`
- the prompt holds, and only holds:
  - `Tour 1`;
  - **the user's request, word for word**: every message that defines it, answers to your questions included;
  - **the full plan text**.

Do not send your reasoning, your doubts or the options you dropped: the critic judges the plan as a colleague
discovering it. Keep the agent id from the result: the next rounds resume this same agent.

## 3. Handle each finding

For every finding, decide:

- **Accept**: change the plan.
- **Refuse**: give the reason — a fact from the code, an instruction from the user, a `floor-dev` rule, or the
  request's scope.

Do not accept everything to reach VALIDÉ, and do not refuse to save work: a refusal that cannot be justified is an
acceptance. A finding marked DÉSACCORD, or one that only the user can settle (a product choice, a design choice on
screen, a priority), goes to the user — do not decide it yourself.

Log the round in the journal, one line per finding:

```
Tour 1 — À REVOIR
- R1.1 [IMPORTANT] accepté : la recherche passe par .task(id:) au lieu d'un @Observable dédié (étape 2).
- R1.2 [SUGGESTION] refusé : ClientRow est déjà le composant partagé, il n'y a rien à extraire.
```

## 4. Rounds 2 and 3

Resume the same agent with `SendMessage` (its id from round 1): `Tour <n>`, the full revised plan, and the journal.
It remembers its earlier findings and only follows them up, plus anything new that is BLOQUANT or IMPORTANT.

Stop when:
- the verdict is **VALIDÉ**, or
- round 3 is done, whatever the verdict. **Never a fourth round.** What is still open goes to the user.

## 5. Present the plan

Fill the box at the top of the plan, then call `ExitPlanMode`:

```
> Relecture : <n> tour(s), <VALIDÉ | non validé après 3 tours>
> - Changé grâce à la relecture : <les points acceptés qui ont modifié le plan>
> - Refusé : <point — raison, une ligne chacun>
> - À arbitrer par toi : <désaccords, choix produit, BLOQUANT/IMPORTANT encore ouverts — ou « rien »>
> QA proposé : <renforcé — critère | simple>
```

The box is for a reader who has not followed the debate: plain words, one line per point. The details stay in the
journal. The user changes the QA mode with one word when approving ("QA simple", "QA renforcé", "sans QA"); once the
plan is approved, the `qa-review` skill takes over (the photo before the first edit, the QA at the end).

## 6. After the user's remarks

The user's remarks on the presented plan are decisions. Revise the plan, then:

- **Form only** (wording, a clarification in the text): no review. Present the revised plan.
- **Substance** (design, steps, files, types, views, tests, server contract): one targeted round, unless the user
  said "sans relecture".

The targeted round resumes the same agent with `SendMessage`:

- `Tour ciblé`;
- **the user's remarks, word for word**;
- the full revised plan;
- the list of what changed, one line per change.

The critic reads only the changes. It may not contest the user's decisions; it can report a serious consequence the
user may not have seen, as information. Points the user already arbitrated stay closed.

**One round only, never a loop.** Fix what it finds when the fix does not touch a user decision, log the round in the
journal, update the box, and present the plan. The box gets one more line:

```
> - Relecture de tes changements : <rien à signaler | ce qui a été corrigé | conséquence à connaître>
```

A consequence that would require going back on a user decision is reported in that line, not fixed: the user decides.

## When the critic fails

If the critic errors out or answers outside its format, retry once. If it fails again, present the plan anyway
with `> Relecture : non faite — <raison>`, so the user knows.
