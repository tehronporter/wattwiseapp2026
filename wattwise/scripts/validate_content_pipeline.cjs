#!/usr/bin/env node

const path = require("path");
const {
  buildReadinessReport,
  collectLessonAudit,
  collectQuestionAudit,
  defaultContentPackPath,
  loadJson,
  verificationOf,
  writeJson,
} = require("./content_pipeline_utils.cjs");

const contentPackPath = process.argv[2]
  ? path.resolve(process.argv[2])
  : defaultContentPackPath();
const outputPath = process.argv[3] ? path.resolve(process.argv[3]) : null;

const pack = loadJson(contentPackPath);
const readinessReport = buildReadinessReport(pack);
const lessonAudit = readinessReport.lesson_audit;
const questionAudit = readinessReport.question_audit;

const publishedLessons = lessonAudit.filter((entry) => entry.publish_status === "published");
const publishedQuestions = questionAudit.filter((entry) => entry.publish_status === "published");

const report = {
  ...readinessReport,
  generated_at: new Date().toISOString(),
  content_pack_path: contentPackPath,
  lessons: lessonAudit,
  questions: questionAudit,
  summary: {
    lesson_issues: lessonAudit.reduce((count, lesson) => count + lesson.issues.length, 0),
    question_issues: questionAudit.reduce((count, question) => count + question.issues.length, 0),
    published_content_ready:
      publishedLessons.length > 0 &&
      publishedQuestions.length > 0 &&
      lessonAudit.every((lesson) => lesson.publish_status !== "published" || lesson.issues.length === 0) &&
      questionAudit.every((question) => question.publish_status !== "published" || question.issues.length === 0),
    draft_content_ready:
      lessonAudit.length === 92 &&
      lessonAudit.every((lesson) => lesson.issues.length === 0) &&
      questionAudit.every((question) => question.issues.length === 0),
  },
};

if (outputPath) {
  writeJson(outputPath, report);
}

const errors = [];

if (lessonAudit.length !== 92) {
  errors.push(`Expected 92 lessons, found ${lessonAudit.length}.`);
}

const lessonFailures = lessonAudit.filter((lesson) => lesson.issues.length > 0);
const questionFailures = questionAudit.filter((question) => question.issues.length > 0);

if (lessonFailures.length > 0) {
  errors.push(`${lessonFailures.length} lessons have validation issues.`);
}

if (questionFailures.length > 0) {
  errors.push(`${questionFailures.length} practice questions have validation issues.`);
}

for (const lesson of publishedLessons) {
  const verification = verificationOf(
    (pack.fullLessons || []).find((entry) => entry.id === lesson.id)
  );
  if ((verification.source_hashes || []).length === 0) {
    errors.push(`Published lesson ${lesson.id} is missing source_hashes.`);
  }
}

if (errors.length > 0) {
  console.error("Automated content validation failed.");
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exitCode = 1;
} else {
  console.log("Automated content validation passed.");
}

console.log(`Lessons: ${lessonAudit.length} (${publishedLessons.length} published)`);
console.log(`Practice questions: ${questionAudit.length} (${publishedQuestions.length} published)`);
console.log(`Readiness score: ${readinessReport.score_out_of_10}/10`);
if (outputPath) {
  console.log(`Audit report: ${outputPath}`);
}
