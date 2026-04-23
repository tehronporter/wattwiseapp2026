# WattWise Content Completion Plan — 10/10

**Goal:** Ship a content library so complete, accurate, and thorough that WattWise is the definitive electrician exam prep resource for every user in every state.  
**Date:** 2026-04-23  
**Current Status:** Strong foundation — 92 lessons, 305 questions, full NEC 2026 baseline. Three critical gaps remain before 10/10.

---

## Current Score: ~6/10

| Dimension | Now | Target |
|---|---|---|
| Core Lessons | 92 ✓ | 92+ |
| Practice Questions | 305 | 1,200+ |
| Full Practice Exams | 0 | 15 (3 per level × 5 sets) |
| State Coverage | 8 states (notes only) | 50 states + DC |
| Calculation Drills | Partial (in lessons) | Dedicated drill sets |
| NEC Article Lookup | ~70 articles | Complete 2026 NEC index |
| Specialty Areas | Covered at intro level | Deep-dive modules |

---

## The Three Critical Gaps

### Gap 1: Practice Exams (0 exist)
The app has a `PracticeExamBlueprint` data structure but no actual exams. Real exam prep requires full-length, timed, exam-accurate practice tests. This is the #1 differentiator vs. flashcard apps.

### Gap 2: Question Bank Too Thin (305 total)
A full-length journeyman exam is 80–100 questions. With only 97 journeyman questions in the entire bank, users see repeats constantly. Target is 400+ per level (1,200 total).

### Gap 3: State-by-State Content (8 states, no dedicated prep)
Every user takes a state exam — not a national exam. States adopt different NEC cycles, have amendments, and use different exam providers. Without this, users can't trust WattWise for their specific test.

---

## Phase 1 — Practice Exams (Highest Impact)
**Target:** 15 full-length practice exams (3 levels × 5 exams)  
**Deliverable:** Populated `practiceExams` array in `WattWiseContentPack.json`

### Exam Specifications

**Apprentice Practice Exams (5 exams × 50 questions each = 250 questions)**
- Time limit: 90 minutes per exam
- Topics mirror NJATC / IBEW apprenticeship assessment areas:
  - Electrical theory and math (25%)
  - NEC fundamentals (25%)
  - Safety and OSHA (20%)
  - Wiring methods and materials (15%)
  - Grounding and protection (15%)

**Journeyman Practice Exams (5 exams × 80 questions each = 400 questions)**
- Time limit: 2.5 hours per exam
- Topics mirror PSI / Prometric journeyman blueprints:
  - Load calculations (20%)
  - NEC code lookup and application (30%)
  - Wiring methods and installations (20%)
  - Motors and controls (10%)
  - Service entrance and feeders (10%)
  - Grounding and bonding (10%)

**Master Practice Exams (5 exams × 80 questions each = 400 questions)**
- Time limit: 3 hours per exam
- Topics mirror state master electrician blueprints:
  - Complex load calculations (20%)
  - Special occupancies and systems (15%)
  - Hazardous locations (10%)
  - Emergency and standby systems (10%)
  - Advanced NEC design (20%)
  - Business, contracts, safety management (15%)
  - Renewable energy and EV systems (10%)

### Exam Authoring Guidelines
- Every question must have: question text, 4 answer choices, correct answer, explanation, NEC reference, difficulty tag
- No question may appear in more than one exam set
- At least 30% of questions must require NEC table lookups (Article 310.16, 314.16, etc.)
- At least 20% must be calculation-based (load calc, voltage drop, conduit fill, box fill)
- Rotate difficulty: 40% easy, 40% moderate, 20% hard per exam

---

## Phase 2 — Question Bank Expansion
**Target:** 1,200+ total questions (400 per level)  
**Current:** 305 (112 Apprentice, 97 Journeyman, 96 Master)  
**Net New Questions Needed:** ~895

### By Level

**Apprentice — Add ~288 questions (to reach 400)**
Priority topic areas needing more questions:
- Ohm's Law and power calculations (add 30)
- NEC Article 100 definitions (add 30)
- NEC Article 210 branch circuits (add 25)
- NEC Article 250 grounding (add 25)
- Safety, PPE, LOTO (add 25)
- Box fill calculations (add 20)
- Trade math and fractions (add 20)
- Conductor sizing basics (add 20)
- GFCI/AFCI protection (add 20)
- Code lookup practice (add 20)
- Series and parallel circuits (add 15)
- Raceways and cable types (add 18)

