
# WattWise — iOS Architecture (Production-Level)

## 0. Purpose

This document defines the complete iOS application architecture for WattWise.

It exists to ensure that:
- the SwiftUI codebase is scalable and maintainable
- product behavior remains predictable as the app grows
- engineering decisions stay aligned with the PRD, UI Spec, User Flows, Content Strategy, and TEHSO Design System
- Codex, Claude, and human developers have one technical source of truth for how the app should be structured

This architecture is intentionally opinionated. WattWise should not be built as an improvised collection of SwiftUI screens and networking calls. It should be built as a disciplined, modular, testable iOS application.

---

## 1. Architecture Principles

## 1.1 SwiftUI-Native
WattWise should be built natively in SwiftUI. UIKit should only be introduced when absolutely necessary for platform-specific integrations or missing framework capabilities.

## 1.2 MVVM + Services
The app should use a clear separation between:
- Views
- ViewModels
- Services
- Models
- Core infrastructure

Views should render state.
ViewModels should manage screen-level state and orchestration.
Services should own business logic, API communication, persistence, and domain workflows.

## 1.3 Thin Views
SwiftUI Views must stay lightweight.
They should not:
- perform raw networking
- contain business rules
- decode API payloads
- manage unrelated application state

## 1.4 Predictable State
State should have a clear owner.
If a screen needs data, there must be an obvious answer to:
- where that data comes from
- who updates it
- how it is cached
- what happens on failure

## 1.5 Offline-Friendly by Default
WattWise does not need a full offline-first architecture in v1, but it must be designed to handle:
- temporary network interruption
- cached recent progress
- lesson re-entry
- locally stored UI/session state

## 1.6 Backend Abstraction
The Swift app must never tightly couple itself to a specific AI provider or raw database layout beyond stable service interfaces.
The app talks to:
- Supabase auth/session systems
- structured backend APIs / edge functions
- local service abstractions

Not directly to OpenAI or other provider SDKs from the client.

## 1.7 TEHSO Consistency
Architecture decisions should support:
- calm UI
- predictable navigation
- low-friction interactions
- reusable components
- elegant loading and error handling

---

## 2. Platform Scope

### Initial Target
- iPhone-only
- iOS 18+ preferred target if aligned with your current stack, otherwise iOS 17+ minimum depending on package compatibility and device coverage goals

### Initial Orientation
- Portrait-first
- No landscape-specific UX required for v1 unless practice mode benefits from it later

### Initial Device Classes
- Small iPhone
- Standard iPhone
- Pro Max iPhone

Architecture must support responsiveness across all primary iPhone sizes.

---

## 3. Recommended Tech Stack

## 3.1 UI Layer
- SwiftUI

## 3.2 Concurrency
- Swift Concurrency (`async/await`)
- MainActor isolation for UI-bound state
- structured tasks
- cancellation-aware async operations

## 3.3 Persistence
Recommended:
- SwiftData for lightweight local app persistence and caching
or
- a hybrid lightweight file/cache layer if you want to stay lean initially

Suggested local persistence use cases:
- recent lesson context
- cached module metadata
- quiz in-progress state if retained locally
- tutor drafts / recent chat state (optional)
- user preferences already mirrored from backend

## 3.4 Networking
- URLSession-based networking through a centralized API client layer
- Supabase Swift SDK for auth and database/API interactions where appropriate
- edge function calls wrapped inside service abstractions

## 3.5 Authentication
- Supabase Auth
- Sign in with Apple
- Email/password

## 3.6 Purchases
- StoreKit 2

## 3.7 Analytics / Observability
For v1, keep analytics abstracted behind a client-facing service protocol.
Do not scatter logging and event tracking throughout views.

Potential later integrations:
- PostHog
- Firebase Analytics
- custom Supabase event logging

---

## 4. Application Layering

WattWise should be structured across five primary layers:

### 4.1 App Layer
Responsible for:
- app entry point
- dependency bootstrapping
- global containers/environment injection
- tab shell
- scene lifecycle handling

