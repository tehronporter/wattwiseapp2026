#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const packPath = path.join(root, "wattwise", "Resources", "WattWiseContentPack.json");
const seedPath = path.join(root, "supabase", "seed.sql");
const schemaPaths = [
  path.join(root, "supabase", "migrations", "20260330000000_wattwise_schema.sql"),
  path.join(root, "supabase", "migrations", "20260401010000_content_pipeline_hardening.sql"),
];

const edgeFunctions = [
  "get_modules",
  "get_lesson",
  "save_progress",
  "progress_summary",
  "nec_search",
  "nec_detail",
  "nec_explain",
];

const requiredHeadings = [
  "Learning objective",
  "Why this matters",
  "Core explanation",
  "Key concepts",
  "NEC / code relevance",
  "Practical example",
  "Common mistakes",
  "Exam insight",
];

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exitCode = 1;
}

function expect(condition, message) {
  if (!condition) fail(message);
}

function countOccurrences(haystack, needle) {
  return (haystack.match(new RegExp(needle, "g")) || []).length;
}

const pack = JSON.parse(fs.readFileSync(packPath, "utf8"));
const seed = fs.readFileSync(seedPath, "utf8");
const schemas = schemaPaths.map((filePath) => fs.readFileSync(filePath, "utf8")).join("\n");

const blueprintIds = pack.curriculumFramework.flatMap((course) =>
  course.modules.flatMap((module) => module.lessons.map((lesson) => lesson.id))
);
const authoredIds = pack.fullLessonContent.map((lesson) => lesson.id);

expect(new Set(blueprintIds).size === 24, "Curriculum should define exactly 24 lesson IDs.");
expect(
  JSON.stringify([...new Set(blueprintIds)].sort()) === JSON.stringify([...new Set(authoredIds)].sort()),
  "Authored lesson IDs must match curriculum lesson IDs exactly."
);

for (const lesson of pack.fullLessonContent) {
  expect(
    JSON.stringify(lesson.lessonContent.map((section) => section.heading)) === JSON.stringify(requiredHeadings),
    `Lesson ${lesson.id} must follow the required heading order.`
  );
  expect(lesson.keyTakeaways.length >= 4, `Lesson ${lesson.id} must have at least 4 takeaways.`);
  expect(lesson.practiceQuestions.length >= 3, `Lesson ${lesson.id} must have at least 3 practice questions.`);
  expect(lesson.references.length > 0, `Lesson ${lesson.id} must have references.`);

  const sectionRefs = new Set(lesson.lessonContent.flatMap((section) => section.necReferences));
  for (const code of sectionRefs) {
    expect(
      lesson.references.includes(code),
      `Lesson ${lesson.id} is missing ${code} from top-level references.`
    );
  }
}

expect(countOccurrences(seed, "INSERT INTO modules ") === 12, "Seed must insert 12 modules.");
expect(countOccurrences(seed, "INSERT INTO lessons ") === 24, "Seed must insert 24 lessons.");
expect(countOccurrences(seed, "INSERT INTO lesson_sections ") === 408, "Seed must insert 408 lesson sections.");
expect(countOccurrences(seed, "INSERT INTO lesson_nec_references ") > 0, "Seed must insert lesson NEC references.");

const requiredSchemaFragments = [
  "CREATE TABLE IF NOT EXISTS modules",
  "CREATE TABLE IF NOT EXISTS lessons",
  "CREATE TABLE IF NOT EXISTS lesson_sections",
  "CREATE TABLE IF NOT EXISTS topic_tags",
  "CREATE TABLE IF NOT EXISTS lesson_topic_tags",
  "CREATE TABLE IF NOT EXISTS nec_entries",
  "CREATE TABLE IF NOT EXISTS nec_search_index",
  "CREATE TABLE IF NOT EXISTS lesson_nec_references",
  "CREATE TABLE IF NOT EXISTS lesson_progress",
  "CREATE OR REPLACE FUNCTION public.handle_new_user_profile()",
  "CREATE UNIQUE INDEX IF NOT EXISTS idx_lesson_sections_lesson_sort_unique",
];

for (const fragment of requiredSchemaFragments) {
  expect(schemas.includes(fragment), `Schema is missing required fragment: ${fragment}`);
}

for (const functionName of edgeFunctions) {
  const filePath = path.join(root, "supabase", "functions", functionName, "index.ts");
  const source = fs.readFileSync(filePath, "utf8");
  expect(source.includes("success: true"), `${functionName} must return success responses.`);
  expect(source.includes("data:"), `${functionName} must wrap payloads in a data envelope.`);
}

if (process.exitCode !== 1) {
  console.log("Content pipeline validation passed.");
  console.log("Lessons: 24");
  console.log("Modules: 12");
  console.log("Seed lesson sections: 408");
  console.log(`Edge functions checked: ${edgeFunctions.length}`);
}