**Journeyman — Add ~303 questions (to reach 400)**
Priority topic areas:
- Dwelling unit load calculations (add 40)
- Feeder and service sizing (add 35)
- Conduit fill (Article 358–362) (add 30)
- Motor calculations (Article 430) (add 30)
- Voltage drop calculations (add 25)
- Commercial load calcs (add 25)
- NEC exception hunting (add 20)
- Transformer protection (add 20)
- Multi-family wiring (add 20)
- Grounding electrode system (add 20)
- Kitchen/bath code requirements (add 18)
- Underground wiring (add 20)

**Master — Add ~304 questions (to reach 400)**
Priority topic areas:
- Optional calculation method (Article 220 Part IV) (add 40)
- Commercial demand factor problems (add 35)
- Hazardous location classification (add 30)
- Healthcare facility requirements (add 30)
- Emergency/standby system design (add 25)
- Generator and transfer switch sizing (add 25)
- Solar PV system design (Article 690) (add 25)
- EV charging system design (Article 625) (add 20)
- Energy storage systems (Article 706) (add 20)
- Special occupancies (Articles 500-590) (add 20)
- Code synthesis and gray areas (add 19)
- Multi-family complex load problems (add 15)

---

## Phase 3 — State-by-State Exam Content
**Target:** All 50 states + DC  
**Deliverable:** Per-state content modules added to content pack under a new `jurisdictions` top-level key

### What Each State Module Contains
For every state/jurisdiction:
1. **Exam Profile Card** — Exam provider, number of questions, time limit, passing score, current adopted NEC cycle
2. **License Type Map** — What apprentice/journeyman/master equivalents are called in that state
3. **State Amendments** — Specific deviations from national NEC in that state
4. **Exam Board Info** — Licensing authority, website, application process summary
5. **State-Specific Practice Questions** — 15–25 questions reflecting that state's known exam patterns
6. **Reciprocity Notes** — Which licenses transfer to/from

### Priority Order (by electrician employment / user demand)

**Tier 1 — Build First (Top 10 by Employment)**
1. California — CA DLSE / PSI / NEC 2022 + Title 24 amendments
2. Texas — TDLR / PSI / NEC 2020 / Journeyman split-exam
3. Florida — DBPR / Pearson VUE / NEC 2020
4. New York — DOS / Varies by county / NEC 2017 (NYC Local Law amendments)
5. Pennsylvania — L&I / PSI / NEC 2020 / no state license (local)
6. Illinois — IDFPR / PSI / NEC 2020 + Chicago amendments
7. Ohio — COM / PSI / NEC 2017 (some locals on 2020)
8. Georgia — Secretary of State / PSI / NEC 2020
9. North Carolina — NCSBEEC / PSI / NEC 2023
10. Michigan — LARA / PSI / NEC 2023

**Tier 2 — Next 20 States**
11. Washington — L&I / AMP / NEC 2023
12. Arizona — ROC / Prometric / NEC 2017
13. Massachusetts — BBRS / PSI / NEC 2020
14. Tennessee — TDCI / PSI / NEC 2020
15. Virginia — DPOR / PSI / NEC 2023
16. Indiana — SLB / PSI / NEC 2020
17. Oregon — BCD / PSI / NEC 2023
18. Colorado — DORA / PSI / NEC 2023
19. Nevada — NSCB / PSI / NEC 2020
20. Minnesota — DLI / PSI / NEC 2020
21. Wisconsin — DSPS / PSI / NEC 2023
22. Missouri — SOS / PSI / NEC 2017
23. Maryland — MHIC / PSI / NEC 2020
24. South Carolina — LLR / PSI / NEC 2020
25. Alabama — AECB / PSI / NEC 2023
26. Louisiana — LSLBC / PSI / NEC 2020
27. Kentucky — DPHA / PSI / NEC 2017
28. Connecticut — DCP / PSI / NEC 2020
29. Iowa — IDLR / PSI / NEC 2020
30. Kansas — KSBTP / PSI / NEC 2020

**Tier 3 — Remaining States + DC**
31–51: Remaining states + DC, each with same structure

**Special Jurisdictions**
- ICC — International Code Council exam model (multiple states use ICC rather than PSI)
- NCCER — National Center for Construction Education and Research (apprenticeship programs)
- IBEW — Local union apprenticeship exam model

