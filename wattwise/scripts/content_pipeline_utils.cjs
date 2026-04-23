#!/usr/bin/env node

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const REQUIRED_LESSON_HEADINGS = [
  "Learning objective",
  "Why this matters",
  "Core explanation",
  "Key concepts",
  "NEC / code relevance",
  "Practical example",
  "Common mistakes",
  "Exam insight",
];

const BANNED_GENERIC_PHRASES = [
  "todo",
  "tbd",
  "placeholder",
  "coming soon",
  "lorem ipsum",
  "the fundamental principle behind",
  "in real-world applications,",
  "many apprentices and journeymen misunderstand",
  "real electricians must master this concept",
  "in what real-world scenario would you apply",
  "this question tests",
  "the correct answer is",
];

function rootDir() {
  return path.resolve(__dirname, "..");
}

function defaultContentPackPath() {
  return path.join(rootDir(), "wattwise", "Resources", "WattWiseContentPack.json");
}

function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, JSON.stringify(value, null, 2) + "\n");
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function verificationOf(record) {
  return record && record.verification ? record.verification : {
    base_code_cycle: null,
    jurisdiction_scope: "national",
    last_verified_at: null,
    source_urls: [],
    source_hashes: [],
    verification_confidence: 0,
    freshness_status: "unknown",
    publish_status: "draft",
    staleness_reason: "Content has not passed the automated verification pipeline yet.",
    disclaimer: null,
  };
}

function isPublished(record) {
  return verificationOf(record).publish_status === "published";
}

function hasBannedGenericText(text) {
  const lowered = String(text || "").toLowerCase();
  return BANNED_GENERIC_PHRASES.some((phrase) => lowered.includes(phrase));
}

