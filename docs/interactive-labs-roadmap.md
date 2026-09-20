# Interactive labs delivery record

## Delivered: initial playable release

- `/labs` catalog and five addressable lab routes, accessible from navigation.
- Shared assessment functions, bounded local attempt history, feedback and hints.
- Three.js scene renderer with orbit/zoom, component picking, camera reset, text controls, resource disposal, and on-demand rendering.
- Circuit trainer: explicit terminal connections, reversible wiring, switched resistive load, current calculation, protective-path validation and overload feedback.
- Panel explorer: six selectable components, exploded view, component explanations and retrieval checks.
- Diagnostics: three cases, three measurement locations, evidence-gated diagnosis and explanations.
- Room planner: interactive placement on a 20-foot wall, endpoint and gap coverage checks.
- Safety: four sequential decisions, corrective feedback and error-aware scoring.
- Guided coach: context-dependent explanations within every lab and tutor handoff.
- Learn and Review surface actual local lab attempts.
- Unit tests cover topology and coverage boundaries.

## Remaining phases and release gates

This is the initial playable release, not completion of the full multi-phase curriculum.

1. Content validation: qualified instructor review of every model and question; adopted code edition and jurisdiction metadata; reviewed citations; published version history. Current content is explicitly a simplified concept trainer.
2. Platform expansion: authenticated server persistence, full interaction event history, configurable authoring schema, attempt resume, spaced-review scheduling, instructor reporting and measured pilot outcomes. Existing app dashboard statistics are demonstration data and are not replaced by local lab scores.
3. Circuit expansion: general circuit graph solver; source/switch/load component placement; AC models; GFCI residual-current behavior; protection curves; voltage drop; five graded scenario variants; guided and independent modes. The initial trainer validates one known topology before calculating current.
4. Equipment expansion: reviewed service disconnect, meter, transformer, motor and raceway models; section planes, isolated-part mode and comparison scenes; contextual Codebook integration. The first panel is geometric and conceptual.
5. Diagnostics expansion: six or more instructor-reviewed faults, instrument selection/ranges and probe placement, controlled repair and verification, adaptive remediation. The current three cases expose modeled readings at named points.
6. Room expansion: complete room geometry, blueprint mode, doors and wall-space exclusions, special rooms, adopted-code protection checks, conductor/box fill calculations and material estimation. Current coverage checks apply only to the defined uninterrupted practice wall.
7. Safety expansion: multiple task-specific procedures, PPE and instrument context, stored-energy scenarios, cross-lab prerequisite gating and instructor reporting. Initial four decisions are not a complete field procedure.
8. Tutor expansion: structured scene state and action history supplied to a grounded server-side tutor, validated explanations and privacy controls. Current explanations are deterministic; no model calls or API credentials are required.
9. Pilot: evaluate mobile performance, keyboard and screen-reader usability, pre/post retention, hint dependence, and diagnosis quality; expand only after the content and learning outcomes are reviewed.

## Verification

Run `node --experimental-strip-types --test src/lib/labs.test.ts`, `npm run lint`, and `npm run build`. Browser acceptance: complete a circuit, inspect all six components, solve three faults, pass and fail room coverage, revisit a safety decision, reload Review to confirm persistence, and exercise text mode at a narrow viewport.