### 4.2 Presentation Layer
Responsible for:
- SwiftUI screens
- reusable view components
- visual states
- gestures
- user interactions
- accessibility rendering

### 4.3 State / ViewModel Layer
Responsible for:
- screen-level state
- async loading orchestration
- invoking services
- state transitions
- user intent handling

### 4.4 Domain / Service Layer
Responsible for:
- auth flows
- content fetching
- quiz generation
- tutor messaging
- NEC lookup orchestration
- progress updates
- subscription state
- recommendations

### 4.5 Data / Infrastructure Layer
Responsible for:
- API client
- Supabase integration
- local cache
- decoding/encoding
- secrets/config
- error mapping
- system adapters

---

## 5. Recommended Project Structure

```text
WattWise/
├── App/
│   ├── WattWiseApp.swift
│   ├── AppRouter.swift
│   ├── AppContainer.swift
│   ├── AppEnvironment.swift
│   └── RootTabView.swift
│
├── Core/
│   ├── Config/
│   │   ├── AppConfig.swift
│   │   ├── EnvironmentValues.swift
│   │   └── FeatureFlags.swift
│   ├── DesignSystem/
│   │   ├── WWColor.swift
│   │   ├── WWTypography.swift
│   │   ├── WWSpacing.swift
│   │   ├── WWButtonStyle.swift
│   │   ├── WWCardStyle.swift
│   │   └── WWProgressStyle.swift
│   ├── Networking/
│   │   ├── APIClient.swift
│   │   ├── APIEndpoint.swift
│   │   ├── APIRequest.swift
│   │   ├── APIError.swift
│   │   └── NetworkMonitor.swift
│   ├── Persistence/
│   │   ├── CacheStore.swift
│   │   ├── LocalStore.swift
│   │   ├── LessonCache.swift
│   │   └── QuizDraftStore.swift
│   ├── Utilities/
│   │   ├── DateFormatter+WW.swift
│   │   ├── String+WW.swift
│   │   ├── Logger.swift
│   │   └── Haptics.swift
│   └── Extensions/
│
├── Models/
│   ├── User/
│   │   ├── WWUser.swift
│   │   ├── UserProfile.swift
│   │   └── StudyPreferences.swift
│   ├── Content/
│   │   ├── Module.swift
│   │   ├── Lesson.swift
│   │   ├── LessonSection.swift
│   │   ├── NECReference.swift
│   │   └── TopicTag.swift
│   ├── Quiz/
│   │   ├── Quiz.swift
│   │   ├── QuizQuestion.swift
│   │   ├── AnswerOption.swift
│   │   ├── QuizAnswer.swift
│   │   ├── QuizAttempt.swift
│   │   └── QuizResult.swift
│   ├── Tutor/
│   │   ├── TutorSession.swift
│   │   ├── TutorMessage.swift
│   │   └── TutorContext.swift
│   ├── NEC/
│   │   ├── NECSearchResult.swift
│   │   └── NECDetail.swift
│   ├── Subscription/
│   │   ├── SubscriptionPlan.swift
│   │   ├── SubscriptionState.swift
│   │   └── Entitlement.swift
│   └── Common/
│       ├── LoadState.swift
│       ├── AppErrorState.swift
│       └── EmptyStateConfig.swift
│
├── Services/
│   ├── Auth/
│   │   ├── AuthService.swift
│   │   └── AuthSessionCoordinator.swift
│   ├── Content/
│   │   ├── ContentService.swift
│   │   ├── LessonService.swift
│   │   ├── ModuleService.swift
│   │   └── RecommendationService.swift
│   ├── Quiz/
│   │   ├── QuizService.swift
│   │   ├── QuizSessionService.swift
│   │   └── WeakAreaService.swift
│   ├── Tutor/
│   │   ├── TutorService.swift
│   │   └── TutorContextBuilder.swift
│   ├── NEC/
│   │   ├── NECService.swift
│   │   └── NECSearchService.swift
│   ├── Progress/
│   │   ├── ProgressService.swift
│   │   ├── StudyGoalService.swift
│   │   └── StreakService.swift
│   ├── Subscription/
│   │   ├── SubscriptionService.swift
│   │   ├── PurchaseService.swift
│   │   └── EntitlementSyncService.swift
│   └── Analytics/
│       └── AnalyticsService.swift
│
├── ViewModels/
│   ├── Root/
│   │   ├── AppViewModel.swift
│   │   └── RootTabViewModel.swift
│   ├── Auth/
│   │   ├── WelcomeViewModel.swift
│   │   ├── SignInViewModel.swift
│   │   ├── SignUpViewModel.swift
│   │   └── OnboardingViewModel.swift
│   ├── Home/
│   │   └── HomeViewModel.swift
│   ├── Learn/
│   │   ├── LearnViewModel.swift
│   │   ├── ModuleDetailViewModel.swift
│   │   └── LessonViewModel.swift
│   ├── Practice/
│   │   ├── PracticeHomeViewModel.swift
│   │   ├── QuizViewModel.swift
│   │   └── QuizResultsViewModel.swift
│   ├── Tutor/
│   │   └── TutorViewModel.swift
│   ├── NEC/
│   │   ├── NECSearchViewModel.swift
│   │   └── NECDetailViewModel.swift
│   ├── Profile/
│   │   └── ProfileViewModel.swift
│   └── Paywall/
│       └── PaywallViewModel.swift
│
├── Views/
│   ├── Auth/
│   ├── Home/
│   ├── Learn/
│   ├── Practice/
│   ├── Tutor/
│   ├── NEC/
│   ├── Profile/
│   ├── Paywall/
│   ├── Components/
│   └── Shared/
│
├── Resources/
│   ├── Assets.xcassets
│   ├── Localizable.strings
│   └── Preview Content/
│
└── Tests/
    ├── Unit/
    ├── Integration/
    └── Snapshot/
```

