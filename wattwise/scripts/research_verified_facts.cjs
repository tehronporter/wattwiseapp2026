#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const {
  rootDir,
  sha256,
  writeJson,
} = require("./content_pipeline_utils.cjs");

const DEFAULT_OUTPUT = path.join(rootDir(), "supabase", "verified_code_facts.json");

const SOURCES = [
  {
    key: "nfpa_latest_published_cycle",
    url: "https://docinfofiles.nfpa.org/files/AboutTheCodes/70/TIA_70_26_3.pdf",
    provider: "NFPA",
    kind: "pdf",
    parse(text) {
      const editionMatch = text.match(/National Electrical Code[^0-9]*2026 Edition/i);
      const effectiveMatch = text.match(/Effective Date:\s*([A-Za-z]+\s+\d{1,2},\s+\d{4})/i);
      if (!editionMatch || !effectiveMatch) {
        throw new Error("Could not parse NFPA 2026 publication metadata.");
      }
      return [{
        fact_key: "nfpa:70:latest_published_cycle",
        fact_type: "code_cycle",
        jurisdiction_code: null,
        code_cycle: "2026",
        title: "Latest published NFPA 70 cycle",
        summary: "NFPA 70 2026 is the latest published National Electrical Code cycle.",
        effective_date: "2025-09-09",
        official_source_url: this.url,
        source_provider: this.provider,
        source_priority: 1,
        amendment_reference: "TIA 26-3",
        fact_json: {
          effective_date_text: effectiveMatch[1],
        },
        freshness_status: "fresh",
      }];
    },
  },
  {
    key: "texas_adoption",
    url: "https://www.tdlr.texas.gov/electricians/compliance-guide.htm",
    provider: "Texas Department of Licensing and Regulation",
    kind: "html",
    parse(text) {
      const editionMatch = text.match(/National Electric Code 2023 Edition/i);
      const dateMatch = text.match(/effective September 1,\s*2023/i);
      if (!editionMatch || !dateMatch) {
        throw new Error("Could not parse Texas NEC adoption details.");
      }
      return [{
        fact_key: "state:TX:adopted_nec_cycle",
        fact_type: "state_adoption",
        jurisdiction_code: "TX",
        code_cycle: "2023",
        title: "Texas adopted NEC cycle",
        summary: "Texas adopts NEC 2023 as the minimum electrical code.",
        effective_date: "2023-09-01",
        official_source_url: this.url,
        source_provider: this.provider,
        source_priority: 2,
        amendment_reference: null,
        fact_json: {
          exam_basis: "State electrical exams are based on NEC 2023.",
        },
        freshness_status: "fresh",
      }];
    },
  },
  {
    key: "florida_adoption",
    url: "https://www.miami.gov/My-Government/Departments/Building/Building-Services/State-of-Florida-Applicable-Codes",
    provider: "City of Miami / State of Florida applicable codes",
    kind: "html",
    parse(text) {
      const editionMatch = text.match(/National Electrical Code\s*\(NEC\)\s*\/\s*\(NFPA 70\)\s*\/\s*2020 Edition/i);
      const dateMatch = text.match(/Effective December 31,\s*2023/i);
      if (!editionMatch || !dateMatch) {
        throw new Error("Could not parse Florida NEC adoption details.");
      }
      return [{
        fact_key: "state:FL:adopted_nec_cycle",
        fact_type: "state_adoption",
        jurisdiction_code: "FL",
        code_cycle: "2020",
        title: "Florida adopted NEC cycle",
        summary: "Florida applicable codes include NEC 2020.",
        effective_date: "2023-12-31",
        official_source_url: this.url,
        source_provider: this.provider,
        source_priority: 2,
        amendment_reference: null,
        fact_json: {
          adopted_within: "8th Edition Florida code set",
        },
        freshness_status: "fresh",
      }];
    },
  },
  {
    key: "north_carolina_delay",
    url: "https://www.ncosfm.gov/codes/state-electrical-division/state-electrical-code-and-interpretations",
    provider: "North Carolina OSFM",
    kind: "html",
    parse(text) {
      const cycleMatch = text.match(/2023 State Electrical Code/i);
      const delayMatch = text.match(/delayed from original adoption date of January 1,\s*2025/i);
      if (!cycleMatch || !delayMatch) {
        throw new Error("Could not parse North Carolina adoption delay.");
      }
      return [{
        fact_key: "state:NC:adopted_nec_cycle_delay",
        fact_type: "state_adoption",
        jurisdiction_code: "NC",
        code_cycle: "2023",
        title: "North Carolina adoption delay",
        summary: "North Carolina references the 2023 State Electrical Code but notes the original January 1, 2025 adoption date was delayed.",
        effective_date: null,
        official_source_url: this.url,
        source_provider: this.provider,
        source_priority: 2,
        amendment_reference: null,
        fact_json: {
          status: "delayed",
          original_adoption_date: "2025-01-01",
        },
        freshness_status: "fresh",
      }];
    },
  },
  {
    key: "oregon_2026_process",
    url: "https://www.oregon.gov/bcd/codes-stand/Pages/oesc-adoption.aspx",
    provider: "Oregon Building Codes Division",
    kind: "html",
    parse(text) {
      const cycleMatch = text.match(/2026 NFPA 70/i);
      const adoptionMatch = text.match(/Anticipated adoption date:\s*Oct\.\s*1,\s*2026/i);
      if (!cycleMatch || !adoptionMatch) {
        throw new Error("Could not parse Oregon 2026 adoption process.");
      }
      return [{
        fact_key: "state:OR:anticipated_2026_nec_adoption",
        fact_type: "state_adoption",
        jurisdiction_code: "OR",
        code_cycle: "2026",
        title: "Oregon anticipated NEC 2026 adoption",
        summary: "Oregon is running the adoption process for the 2026 Oregon Electrical Specialty Code based on NFPA 70 2026.",
        effective_date: "2026-10-01",
        official_source_url: this.url,
        source_provider: this.provider,
        source_priority: 2,
        amendment_reference: null,
        fact_json: {
          status: "anticipated",
        },
        freshness_status: "fresh",
      }];
    },
  },
];

