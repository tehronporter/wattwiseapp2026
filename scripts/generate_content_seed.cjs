#!/usr/bin/env node

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const packPath = path.join(root, "wattwise", "Resources", "WattWiseContentPack.json");
const outputPath = path.join(root, "supabase", "seed.sql");

const referenceCatalog = {
  "90.1": ["Purpose", "Explains the practical purpose of the NEC and its role in safeguarding people and property."],
  "90.3": ["Code Arrangement", "Shows how general rules interact with specific rules and why special chapters can modify the earlier chapters."],
  "90.4": ["Enforcement", "Addresses interpretation and enforcement by the authority having jurisdiction."],
  "110.1": ["Scope", "Introduces the general requirements that apply to electrical installations and equipment."],
  "110.2": ["Approval", "Requires equipment and conductors to be acceptable to the authority having jurisdiction."],
  "110.3(B)": ["Installation and Use", "Requires listed or labeled equipment to be installed and used according to its instructions."],
  "110.4": ["Voltages", "Addresses voltage considerations that affect installation and equipment application."],
  "110.26": ["Spaces About Electrical Equipment", "Covers working-space, access, and dedicated-space rules around electrical equipment."],
  "110.27": ["Guarding of Live Parts", "Requires live parts to be guarded against accidental contact."],
  "210.11": ["Branch Circuits Required", "Identifies required dwelling-unit branch circuits such as small-appliance, laundry, and bathroom circuits."],
  "210.19(A)(1)": ["Branch-Circuit Conductor Sizing", "Sets minimum conductor ampacity for branch circuits and continuous loads."],
  "210.20(A)": ["Overcurrent Protection", "Requires branch-circuit overcurrent devices to be sized for noncontinuous and continuous loads."],
  "210.52": ["Dwelling Receptacle Requirements", "Sets receptacle placement rules for dwelling-unit wall spaces and special areas."],
  "215.2": ["Feeder Conductor Sizing", "Covers minimum ampacity requirements for feeder conductors."],
  "215.3": ["Feeder Overcurrent Protection", "Requires feeder overcurrent devices to be sized for continuous and noncontinuous loads."],
  "220.40": ["General Calculation Methods", "States that branch-circuit, feeder, and service calculations use the rules in Article 220."],
  "220.42": ["Lighting Load Demand Factors", "Provides demand factors for lighting loads used in building calculations."],
  "220.44": ["Receptacle Load Demand Factors", "Allows demand factors for certain receptacle loads in feeder and service calculations."],
  "220.50": ["Motor Loads", "Requires the motor load to be based on the largest motor plus other applicable loads."],
  "220.53": ["Appliance Demand Factors", "Allows demand factors for fastened-in-place appliances when the conditions are met."],
  "220.54": ["Electric Clothes Dryers", "Provides load rules for household electric clothes dryers."],
  "220.60": ["Noncoincident Loads", "Allows only the larger of two loads when it is clear they will not operate at the same time."],
  "220.82": ["Optional Dwelling Calculation", "Provides the optional calculation method for dwelling-unit services and feeders."],
  "230.42": ["Service Conductors", "Covers minimum ampacity requirements for service conductors."],
  "250.24": ["Service Grounding and Bonding", "Explains grounding and bonding rules at the service disconnecting means."],
  "250.32": ["Buildings or Structures Supplied by a Feeder", "Gives grounding and bonding rules for separate buildings or structures."],
  "250.50": ["Grounding Electrode System", "Requires available electrodes to be bonded together into one grounding electrode system."],
  "250.66": ["Grounding Electrode Conductor Sizing", "Provides sizing rules for grounding electrode conductors."],
  "300.11": ["Securing and Supporting", "Requires raceways, cable assemblies, and boxes to be secured and supported correctly."],
  "310.14": ["Ampacity Selection", "Directs users to choose conductor ampacity using the applicable tables and conditions of use."],
  "310.16": ["Ampacity Table", "Lists allowable ampacities for insulated conductors under stated conditions."],
  "314.16": ["Box Fill", "Provides box-volume calculations based on conductors, devices, fittings, and grounds."],
  "430.22": ["Motor Circuit Conductors", "Requires motor branch-circuit conductors to be sized from motor full-load current rules."],
  "430.32": ["Motor Overload Protection", "Covers motor overload protection sizing and settings."],
  "430.52": ["Short-Circuit and Ground-Fault Protection", "Gives maximum ratings for motor branch-circuit short-circuit and ground-fault protection."],
  "500.5": ["Classifications of Hazardous Locations", "Defines how hazardous locations are classified by class, division, and zone."],
  "500.7": ["Protection Techniques", "Lists protection techniques used for equipment in hazardous locations."],
  "501.10": ["Wiring Methods", "Covers permitted wiring methods in Class I locations."],
  "501.15": ["Sealing and Drainage", "Explains sealing fitting rules used to control gases, vapors, and pressure."],
  "501.125": ["Motors", "Provides motor requirements for Class I hazardous locations."],
  "502.10": ["Class II Wiring Methods", "Covers wiring methods in Class II locations where combustible dust is present."],
  "505.9": ["Zone 0, 1, and 2 Equipment", "Addresses equipment permitted in classified zone locations."],
  "Annex D": ["Examples", "Contains informative calculation examples that help users practice NEC problem solving."],
  "Article 100": ["Definitions", "Holds defined terms used throughout the NEC and is a frequent starting point for code lookup."]
};