This structure can evolve, but its layering must remain intact.

---

## 6. App Entry & Bootstrapping

## 6.1 `WattWiseApp.swift`
Responsibilities:
- initialize app container
- configure shared environment objects if needed
- launch root scene
- coordinate auth/session restoration
- inject root dependencies

`WattWiseApp` should remain minimal.

## 6.2 `AppContainer`
This should be the dependency composition root.

Responsibilities:
- construct services
- construct API clients
- configure persistence stores
- inject shared dependencies into view models
- centralize environment selection (dev, staging, production)

This avoids hidden dependencies and scattered singleton usage.

## 6.3 `AppEnvironment`
Stores environment-wide values such as:
- app mode
- feature flags
- API base references
- build settings
- debug toggles

---

## 7. Navigation Architecture

## 7.1 Root Navigation Model
WattWise uses a root tab shell with five tabs:

1. Home
2. Learn
3. Practice
4. Tutor
5. Profile

Each tab should own its own `NavigationStack`.

Why:
- preserves stack state per tab
- improves UX continuity
- aligns with Apple-native navigation behavior
- avoids brittle cross-screen routing logic

## 7.2 Tab Behavior
Each tab should preserve its last navigation depth when reasonable.

Examples:
- if user is inside a module and switches tabs, returning to Learn should preserve position
- if user is deep in Tutor, that conversation should remain intact if memory constraints permit

## 7.3 Deep Linking / Future Re-entry
Architecture should support future routing into:
- specific lesson
- specific quiz results
- tutor context
- NEC reference detail
- paywall
- reminder-driven destination

This means route representations should be typed and explicit, not stringly typed ad hoc logic.

Suggested approach:
- per-tab route enums
- central route coordinator only when necessary

---

## 8. State Management Strategy

## 8.1 State Ownership Rules
The owner of a piece of state must be clear.

### View-Owned State
Use for:
- local field focus
- toggles
- sheet presentation flags
- transient UI behavior

### ViewModel-Owned State
Use for:
- loaded screen data
- async request states
- selection state that matters to screen logic
- error state
- CTA availability

### App-Level State
Use for:
- auth/session
- subscription status
- current user profile summary
- global app readiness
- route decisions at app startup

