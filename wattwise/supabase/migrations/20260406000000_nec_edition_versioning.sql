-- NEC Code Cycle Versioning
-- Adds edition tracking to nec_entries so content can be scoped to the NEC edition
-- a user's state has adopted (2020 or 2023; 2026 in draft).

-- 1. Add edition column to nec_entries
ALTER TABLE nec_entries ADD COLUMN IF NOT EXISTS
    nec_edition TEXT NOT NULL DEFAULT '2023'
    CHECK (nec_edition IN ('2017','2020','2023','2026'));

-- 2. Add edition column to nec_search_index so search can filter
ALTER TABLE nec_search_index ADD COLUMN IF NOT EXISTS
    nec_edition TEXT NOT NULL DEFAULT '2023';

-- 3. Add jurisdiction_nec_editions table — maps each US state to its adopted NEC edition
CREATE TABLE IF NOT EXISTS jurisdiction_nec_editions (
    jurisdiction_code   TEXT PRIMARY KEY,         -- e.g. 'TX', 'CA'
    adopted_edition     TEXT NOT NULL DEFAULT '2023'
        CHECK (adopted_edition IN ('2017','2020','2023','2026')),
    adoption_notes      TEXT,                     -- e.g. "Adopted 2023 NEC with amendments effective Jan 2024"
    effective_date      DATE,
    source_url          TEXT,
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Seed known NEC edition adoptions as of early 2026
--    Sources: NFPA adoption tracker, state licensing board announcements.
--    Always verify against current official sources before relying on this data.
INSERT INTO jurisdiction_nec_editions (jurisdiction_code, adopted_edition, adoption_notes, effective_date) VALUES
-- 2023 NEC adopters (as of 2026)
('AK', '2023', 'Adopted 2023 NEC', '2024-01-01'),
('CA', '2023', 'California Electrical Code (2023 NEC base with state amendments)', '2023-01-01'),
('CO', '2023', 'Adopted 2023 NEC', '2023-07-01'),
('CT', '2023', 'Adopted 2023 NEC', '2024-01-01'),
('DC', '2023', 'District of Columbia adopted 2023 NEC', '2023-10-01'),
('FL', '2023', 'Florida Building Code based on 2023 NEC', '2024-01-01'),
('HI', '2023', 'Adopted 2023 NEC', '2024-01-01'),
('ID', '2023', 'Adopted 2023 NEC', '2023-01-01'),
('ME', '2023', 'Adopted 2023 NEC', '2024-01-01'),
('MA', '2023', 'Massachusetts Electrical Code 527 CMR 12.00 (2023 NEC base)', '2024-01-01'),
('MN', '2023', 'Adopted 2023 NEC', '2023-10-01'),
('MT', '2023', 'Adopted 2023 NEC', '2023-01-01'),
('NE', '2023', 'Adopted 2023 NEC', '2024-01-01'),
('NV', '2023', 'Adopted 2023 NEC', '2023-01-01'),
('NH', '2023', 'Adopted 2023 NEC', '2023-07-01'),
('NM', '2023', 'Adopted 2023 NEC', '2024-01-01'),
('ND', '2023', 'Adopted 2023 NEC', '2023-01-01'),
('OR', '2023', 'Oregon Electrical Specialty Code (2023 NEC base)', '2024-01-01'),
('RI', '2023', 'Adopted 2023 NEC', '2023-07-01'),
('SD', '2023', 'Adopted 2023 NEC', '2023-01-01'),
('TX', '2023', 'Texas adopted 2023 NEC for state licensed work', '2023-09-01'),
('UT', '2023', 'Adopted 2023 NEC', '2023-01-01'),
('VT', '2023', 'Adopted 2023 NEC', '2023-07-01'),
('VA', '2023', 'Virginia Uniform Statewide Building Code (2023 NEC base)', '2024-01-01'),
('WA', '2023', 'Washington State Electrical Code (2023 NEC base)', '2023-07-01'),
('WI', '2023', 'Wisconsin Electrical Code (2023 NEC base)', '2024-01-01'),
('WY', '2023', 'Adopted 2023 NEC', '2023-01-01'),
-- 2020 NEC adopters (still on 2020 as of early 2026)
('AL', '2020', 'Alabama adopted 2020 NEC', '2021-01-01'),
('AR', '2020', 'Arkansas adopted 2020 NEC', '2021-07-01'),
('AZ', '2020', 'Arizona adopted 2020 NEC statewide', '2021-01-01'),
('DE', '2020', 'Delaware adopted 2020 NEC', '2021-01-01'),
('GA', '2020', 'Georgia adopted 2020 NEC', '2021-01-01'),
('IL', '2020', 'Illinois adopted 2020 NEC', '2021-07-01'),
('IN', '2020', 'Indiana adopted 2020 NEC', '2021-01-01'),
('IA', '2020', 'Iowa adopted 2020 NEC', '2021-01-01'),
('KS', '2020', 'Kansas adopted 2020 NEC', '2021-01-01'),
('KY', '2020', 'Kentucky adopted 2020 NEC', '2021-01-01'),
('LA', '2020', 'Louisiana adopted 2020 NEC', '2021-07-01'),
('MD', '2020', 'Maryland adopted 2020 NEC', '2021-01-01'),
('MI', '2020', 'Michigan adopted 2020 NEC', '2021-01-01'),
('MS', '2020', 'Mississippi adopted 2020 NEC', '2021-01-01'),
('MO', '2020', 'Missouri adopted 2020 NEC', '2021-07-01'),
('NJ', '2020', 'New Jersey adopted 2020 NEC', '2021-01-01'),
('NY', '2020', 'New York State Electrical Code (2020 NEC base)', '2021-07-01'),
('NC', '2020', 'North Carolina adopted 2020 NEC', '2021-01-01'),
('OH', '2020', 'Ohio adopted 2020 NEC', '2021-07-01'),
('OK', '2020', 'Oklahoma adopted 2020 NEC', '2021-01-01'),
('PA', '2020', 'Pennsylvania adopted 2020 NEC', '2021-07-01'),
('SC', '2020', 'South Carolina adopted 2020 NEC', '2021-01-01'),
('TN', '2020', 'Tennessee adopted 2020 NEC', '2021-01-01'),
('WV', '2020', 'West Virginia adopted 2020 NEC', '2021-01-01'),
-- States with no statewide adoption (local jurisdiction controls)
('AK', '2023', NULL, NULL)  -- overridden above; placeholder for tracking purposes
ON CONFLICT (jurisdiction_code) DO UPDATE SET
    adopted_edition = EXCLUDED.adopted_edition,
    adoption_notes  = EXCLUDED.adoption_notes,
    effective_date  = EXCLUDED.effective_date,
    updated_at      = NOW();

-- 5. Performance index
CREATE INDEX IF NOT EXISTS idx_nec_entries_edition ON nec_entries(nec_edition);
CREATE INDEX IF NOT EXISTS idx_nec_search_edition  ON nec_search_index(nec_edition);
