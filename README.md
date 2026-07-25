# Launch CRM — hosted app

Your CRM as a real web app: live shared data for the whole team, sign-in by email, working client quote/form links, and installable on your phone.

The app runs in two modes. With no configuration it runs in **demo mode** (sample data, resets on reload) — open `index.html` and look around. Once you connect Supabase and deploy it, it becomes **live**: everything saves to your database, your team signs in with email links, and quote signatures / form submissions from customers flow back in automatically, even while nobody is online.

**Time to go live: about 20 minutes. Cost: $0 on the free tiers** (Supabase free tier + Netlify/Vercel free tier comfortably run a small team).

---

## Step 1 — Create the database (Supabase, ~10 min)

1. Go to **supabase.com** → Start your project → sign up (free).
2. Create a **New project** — name it `launch-crm`, pick a strong database password (you won't need it day-to-day), choose the region closest to you.
3. When the project finishes provisioning, open **SQL Editor** (left sidebar) → **New query**.
4. Open `schema.sql` from this folder, copy **all** of it, paste it into the editor, and click **Run**. You should see "Success".
5. Go to **Project Settings → API** and copy two values:
   - **Project URL** (looks like `https://abcdefgh.supabase.co`)
   - **anon / public key** (a long string — this one is safe to ship in the browser; RLS policies in the schema control what it can touch)
6. Open `config.js` in this folder and paste both values between the quotes.

## Step 2 — Put it on the internet (~5 min)

Easiest: **Netlify Drop** — no account needed to try, free account to keep it.

1. Go to **app.netlify.com/drop**
2. Drag this whole folder onto the page.
3. You get a URL like `https://something.netlify.app` — that's your CRM. (Create the free account to claim it and optionally rename it, e.g. `launch-crm.netlify.app`.)

Prefer Vercel? `vercel.com` → Add New Project → upload the folder — same result.

> Redeploying after a change (like editing `config.js`): drag the folder onto your site's **Deploys** page again.

## Step 3 — Sign in and lock it down (~5 min)

1. Open your new URL. You'll see the sign-in screen. Enter your email → click the link that arrives → you're in, and the app seeds itself with the sample workspace (edit or delete that data as you like — it's yours now, and it saves).
2. Have each teammate sign in the same way once.
3. Then, in Supabase: **Authentication → Sign In / Providers → disable "Allow new users to sign up."** From then on only existing users (your team) can get in; add someone later via **Authentication → Users → Invite**.

That last step matters: until you disable signups, anyone who finds the URL could create an account.

## Step 4 — Put it on your phone (~1 min)

Open the URL in your phone's browser, sign in, then:

- **iPhone (Safari):** Share button → **Add to Home Screen**
- **Android (Chrome):** ⋮ menu → **Add to Home screen** / **Install app**

It opens full-screen like a native app, with the Launch icon.

---

## How the pieces work

- **Live shared data** — the workspace (accounts, deals, quotes, forms, to-dos, custom stages…) is stored in your Supabase Postgres database. Changes save automatically about a second after you make them, and teammates' changes appear on your screen live.
- **Client quote links** — "Copy client link" now produces a real URL (`your-site.netlify.app/?q=TOKEN`). The customer sees only the clean signing page. When they sign, the signature record (name, title, email, timestamp, consent, document checksum) lands in your database — instantly if someone's online (you'll see a toast), otherwise the next time anyone opens the CRM. Tokens are long and unguessable, and anonymous visitors can *only* read that one quote and drop a signature — nothing else (enforced by row-level security).
- **Form links** — same pattern (`/?f=TOKEN`). Submissions create the account/contact/deal and internal note exactly like in the prototype.
- **Sign-in** — Supabase email magic links; no passwords to manage.
- **Demo mode** — if `config.js` is empty the app runs exactly like the prototype, with a banner. Handy for trying changes before deploying.

## Honest limitations of this v1 (and what production hardening looks like)

- **Data model**: the workspace is stored as JSON collections (one row per collection), synced last-write-wins per collection. Perfect for a small team; if two people edit *the same collection* in the same second, the later save wins. As the team and data grow, the natural next step is normalizing into real tables (accounts, deals, quotes as rows) with per-record updates.
- **Signature IP address**: browsers can't see their own public IP, so the signature record notes "Recorded at signing" rather than a real IP. Capturing true IP + user-agent server-side (a small Supabase Edge Function) is the first hardening step if you want stronger evidence — as is a review of the agreement terms by your attorney.
- **Team names**: the team roster shown in the app (owners, assignees) is defined in `index.html` (search for `const TEAM`). Edit names/roles there; a future version can drive this from the actual signed-in users.
- **Backups**: Supabase free tier keeps daily backups for 7 days. Worth checking Settings → Database → Backups once you have real data.

## Files

| File | What it is |
|---|---|
| `index.html` | The entire app (UI + logic + cloud sync layer) |
| `config.js` | Your Supabase URL + anon key (the only file you must edit) |
| `schema.sql` | Database setup — run once in the Supabase SQL editor |
| `manifest.webmanifest`, `sw.js`, `icon-*.png` | Phone install (PWA) support |
