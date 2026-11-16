# Office of the Vice President

The Vice President's site for the United States 2070. It covers the Vice President, the President of the Senate, and the Acting Secretary of War under the national emergency.

## Deploy on Vercel
1. Put this folder in a GitHub repository.
2. On vercel.com, go to Add New > Project and import that repository.
3. Framework preset: Other. No build command. Press Deploy.

## First-time setup
1. Open the site. It shows First-time setup.
2. Enter your name, a username, and a password. That makes you the admin.
3. Do this right after you deploy. Setup closes as soon as the first admin exists.

## Accounts
- Sign-in is a username and a password. No emails are sent.
- Only an admin can add, change, or remove accounts, from the Admin tab.
- Roles:
  - Admin: manages accounts. Keep yourself as Admin.
  - Vice President: the name signed on documents by default. Only one at a time. Naming a new Vice President moves the old one to Staff.
  - Staff: drafts, signs, and issues, but cannot manage accounts.
- When a term ends: add the new Vice President, set them as Vice President, then hold Remove on the old account.
- Forgot password: the admin uses Reset password.

## Optional Supabase setting
In Supabase, open project us-2070-nation, then Authentication > Sign In / Providers, and turn off "Allow new users to sign up". The site does not need public sign-ups, because the admin makes every account. Admin-made accounts still work with it off.

## What is in this folder
- index.html: the whole site.
- vercel.json: security headers for Vercel.
- vp-seal.svg: the Vice President seal.
- supabase/: copies of the database setup and the account function, for your records. Both are already live.