function deterministicUuid(key) {
  const bytes = crypto.createHash("sha256").update(key).digest().subarray(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function slugify(value) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

function sqlValue(value) {
  if (value === null || value === undefined) return "NULL";
  if (typeof value === "boolean") return value ? "TRUE" : "FALSE";
  if (typeof value === "number") return Number.isFinite(value) ? String(value) : "NULL";
  return `'${String(value).replace(/'/g, "''")}'`;
}

function jsonValue(value) {
  return sqlValue(JSON.stringify(value));
}

function collectLessons(pack) {
  const lessons = [];

  for (const course of pack.curriculumFramework) {
    for (const module of course.modules) {
      const moduleId = deterministicUuid(`module:${module.id}`);
      const moduleTags = [
        course.certificationLevel.toLowerCase(),
        slugify(module.moduleName),
        module.learningObjectives.some((objective) => objective.toLowerCase().includes("nec")) ? "nec" : null
      ].filter(Boolean);

      for (const lesson of module.lessons) {
        const record = pack.fullLessonContent.find((entry) => entry.id === lesson.id);
        if (!record) {
          throw new Error(`Missing authored lesson content for ${lesson.id}`);
        }

        lessons.push({
          course,
          module,
          moduleId,
          moduleTags,
          lesson,
          lessonId: deterministicUuid(`lesson:${lesson.id}`),
          record
        });
      }
    }
  }

  return lessons;
}

function validate(pack) {
  const blueprintIds = new Set(pack.curriculumFramework.flatMap((course) => course.modules).flatMap((module) => module.lessons).map((lesson) => lesson.id));
  const authoredIds = new Set(pack.fullLessonContent.map((lesson) => lesson.id));

  if (blueprintIds.size !== 24) {
    throw new Error(`Expected 24 curriculum lessons, found ${blueprintIds.size}.`);
  }

  if (authoredIds.size !== blueprintIds.size) {
    throw new Error(`Expected ${blueprintIds.size} authored lessons, found ${authoredIds.size}.`);
  }

  for (const id of blueprintIds) {
    if (!authoredIds.has(id)) {
      throw new Error(`Missing authored lesson for ${id}.`);
    }
  }
}

function uniqueReferenceCodes(lessonRecord) {
  return Array.from(
    new Set([
      ...lessonRecord.references,
      ...lessonRecord.lessonContent.flatMap((section) => section.necReferences),
    ])
  );
}

function buildSections(lessonRecord) {
  const sections = [];
  let order = 1;

  for (const paragraph of lessonRecord.lessonContent) {
    sections.push({
      id: deterministicUuid(`section:${lessonRecord.id}:core:${order}`),
      sortOrder: order,
      sectionType: "paragraph",
      heading: paragraph.heading,
      body: paragraph.body,
      meta: paragraph.necReferences.length > 0 ? { necReferences: paragraph.necReferences } : {}
    });
    order += 1;
  }

  sections.push({
    id: deterministicUuid(`section:${lessonRecord.id}:takeaways-heading`),
    sortOrder: order++,
    sectionType: "heading",
    heading: null,
    body: "Key Takeaways",
    meta: {}
  });

  lessonRecord.keyTakeaways.forEach((takeaway, index) => {
    sections.push({
      id: deterministicUuid(`section:${lessonRecord.id}:takeaway:${index}`),
      sortOrder: order++,
      sectionType: "bullet",
      heading: null,
      body: takeaway,
      meta: {}
    });
  });

  sections.push({
    id: deterministicUuid(`section:${lessonRecord.id}:knowledge-heading`),
    sortOrder: order++,
    sectionType: "heading",
    heading: null,
    body: "Knowledge Check",
    meta: {}
  });

  lessonRecord.practiceQuestions.forEach((question, index) => {
    sections.push({
      id: deterministicUuid(`section:${lessonRecord.id}:question:${index}`),
      sortOrder: order++,
      sectionType: "callout",
      heading: `Question ${index + 1}`,
      body: question,
      meta: {}
    });
  });

  return sections;
}

function main() {
  const pack = JSON.parse(fs.readFileSync(packPath, "utf8"));
  validate(pack);

  const lessons = collectLessons(pack);
  const modules = [];
  const moduleSeen = new Set();
  const sections = [];
  const topicTags = new Map();
  const moduleTopicTags = [];
  const lessonTopicTags = [];
  const necCodes = new Set();
  const lessonNecRefs = [];
  const practiceQuestions = [];

  for (const item of lessons) {
    if (!moduleSeen.has(item.module.id)) {
      moduleSeen.add(item.module.id);
      const moduleTagIds = item.moduleTags.map((tag) => {
        if (!topicTags.has(tag)) {
          topicTags.set(tag, {
            id: deterministicUuid(`topic:${tag}`),
            slug: tag,
            name: tag.replace(/-/g, " ").replace(/\b\w/g, (c) => c.toUpperCase()),
            description: `Auto-generated tag for ${tag.replace(/-/g, " ")}.`
          });
        }
        return topicTags.get(tag).id;
      });

      modules.push({
        id: item.moduleId,
        slug: `${item.module.id}-${slugify(item.module.moduleName)}`,
        title: item.module.moduleName,
        description: item.module.learningObjectives.join(" "),
        examType: item.course.certificationLevel.toLowerCase(),
        difficulty: item.course.certificationLevel === "Apprentice" ? "beginner" : item.course.certificationLevel === "Journeyman" ? "intermediate" : "advanced",
        sortOrder: modules.length + 1,
        estimatedMinutes: item.module.lessons.reduce((total, lesson) => total + lesson.estimatedMinutes, 0)
      });

      moduleTagIds.forEach((tagId) => {
        moduleTopicTags.push({ moduleId: item.moduleId, topicTagId: tagId });
      });
    }

    const lessonTags = Array.from(new Set([
      ...item.moduleTags,
      slugify(item.lesson.lessonTitle)
    ]));

    const lessonTagIds = lessonTags.map((tag) => {
      if (!topicTags.has(tag)) {
        topicTags.set(tag, {
          id: deterministicUuid(`topic:${tag}`),
          slug: tag,
          name: tag.replace(/-/g, " ").replace(/\b\w/g, (c) => c.toUpperCase()),
          description: `Auto-generated tag for ${tag.replace(/-/g, " ")}.`
        });
      }
      return topicTags.get(tag).id;
    });

    lessonTagIds.forEach((topicTagId) => {
      lessonTopicTags.push({ lessonId: item.lessonId, topicTagId });
    });

    buildSections(item.record).forEach((section) => {
      sections.push({ ...section, lessonId: item.lessonId });
    });

    uniqueReferenceCodes(item.record).forEach((code, index) => {
      necCodes.add(code);
      lessonNecRefs.push({
        lessonId: item.lessonId,
        necEntryId: deterministicUuid(`nec:${code}`),
        displayOrder: index
      });
    });
  }

  for (const record of pack.questionBank) {
    const topicSlug = slugify(record.topicCategory);
    if (!topicTags.has(topicSlug)) {
      topicTags.set(topicSlug, {
        id: deterministicUuid(`topic:${topicSlug}`),
        slug: topicSlug,
        name: record.topicCategory,
        description: `Auto-generated tag for ${record.topicCategory.toLowerCase()}.`
      });
    }

    practiceQuestions.push({
      id: deterministicUuid(`practice-question:${record.id}`),
      sourceKey: record.id,
      certificationLevel: record.certificationLevel.toLowerCase(),
      topicSlug,
      topicTitle: record.topicCategory,
      questionText: record.questionText,
      choices: record.answerChoices,
      correctChoice: record.correctAnswer,
      explanation: record.explanation,
      necReference: record.necReference,
      difficulty:
        record.difficultyLevel.toLowerCase() === "easy"
          ? "beginner"
          : record.difficultyLevel.toLowerCase() === "hard"
            ? "advanced"
            : "intermediate"
    });
  }

  const topicTagRows = Array.from(topicTags.values());
  const necEntries = Array.from(necCodes).sort().map((code) => {
    const [title, summary] = referenceCatalog[code] || [
      `NEC ${code}`,
      `Simplified explanation for NEC ${code}. Verify the adopted code cycle and official text in your jurisdiction.`
    ];

    return {
      id: deterministicUuid(`nec:${code}`),
      referenceCode: code,
      title,
      simplifiedSummary: summary
    };
  });

  const necSearchRows = necEntries.map((entry) => ({
    id: deterministicUuid(`nec-search:${entry.referenceCode}`),
    necEntryId: entry.id,
    searchText: `${entry.referenceCode} ${entry.title} ${entry.simplifiedSummary}`
  }));

  const lessonRows = lessons.map((item, index) => {
    const whyThisMatters = item.record.lessonContent.find((section) => section.heading === "Why this matters");
    return {
      id: item.lessonId,
      moduleId: item.moduleId,
      slug: `${item.lesson.id}-${slugify(item.lesson.lessonTitle)}`,
      title: item.lesson.lessonTitle,
      subtitle: item.module.moduleName,
      summary: whyThisMatters ? whyThisMatters.body : item.record.lessonContent[0].body,
      examType: item.course.certificationLevel.toLowerCase(),
      difficulty: item.course.certificationLevel === "Apprentice" ? "beginner" : item.course.certificationLevel === "Journeyman" ? "intermediate" : "advanced",
      sortOrder: item.module.lessons.findIndex((lesson) => lesson.id === item.lesson.id) + 1,
      estimatedMinutes: item.lesson.estimatedMinutes
    };
  });

  const sql = [];
  sql.push("-- Generated by scripts/generate_content_seed.cjs");
  sql.push("-- Source: wattwise/Resources/WattWiseContentPack.json");
  sql.push("BEGIN;");
  sql.push("TRUNCATE TABLE quiz_question_assignments, practice_questions, lesson_progress, lesson_nec_references, lesson_topic_tags, module_topic_tags, lesson_sections, lessons, modules, nec_entry_topic_tags, nec_search_index, nec_entries, topic_tags RESTART IDENTITY CASCADE;");

  for (const row of topicTagRows) {
    sql.push(`INSERT INTO topic_tags (id, slug, name, description) VALUES (${sqlValue(row.id)}, ${sqlValue(row.slug)}, ${sqlValue(row.name)}, ${sqlValue(row.description)});`);
  }

  for (const row of practiceQuestions) {
    sql.push(`INSERT INTO practice_questions (id, source_key, certification_level, topic_slug, topic_title, question_text, choices, correct_choice, explanation, nec_reference, difficulty_level, is_active) VALUES (${sqlValue(row.id)}, ${sqlValue(row.sourceKey)}, ${sqlValue(row.certificationLevel)}, ${sqlValue(row.topicSlug)}, ${sqlValue(row.topicTitle)}, ${sqlValue(row.questionText)}, ${jsonValue(row.choices)}::jsonb, ${sqlValue(row.correctChoice)}, ${sqlValue(row.explanation)}, ${sqlValue(row.necReference)}, ${sqlValue(row.difficulty)}, TRUE);`);
  }

  for (const row of modules) {
    sql.push(`INSERT INTO modules (id, slug, title, description, exam_type, difficulty_level, sort_order, is_published, estimated_minutes) VALUES (${sqlValue(row.id)}, ${sqlValue(row.slug)}, ${sqlValue(row.title)}, ${sqlValue(row.description)}, ${sqlValue(row.examType)}, ${sqlValue(row.difficulty)}, ${row.sortOrder}, TRUE, ${row.estimatedMinutes});`);
  }

  for (const row of moduleTopicTags) {
    sql.push(`INSERT INTO module_topic_tags (module_id, topic_tag_id) VALUES (${sqlValue(row.moduleId)}, ${sqlValue(row.topicTagId)});`);
  }

  for (const row of lessonRows) {
    sql.push(`INSERT INTO lessons (id, module_id, slug, title, subtitle, summary, exam_type, difficulty_level, sort_order, estimated_minutes, is_published) VALUES (${sqlValue(row.id)}, ${sqlValue(row.moduleId)}, ${sqlValue(row.slug)}, ${sqlValue(row.title)}, ${sqlValue(row.subtitle)}, ${sqlValue(row.summary)}, ${sqlValue(row.examType)}, ${sqlValue(row.difficulty)}, ${row.sortOrder}, ${row.estimatedMinutes}, TRUE);`);
  }

  for (const row of lessonTopicTags) {
    sql.push(`INSERT INTO lesson_topic_tags (lesson_id, topic_tag_id) VALUES (${sqlValue(row.lessonId)}, ${sqlValue(row.topicTagId)});`);
  }

  for (const row of sections) {
    sql.push(`INSERT INTO lesson_sections (id, lesson_id, sort_order, section_type, heading, body_markdown, body_plaintext, meta_json) VALUES (${sqlValue(row.id)}, ${sqlValue(row.lessonId)}, ${row.sortOrder}, ${sqlValue(row.sectionType)}, ${sqlValue(row.heading)}, ${sqlValue(row.body)}, ${sqlValue(row.body)}, ${jsonValue(row.meta)}::jsonb);`);
  }

  for (const row of necEntries) {
    sql.push(`INSERT INTO nec_entries (id, reference_code, title, canonical_text_excerpt, simplified_summary, edition, topic_notes, is_active) VALUES (${sqlValue(row.id)}, ${sqlValue(row.referenceCode)}, ${sqlValue(row.title)}, NULL, ${sqlValue(row.simplifiedSummary)}, ${sqlValue("National core; verify adopted cycle")}, NULL, TRUE);`);
  }

  for (const row of necSearchRows) {
    sql.push(`INSERT INTO nec_search_index (id, nec_entry_id, search_text) VALUES (${sqlValue(row.id)}, ${sqlValue(row.necEntryId)}, ${sqlValue(row.searchText)});`);
  }

  for (const row of lessonNecRefs) {
    sql.push(`INSERT INTO lesson_nec_references (lesson_id, nec_entry_id, display_order, context_note) VALUES (${sqlValue(row.lessonId)}, ${sqlValue(row.necEntryId)}, ${row.displayOrder}, NULL);`);
  }

  sql.push("COMMIT;");
  sql.push("");

  fs.writeFileSync(outputPath, sql.join("\n"));

  console.log(`Wrote ${outputPath}`);
  console.log(`Modules: ${modules.length}`);
  console.log(`Lessons: ${lessonRows.length}`);
  console.log(`Sections: ${sections.length}`);
  console.log(`NEC entries: ${necEntries.length}`);
  console.log(`Practice questions: ${practiceQuestions.length}`);
}

main();
