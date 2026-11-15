# Office of the Vice President

The Vice President's site for the United States 2070. It covers the Vice President, the President of the Senate, and the Acting Secretary of War under the national emergency.

## What it does
- Document Studio:
  - Vice President documents: statements, memoranda, and letters.
  - President of the Senate documents: tie-breaking votes and rulings of the chair.
  - Every War Department order type, signed as "Vice President and Acting Secretary of War" on War Department letterhead.
- Overview: the emergency banner and the War Department command post.
- Senate: the record of every tie-breaking vote and ruling.
- Units, Personnel, Operations, and Military Justice: the full War Department toolkit.
- Discord: issued documents post to the right server through the nation bot.
- Staff: invite staff by email. Only staff can sign in or see anything.

## Deploy on Vercel
1. Put this folder in a GitHub repository.
2. On vercel.com, go to Add New > Project and import that repository.
3. Framework preset: Other. No build command. Press Deploy.

## One Supabase setting (required)
In Supabase, open project us-2070-nation, then Authentication > URL Configuration:
- Set Site URL to your Vercel address, for example https://office-of-the-vice-president.vercel.app
- Add the same address under Redirect URLs.

If you skip this, the sign-in email sends you to the wrong address.

## First sign-in
The first person who signs in becomes the owner. Sign in yourself right after you deploy.

## Database
The tables are already set up. supabase/setup-vp-db.sql is a copy for your records. It is safe to run again.
