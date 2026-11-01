# ELITEGRAM — full-stack starter

React + Vite + Supabase. The package contains the web client, SMS OTP auth flow, database schema, realtime chat foundation, and setup notes.

## Important
This is a deployable codebase, **not an already-hosted public messenger**. Real accounts, SMS delivery, cross-device messages, uploads, and public channels only work after connecting your own Supabase project and configuring its providers. No secrets are included.

## 1. Supabase
Use the existing project named `ELITIUM` if that is the backend you already created:
1. Open Supabase → SQL Editor.
2. Run the complete `supabase/schema.sql`.
3. Authentication → Providers → enable Phone and configure an SMS provider.
4. Project Settings → API: copy Project URL and anon/public key.

SMS delivery may require a paid provider account and sender configuration. Do not put provider secrets or the `service_role` key in frontend code.

## 2. Environment
Copy `.env.example` to `.env.local` and fill:
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

## 3. Run and build
```bash
npm install
npm run dev
npm run build
```

## 4. Deploy
Import this folder/repository into Vercel as a Vite project. Add the same two `VITE_` variables in Vercel project settings, then deploy.

## Included foundations
- Phone number + SMS OTP sign-in via Supabase Auth.
- Unique username/profile table.
- Direct/group conversation tables and membership model.
- Message table with Realtime-ready structure.
- Channel, subscriber, and channel-post tables.
- Attachment metadata fields and private-storage setup notes.
- Dark/light theme and responsive React interface.

## Still requires implementation / production hardening
The UI from the early ELITIUM codebase is retained and rebranded. The SQL provides the backend data model and row-level security foundation, but not every screen is wired to every table yet. In particular: creating server-side groups/channels and memberships, user discovery/direct-chat creation, file upload/download policies, channel subscription/post UI, push notifications, voice/video calls, moderation, rate limits, account deletion, privacy policy, and a full RLS/security review. Do not call this production-ready until those are completed and tested with multiple accounts.
