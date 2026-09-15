# WattWise Web

WattWise is a web-first electrician exam-preparation workspace built with Next.js, React, TypeScript, and Tailwind CSS. It converts the original SwiftUI product into a responsive learning system while retaining the verified curriculum, question-bank source material, Supabase schema, and backend function contracts.

## Run locally

```bash
npm install
npm run dev
```

Open `http://localhost:3000`. The current build uses local demo state so every primary experience can be reviewed without credentials.

## Available product flows

- Public product landing page
- Responsive authenticated workspace shell
- Personalized dashboard and study plan
- Curriculum, module, and lesson reading flow
- Interactive five-question practice set with explanations and results
- Review dashboard with weak-area routing
- Searchable NEC article guide
- Context-aware local tutor demo
- Account and study-plan settings

## Connect services later

Copy `.env.example` to `.env.local` and add Supabase and AI credentials. The existing `wattwise/supabase` migrations and edge functions remain the backend source of truth and can be adapted to web sessions. Replace the local tutor response adapter and demo progress with authenticated API calls after the Supabase project is connected.

## Migration decisions

Kept: curriculum and question content, NEC verification metadata, Supabase tables/functions, progress concepts, adaptive-practice rules, and the restrained TEHSO visual identity.

Rebuilt: navigation, screen hierarchy, responsive layouts, lesson reader, practice feedback, Code lookup, and the marketing/onboarding entry point.

Deferred until external services are connected: production authentication, persisted cross-device progress, AI streaming, billing, and transactional email.
