
# WattWise — QA Plan (Production-Level)

## 0. Purpose

Defines the complete quality assurance strategy for WattWise.

Ensures:
- production readiness
- stable user experience
- no critical bugs at launch
- alignment across frontend, backend, and AI systems

---

## 1. QA Philosophy

### 1.1 Prevent, Not Just Detect
QA is not only about finding bugs.
It is about preventing them through:
- strong architecture
- clear contracts
- predictable flows

### 1.2 End-to-End Thinking
Every feature must be tested:
- UI
- ViewModel logic
- Service layer
- Backend responses
- Edge cases

### 1.3 Real User Simulation
Testing should mimic:
- new users
- returning users
- free vs Pro users
- poor network conditions

---

## 2. QA Scope

Must cover:

- Auth + onboarding
- Home dashboard
- Learn system
- Lesson experience
- Quiz engine
- Tutor (AI)
- NEC lookup
- Subscription + paywall
- Profile/settings
- Error states
- Loading states

---

## 3. Testing Layers

### 3.1 Unit Testing
Focus:
- Services
- ViewModels
- business logic

Examples:
- quiz scoring
- weak topic calculation
- entitlement checks

---

### 3.2 Integration Testing
Focus:
- API communication
- Supabase interaction
- Edge functions

Examples:
- login flow
- quiz submission
- tutor response handling

---

### 3.3 UI Testing
Focus:
- navigation flows
- screen rendering
- interaction correctness

Examples:
- onboarding flow
- tab navigation
- quiz answering

---

### 3.4 Manual Testing
Critical before launch:
- full user journeys
- edge cases
- real device testing

---

## 4. Core User Flow Tests

### 4.1 First-Time User
- install app
- complete onboarding
- start first lesson
- complete lesson
- take quiz

### 4.2 Returning User
- open app
- resume lesson
- check progress
- complete quiz

### 4.3 Free User Limits
- complete preview lesson
- complete preview quick quiz
- hit tutor preview limit
- hit quiz preview limit
- verify paywall appears correctly
- verify locked lesson states are clear

### 4.4 Pro User
- purchase Fast Track
- verify full unlock
- purchase Full Prep
- verify full unlock
- verify expiration handling for paid access

---

## 5. Feature Test Cases

## 5.1 Auth
- valid login
- invalid login
- session restore
- logout

## 5.2 Onboarding
- exam type selection
- state selection
- goal selection

## 5.3 Lessons
- load lesson
- navigate sections
- save progress

## 5.4 Quiz
- generate quiz
- select answers
- submit
- review results

## 5.5 Tutor
- send message
- receive response
- handle failure

## 5.6 NEC
- search
- view detail
- AI explain

## 5.7 Access / Purchase
- purchase Fast Track
- purchase Full Prep
- restore access
- entitlement update
- preview fallback after expiration

---

## 6. Edge Case Testing

- no internet
- slow network
- API timeout
- empty data
- corrupted state
- expired session

---

## 7. Performance Testing

Ensure:
- Home loads fast
- lists scroll smoothly
- quiz interactions are instant
- tutor shows loading quickly

---

## 8. Error Handling QA

Verify:
- clear error messages
- retry actions
- no crashes
- no blank screens

---

## 9. Device Testing

Test on:
- small iPhone
- standard iPhone
- Pro Max

Ensure:
- layout consistency
- no overflow issues

---

## 10. TestFlight Checklist

Before submission:
- no crashes
- all flows working
- access purchase and restore working
- privacy + terms visible
- test account ready

---

## 11. Regression Testing

After any update:
- re-test core flows
- verify no broken features
- verify API compatibility

---

## 12. Definition of QA Done

QA is complete when:
- all core flows pass
- no critical bugs remain
- UI is consistent
- performance is acceptable
- app is TestFlight ready

---

## 13. Final Principle

If a user can get confused, stuck, or blocked,
QA is not complete.
