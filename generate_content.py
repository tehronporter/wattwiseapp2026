#!/usr/bin/env python3
"""
WattWise Content Generation Script
Generates draft lesson content and practice questions for all 92 lessons
using a source-conditioned Claude prompt, then writes the updated JSON back
to WattWiseContentPack.json.

Usage:
    pip install anthropic
    export ANTHROPIC_API_KEY=sk-ant-...
    python generate_content.py

Options:
    --dry-run          Print first lesson without writing to file
    --lesson-id ID     Regenerate a single lesson (e.g. ap-les-001)
    --questions-only   Only regenerate placeholder practice questions
    --lessons-only     Only regenerate lesson content sections
    --start-from ID    Skip lessons before this ID (for resuming)
    --facts-file PATH  JSON file of normalized verified code facts
"""

import json
import os
import sys
import time
import argparse
from pathlib import Path

import anthropic

# ── Config ──────────────────────────────────────────────────────────────────

CONTENT_PACK_PATH = Path(__file__).parent / "wattwise" / "wattwise" / "Resources" / "WattWiseContentPack.json"
BACKUP_PATH = CONTENT_PACK_PATH.with_suffix(".backup.json")

MODEL = "claude-opus-4-7"   # Best quality for exam prep content
DELAY_BETWEEN_CALLS = 0.5   # seconds — stay within rate limits

# ── Prompts ─────────────────────────────────────────────────────────────────

LESSON_SYSTEM_PROMPT = """You are an expert electrician educator writing study material for US electrician licensing exams (Apprentice, Journeyman, and Master levels). Your writing:
- Uses 8th-12th grade reading level — clear, direct, no jargon without explanation
- Always explains the WHY before the WHAT — why does this rule exist?
- Uses concrete job-site examples an electrician can picture
- References specific NEC articles correctly
- Is exam-focused — flags common trick questions and misconceptions
- Is accurate enough that a licensed electrician would trust it
- Never invents a current code-cycle or jurisdiction claim that is not present in the verified facts provided by the user
- Clearly narrows scope to a national baseline when the verified facts do not support a state-specific claim

You produce structured JSON only. No markdown. No commentary outside the JSON."""

LESSON_USER_TEMPLATE = """Generate lesson content for this electrician exam topic:

Lesson ID: {lesson_id}
Course: {course_title}
Module: {module_name}
Title: {lesson_title}
Level: {certification_level}
Learning Objectives: {objectives}
NEC References: {nec_refs}
Verified facts:
{verified_facts}

Return a JSON array of exactly 8 section objects. Each object has:
- "heading": one of these exact strings in order:
  1. "Learning objective"
  2. "Why this matters"
  3. "Core explanation"
  4. "Key concepts"
  5. "NEC / code relevance"
  6. "Practical example"
  7. "Common mistakes"
  8. "Exam insight"
- "body": 2-4 sentences of real educational content for that heading
- "necReferences": array of relevant NEC article strings (can be empty)

The content must be specific to "{lesson_title}" — not generic filler.
Every code-cycle or jurisdiction-sensitive statement must be traceable to the verified facts block.
Return only the JSON array, nothing else."""

QUESTIONS_SYSTEM_PROMPT = """You are an expert electrician exam question writer creating practice questions for US licensing exams. Your questions:
- Test real knowledge, not just vocabulary
- Have plausible wrong answers (not obviously wrong "Option A" distractors)
- Include clear explanations for why the correct answer is right
- Reference NEC articles where relevant
- Match the difficulty level specified
- Reflect actual exam-style questions (IBEW, PSI, Prometric formats)

You produce structured JSON only. No markdown."""

QUESTIONS_USER_TEMPLATE = """Generate {count} practice questions for this electrician exam topic:

Topic: {topic}
Certification Level: {level}
Difficulty Mix: Easy (40%), Moderate (40%), Difficult (20%)
Verified facts:
{verified_facts}

Return a JSON array of question objects. Each object has:
- "question": the question text (specific, not "Question X about Topic?")
- "optionA": first option (not "Option A")
- "optionB": second option
- "optionC": third option
- "optionD": fourth option
- "correctAnswer": "A", "B", "C", or "D"
- "explanation": 2-3 sentences explaining why the correct answer is right and why one distractor is wrong
- "necReference": NEC article/table reference when applicable, otherwise empty string
- "difficulty": "Easy", "Moderate", or "Difficult"

All 4 options must be plausible — a student who doesn't know the answer should not be able to guess by elimination.
Do not make a "current code" or state-adoption claim unless it appears in the verified facts block.
Do not use generic explanation patterns like "This question tests..."
Return only the JSON array, nothing else."""