function normalizeText(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

function countBy(items, getKey) {
  return items.reduce((accumulator, item) => {
    const key = getKey(item);
    if (!key) {
      return accumulator;
    }
    accumulator[key] = (accumulator[key] || 0) + 1;
    return accumulator;
  }, {});
}

function duplicatedNormalizedValues(items, getValue) {
  const counts = countBy(items, (item) => normalizeText(getValue(item)));
  return new Set(
    Object.entries(counts)
      .filter(([key, count]) => key && count > 1)
      .map(([key]) => key)
  );
}

function collectLessonAudit(pack) {
  const lessons = pack.fullLessons || [];
  const duplicatedSectionBodies = duplicatedNormalizedValues(
    lessons.flatMap((lesson) =>
      (lesson.lessonContent || []).map((section) => ({
        lessonId: lesson.id,
        heading: section.heading,
        body: section.body,
      }))
    ),
    (item) => `${item.heading || ""}::${item.body || ""}`
  );
  const duplicatedTakeaways = duplicatedNormalizedValues(
    lessons.flatMap((lesson) => (lesson.keyTakeaways || []).map((takeaway) => ({ lessonId: lesson.id, takeaway }))),
    (item) => item.takeaway
  );

  return lessons.map((lesson) => {
    const verification = verificationOf(lesson);
    const headings = (lesson.lessonContent || []).map((section) => section.heading);
    const issues = [];

    const missingHeadings = REQUIRED_LESSON_HEADINGS.filter((heading) => !headings.includes(heading));
    if (missingHeadings.length > 0) {
      issues.push(`Missing required headings: ${missingHeadings.join(", ")}`);
    }

    if (JSON.stringify(headings) !== JSON.stringify(REQUIRED_LESSON_HEADINGS)) {
      issues.push("Headings are not in the required order.");
    }

    if ((lesson.keyTakeaways || []).length < 4) {
      issues.push("Needs at least four key takeaways.");
    }

    if ((lesson.practiceQuestions || []).length < 3) {
      issues.push("Needs at least three knowledge-check questions.");
    }

    if (!(lesson.references || []).length) {
      issues.push("Missing top-level NEC references.");
    }

    for (const section of lesson.lessonContent || []) {
      const body = (section.body || "").trim();
      if (!body) {
        issues.push(`Section ${section.id} is empty.`);
      } else if (body.length < 40) {
        issues.push(`Section ${section.id} is too thin.`);
      }
      if (hasBannedGenericText(body)) {
        issues.push(`Section ${section.id} contains banned generic text.`);
      }
      if (duplicatedSectionBodies.has(normalizeText(`${section.heading || ""}::${section.body || ""}`))) {
        issues.push(`Section ${section.id} reuses body copy found elsewhere in the pack.`);
      }
    }

    for (const takeaway of lesson.keyTakeaways || []) {
      const normalizedTakeaway = normalizeText(takeaway);
      if (normalizedTakeaway.length < 20) {
        issues.push("Lesson contains a takeaway that is too short.");
      }
      if (hasBannedGenericText(takeaway)) {
        issues.push("Lesson contains banned generic text in key takeaways.");
      }
      if (duplicatedTakeaways.has(normalizedTakeaway)) {
        issues.push("Lesson contains a reused takeaway found elsewhere in the pack.");
      }
    }

    for (const prompt of lesson.practiceQuestions || []) {
      const normalizedPrompt = normalizeText(prompt);
      if (!normalizedPrompt.endsWith("?")) {
        issues.push("Lesson knowledge-check prompt is not phrased as a question.");
      }
      if (hasBannedGenericText(prompt)) {
        issues.push("Lesson knowledge-check prompt contains banned generic text.");
      }
    }

    if (!lesson.verification) {
      issues.push("Lesson is missing verification metadata.");
    }

    if (verification.publish_status === "published") {
      if (!verification.last_verified_at) {
        issues.push("Published lesson is missing last_verified_at.");
      }
      if (!(verification.source_urls || []).length) {
        issues.push("Published lesson is missing source_urls.");
      }
      if ((verification.verification_confidence || 0) < 80) {
        issues.push("Published lesson confidence is below 80.");
      }
      if (verification.freshness_status !== "fresh") {
        issues.push(`Published lesson freshness_status is ${verification.freshness_status}.`);
      }
    }

    return {
      id: lesson.id,
      title: lesson.lessonTitle,
      publish_status: verification.publish_status,
      freshness_status: verification.freshness_status,
      verification_confidence: verification.verification_confidence || 0,
      source_count: (verification.source_urls || []).length,
      issues,
    };
  });
}

function collectQuestionAudit(pack) {
  const questions = pack.practiceQuestions || [];
  const duplicatedQuestions = duplicatedNormalizedValues(questions, (question) => question.question);
  const duplicatedExplanations = duplicatedNormalizedValues(questions, (question) => question.explanation);

  return questions.map((question) => {
    const verification = verificationOf(question);
    const issues = [];

    const choices = ["A", "B", "C", "D"].filter((key) => question[`option${key}`]);
    if (choices.length !== 4) {
      issues.push("Question does not have exactly four answer choices.");
    }
    if (!choices.includes(question.correctAnswer)) {
      issues.push("Question has an invalid correct answer key.");
    }
    if (hasBannedGenericText(`${question.question || ""} ${question.explanation || ""}`)) {
      issues.push("Question contains banned generic text.");
    }
    if (!String(question.question || "").trim().endsWith("?")) {
      issues.push("Question stem is not phrased as a question.");
    }
    if (String(question.explanation || "").trim().length < 40) {
      issues.push("Question explanation is too thin.");
    }
    if (!/\bbecause\b|\brather than\b|\bwhile\b/i.test(String(question.explanation || ""))) {
      issues.push("Question explanation does not explain why the correct answer beats the distractors.");
    }
    if (!String(question.necReference || "").trim()) {
      issues.push("Question is missing a reference code.");
    }
    if (duplicatedQuestions.has(normalizeText(question.question))) {
      issues.push("Question stem is duplicated elsewhere in the pack.");
    }
    if (duplicatedExplanations.has(normalizeText(question.explanation))) {
      issues.push("Question explanation is duplicated elsewhere in the pack.");
    }
    if (!question.verification) {
      issues.push("Question is missing verification metadata.");
    }

    if (verification.publish_status === "published") {
      if (!(verification.source_urls || []).length) {
        issues.push("Published question is missing source_urls.");
      }
      if ((verification.verification_confidence || 0) < 80) {
        issues.push("Published question confidence is below 80.");
      }
      if (verification.freshness_status !== "fresh") {
        issues.push(`Published question freshness_status is ${verification.freshness_status}.`);
      }
    }

    return {
      id: question.id,
      topic: question.topic || question.topic_title || "Unknown",
      publish_status: verification.publish_status,
      freshness_status: verification.freshness_status,
      verification_confidence: verification.verification_confidence || 0,
      source_count: (verification.source_urls || []).length,
      issues,
    };
  });
}

function buildReadinessReport(pack) {
  const lessons = pack.fullLessons || [];
  const questions = pack.practiceQuestions || [];
  const flashcards = pack.flashcards || [];
  const glossary = pack.glossary || [];
  const quickReferenceGuides = pack.quickReferenceGuides || [];
  const studyPlans = pack.studyPlans || [];
  const sources = pack.sources || [];

  const lessonAudit = collectLessonAudit(pack);
  const questionAudit = collectQuestionAudit(pack);
  const lessonIssueCount = lessonAudit.reduce((count, lesson) => count + lesson.issues.length, 0);
  const questionIssueCount = questionAudit.reduce((count, question) => count + question.issues.length, 0);
  const lessonFailures = lessonAudit.filter((lesson) => lesson.issues.length > 0).length;
  const questionFailures = questionAudit.filter((question) => question.issues.length > 0).length;
  const repeatedLessonCopyWarnings = lessonAudit.flatMap((lesson) =>
    lesson.issues.filter((issue) => issue.includes("reuses body copy"))
  ).length;

  const score = Math.max(
    0,
    Math.round(
      100
        - lessonFailures * 0.55
        - questionFailures * 0.12
        - repeatedLessonCopyWarnings * 0.03
        - Math.max(0, 92 - lessons.length) * 0.4
        - Math.max(0, 460 - questions.length) * 0.05
        - (glossary.length === 0 ? 6 : 0)
        - (quickReferenceGuides.length === 0 ? 6 : 0)
        - (studyPlans.length === 0 ? 5 : 0)
        - (sources.length < 10 ? 10 : 0)
    )
  );

  return {
    generated_at: new Date().toISOString(),
    metadata_status: pack.metadata?.contentStatus || null,
    score_out_of_10: Number((score / 10).toFixed(1)),
    score_out_of_100: score,
    totals: {
      lessons: lessons.length,
      practice_questions: questions.length,
      flashcards: flashcards.length,
      glossary: glossary.length,
      quick_reference_guides: quickReferenceGuides.length,
      study_plans: studyPlans.length,
      sources: sources.length,
      published_lessons: lessonAudit.filter((lesson) => lesson.publish_status === "published").length,
      published_questions: questionAudit.filter((question) => question.publish_status === "published").length,
    },
    grade_breakdown: {
      curriculum_coverage: lessons.length === 92 ? 8 : 4,
      lesson_quality: Number((Math.max(0, 10 - lessonFailures / 18)).toFixed(1)),
      quiz_quality: Number((Math.max(0, 10 - questionFailures / 35)).toFixed(1)),
      source_provenance: sources.length >= 10 ? 7 : 2,
      customer_readiness:
        lessonAudit.some((lesson) => lesson.publish_status === "published") ||
        questionAudit.some((question) => question.publish_status === "published")
          ? 5
          : 2,
    },
    critical_findings: [
      lessonFailures === 92 ? "All 92 lessons still fail production validation." : null,
      questionFailures > 0 ? `${questionFailures} practice questions fail production validation.` : null,
      sources.length < 10 ? "Source coverage is too thin for customer-ready claims." : null,
      repeatedLessonCopyWarnings > 0 ? `${repeatedLessonCopyWarnings} lesson sections still reuse body copy from elsewhere in the pack.` : null,
      glossary.length === 0 ? "Glossary is missing." : null,
      quickReferenceGuides.length === 0 ? "Quick-reference guides are missing." : null,
      studyPlans.length === 0 ? "Study plans are missing." : null,
      (pack.metadata?.contentStatus || "").includes("production_ready")
        ? "Raw metadata still overstates content readiness."
        : null,
    ].filter(Boolean),
    issue_counts: {
      lesson_issue_count: lessonIssueCount,
      question_issue_count: questionIssueCount,
      lessons_with_issues: lessonFailures,
      questions_with_issues: questionFailures,
    },
    asset_coverage: {
      flashcards_per_lesson: Number((flashcards.length / Math.max(lessons.length, 1)).toFixed(2)),
      questions_per_lesson: Number((questions.length / Math.max(lessons.length, 1)).toFixed(2)),
      glossary_entries: glossary.length,
      quick_reference_guides: quickReferenceGuides.length,
      study_plans: studyPlans.length,
    },
    lesson_audit: lessonAudit,
    question_audit: questionAudit,
  };
}

module.exports = {
  BANNED_GENERIC_PHRASES,
  REQUIRED_LESSON_HEADINGS,
  buildReadinessReport,
  collectLessonAudit,
  collectQuestionAudit,
  defaultContentPackPath,
  hasBannedGenericText,
  isPublished,
  loadJson,
  rootDir,
  sha256,
  verificationOf,
  writeJson,
};
