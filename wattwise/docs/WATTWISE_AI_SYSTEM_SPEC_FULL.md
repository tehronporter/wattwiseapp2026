
# WattWise — AI System Specification (Production-Level)

## 0. Purpose

Defines how AI is used, orchestrated, constrained, and evaluated in WattWise.
Covers tutor, quiz generation, NEC explanation, and recommendation enrichment.

---

## 1. AI Philosophy

- Educational first, not chat-first
- Deterministic structure over free-form output
- Context-aware responses
- Safety and accuracy over creativity
- Backend-mediated (no client-side provider calls)

---

## 2. AI Use Cases

1. Tutor (core)
2. Quiz generation (hybrid with bank)
3. NEC explanation expansion
4. Recommendation hints (optional)

---

## 3. System Architecture

iOS App → Edge Function → AI Orchestrator → Provider → Post-process → Response DTO

No provider SDKs on client. All prompts, keys, and routing live server-side.

---

## 4. Prompting Strategy

### 4.1 System Prompts (per use case)
- Tutor: explain concepts simply, step-by-step, avoid hallucination, cite NEC refs when applicable
- Quiz Gen: produce MCQs with 4 options, 1 correct, plausible distractors, include explanations
- NEC Explain: expand anchored to known reference, no invented codes

### 4.2 Context Injection
- exam_type
- jurisdiction
- topic tags
- lesson excerpt (if in-lesson)
- missed question payload (if from results)
- NEC entry (for expansions)

### 4.3 Output Contracts
Always return structured JSON:

Tutor:
{
  "answer": "string",
  "steps": ["string"],
  "bullets": ["string"],
  "references": ["210.8"],
  "follow_ups": ["string"]
}

Quiz:
{
  "questions": [
    {
      "question": "...",
      "choices": {"A":"...","B":"...","C":"...","D":"..."},
      "correct": "A",
      "explanation": "...",
      "topics": ["grounding"]
    }
  ]
}

NEC:
{
  "reference": "210.8",
  "summary": "...",
  "expanded": "...",
  "notes": ["..."]
}

---

## 5. Model Selection

- Default: cost-efficient, reliable model (e.g., GPT-4o-mini class)
- Fallback: secondary model if failure/timeout
- Routing:
  - Tutor: balanced reasoning
  - Quiz: structured generation
  - NEC: precise expansion

---

## 6. Safety & Guardrails

- No fabricated NEC references
- If uncertain: say “I’m not certain” and suggest clarification
- Strip unsafe content
- Limit verbosity
- Enforce max tokens

---

## 7. Rate Limiting & Quotas

- Preview-lifetime limits for preview users
- No preview caps for active paid access
- Endpoint-level throttles
- Backend-enforced counters (ai_usage_counters)
- Graceful errors tied to preview access, not generic subscription language

---

## 8. Caching Strategy

- Cache NEC expansions by (nec_entry_id, normalized_prompt)
- Cache common tutor answers (optional)
- Do not cache personalized quiz sessions

---

## 9. Evaluation & Quality

Metrics:
- correctness (manual spot checks)
- user follow-up rate
- answer length vs usefulness
- error rate / retries
- cost per user/day

Add lightweight feedback later (thumbs up/down).

---

## 10. Observability

Log per request:
- type
- model
- latency
- tokens
- status
- error codes

Use ai_request_logs.

---

## 11. Failure Handling

- Timeout → retry once → fallback model
- Malformed JSON → repair pass or reject with retry
- Provider error → user-friendly message

---

## 12. Cost Controls

- token caps per request
- shorter defaults
- reuse cached NEC
- limit quiz size by tier

---

## 13. Versioning

- version prompts (e.g., tutor_v1, tutor_v2)
- store version in logs
- allow gradual rollout via feature flags

---

## 14. Testing

- golden test prompts for each use case
- schema validation for JSON outputs
- regression checks when prompts/models change

---

## 15. Definition of Done

- All endpoints return valid structured JSON
- No client-side provider calls
- Quotas enforced
- Logs captured
- Responses consistent with contracts

---

## 16. Final Principle

AI should make WattWise feel clearer and more helpful—not more random.