### State Content Data Schema (new in content pack)
```json
{
  "id": "state-ca-journeyman",
  "state": "California",
  "stateCode": "CA",
  "certificationLevel": "journeyman",
  "examProvider": "PSI",
  "licenseAuthority": "California Division of Labor Standards Enforcement (DLSE)",
  "adoptedNECCycle": "2022",
  "stateAmendments": ["Title 24 energy efficiency", "..."],
  "examFormat": {
    "questionCount": 100,
    "timeLimitMinutes": 240,
    "passingScore": 70,
    "openBook": false
  },
  "licenseTypeEquivalent": "Journeyman Electrician (C-10 Contractor = Master equivalent)",
  "reciprocityStates": ["OR", "WA", "NV"],
  "stateSpecificQuestions": [...],
  "examAmendmentNotes": "...",
  "lastVerified": "2026-04-23",
  "sourceURL": "https://www.dir.ca.gov/dlse/Electrical.html"
}
```

---

## Phase 4 — Calculation Mastery Drills
**Target:** Dedicated calculation drill sets, not embedded in lessons  
**Deliverable:** New `calculationDrills` key in content pack

### Drill Sets to Build

**Set 1: Ohm's Law and Power (All Levels)**
- 50 problems: V=IR, P=IV, P=V²/R — increasing complexity
- From simple (find current given V and R) to complex (multi-load circuit analysis)

**Set 2: Box Fill Calculations (Article 314) — Apprentice/Journeyman**
- 40 problems using Table 314.16(A) and 314.16(B)
- Cover wire fill, device fill, clamp fill, fixture stud fill

**Set 3: Conduit Fill (Chapter 9 Tables) — Journeyman/Master**
- 40 problems across EMT, RMC, IMC, PVC, LFMC
- Mix of: same-size conductors, mixed sizes, derating scenarios

**Set 4: Voltage Drop Calculations — Journeyman/Master**
- 30 problems: single-phase and three-phase
- VD = (K × I × D) / A method
- Cover both acceptable (3%) and total (5%) scenarios

**Set 5: Dwelling Unit Load Calculations (Article 220) — Journeyman/Master**
- 40 problems from simple single-family to complex 3-story dwelling
- Standard method and optional method (Part IV)

**Set 6: Commercial Load Calculations — Master**
- 30 problems: office, warehouse, retail, restaurant
- Include demand factors, panelboard sizing, feeder design

**Set 7: Motor Calculations (Article 430) — Journeyman/Master**
- 30 problems: branch circuit conductors, OCPD, overload protection, feeder sizing
- Cover 1φ and 3φ scenarios

**Set 8: Transformer Sizing (Article 450) — Master**
- 25 problems: KVA sizing, primary/secondary protection, overcurrent coordination

---

## Phase 5 — Content Depth Additions
**Target:** Fill gaps in specific topic areas identified as high-frequency exam content

### New Lessons to Add (Supplemental — beyond current 92)

**Apprentice Additions (3 new lessons)**
- "Reading Electrical Plans and Symbols" — Blueprint reading basics for field work and exams
- "NEC Table Navigation Practice" — Hands-on code table lookup strategies (Article 310, 314, 358)
- "Electrical Math: Fractions, Decimals, and Unit Conversions" — Dedicated math module

**Journeyman Additions (4 new lessons)**
- "Commercial Branch Circuit and Feeder Design" — Applied NEC 215/210 for commercial buildings
- "Panelboard and Load Center Sizing" — Full-panel design workflow
- "Working with Demand Factors" — Article 220 demand factor tables applied
- "Inspection and Code Compliance Workflow" — What inspectors look for; common citations

**Master Additions (4 new lessons)**
- "Business Law for Master Electricians" — Contracts, liens, licensing requirements (often tested)
- "Project Estimation and Bidding" — Labor and material takeoffs (common on master exams)
- "OSHA 30 and Supervision Requirements" — Regulatory requirements for master-level work
- "Energy Efficiency and Green Building" — Title 24, ASHRAE 90.1, IECC touchpoints

---

## Phase 6 — Content Quality Pass
**Target:** Every piece of content reviewed against actual 2026 NEC text  
**This is the "10/10" threshold.**