## 8.2 Recommended Patterns
Use:
- `@State` for local SwiftUI UI state
- `@StateObject` for long-lived view model ownership by root screen
- `@ObservedObject` or observation system where appropriate for injected view models
- `@MainActor` on UI-facing view models
- explicit immutable view data structs where helpful

## 8.3 Avoid
- giant global view models
- excessive environment objects for everything
- views mutating shared domain state directly
- networking inside views
- logic duplicated between multiple screens

---

## 9. ViewModel Design

Every major screen gets its own view model.

## 9.1 Responsibilities of a ViewModel
A ViewModel may:
- fetch and load screen data
- call services
- transform domain models into display state
- handle user intents
- manage loading, empty, and error states
- coordinate navigation output signals if needed

A ViewModel should not:
- render UI
- contain raw API endpoint definitions
- duplicate service business rules
- manage unrelated app features

## 9.2 Example ViewModel Breakdown

### `HomeViewModel`
Owns:
- continue learning card data
- today’s focus data
- daily goal progress
- streak summary
- quick action routes

### `LessonViewModel`
Owns:
- lesson content loading
- active mode (read / slides / future listen)
- lesson progress state
- NEC reference tap actions
- contextual tutor launch data

### `QuizViewModel`
Owns:
- active quiz session
- selected answers
- question progression
- timer state
- submit state
- exit confirmation behavior

### `TutorViewModel`
Owns:
- message list
- input field state
- contextual entry mode
- send message lifecycle
- AI failure state
- free-tier gating signals

---

## 10. Models & Domain Design

Models must be cleanly separated between:
- backend DTOs
- domain models
- view-facing presentation models if needed

## 10.1 Domain Model Goals
- strongly typed
- readable
- independent from UI
- stable across feature evolution

## 10.2 Suggested Domain Models

### User / Profile
- `WWUser`
- `UserProfile`
- `StudyPreferences`
- `ExamType`
- `Jurisdiction`

### Learning Content
- `Module`
- `Lesson`
- `LessonSection`
- `LessonSummary`
- `NECReference`

### Quiz
- `Quiz`
- `QuizQuestion`
- `AnswerOption`
- `QuizAnswer`
- `QuizAttempt`
- `QuizResult`
- `WeakTopicSummary`

### Tutor
- `TutorSession`
- `TutorMessage`
- `TutorContext`
- `TutorEntryPoint`

### NEC
- `NECSearchResult`
- `NECDetail`
- `NECExplanation`

### Subscription
- `SubscriptionPlan`
- `SubscriptionState`
- `Entitlement`

## 10.3 DTO Mapping
Backend payloads should decode into DTOs, then map into domain models.
Do not let raw backend payload shapes leak throughout the app.

This is important because:
- backend shape may evolve
- UI should not depend on transport structure
- domain models should stay clean

---

## 11. Services Layer Design

Services are the functional backbone of the app.

## 11.1 Service Design Rules
Every service should:
- have a narrow purpose
- expose async methods
- map low-level errors into domain/app errors
- avoid UI concerns
- be testable in isolation
- support dependency injection

## 11.2 Core Services

### `AuthService`
Responsibilities:
- sign in / sign up
- sign out
- restore session
- refresh session if needed
- expose current auth status

### `AuthSessionCoordinator`
Responsibilities:
- app launch session restore
- route decisions based on session state
- avoid auth drift across app shell

### `ContentService`
Responsibilities:
- fetch module list
- fetch module detail
- fetch recommended lessons
- coordinate state-specific content retrieval

### `LessonService`
Responsibilities:
- fetch lesson body
- fetch lesson section content
- save lesson progress
- resume lesson state

### `RecommendationService`
Responsibilities:
- determine next best action
- support Today’s Focus
- combine progress + weak area logic

### `QuizService`
Responsibilities:
- request generated quiz
- submit answers
- receive results
- fetch explanation data if needed

### `QuizSessionService`
Responsibilities:
- manage active local quiz session state
- store temporary draft/progress
- restore in-progress session if supported

### `WeakAreaService`
Responsibilities:
- identify weak topics
- return review recommendations
- support results follow-up flows

