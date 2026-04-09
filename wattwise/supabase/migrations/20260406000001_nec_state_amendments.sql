-- State-Specific NEC Amendments
-- Stores local amendments that states apply on top of their adopted NEC edition.
-- Sources: state electrical code offices, NFPA adoption tracker, ICC adoption database.
-- Always verify against current official state sources before relying on this data.

-- 1. Table definition
CREATE TABLE IF NOT EXISTS nec_state_amendments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    jurisdiction_code   TEXT NOT NULL,
    nec_article         TEXT NOT NULL,
    amendment_type      TEXT NOT NULL DEFAULT 'modification',
    summary             TEXT NOT NULL,
    effective_date      DATE,
    source_reference    TEXT,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_nec_state_amendments_jurisdiction
    ON nec_state_amendments(jurisdiction_code);
CREATE INDEX IF NOT EXISTS idx_nec_state_amendments_article
    ON nec_state_amendments(nec_article);

-- 2. Seed known state amendments for high-volume exam states.
INSERT INTO nec_state_amendments (jurisdiction_code, nec_article, amendment_type, summary, effective_date, source_reference)
VALUES
('CA', '210.8', 'stricter', 'California GFCI requirements', '2023-01-01', 'CEC 2023 210.8'),
('CA', '110.26', 'stricter', 'California working space requirements', '2023-01-01', 'CEC 2023 110.26'),
('TX', '210.8', 'modification', 'Texas GFCI requirements', '2023-09-01', 'TX H&S Code 754'),
('NY', '210.12', 'stricter', 'New York AFCI requirements', '2021-07-01', 'NYSEC 2020 210.12'),
('FL', '210.8', 'stricter', 'Florida GFCI requirements', '2024-01-01', 'FBC 2023 210.8'),
('IL', '230.82', 'modification', 'Illinois energy management', '2021-07-01', 'Illinois Electrical Licensing Act'),
('MI', '210.8', 'stricter', 'Michigan GFCI requirements', '2021-01-01', 'Michigan Electrical Code 408.30801'),
('OH', '250.52', 'modification', 'Ohio grounding requirements', '2021-07-01', 'Ohio Basic Building Code 250.52'),
('PA', '406.12', 'stricter', 'Pennsylvania receptacle requirements', '2021-07-01', 'PA UCC 406.12'),
('WA', '210.12', 'stricter', 'Washington AFCI requirements', '2023-07-01', 'WSEC 2023 210.12'),
('MA', '230.70', 'stricter', 'Massachusetts disconnect requirements', '2024-01-01', '527 CMR 12.00 230.70')
ON CONFLICT DO NOTHING;
