#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const packPath = process.argv[2] || path.resolve(__dirname, "..", "wattwise", "Resources", "WattWiseContentPack.json");
const pack = JSON.parse(fs.readFileSync(packPath, "utf8"));
const lessons = pack.fullLessons || [];
const questions = pack.practiceQuestions || [];

function normalize(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[“”]/g, '"')
    .replace(/\b[a-z]{2,4}-les-\d+\b/g, "<lesson>")
    .replace(/\b(?:scenario|question) \d+\b/g, "<numbered>")
    .replace(/\s+/g, " ")
    .trim();
}

function countBy(values) {
  const result = new Map();
  for (const value of values) {
    const key = normalize(value);
    if (key) result.set(key, (result.get(key) || 0) + 1);
  }
  return [...result.entries()].filter(([, count]) => count > 1).sort((a, b) => b[1] - a[1]);
}

const lessonBodies = lessons.flatMap((lesson) => (lesson.lessonContent || []).map((section) => section.body));
const genericPatterns = [
  "confirm scope before selecting",
  "identify the governing rule path",
  "select the table path",
  "timed exams because candidates must connect theory",
];
const sample = (items, limit = 12) => ({ count: items.length, sample_ids: items.slice(0, limit) });
const lessonText = (lesson) => (lesson.lessonContent || []).map((section) => section.body || "").join(" ");
const topicCounts = {};
for (const question of questions) {
  const topic = question.topic || "Unclassified";
  topicCounts[topic] = (topicCounts[topic] || 0) + 1;
}
const report = {
  generated_at: new Date().toISOString(),
  source: packPath,
  totals: { lessons: lessons.length, questions: questions.length },
  coverage: {
    lessons_by_level: Object.fromEntries(["Apprentice", "Journeyman", "Master"].map((level) => [level, lessons.filter((lesson) => lesson.certificationLevel === level).length])),
    questions_by_level: Object.fromEntries(["Apprentice", "Journeyman", "Master"].map((level) => [level, questions.filter((question) => question.certificationLevel === level).length])),
    questions_by_topic: topicCounts,
    calculation_questions: questions.filter((question) => question.isCalculation).length,
    code_lookup_questions: questions.filter((question) => question.isCodeLookup).length,
  },
  quality_signals: {
    lessons_without_numeric_worked_example: sample(lessons.filter((lesson) => !/\d+\s*(?:a|amp|v|volt|w|watt|ohm|%|awg|ft)\b/i.test(lessonText(lesson))).map((lesson) => lesson.id)),
    lessons_without_explicit_solution_sequence: sample(lessons.filter((lesson) => !/\b(?:given|solve|calculate|equation|formula|step 1)\b/i.test(lessonText(lesson))).map((lesson) => lesson.id)),
    questions_with_generic_scenario_language: sample(questions.filter((question) => /\bscenario \d+\b/i.test(question.question || "")).map((question) => question.id)),
    repeated_normalized_lesson_bodies: countBy(lessonBodies).slice(0, 25).map(([text, count]) => ({ text, count })),
    generic_phrase_frequency: Object.fromEntries(genericPatterns.map((pattern) => [pattern, lessonBodies.filter((body) => normalize(body).includes(pattern)).length])),
    questions_missing_state_or_exam_blueprint_mapping: sample(questions.filter((question) => !(question.examBlueprintTags || []).some((tag) => /state|jurisdiction|blueprint/i.test(tag))).map((question) => question.id)),
  },
  publication_note: "This is a quality and coverage diagnostic, not an approval gate. Instructor/SME review remains required before claims of state-exam alignment.",
};

console.log(JSON.stringify(report, null, 2));