### `TutorService`
Responsibilities:
- send tutor messages
- attach context payloads
- receive structured AI responses
- store tutor thread state if persisted

### `TutorContextBuilder`
Responsibilities:
- build contextual entry payloads from:
  - lesson
  - missed question
  - NEC detail
  - general tutor entry

### `NECService`
Responsibilities:
- fetch NEC detail
- retrieve simplified explanation
- bridge to AI expansion

### `NECSearchService`
Responsibilities:
- search NEC references by keyword / code / phrase

### `ProgressService`
Responsibilities:
- compute and fetch user progress
- module completion
- lesson completion
- study minutes
- dashboard summaries

### `StudyGoalService`
Responsibilities:
- track minutes studied
- daily goal progress

### `StreakService`
Responsibilities:
- compute streaks
- determine study-day qualification rules

### `SubscriptionService`
Responsibilities:
- hold current subscription state
- expose entitlement checks
- sync backend subscription metadata if needed

### `PurchaseService`
Responsibilities:
- interact with StoreKit 2
- initiate purchase
- restore purchases

### `EntitlementSyncService`
Responsibilities:
- reconcile StoreKit purchase state with backend profile if required

### `AnalyticsService`
Responsibilities:
- event logging behind abstraction
- no raw analytics calls scattered across UI

---

## 12. Networking Architecture

## 12.1 API Strategy
WattWise should centralize all networking through a consistent client abstraction.

Recommended components:
- `APIClient`
- `APIEndpoint`
- `APIRequest`
- `APIError`

## 12.2 Rules
- no raw `URLSession` calls spread through services without shared wrapper
- common request/response pipeline
- common error mapping
- common retry policy where appropriate
- authentication headers handled centrally

## 12.3 Supabase Usage
The app may use Supabase client features for:
- auth
- protected data access
- edge function invocation

But these interactions must still be wrapped in your own app services.

The rest of the app should not “know Supabase” deeply.

## 12.4 Edge Function Usage
All AI-related actions should flow through backend edge functions, not direct provider access.

Examples:
- tutor response generation
- quiz generation
- study plan generation later
- NEC explanation expansion
- recommendation enrichment if AI-backed later

This allows:
- secret protection
- provider swapping later
- moderation / safety rules
- cost controls
- server-side logging

---

## 13. Error Handling Architecture

## 13.1 Error Philosophy
Errors should be:
- predictable
- typed
- human-readable at the UI layer
- detailed enough for internal diagnostics

## 13.2 Error Layers

### Infrastructure Errors
Examples:
- networking failure
- decoding failure
- timeout
- invalid response

### Domain Errors
Examples:
- quiz generation unavailable
- tutor quota reached
- subscription required
- invalid state selection
- lesson unavailable

### UI Errors
Friendly messages surfaced to users, mapped from domain errors.

## 13.3 Recommended Pattern
Define an app-wide error model such as:
- `AppError`
- `AppErrorState`
- `UserFacingError`

Services map low-level failures into domain/app errors.
ViewModels map app errors into displayable state.

Views only render user-facing messages and actions.

---

## 14. Loading / Empty / Error State Modeling

Every primary async screen should have a standardized load state model.

Suggested enum pattern:
- idle
- loading
- loaded(data)
- empty
- failed(error)

This keeps screens predictable and easier to test.

Use shared rendering patterns so:
- all empty states feel consistent
- all retry UX feels consistent
- loading skeletons feel TEHSO-aligned

---

## 15. Persistence & Caching Strategy

## 15.1 Goals
Caching should improve:
- perceived speed
- session continuity
- resilience to minor connectivity issues

## 15.2 Recommended Local Persistence Targets

### Essential for v1
- authenticated session tokens via supported auth storage flow
- last viewed lesson context
- module list cache
- progress summary snapshot
- study goal progress snapshot
- selected user preferences

### Nice-to-Have for v1 / v1.1
- in-progress quiz draft
- NEC recent searches
- tutor draft input
- recent NEC details
- recently opened lessons

## 15.3 Cache Rules
- cached content must have freshness rules
- stale cache should not masquerade as guaranteed-current backend truth
- the app should show cached content gracefully while refreshing in background where practical

