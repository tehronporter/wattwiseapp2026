# WattWise SME review playbook

The editorial queue is intentionally separate from the published-content flag. A lesson can remain available as a draft learning aid, but it must not be described as SME-approved, code-current, or state-exam aligned until the items below are complete.

For every queued lesson, the reviewer records the governing code edition, jurisdiction assumptions, source locations, and review notes in `public.content_sme_reviews`. Use the queue's `source_key` rather than a database lesson ID so review history remains intact when the content seed is rebuilt.

Required review artifacts:

- `citation_check`: Every rule, table, exception, and limitation is checked against the stated edition and source.
- `worked_example`: A complete calculation or decision path, including assumptions, units, rounding, and a check of the result.
- `illustrated_concept_check`: For conceptual lessons, diagrams and wording accurately distinguish the relevant conductors, paths, and conditions.
- `guided_code_lookup`: A learner can follow a verified path from scenario to article/table/notes without relying on an unexplained answer.
- `vetted_practice_set`: At least 15 reviewed items, balanced across recall, application, and calculation when appropriate. Each distractor has a defensible rationale.
- `exam_blueprint_mapping`: Scope is mapped to a named jurisdiction/exam blueprint and cycle; unsupported jurisdictions remain explicitly unclaimed.
- `second_reviewer_signoff`: A different qualified reviewer confirms the citations, examples, and assessment answers.

When all artifacts are approved, set the review status to `approved`, record the reviewer identity and approval timestamp, and run `npm run validate:editorial-release`. The command is deliberately blocking while items remain incomplete. Use `npm run validate:editorial-release -- --report-only` for a non-blocking progress report during normal development.
