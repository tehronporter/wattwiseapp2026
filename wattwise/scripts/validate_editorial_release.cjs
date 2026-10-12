#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const reportOnly = process.argv.includes("--report-only");
const queuePath = path.resolve(__dirname, "..", "docs", "editorial-priority-queue.json");
const contentPackPath = path.resolve(__dirname, "..", "wattwise", "Resources", "WattWiseContentPack.json");
const validStatuses = new Set(["not_started", "in_review", "changes_requested", "approved"]);
const queue = JSON.parse(fs.readFileSync(queuePath, "utf8"));
const contentPack = JSON.parse(fs.readFileSync(contentPackPath, "utf8"));
const knownContent = {
  lesson: new Set((contentPack.fullLessons || []).map((item) => item.id)),
  practice_question: new Set((contentPack.practiceQuestions || []).map((item) => item.id)),
  exam: new Set((contentPack.mockExams || []).map((item) => item.id)),
};

if (!Array.isArray(queue.items) || queue.items.length === 0) {
  console.error("Editorial release gate: queue has no review items.");
  process.exit(1);
}

const malformed = [];
const sourceMismatches = [];
const incomplete = [];
const seen = new Set();

for (const item of queue.items) {
  const key = `${item.content_kind}:${item.source_key}`;
  if (!item.content_kind || !item.source_key || !Number.isInteger(item.priority) || item.priority < 1 || !validStatuses.has(item.review_status) || !Array.isArray(item.required_artifacts) || item.required_artifacts.length === 0 || seen.has(key)) {
    malformed.push(key);
  }
  seen.add(key);
  if (!knownContent[item.content_kind]?.has(item.source_key)) sourceMismatches.push(key);
  if (item.review_status !== "approved") incomplete.push(`${key} (${item.review_status})`);
}

const summary = {
  queue: path.relative(process.cwd(), queuePath),
  total_items: queue.items.length,
  approved_items: queue.items.length - incomplete.length,
  pending_items: incomplete,
  malformed_items: malformed,
  source_mismatches: sourceMismatches,
  outcome: malformed.length || sourceMismatches.length || incomplete.length ? "blocked" : "ready_for_sme_approved_release",
};

console.log(JSON.stringify(summary, null, 2));

if (!reportOnly && (malformed.length || sourceMismatches.length || incomplete.length)) {
  console.error("Editorial release gate is blocked. Run with --report-only to inspect progress without failing development checks.");
  process.exit(1);
}