---

## 16. Lesson Continuity Architecture

Lesson continuity is core to WattWise.

## 16.1 What Must Persist
- current lesson ID
- last completed section/page
- selected mode if relevant
- timestamp of last interaction

## 16.2 Continue Learning Source of Truth
`Continue Learning` should come from a combination of:
- backend-saved lesson progress
- local cached session continuity
- progress service reconciliation

The user should not lose their place because of a temporary interruption.

---

## 17. Quiz Session Architecture

Quiz behavior must be deterministic and safe.

## 17.1 Quiz Session State
A quiz session should track:
- quiz ID
- question order
- selected answers
- current index
- timer state if applicable
- started timestamp
- submission state

## 17.2 Local Handling
In-progress quiz state may be stored locally if you choose to support resume.

If resume is not supported in v1:
- architecture should still isolate quiz session logic cleanly for future support

## 17.3 Results Integrity
Quiz results must be derived from a trusted submission flow and not loosely computed in multiple places.

Prefer one source of truth for:
- scoring
- correct answers
- weak topic tagging

---

## 18. Tutor Architecture

Tutor is not generic chat. It is a context-aware educational assistant.

## 18.1 Tutor Entry Types
Tutor sessions may start from:
- general tutor tab
- lesson context
- missed question context
- NEC detail context

This means Tutor architecture should support:
- contextual metadata
- source reference
- conversation continuity
- user tier gating

## 18.2 Message Model
Each message should carry:
- ID
- role
- timestamp
- content
- optional structured blocks
- optional related content context

## 18.3 Response Strategy
The UI should be capable of rendering:
- short paragraph replies
- bullet lists
- step-by-step sections
- code explanation blocks
- follow-up suggestions

Even if the first version is simple, the model should anticipate richer structured output.

---

## 19. NEC Architecture

NEC is a distinct product feature and should not be an afterthought tucked into generic tutor logic.

## 19.1 NEC Services
Separate NEC search and NEC detail responsibilities from tutor services.

Why:
- NEC needs structured lookups
- tutor may elaborate, but NEC retrieval is its own domain behavior
- this prevents “everything becomes chat”

## 19.2 NEC Detail Model
Should include:
- code reference identifier
- title
- simplified explanation
- optional original reference/source metadata
- related topic tags
- optional AI expansion availability

---

## 20. Subscription & Entitlement Architecture

## 20.1 Design Goal
Subscription status must be:
- accurate
- quickly accessible
- app-wide
- consistent between StoreKit and backend profile state if synced

## 20.2 Entitlement Source
Use StoreKit 2 as the primary transaction authority on device.
Backend sync may mirror status for analytics, server-side access rules, or cross-device logic.

## 20.3 App-Wide Access Pattern
The app should be able to ask simple questions like:
- can user access tutor?
- can user start another quiz?
- should paywall be shown?
- is feature fully unlocked?

This should happen through a clear entitlement interface, not scattered conditional logic.

---

## 21. App Startup Flow

On launch, the app should determine:

1. Is there a valid session?
2. Has onboarding been completed?
3. Has essential profile data loaded?
4. What is current subscription state?
5. Can root shell be shown safely?

Suggested startup states:
- booting
- needsAuth
- needsOnboarding
- ready
- fatalError (rare)

This avoids messy launch races and navigation flashes.

---

## 22. Concurrency Guidelines

## 22.1 Use Structured Concurrency
Prefer:
- `Task`
- `async let`
- `await`
- task cancellation

Avoid callback-heavy architecture.

## 22.2 MainActor Discipline
UI-facing ViewModels should be `@MainActor`.
Heavy parsing / mapping can occur off-main when needed.

## 22.3 Cancellation
Long-running operations should support cancellation, especially:
- tutor requests
- NEC expansion requests
- quiz generation
- lesson loads triggered by fast navigation changes

---

## 23. Testing Strategy

Architecture must support testing from the beginning.

## 23.1 Unit Testing Priorities
- service behavior
- view model state transitions
- entitlement logic
- recommendation logic
- error mapping