# ── Helpers ──────────────────────────────────────────────────────────────────

def is_placeholder_lesson(lesson: dict) -> bool:
    """Detect template-generated content."""
    for section in lesson.get("lessonContent", []):
        body = section.get("body", "")
        if "The fundamental principle behind" in body:
            return True
        if "electrical safety depends on proper design" in body:
            return True
    return False

def is_placeholder_question(q: dict) -> bool:
    """Detect placeholder questions."""
    return (
        q.get("optionA", "") == "Option A"
        or q.get("question", "").startswith("Question ")
        or "This question tests" in q.get("explanation", "")
    )

def call_claude(client: anthropic.Anthropic, system: str, user: str, retries: int = 3) -> str:
    for attempt in range(retries):
        try:
            message = client.messages.create(
                model=MODEL,
                max_tokens=2048,
                system=system,
                messages=[{"role": "user", "content": user}],
            )
            return message.content[0].text.strip()
        except anthropic.RateLimitError:
            wait = 30 * (attempt + 1)
            print(f"  Rate limited. Waiting {wait}s...")
            time.sleep(wait)
        except anthropic.APIError as e:
            print(f"  API error (attempt {attempt+1}): {e}")
            time.sleep(5)
    raise RuntimeError(f"Failed after {retries} retries")

def parse_json_response(text: str, context: str = "") -> list | None:
    """Parse JSON from Claude response, handling common formatting issues."""
    # Strip markdown code fences if present
    text = text.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        text = "\n".join(lines[1:-1] if lines[-1] == "```" else lines[1:])
    try:
        result = json.loads(text)
        return result if isinstance(result, list) else None
    except json.JSONDecodeError as e:
        print(f"  JSON parse error{' (' + context + ')' if context else ''}: {e}")
        print(f"  Raw response (first 200 chars): {text[:200]}")
        return None

def load_verified_facts(path_str: str | None) -> dict:
    if not path_str:
        return {}
    path = Path(path_str)
    if not path.exists():
        raise FileNotFoundError(f"Verified facts file not found: {path}")
    with open(path, "r") as f:
        payload = json.load(f)

    facts = payload.get("facts", payload)
    grouped: dict[str, list[dict]] = {}
    for fact in facts:
        jurisdiction = fact.get("jurisdiction_code") or "national"
        grouped.setdefault(jurisdiction, []).append(fact)
    return grouped

def summarize_verified_facts(facts_by_scope: dict, lesson: dict) -> str:
    if not facts_by_scope:
        return "No verified facts provided. Keep claims national-baseline only and avoid date-sensitive statements."

    state_hints = []
    for scope in ("national", "TX", "FL", "NC", "OR"):
        if scope in facts_by_scope:
            for fact in facts_by_scope[scope][:3]:
                state_hints.append(
                    f"- [{scope}] {fact.get('title')}: {fact.get('summary')} "
                    f"(cycle={fact.get('code_cycle')}, effective={fact.get('effective_date')}, source={fact.get('official_source_url')})"
                )
    if not state_hints:
        return "Verified facts file loaded but no matching facts were found. Keep claims national-baseline only."
    return "\n".join(state_hints)

def generate_lesson_sections(client: anthropic.Anthropic, lesson: dict, facts_by_scope: dict) -> list | None:
    """Generate real content sections for a lesson."""
    nec_refs = []
    for section in lesson.get("lessonContent", []):
        nec_refs.extend(section.get("necReferences", []))
    nec_refs = list(dict.fromkeys(nec_refs))  # deduplicate, preserve order

    user_prompt = LESSON_USER_TEMPLATE.format(
        lesson_id=lesson["id"],
        course_title=lesson.get("courseTitle", ""),
        module_name=lesson.get("moduleName", ""),
        lesson_title=lesson["lessonTitle"],
        certification_level=lesson.get("certificationLevel", ""),
        objectives=", ".join(lesson.get("learningObjectives", [])),
        nec_refs=", ".join(nec_refs) or "See NEC",
        verified_facts=summarize_verified_facts(facts_by_scope, lesson),
    )

    response = call_claude(client, LESSON_SYSTEM_PROMPT, user_prompt)
    sections = parse_json_response(response, lesson["id"])
    if not sections or len(sections) != 8:
        print(f"  Warning: got {len(sections) if sections else 0} sections, expected 8")
        return sections

    # Rebuild sections with original IDs (sec-001 through sec-008)
    original_sections = lesson.get("lessonContent", [])
    result = []
    section_ids = [s.get("id", f"{lesson['id']}-sec-{i+1:03d}") for i, s in enumerate(original_sections[:8])]

    for i, (new_section, section_id) in enumerate(zip(sections, section_ids)):
        result.append({
            "id": section_id,
            "heading": new_section.get("heading", f"Section {i+1}"),
            "body": new_section.get("body", ""),
            "necReferences": new_section.get("necReferences", []),
        })

    if len(original_sections) > 8:
        result.extend(original_sections[8:])

    return result

