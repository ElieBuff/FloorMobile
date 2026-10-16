export const meta = {
  name: 'qa-deep',
  description: 'QA renforcé FloorMobile, tour 1 : cinq regards sur le code du chantier, contre-vérification des remarques graves, synthèse',
  whenToUse: 'Round 1 of the enhanced QA, launched by the qa-review skill with args { request, planPath, before, after, suites, outside }.',
  phases: [
    { title: 'Relecture', detail: 'cinq regards en parallèle ; seul le regard tests lance xcodebuild' },
    { title: 'Contre-vérification', detail: 'chaque BLOQUANT ou IMPORTANT, réfuté seulement preuve à l’appui, en lisant le code' },
    { title: 'Synthèse', detail: 'doublons fusionnés, rapport au format du qa-reviewer' },
  ],
}

// Round 1 of the enhanced QA (.claude/skills/qa-review/SKILL.md). Five qa-reviewer agents each cover one axis of the
// agent's "What to check" (.claude/agents/qa-reviewer.md); every BLOQUANT or IMPORTANT finding then goes to another
// qa-reviewer told to refute it, which may only do so with evidence; a last one merges everything into the agent's
// report. Every agent is a qa-reviewer, so it carries the agent's tools and its Bash hook. Nothing is dropped silently:
// refuted findings are listed with their evidence, an axis that failed is named, and the report is never VALIDÉ
// without all five.

const { request, planPath, before, after, suites = [], outside = [] } = args ?? {}
if (!request || !planPath || !before || !after) {
  throw new Error('qa-deep needs args { request, planPath, before, after, suites[], outside[] } — see the qa-review skill')
}

// The axes, as the agent numbers them in "What to check". Only `tests` runs xcodebuild: two builds at once lock the
// same DerivedData and fight over the same simulator.
const LENSES = [
  { key: 'tests', title: 'tests', axis: '5. Tests', runsBuild: true },
  { key: 'plan', title: 'conformité au plan et justesse', axis: '1. Conformity to the plan, and 3. Correctness' },
  { key: 'place', title: 'bonne place et réutilisation', axis: '2. Right place and reuse, with the questions of the shared file' },
  { key: 'clean', title: 'propreté et commentaires', axis: '4. Clean and documented code' },
  { key: 'practices', title: 'pratiques Apple, règles du projet et livraison', axis: "6. Apple's practices and the project's rules, and 7. Release" },
]

const FINDING = {
  type: 'object',
  properties: {
    severity: { type: 'string', enum: ['BLOQUANT', 'IMPORTANT', 'SUGGESTION'] },
    title: { type: 'string' },
    file: { type: 'string', description: 'repository-relative path' },
    line: { type: 'integer' },
    problem: { type: 'string' },
    scenario: { type: 'string', description: 'this input → this wrong result' },
    evidence: { type: 'string', description: 'path:line opened, build or test result, floor-dev rule, house rule, or Apple page' },
    proposal: { type: 'string' },
  },
  required: ['severity', 'title', 'file', 'problem', 'scenario', 'evidence', 'proposal'],
}
const LENS_RESULT = {
  type: 'object',
  properties: {
    findings: { type: 'array', items: FINDING },
    testsRun: {
      type: 'array',
      items: {
        type: 'object',
        properties: { command: { type: 'string' }, result: { type: 'string' } },
        required: ['command', 'result'],
      },
    },
    checked: { type: 'string', description: 'one line: what was checked and found right' },
  },
  required: ['findings', 'testsRun', 'checked'],
}
const COUNTER_CHECK = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['réfutée', 'confirmée', 'non confirmée'] },
    reason: { type: 'string' },
    evidence: { type: 'string', description: 'path:line opened; empty only when non confirmée' },
  },
  required: ['verdict', 'reason', 'evidence'],
}

// What every agent of the round is given, as the skill gives it to the single agent of the simple mode.
const context = [
  `Demande de l'utilisateur, mot pour mot :\n${request}`,
  `Plan (avec son journal de relecture) : ${planPath}`,
  `Photos de l'arbre : avant la première édition ${before}, maintenant ${after}. Le chantier est exactement \`git diff ${before} ${after}\`.`,
  suites.length > 0
    ? `Suites que le plan nomme :\n${suites.map((suite) => `- ${suite}`).join('\n')}`
    : 'Suites que le plan nomme : aucune en particulier.',
  outside.length > 0
    ? `Chemins modifiés hors de la photo (le BFF dans ../FloorPlatform, un fichier ignoré), à lire directement :\n${outside.map((path) => `- ${path}`).join('\n')}`
    : 'Chemins modifiés hors de la photo : aucun.',
].join('\n\n')