## 23.2 Integration Testing Priorities
- auth flows
- session restore
- content loading
- quiz submission
- tutor request flow
- purchase / restore flows

## 23.3 Snapshot / UI Tests
Optional but helpful for:
- core screens
- empty states
- error states
- paywall
- small iPhone layout regressions

## 23.4 Testability Rules
Services must be protocol-backed or injectable.
Avoid hard-coding live dependencies into view models.

---

## 24. Dependency Injection Strategy

Use constructor injection wherever possible.

Example:
- a ViewModel receives service protocols in its initializer
- preview/test environments can inject mock services
- live app container injects real services

Benefits:
- testability
- preview support
- cleaner code ownership
- easier migration later if backend/provider changes

Do not default to global singletons for everything.

Singleton-style shared objects may exist only where truly justified, such as carefully controlled app container or auth coordinator patterns.

---

## 25. Accessibility Architecture Considerations

Accessibility should not be treated as a last-step polish item.

The architecture should support:
- dynamic text size
- semantic grouping
- clear labels for interactive elements
- screen-reader-friendly ordering
- contrast-safe reusable design system tokens

Reusable components should carry accessible defaults.

---

## 26. Localization Readiness

Even if English is the only launch language, architecture should not hardcode user-facing strings all over the codebase.

Use centralized string strategy so future bilingual expansion is possible.

This matters because WattWise may later benefit from broader accessibility and multilingual explanations.

---

## 27. Logging & Diagnostics

A lightweight logger abstraction should exist from v1.

Goals:
- debug network issues
- trace AI request failures
- inspect session restore issues
- diagnose purchase problems
- avoid polluting production console output

Logs should be environment-aware:
- verbose in debug
- restrained in release

Sensitive user data must never be carelessly logged.

---

## 28. Performance Considerations

## 28.1 App Performance Goals
- Home should feel instant
- Learn list should scroll smoothly
- lesson loading should feel fast
- quiz interactions should feel immediate
- tutor should show responsive sending/loading state

## 28.2 Architectural Performance Rules
- avoid over-nesting giant SwiftUI trees without extraction
- avoid unnecessary full-screen re-renders from over-shared state
- keep expensive transforms out of body calculations
- precompute or cache where appropriate

---

## 29. Feature Flags & Future-Proofing

Feature flags may be useful for:
- phased rollout of NEC tools
- future listen mode
- future study plans
- future analytics experiments

But feature flags should not become a crutch for sloppy architecture.

Use them sparingly and centrally.

---

## 30. Security Considerations

The iOS app must:
- never embed private AI provider keys
- avoid exposing sensitive backend internals unnecessarily
- rely on authenticated backend access
- respect RLS and entitlement checks
- store local sensitive values securely where needed

Use:
- Keychain for appropriate secure token storage paths if not fully managed by auth SDK
- backend-mediated privileged actions
- minimal trust in client-side premium state alone

---

## 31. Definition of Architectural Done

The architecture is considered correctly implemented when:
- every major feature has a defined service owner
- every screen has a clear view model owner
- navigation is predictable and stable
- app launch/session restore is deterministic
- core state is testable
- no major feature relies on view-layer networking
- purchase, auth, tutor, quiz, lesson, and NEC domains are all cleanly separated
- future additions can be made without rewriting the app shell

---

## 32. Anti-Patterns to Avoid

Do not:
- put API calls directly in SwiftUI views
- use one giant app view model for everything
- couple UI directly to raw Supabase or AI payloads
- mix purchase logic into unrelated content services
- treat tutor as an unstructured text blob system only
- bury NEC logic inside generic lesson rendering code
- create dozens of inconsistent reusable components with overlapping purposes
- introduce multiple navigation paradigms across the app

---

## 33. Final Architectural Principle

WattWise should feel simple to the user because it is disciplined underneath.

The goal is not architectural complexity.
The goal is architectural clarity.

When implemented correctly:
- the UI stays calm
- the logic stays modular
- the app stays flexible
- the product remains trustworthy as it grows
