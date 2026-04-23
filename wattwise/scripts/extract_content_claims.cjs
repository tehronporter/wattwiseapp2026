#!/usr/bin/env node

const path = require("path");
const {
  defaultContentPackPath,
  isPublished,
  loadJson,
  writeJson,
} = require("./content_pipeline_utils.cjs");

function sentenceSplit(text) {
  return String(text || "")
    .split(/(?<=[.?!])\s+/)
    .map((value) => value.trim())
    .filter(Boolean);
}

function classifyClaim(text) {
  const lowered = text.toLowerCase();
  if (/\b(article|section|table|annex)\b|\b\d{2,3}\.\d/.test(lowered)) return "nec_reference";
  if (/[=×x\/]\s*\d|\bamp|\bvolt|\bohm|\bva\b|\b125%\b/.test(lowered)) return "formula";
  if (/\bexam\b|\btest\b|\bquestion\b|\bcommon mistake\b/.test(lowered)) return "exam_strategy";
  if (/\bstate\b|\bjurisdiction\b|\badopted\b|\beffective\b/.test(lowered)) return "jurisdiction";
  if (/\bcurrent\b|\blatest\b|\bnow\b|\b202[0-9]\b|\bnec\s20[0-9]{2}\b/.test(lowered)) return "currentness";
  if (/\bis\b|\bmeans\b|\brefers to\b/.test(lowered)) return "definition";
  return "other";
}

function claimKey(recordId, sourceId, index, text) {
  return `${recordId}:${sourceId}:${index}:${text.toLowerCase().replace(/[^a-z0-9]+/g, "-").slice(0, 60)}`;
}

const includeDrafts = process.argv.includes("--include-drafts");
const positionalArgs = process.argv.slice(2).filter((arg) => !arg.startsWith("--"));
const inputPath = positionalArgs[0]
  ? path.resolve(positionalArgs[0])
  : defaultContentPackPath();
const outputPath = positionalArgs[1]
  ? path.resolve(positionalArgs[1])
  : path.join(path.dirname(inputPath), "content_claims.json");

const pack = loadJson(inputPath);
const lessons = (pack.fullLessons || []).filter((lesson) => includeDrafts || isPublished(lesson));
const questions = (pack.practiceQuestions || []).filter((question) => includeDrafts || isPublished(question));

const lessonClaims = lessons.flatMap((lesson) =>
  (lesson.lessonContent || []).flatMap((section) =>
    sentenceSplit(section.body).map((sentence, index) => ({
      lesson_id: lesson.id,
      source_id: section.id,
      claim_key: claimKey(lesson.id, section.id, index, sentence),
      claim_type: classifyClaim(sentence),
      claim_text: sentence,
      nec_references: section.necReferences || [],
      certification_level: lesson.certificationLevel,
      jurisdiction_scope: lesson.verification?.jurisdiction_scope || "national",
    }))
  )
);

const questionClaims = questions.flatMap((question, index) =>
  [question.question, question.explanation]
    .filter(Boolean)
    .map((text, localIndex) => ({
      question_id: question.id,
      claim_key: claimKey(question.id, question.id, localIndex, text),
      claim_type: classifyClaim(text),
      claim_text: text,
      nec_reference: question.necReference || "",
      certification_level: question.certificationLevel,
      jurisdiction_scope: question.verification?.jurisdiction_scope || "national",
    }))
);

const payload = {
  generated_at: new Date().toISOString(),
  include_drafts: includeDrafts,
  lesson_claims: lessonClaims,
  question_claims: questionClaims,
};

writeJson(outputPath, payload);

console.log(`Extracted content claims to ${outputPath}`);
console.log(`Lesson claims: ${lessonClaims.length}`);
console.log(`Question claims: ${questionClaims.length}`);