function stripHtml(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

async function fetchSource(source) {
  const response = await fetch(source.url, {
    headers: {
      "user-agent": "WattWiseAccuracyPipeline/1.0",
    },
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} for ${source.url}`);
  }

  const buffer = Buffer.from(await response.arrayBuffer());
  const hash = sha256(buffer);
  const rawText = source.kind === "html"
    ? stripHtml(buffer.toString("utf8"))
    : buffer.toString("latin1").replace(/\s+/g, " ");

  const facts = source.parse(rawText).map((fact) => ({
    ...fact,
    source_hash: hash,
    source_retrieved_at: new Date().toISOString(),
  }));

  return {
    source,
    hash,
    facts,
  };
}

function toSqlLiteral(value) {
  if (value === null || value === undefined) return "NULL";
  if (typeof value === "boolean") return value ? "TRUE" : "FALSE";
  if (typeof value === "number") return String(value);
  return `'${String(value).replace(/'/g, "''")}'`;
}

function factsToSql(facts) {
  const rows = facts.map((fact) => `(
  gen_random_uuid(),
  ${toSqlLiteral(fact.fact_key)},
  ${toSqlLiteral(fact.fact_type)},
  ${toSqlLiteral(fact.jurisdiction_code)},
  ${toSqlLiteral(fact.code_cycle)},
  ${toSqlLiteral(fact.title)},
  ${toSqlLiteral(fact.summary)},
  ${toSqlLiteral(fact.effective_date)},
  ${toSqlLiteral(fact.official_source_url)},
  ${toSqlLiteral(fact.source_provider)},
  ${toSqlLiteral(fact.source_priority)},
  ${toSqlLiteral(fact.source_hash)},
  ${toSqlLiteral(fact.source_retrieved_at)},
  ${toSqlLiteral(fact.amendment_reference)},
  ${toSqlLiteral(JSON.stringify(fact.fact_json || {}))}::jsonb,
  ${toSqlLiteral(fact.freshness_status)}
)`).join(",\n");

  return `INSERT INTO verified_code_facts (
  id,
  fact_key,
  fact_type,
  jurisdiction_code,
  code_cycle,
  title,
  summary,
  effective_date,
  official_source_url,
  source_provider,
  source_priority,
  source_hash,
  source_retrieved_at,
  amendment_reference,
  fact_json,
  freshness_status
)
VALUES
${rows}
ON CONFLICT (fact_key) DO UPDATE SET
  code_cycle = EXCLUDED.code_cycle,
  title = EXCLUDED.title,
  summary = EXCLUDED.summary,
  effective_date = EXCLUDED.effective_date,
  official_source_url = EXCLUDED.official_source_url,
  source_provider = EXCLUDED.source_provider,
  source_priority = EXCLUDED.source_priority,
  source_hash = EXCLUDED.source_hash,
  source_retrieved_at = EXCLUDED.source_retrieved_at,
  amendment_reference = EXCLUDED.amendment_reference,
  fact_json = EXCLUDED.fact_json,
  freshness_status = EXCLUDED.freshness_status,
  updated_at = now();
`;
}

async function main() {
  const outputPath = process.argv[2] ? path.resolve(process.argv[2]) : DEFAULT_OUTPUT;
  const sqlOutputPath = process.argv[3] ? path.resolve(process.argv[3]) : null;

  const results = [];
  for (const source of SOURCES) {
    const result = await fetchSource(source);
    results.push(result);
  }

  const facts = results.flatMap((result) => result.facts);
  writeJson(outputPath, {
    generated_at: new Date().toISOString(),
    facts,
  });

  if (sqlOutputPath) {
    fs.writeFileSync(sqlOutputPath, factsToSql(facts));
  }

  console.log(`Fetched ${facts.length} verified facts from ${results.length} official sources.`);
  console.log(`JSON output: ${outputPath}`);
  if (sqlOutputPath) {
    console.log(`SQL output: ${sqlOutputPath}`);
  }
}

main().catch((error) => {
  console.error(error.stack || String(error));
  process.exitCode = 1;
});