def generate_questions_for_topics(
    client: anthropic.Anthropic,
    topic: str,
    level: str,
    verified_facts: str,
    count: int = 3,
) -> list | None:
    user_prompt = QUESTIONS_USER_TEMPLATE.format(
        topic=topic,
        level=level,
        count=count,
        verified_facts=verified_facts,
    )
    response = call_claude(client, QUESTIONS_SYSTEM_PROMPT, user_prompt)
    return parse_json_response(response, f"{topic}/{level}")

# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Generate WattWise content via Claude API")
    parser.add_argument("--dry-run", action="store_true", help="Process first lesson only, print result, don't write")
    parser.add_argument("--lesson-id", help="Regenerate a single lesson ID (e.g. ap-les-001)")
    parser.add_argument("--questions-only", action="store_true", help="Only regenerate placeholder questions")
    parser.add_argument("--lessons-only", action="store_true", help="Only regenerate lesson content sections")
    parser.add_argument("--start-from", help="Skip lessons before this ID")
    parser.add_argument("--facts-file", help="JSON file of normalized verified code facts")
    args = parser.parse_args()

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("Error: ANTHROPIC_API_KEY environment variable not set")
        sys.exit(1)

    print(f"Loading content pack from {CONTENT_PACK_PATH}...")
    with open(CONTENT_PACK_PATH, "r") as f:
        pack = json.load(f)

    # Backup
    if not args.dry_run:
        print(f"Creating backup at {BACKUP_PATH}...")
        with open(BACKUP_PATH, "w") as f:
            json.dump(pack, f, indent=2)

    client = anthropic.Anthropic(api_key=api_key)
    facts_by_scope = load_verified_facts(args.facts_file)

    lessons = pack.get("fullLessons", [])
    questions = pack.get("practiceQuestions", [])

    # ── Lesson content generation ────────────────────────────────────────────
    if not args.questions_only:
        lessons_to_process = lessons
        if args.lesson_id:
            lessons_to_process = [l for l in lessons if l["id"] == args.lesson_id]
            if not lessons_to_process:
                print(f"Error: lesson '{args.lesson_id}' not found")
                sys.exit(1)
        elif args.start_from:
            found = False
            lessons_to_process = []
            for l in lessons:
                if l["id"] == args.start_from:
                    found = True
                if found:
                    lessons_to_process.append(l)
            if not found:
                print(f"Error: start-from lesson '{args.start_from}' not found")
                sys.exit(1)

        placeholder_count = sum(1 for l in lessons_to_process if is_placeholder_lesson(l))
        print(f"\n{'='*60}")
        print(f"LESSON GENERATION")
        print(f"  Total to process: {len(lessons_to_process)}")
        print(f"  Placeholder lessons: {placeholder_count}")
        print(f"  Model: {MODEL}")
        print(f"{'='*60}\n")

        for i, lesson in enumerate(lessons_to_process):
            if not is_placeholder_lesson(lesson) and not args.lesson_id:
                print(f"[{i+1}/{len(lessons_to_process)}] {lesson['id']} — skipping (already has real content)")
                continue

            print(f"[{i+1}/{len(lessons_to_process)}] {lesson['id']}: {lesson['lessonTitle']}")

            try:
                new_sections = generate_lesson_sections(client, lesson, facts_by_scope)
                if new_sections:
                    # Update in place
                    for j, l in enumerate(pack["fullLessons"]):
                        if l["id"] == lesson["id"]:
                            pack["fullLessons"][j]["lessonContent"] = new_sections
                            break
                    print(f"  ✓ Generated {len(new_sections)} sections")
                else:
                    print(f"  ✗ Failed to generate sections, keeping original")
            except Exception as e:
                print(f"  ✗ Error: {e}")

            if args.dry_run:
                print("\n--- DRY RUN: Sample lesson content ---")
                if new_sections:
                    for section in new_sections:
                        print(f"\n{section['heading']}:")
                        print(f"  {section['body'][:200]}...")
                print("\n--- Stopping after first lesson (dry run) ---")
                return

            # Save progress after each lesson
            with open(CONTENT_PACK_PATH, "w") as f:
                json.dump(pack, f, indent=2, ensure_ascii=False)

            time.sleep(DELAY_BETWEEN_CALLS)

    # ── Practice question generation ─────────────────────────────────────────
    if not args.lessons_only:
        placeholder_questions = [q for q in questions if is_placeholder_question(q)]
        print(f"\n{'='*60}")
        print(f"QUESTION GENERATION")
        print(f"  Total questions: {len(questions)}")
        print(f"  Placeholder questions: {len(placeholder_questions)}")
        print(f"{'='*60}\n")

        if placeholder_questions:
            # Group placeholder questions by (topic, level) to batch API calls
            from collections import defaultdict
            groups: dict[tuple, list] = defaultdict(list)
            for q in placeholder_questions:
                key = (q.get("topic", "General"), q.get("certificationLevel", "Apprentice"))
                groups[key].append(q)

            group_list = list(groups.items())
            for gi, ((topic, level), group_qs) in enumerate(group_list):
                count = len(group_qs)
                print(f"[{gi+1}/{len(group_list)}] Generating {count} questions — {topic} / {level}")

                try:
                    verified_facts = "\n".join(
                        f"- [{scope}] {fact.get('summary')}"
                        for scope, facts in facts_by_scope.items()
                        for fact in facts[:2]
                    ) or "No verified facts provided. Avoid date-sensitive claims."
                    new_qs = generate_questions_for_topics(client, topic, level, verified_facts, count)
                    if new_qs and len(new_qs) >= count:
                        # Replace placeholder questions with real ones
                        for q_orig, q_new in zip(group_qs, new_qs):
                            for j, q in enumerate(pack["practiceQuestions"]):
                                if q["id"] == q_orig["id"]:
                                    pack["practiceQuestions"][j].update({
                                        "question": q_new.get("question", q_orig["question"]),
                                        "optionA": q_new.get("optionA", q_orig["optionA"]),
                                        "optionB": q_new.get("optionB", q_orig["optionB"]),
                                        "optionC": q_new.get("optionC", q_orig["optionC"]),
                                        "optionD": q_new.get("optionD", q_orig["optionD"]),
                                        "correctAnswer": q_new.get("correctAnswer", q_orig["correctAnswer"]),
                                        "explanation": q_new.get("explanation", q_orig["explanation"]),
                                        "necReference": q_new.get("necReference", q_orig.get("necReference", "")),
                                        "difficulty": q_new.get("difficulty", q_orig["difficulty"]),
                                    })
                                    break
                        print(f"  ✓ Replaced {min(count, len(new_qs))} questions")
                    else:
                        print(f"  ✗ Got {len(new_qs) if new_qs else 0} questions, expected {count}")
                except Exception as e:
                    print(f"  ✗ Error: {e}")

                # Save after each group
                with open(CONTENT_PACK_PATH, "w") as f:
                    json.dump(pack, f, indent=2, ensure_ascii=False)

                time.sleep(DELAY_BETWEEN_CALLS)

    # Final save
    print(f"\n✓ Content generation complete. Saved to {CONTENT_PACK_PATH}")

    # Validation summary
    remaining_placeholder_lessons = sum(1 for l in pack.get("fullLessons", []) if is_placeholder_lesson(l))
    remaining_placeholder_questions = sum(1 for q in pack.get("practiceQuestions", []) if is_placeholder_question(q))
    print(f"\nValidation:")
    print(f"  Lessons still placeholder: {remaining_placeholder_lessons}")
    print(f"  Questions still placeholder: {remaining_placeholder_questions}")
    if remaining_placeholder_lessons == 0 and remaining_placeholder_questions == 0:
        print("  ✓ All content is real!")

if __name__ == "__main__":
    main()
