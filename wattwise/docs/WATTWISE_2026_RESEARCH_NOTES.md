# WattWise 2026 NEC Research Notes

## Status

This repo now includes a structured content seed at:

- `wattwise/Resources/WattWiseContentPack.json`

That file contains:

- executive summary
- 2026 NEC change watchlist
- apprentice, journeyman, and master curriculum framework
- a completed 24-lesson apprentice, journeyman, and master core library
- starter question bank and practice exams
- flashcards
- quick reference guides
- study plans
- glossary
- jurisdiction research notes
- source list

## Validation approach

The seed was built from official public sources available on 2026-03-30, prioritizing:

- NFPA 2026 NEC errata and development documents
- official state licensing-board pages
- official exam-provider pages
- NCCER test-specification pages
- Apprenticeship.gov guidance

## Important production note

This is now a much stronger research-backed content foundation, but two things still remain necessary before WattWise should market the content as fully complete in every jurisdiction:

1. Article-by-article validation against licensed access to the full 2026 NEC text, including any new errata or TIAs.
2. Completion of a 50-state-plus-DC jurisdiction matrix sourced from each official licensing authority and current exam bulletin.

## 2026 NEC themes surfaced by official NFPA documents

- Reorganization of over-1000 Vac and 1500 Vdc content for better usability
- Creation of Article 270 for grounding and bonding of systems over 1000 Vac and 1500 Vdc nominal
- Relocation of overcurrent and overvoltage material into Article 245
- Expanded EV and bidirectional power-transfer terminology
- Proposed Article 627 for electric self-propelled vehicle power transfer systems
- Ongoing refinement of microgrid and hybrid-power terminology
- Published 2026 errata affecting Article 680 pool provisions

## Jurisdiction notes already captured

- California DLSE / PSI flow
- Texas TDLR journeyman split-exam update effective March 11, 2025
- Virginia DPOR tradesman workflow
- Maine board and Prov exam details
- Washington L&I electrician exam eligibility pathway
- Oregon BCD electrical licensing structure
- Florida DBPR Pearson VUE construction exam pathway
- ICC bulletin-driven contractor/trades exam model

## QA improvements added in code

- typed content-pack models
- bundle loader for app-side use
- structural validator for duplicate IDs, invalid question keys, broken references, and incomplete lesson coverage
- a runtime adapter that turns the content pack into app-ready modules and lessons
- a deterministic Supabase seed generator that builds content tables from the same pack
- unit tests that decode, validate, and adapter-check the content pack