const lensPrompt = (lens) => [
  `Regard : ${lens.title}`,
  `Axe de « What to check » : ${lens.axis}. Couvre cet axe seulement, en profondeur.`,
  lens.runsBuild
    ? 'Tu es le seul à lancer xcodebuild : le build, puis toutes les suites unitaires (-only-testing:FloorMobileTests), un seul à la fois. Lis les avertissements avec xcresulttool get build-results, vérifie que le nombre de tests exécutés est au-dessus de zéro, et rapporte chaque commande avec son résultat dans testsRun.'
    : 'Tu ne lances jamais xcodebuild : le regard tests s’en charge, et deux builds à la fois se bloquent. Lis le code.',
  context,
].join('\n\n')

const describe = (finding) => [
  `[${finding.severity}] ${finding.title}`,
  `  Fichier : ${finding.file}${finding.line ? `:${finding.line}` : ''}`,
  `  Problème : ${finding.problem}`,
  `  Scénario : ${finding.scenario}`,
  `  Preuve : ${finding.evidence}`,
  `  Proposition : ${finding.proposal}`,
].join('\n')

const counterCheckPrompt = (finding, lens) => [
  'Contre-vérification',
  `Une remarque du regard « ${lens.title} » :\n${describe(finding)}`,
  'Cherche à la réfuter, en lisant le code, jamais avec xcodebuild. « réfutée » seulement avec une preuve qui la contredit (un chemin:ligne ouvert), « confirmée » avec une preuve qui la soutient, « non confirmée » si tu ne peux pas trancher. Jamais réfutée par défaut.',
  context,
].join('\n\n')

phase('Relecture')
const reviewed = await pipeline(
  LENSES,
  (lens) => agent(lensPrompt(lens), { label: `regard:${lens.key}`, phase: 'Relecture', agentType: 'qa-reviewer', schema: LENS_RESULT }),
  (result, lens) => {
    if (!result) return null
    const grave = result.findings.filter((finding) => finding.severity !== 'SUGGESTION').length
    log(`Regard ${lens.title} : ${result.findings.length} remarque(s), dont ${grave} à contre-vérifier`)
    return parallel(result.findings.map((finding) => () =>
      finding.severity === 'SUGGESTION'
        ? Promise.resolve({ ...finding, counterCheck: null })
        : agent(counterCheckPrompt(finding, lens), {
          label: `contre:${lens.key}`,
          phase: 'Contre-vérification',
          agentType: 'qa-reviewer',
          schema: COUNTER_CHECK,
        }).then((counterCheck) => ({
          ...finding,
          // A counter-check that failed settles nothing: the finding stays, unconfirmed.
          counterCheck: counterCheck ?? { verdict: 'non confirmée', reason: 'la contre-vérification a échoué', evidence: '' },
        })),
    )).then((findings) => ({
      lens: lens.title,
      findings: findings.filter(Boolean),
      testsRun: result.testsRun,
      checked: result.checked,
    }))
  },
)

const lenses = reviewed.filter(Boolean)
const missingLenses = LENSES.filter((_, i) => !reviewed[i]).map((lens) => lens.title)
const refuted = lenses.flatMap((lens) => lens.findings
  .filter((finding) => finding.counterCheck?.verdict === 'réfutée')
  .map((finding) => ({ lens: lens.lens, title: finding.title, evidence: finding.counterCheck.evidence })))
if (missingLenses.length > 0) log(`Regard(s) absent(s), le rapport ne peut pas être VALIDÉ : ${missingLenses.join(', ')}`)
log(`${refuted.length} remarque(s) écartée(s) par la contre-vérification`)

phase('Synthèse')
const report = await agent([
  'Synthèse',
  `Regards absents : ${missingLenses.length > 0 ? missingLenses.join(', ') : 'aucun'}.`,
  `Remarques des regards, avec le verdict de leur contre-vérification (counterCheck null : une suggestion, non contre-vérifiée), le build et les tests lancés et ce que chaque regard a vérifié :\n\`\`\`json\n${JSON.stringify(lenses, null, 2)}\n\`\`\``,
  context,
].join('\n\n'), { label: 'synthèse', phase: 'Synthèse', agentType: 'qa-reviewer' })

return { report, refuted, missingLenses, lenses }