### Validation Checklist for Published Content
- [ ] Every NEC reference cross-checked against 2026 NEC errata (NFPA official errata doc)
- [ ] Every lesson explanation tested against: "Would a journeyman electrician with 10 years experience agree with this?"
- [ ] Every practice question reviewed by at least one licensed master electrician
- [ ] Every calculation problem worked out to verify the math and explanation
- [ ] Every state-specific fact sourced to official state licensing board URL
- [ ] All content updated to reflect any TIAs (Tentative Interim Amendments) issued after NEC 2026 adoption

### Human Review Priority
Content needing expert review before claiming 10/10:
1. Hazardous location classification questions (high legal stakes)
2. Healthcare facility requirements (life safety systems)
3. Emergency/standby system design (Article 700/701/702)
4. State-specific amendments (each state needs its own reviewer)
5. All calculation explanations (math errors cannot be in exam prep)

---

## Implementation Roadmap

### Month 1: Practice Exams + Question Bank Expansion
- Week 1–2: Write 15 practice exams (use AI-assisted drafting, then human review)
- Week 3–4: Expand question bank from 305 → 700 (add highest-priority questions first)
- Update `WattWiseContentPack.json` + re-run `generate_content_seed.cjs`

### Month 2: State-by-State Tier 1 (Top 10 States)
- Week 1–2: Research and draft CA, TX, FL, NY, PA
- Week 3–4: Research and draft IL, OH, GA, NC, MI
- Add `jurisdictions` key to content pack schema in `ContentCatalogModels.swift`

### Month 3: State-by-State Tiers 2 & 3 + Calculation Drills
- Week 1–2: Next 20 states
- Week 3: Remaining states + DC
- Week 4: Calculation drill sets (all 8 drill types)

### Month 4: Supplemental Lessons + Quality Pass
- Week 1: Write 11 new supplemental lessons
- Week 2–4: Full content quality pass with licensed electrician review
- Final validation run with all scripts

---

## Content Pack Schema Changes Required

The following additions need to be made to `ContentCatalogModels.swift` and the content pack:

```swift
// Add to content pack top-level
struct ContentPack: Codable {
    // existing...
    var practiceExams: [PracticeExamBlueprint]      // NEW — currently empty
    var jurisdictions: [JurisdictionModule]          // NEW — state content
    var calculationDrills: [CalculationDrillSet]     // NEW — dedicated drills
}

struct JurisdictionModule: Codable {
    var id: String
    var state: String
    var stateCode: String
    var certificationLevel: String
    var examProvider: String
    var licenseAuthority: String
    var adoptedNECCycle: String
    var stateAmendments: [String]
    var examFormat: ExamFormat
    var reciprocityStates: [String]
    var stateSpecificQuestions: [QuestionBankRecord]
    var lastVerified: String
    var sourceURL: String
}

struct CalculationDrillSet: Codable {
    var id: String
    var title: String
    var certificationLevel: String
    var drillType: String  // "ohms-law" | "box-fill" | "conduit-fill" | etc.
    var problems: [CalculationProblem]
}

struct CalculationProblem: Codable {
    var id: String
    var problemText: String
    var givens: [String: String]
    var steps: [String]
    var answer: String
    var explanation: String
    var necReference: String
    var difficulty: String
}
```

---

## Success Metrics — What 10/10 Looks Like

| Metric | Target |
|---|---|
| Total Lessons | 103 (92 existing + 11 new) |
| Total Practice Questions | 1,200+ |
| Full Practice Exams | 15 (5 per level) |
| Calculation Drill Problems | 285+ |
| States Covered | 51 (50 + DC) |
| State-Specific Questions | 765+ (15 per state avg) |
| NEC Articles Referenced | 80+ unique articles |
| Human Expert Review | 100% of practice exam questions |
| Content Freshness | All verified within 90 days |
| Passing Rate Correlation | Practice exam score ≥75% predicts real exam pass |

---

## What "10/10" Means to a User

A user in any U.S. state should be able to open WattWise and:
1. See exactly which exam they're studying for (their state, their license level)
2. Take 5 full-length practice exams that feel identical in format and difficulty to their real test
3. Drill on calculations until they can do them cold
4. Look up any NEC article covered on their exam and get a clear explanation
5. Know exactly how their state differs from the national code
6. Finish with high confidence they're ready — because our content is thorough enough to prepare them even for edge-case questions

That is 10/10.
