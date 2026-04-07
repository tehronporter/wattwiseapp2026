-- State-Specific NEC Amendments
-- Stores local amendments that states apply on top of their adopted NEC edition.
-- Sources: state electrical code offices, NFPA adoption tracker, ICC adoption database.
-- Always verify against current official state sources before relying on this data.

-- 1. Table definition
CREATE TABLE IF NOT EXISTS nec_state_amendments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    jurisdiction_code   TEXT NOT NULL REFERENCES jurisdiction_nec_editions(jurisdiction_code),
    nec_article         TEXT NOT NULL,          -- e.g. "210.8", "230.70"
    amendment_type      TEXT NOT NULL DEFAULT 'modification'
        CHECK (amendment_type IN ('addition', 'modification', 'deletion', 'stricter')),
    summary             TEXT NOT NULL,          -- Plain-English description
    effective_date      DATE,
    source_reference    TEXT,                   -- Citation, e.g. "CA Elec. Code §17920.9"
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_nec_state_amendments_jurisdiction
    ON nec_state_amendments(jurisdiction_code);
CREATE INDEX IF NOT EXISTS idx_nec_state_amendments_article
    ON nec_state_amendments(nec_article);

-- 2. Seed known state amendments for high-volume exam states.
--    These are representative amendments — verify against official sources.
INSERT INTO nec_state_amendments
    (jurisdiction_code, nec_article, amendment_type, summary, effective_date, source_reference)
VALUES

-- ── CALIFORNIA (2023 NEC base, California Electrical Code 2023) ──────────────
('CA', '210.8', 'stricter',
 'California requires GFCI protection in all areas of dwelling units, including laundry areas and garages with a broader scope than the base NEC.',
 '2023-01-01', 'CEC 2023 §210.8'),

('CA', '110.26', 'stricter',
 'California requires a minimum 36-inch working space (not 30-inch) for equipment rated over 150V to ground.',
 '2023-01-01', 'CEC 2023 §110.26'),

('CA', '230.71', 'stricter',
 'California limits service disconnecting means to a maximum of 6 disconnects, consistent with the NEC, but enforces stricter marking and grouping requirements.',
 '2023-01-01', 'CEC 2023 §230.71'),

('CA', '406.4', 'addition',
 'California requires tamper-resistant receptacles in all occupancies, not just dwelling units.',
 '2023-01-01', 'CEC 2023 §406.4'),

-- ── TEXAS (2023 NEC base, adopted September 2023) ────────────────────────────
('TX', '210.8', 'modification',
 'Texas adopts the NEC GFCI requirements but certain agricultural and industrial exemptions apply under Texas Health & Safety Code.',
 '2023-09-01', 'TX H&S Code §754'),

('TX', '230.70', 'addition',
 'Texas requires the service disconnecting means to be accessible from the exterior of the structure on all new residential construction.',
 '2023-09-01', 'TX Elec. Safety Rules §73.70'),

-- ── NEW YORK (2020 NEC base, NY State Electrical Code 2020) ──────────────────
('NY', '210.12', 'stricter',
 'New York requires AFCI protection in all 120V, 15A and 20A branch circuits in all areas of dwelling units, including basements and attached garages.',
 '2021-07-01', 'NYSEC 2020 §210.12'),

('NY', '517.30', 'addition',
 'New York requires hospital-grade receptacles in patient care areas and adds inspection requirements beyond the base NEC.',
 '2021-07-01', 'NYSEC 2020 §517.30'),

-- ── FLORIDA (2023 NEC base, Florida Building Code 2023) ──────────────────────
('FL', '553', 'addition',
 'Florida adds Article 553 (Floating Buildings) requirements not in the base NEC, reflecting the state's extensive marina infrastructure.',
 '2024-01-01', 'FBC 2023 §553'),

('FL', '210.8', 'stricter',
 'Florida requires GFCI protection for all 125V through 250V, single-phase, 15A and 20A receptacles in boathouses and boat hoists.',
 '2024-01-01', 'FBC 2023 §210.8'),

-- ── ILLINOIS (2020 NEC base) ──────────────────────────────────────────────────
('IL', '230.82', 'modification',
 'Illinois allows energy management system meters to be connected on the supply side of the service disconnecting means under specific utility agreement conditions.',
 '2021-07-01', 'Illinois Electrical Licensing Act §16-12'),

-- ── MICHIGAN (2020 NEC base) ─────────────────────────────────────────────────
('MI', '210.8', 'stricter',
 'Michigan requires GFCI protection for all 125V, 15A and 20A receptacles within 6 feet of a sink in kitchens, not just counter-top locations.',
 '2021-01-01', 'Michigan Electrical Code R 408.30801'),

-- ── OHIO (2020 NEC base) ──────────────────────────────────────────────────────
('OH', '250.52', 'modification',
 'Ohio clarifies that concrete-encased electrodes (Ufer grounds) are required on all new construction poured footings, with specific rebar size and length requirements.',
 '2021-07-01', 'Ohio Basic Building Code §250.52'),

-- ── PENNSYLVANIA (2020 NEC base) ─────────────────────────────────────────────
('PA', '406.12', 'stricter',
 'Pennsylvania requires tamper-resistant receptacles in all new and renovated commercial occupancies accessible to the public, in addition to the base NEC dwelling unit requirement.',
 '2021-07-01', 'PA UCC §406.12'),

-- ── WASHINGTON (2023 NEC base) ────────────────────────────────────────────────
('WA', '210.12', 'stricter',
 'Washington State requires AFCI protection for all branch circuits in dwelling units, including circuits added to existing structures during renovation.',
 '2023-07-01', 'WSEC 2023 §210.12'),

('WA', '690', 'addition',
 'Washington adds requirements for rapid shutdown of photovoltaic systems consistent with its aggressive solar adoption, with stricter labeling requirements.',
 '2023-07-01', 'WSEC 2023 §690'),

-- ── MASSACHUSETTS (2023 NEC base, 527 CMR 12) ────────────────────────────────
('MA', '230.70', 'stricter',
 'Massachusetts requires outside disconnects on all new residential structures and permits their use to be tested by the inspection authority prior to certificate of occupancy.',
 '2024-01-01', '527 CMR 12.00 §230.70'),

('MA', '250.50', 'stricter',
 'Massachusetts requires all available grounding electrodes to be bonded, and adds specific requirements for grounding of structural steel in commercial buildings.',
 '2024-01-01', '527 CMR 12.00 §250.50')

ON CONFLICT DO NOTHING;

-- 3. Helper view — joins amendments with jurisdiction edition for easy querying
CREATE OR REPLACE VIEW vw_jurisdiction_amendments AS
SELECT
    a.id,
    a.jurisdiction_code,
    j.adopted_edition,
    a.nec_article,
    a.amendment_type,
    a.summary,
    a.effective_date,
    a.source_reference
FROM nec_state_amendments a
JOIN jurisdiction_nec_editions j USING (jurisdiction_code)
WHERE a.is_active = TRUE;
