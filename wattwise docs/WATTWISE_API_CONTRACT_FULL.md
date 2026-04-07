
# WattWise — API Contract (Production-Level)

## 0. Purpose

Defines the exact request/response contracts between:
- iOS app (client)
- Supabase backend + Edge Functions

This ensures:
- predictable communication
- no ambiguity for Codex/Swift implementation
- safe evolution of backend without breaking app

---

## 1. Global API Rules

### 1.1 Base Pattern
All API calls follow:

POST /functions/v1/{endpoint}

### 1.2 Headers

Required:
- Authorization: Bearer {access_token}
- Content-Type: application/json

Optional:
- X-App-Version
- X-Platform: iOS

---

## 2. Standard Response Format

All responses must follow:

Success:
{
  "success": true,
  "data": {...}
}

Error:
{
  "success": false,
  "error": {
    "code": "string",
    "message": "string"
  }
}

---

## 3. Auth Context

All endpoints assume:
- user is authenticated
- user_id is derived from JWT

Do NOT pass user_id manually from client.

---

## 4. Endpoint: Home Summary

POST /functions/v1/progress_summary

### Request
{}

### Response
{
  "success": true,
  "data": {
    "continue_learning": {
      "lesson_id": "uuid",
      "title": "string",
      "progress": 0.45
    },
    "daily_goal": {
      "minutes_completed": 18,
      "target_minutes": 30
    },
    "streak_days": 5,
    "recommended_action": {
      "type": "lesson|quiz",
      "id": "uuid",
      "reason": "string"
    }
  }
}

---

## 5. Endpoint: Modules

POST /functions/v1/get_modules

### Request
{}

### Response
{
  "data": [
    {
      "id": "uuid",
      "title": "string",
      "description": "string",
      "progress": 0.3
    }
  ]
}

---

## 6. Endpoint: Lessons

POST /functions/v1/get_lesson

### Request
{
  "lesson_id": "uuid"
}

### Response
{
  "data": {
    "id": "uuid",
    "title": "string",
    "sections": [
      {
        "type": "body",
        "content": "string"
      }
    ],
    "nec_references": [
      {
        "code": "210.8",
        "summary": "string"
      }
    ]
  }
}

---

## 7. Endpoint: Save Lesson Progress

POST /functions/v1/save_progress

### Request
{
  "lesson_id": "uuid",
  "completion_percentage": 0.5
}

### Response
{
  "success": true
}

---

## 8. Endpoint: Generate Quiz

POST /functions/v1/generate_quiz

### Request
{
  "quiz_type": "quick_quiz",
  "topic_tags": ["grounding"],
  "question_count": 5
}

### Response
{
  "data": {
    "quiz_id": "uuid",
    "questions": [
      {
        "id": "uuid",
        "question": "...",
        "choices": {
          "A": "...",
          "B": "...",
          "C": "...",
          "D": "..."
        }
      }
    ]
  }
}

---

## 9. Endpoint: Submit Quiz

POST /functions/v1/submit_quiz

### Request
{
  "quiz_id": "uuid",
  "answers": [
    {
      "question_id": "uuid",
      "selected": "A"
    }
  ]
}

### Response
{
  "data": {
    "score": 80,
    "correct_count": 4,
    "total": 5,
    "results": [
      {
        "question_id": "uuid",
        "correct": true,
        "explanation": "..."
      }
    ],
    "weak_topics": ["grounding"]
  }
}

---

## 10. Endpoint: Tutor

POST /functions/v1/tutor

### Request
{
  "message": "Explain grounding",
  "context": {
    "type": "lesson",
    "lesson_id": "uuid"
  }
}

### Response
{
  "data": {
    "answer": "string",
    "steps": ["string"],
    "follow_ups": ["string"]
  }
}

---

## 11. Endpoint: NEC Search

POST /functions/v1/nec_search

### Request
{
  "query": "GFCI"
}

### Response
{
  "data": [
    {
      "id": "uuid",
      "code": "210.8",
      "title": "GFCI Protection",
      "summary": "..."
    }
  ]
}

---

## 12. Endpoint: NEC Detail

POST /functions/v1/nec_detail

### Request
{
  "nec_id": "uuid"
}

### Response
{
  "data": {
    "code": "210.8",
    "title": "string",
    "summary": "string"
  }
}

---

## 13. Endpoint: NEC Explain (AI)

POST /functions/v1/nec_explain

### Request
{
  "nec_id": "uuid"
}

### Response
{
  "data": {
    "expanded": "string"
  }
}

---

## 14. Endpoint: Subscription Sync

POST /functions/v1/sync_subscription

### Request
{
  "receipt": "string"
}

### Response
{
  "data": {
    "tier": "pro",
    "status": "active"
  }
}

---

## 15. Error Codes

Common:
- UNAUTHORIZED
- RATE_LIMITED
- INVALID_REQUEST
- NOT_FOUND
- INTERNAL_ERROR

---

## 16. Versioning

Future:
- include version header
- avoid breaking existing response shapes

---

## 17. Final Principle

The API must be:
- predictable
- minimal
- stable

The iOS app should never need to guess behavior.
