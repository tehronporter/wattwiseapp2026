
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
  "data": {
    "continue_learning": {
      "lesson_id": "uuid",
      "title": "string",
      "progress": 0.45,
      "module_title": "string"
    },
    "daily_goal": {
      "minutes_completed": 18,
      "target_minutes": 30
    },
    "streak_days": 5,
    "recommended_action": "Resume Branch Circuit Basics"
  }
}

---

## 5. Endpoint: Modules

POST /functions/v1/get_modules

### Request
{}

### Response
{
  "success": true,
  "data": {
    "modules": [
      {
        "id": "uuid",
        "title": "string",
        "description": "string",
        "lessonCount": 2,
        "estimatedMinutes": 30,
        "topicTags": ["apprentice", "safety"],
        "progress": 0.3,
        "lessons": []
      }
    ]
  }
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
  "success": true,
  "data": {
    "lesson": {
      "id": "uuid",
      "moduleId": "uuid",
      "title": "string",
      "topic": "string",
      "estimatedMinutes": 15,
      "status": "not_started|in_progress|completed",
      "completionPercentage": 0.4,
      "sections": [
        {
          "id": "uuid",
          "heading": "Core explanation",
          "body": "string",
          "type": "paragraph|heading|bullet|callout|necCallout",
          "necCode": "210.8"
        }
      ],
      "necReferences": [
        {
          "id": "uuid",
          "code": "210.8",
          "title": "string",
          "summary": "string",
          "expanded": "string|null"
        }
      ]
    }
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
  "success": true,
  "data": {
    "success": true,
    "completion_percentage": 0.5,
    "status": "in_progress"
  }
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
  "success": true,
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
        },
        "topics": ["grounding"]
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
  "success": true,
  "data": {
    "quiz_attempt_id": "uuid",
    "score": 80,
    "correct_count": 4,
    "total_count": 5,
    "results": [
      {
        "question_id": "uuid",
        "question": "string",
        "user_answer": "A",
        "correct_answer": "B",
        "is_correct": true,
        "explanation": "string",
        "topics": ["grounding"],
        "topic_titles": ["Grounding"],
        "reference_code": "250.50"
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
    "lesson": {
      "lessonId": "uuid",
      "title": "Grounding Basics",
      "excerpt": "..."
    },
    "examType": "apprentice",
    "jurisdiction": "TX"
  },
  "history": [
    {
      "role": "user",
      "content": "..."
    }
  ],
  "session_id": "uuid-or-null"
}

### Response
{
  "success": true,
  "data": {
    "answer": "string",
    "steps": ["string"],
    "bullets": ["string"],
    "references": ["250.50"],
    "follow_ups": ["string"],
    "session_id": "uuid",
    "usage": {
      "used": 2,
      "limit": 4
    }
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
  "success": true,
  "data": {
    "results": [
      {
        "id": "uuid",
        "code": "210.8",
        "title": "GFCI Protection",
        "summary": "..."
      }
    ]
  }
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
  "success": true,
  "data": {
    "detail": {
      "id": "uuid",
      "code": "210.8",
      "title": "string",
      "summary": "string",
      "expanded": "string|null"
    }
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
  "success": true,
  "data": {
    "expanded": "string",
    "usage": {
      "used": 1,
      "limit": 1
    }
  }
}

---

## 14. Endpoint: Subscription Sync

POST /functions/v1/sync_subscription

### Request
{
  "product_id": "wattwise.fasttrack.3month|null",
  "transaction_id": "string|null",
  "original_transaction_id": "string|null",
  "purchase_date": "2026-04-01T18:00:00Z|null",
  "expires_at": "2026-07-01T18:00:00Z|null",
  "receipt": "string|null"
}

### Response
{
  "success": true,
  "data": {
    "tier": "preview|fast_track|full_prep",
    "status": "active",
    "expires_at": "2026-05-01T00:00:00Z",
    "store_product_id": "wattwise.fasttrack.3month",
    "preview_quizzes_used": 1,
    "preview_quizzes_limit": 1,
    "tutor_messages_used": 0,
    "tutor_messages_limit": 4,
    "nec_explanations_used": 0,
    "nec_explanations_limit": 1
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
