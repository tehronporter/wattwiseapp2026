#!/usr/bin/env node

const path = require("path");
const {
  defaultContentPackPath,
  isPublished,
  loadJson,
  verificationOf,
  writeJson,
} = require("./content_pipeline_utils.cjs");

function slugify(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

const includeDrafts = process.argv.includes("--include-drafts");
const positionalArgs = process.argv.slice(2).filter((arg) => !arg.startsWith("--"));
const inputPath = positionalArgs[0]
  ? path.resolve(positionalArgs[0])
  : defaultContentPackPath();
const outputPath = positionalArgs[1]
  ? path.resolve(positionalArgs[1])
  : inputPath;

const pack = loadJson(inputPath);
const lessons = (pack.fullLessons || []).filter((lesson) => includeDrafts || isPublished(lesson));
const questions = (pack.practiceQuestions || []).filter((question) => includeDrafts || isPublished(question));

const derivedFlashcards = lessons.flatMap((lesson, lessonIndex) => {
  const verification = verificationOf(lesson);
  return (lesson.keyTakeaways || []).slice(0, 2).map((takeaway, takeawayIndex) => ({
    id: `fc-derived-${lesson.id}-${takeawayIndex + 1}`,
    front: `${lesson.lessonTitle}: key takeaway ${takeawayIndex + 1}`,
    back: takeaway,
    topic: lesson.references?.[0] || lesson.moduleName,
    certificationLevel: lesson.certificationLevel,
    verification,
  }));
});

const derivedGlossary = lessons.map((lesson) => ({
  id: `glossary-${lesson.id}`,
  term: lesson.lessonTitle,
  definition: (lesson.lessonContent || []).find((section) => /core|key/i.test(section.heading || ""))?.body
    || lesson.learningObjectives?.join("; ")
    || lesson.lessonTitle,
  necReference: lesson.references?.[0] || "",
  certificationLevel: lesson.certificationLevel,
  verification: verificationOf(lesson),
}));

const guidesByModule = new Map();
for (const lesson of lessons) {
  const key = `${lesson.certificationLevel}::${lesson.moduleName}`;
  if (!guidesByModule.has(key)) {
    guidesByModule.set(key, []);
  }
  guidesByModule.get(key).push(lesson);
}

const derivedQuickReferenceGuides = Array.from(guidesByModule.entries()).map(([key, moduleLessons]) => {
  const sample = moduleLessons[0];
  return {
    id: `quickref-${slugify(key)}`,
    title: `${sample.moduleName} quick reference`,
    certificationLevel: sample.certificationLevel,
    bullets: moduleLessons.flatMap((lesson) => (lesson.keyTakeaways || []).slice(0, 1)).slice(0, 8),
    references: Array.from(new Set(moduleLessons.flatMap((lesson) => lesson.references || []))).slice(0, 8),
    verification: verificationOf(sample),
  };
});

const levels = Array.from(new Set(lessons.map((lesson) => lesson.certificationLevel)));
const derivedStudyPlans = levels.map((level) => {
  const levelLessons = lessons.filter((lesson) => lesson.certificationLevel === level);
  const weeklyFocus = [];
  for (let index = 0; index < levelLessons.length; index += 4) {
    const window = levelLessons.slice(index, index + 4);
    weeklyFocus.push(window.map((lesson) => lesson.lessonTitle).join(", "));
  }
  return {
    id: `studyplan-${slugify(level)}`,
    title: `${level} study plan`,
    certificationLevel: level,
    durationWeeks: Math.max(weeklyFocus.length, 1),
    weeklyFocus,
    verification: verificationOf(levelLessons[0] || {}),
  };
});

const referencedSourceURLs = new Set(
  [...lessons, ...questions].flatMap((record) => verificationOf(record).source_urls || [])
);

const outputPack = {
  ...pack,
  flashcards: derivedFlashcards,
  glossary: derivedGlossary,
  quickReferenceGuides: derivedQuickReferenceGuides,
  studyPlans: derivedStudyPlans,
  sources: (pack.sources || []).filter((source) => !source.url || referencedSourceURLs.has(source.url)),
};

writeJson(outputPath, outputPack);

console.log(`Derived secondary assets into ${outputPath}`);
console.log(`Lessons considered: ${lessons.length}`);
console.log(`Questions considered: ${questions.length}`);
console.log(`Flashcards: ${derivedFlashcards.length}`);
console.log(`Glossary entries: ${derivedGlossary.length}`);
console.log(`Quick-reference guides: ${derivedQuickReferenceGuides.length}`);
console.log(`Study plans: ${derivedStudyPlans.length}`);
