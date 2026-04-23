#!/usr/bin/env node

const path = require("path");
const {
  defaultContentPackPath,
  isPublished,
  loadJson,
  verificationOf,
  writeJson,
} = require("./content_pipeline_utils.cjs");

const inputPath = process.argv[2]
  ? path.resolve(process.argv[2])
  : defaultContentPackPath();
const outputPath = process.argv[3]
  ? path.resolve(process.argv[3])
  : inputPath;

const pack = loadJson(inputPath);

const publishedLessons = (pack.fullLessons || []).filter(isPublished);
const publishedQuestions = (pack.practiceQuestions || []).filter(isPublished);
const publishedFlashcards = (pack.flashcards || []).filter((entry) => isPublished(entry));
const publishedGlossary = (pack.glossary || []).filter((entry) => isPublished(entry));
const publishedQuickReferenceGuides = (pack.quickReferenceGuides || []).filter((entry) => isPublished(entry));
const publishedStudyPlans = (pack.studyPlans || []).filter((entry) => isPublished(entry));

const referencedSourceURLs = new Set();
for (const record of [...publishedLessons, ...publishedQuestions, ...publishedFlashcards, ...publishedGlossary, ...publishedQuickReferenceGuides, ...publishedStudyPlans]) {
  for (const sourceURL of verificationOf(record).source_urls || []) {
    referencedSourceURLs.add(sourceURL);
  }
}

const publishedPack = {
  ...pack,
  metadata: {
    ...pack.metadata,
    contentStatus: "published_export",
    validationStatus: `${publishedLessons.length} published lessons, ${publishedQuestions.length} published practice questions`,
    exportedOn: new Date().toISOString(),
  },
  fullLessons: publishedLessons,
  practiceQuestions: publishedQuestions,
  flashcards: publishedFlashcards,
  glossary: publishedGlossary,
  quickReferenceGuides: publishedQuickReferenceGuides,
  studyPlans: publishedStudyPlans,
  sources: (pack.sources || []).filter((source) => referencedSourceURLs.has(source.url)),
};

writeJson(outputPath, publishedPack);

console.log(`Exported published content to ${outputPath}`);
console.log(`Lessons: ${publishedLessons.length}`);
console.log(`Practice questions: ${publishedQuestions.length}`);
console.log(`Flashcards: ${publishedFlashcards.length}`);
