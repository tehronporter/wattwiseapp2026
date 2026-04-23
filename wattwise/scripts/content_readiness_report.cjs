#!/usr/bin/env node

const path = require("path");
const {
  buildReadinessReport,
  defaultContentPackPath,
  loadJson,
  writeJson,
} = require("./content_pipeline_utils.cjs");

const inputPath = process.argv[2]
  ? path.resolve(process.argv[2])
  : defaultContentPackPath();
const outputPath = process.argv[3]
  ? path.resolve(process.argv[3])
  : null;

const pack = loadJson(inputPath);
const report = buildReadinessReport(pack);

if (outputPath) {
  writeJson(outputPath, report);
}

console.log(`Content readiness score: ${report.score_out_of_10}/10`);
console.log(`Lessons: ${report.totals.lessons}`);
console.log(`Practice questions: ${report.totals.practice_questions}`);
console.log(`Flashcards: ${report.totals.flashcards}`);
console.log(`Glossary entries: ${report.totals.glossary}`);
console.log(`Quick-reference guides: ${report.totals.quick_reference_guides}`);
console.log(`Study plans: ${report.totals.study_plans}`);
if (report.critical_findings.length > 0) {
  console.log("Critical findings:");
  for (const finding of report.critical_findings) {
    console.log(`- ${finding}`);
  }
}
if (outputPath) {
  console.log(`Report written to ${outputPath}`);
}
