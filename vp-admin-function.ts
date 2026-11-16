// @ts-nocheck
// Accounts for the Office of the Vice President site. Usernames and passwords, no email.
// - status: is first-time setup still open?
// - setup: create the first admin. Works only while no admin exists.
// - add, update, password, remove: admin only.
import { createClient } from 'npm:@supabase/supabase-js@2.49.4';

const URL_ = Deno.env.get('SUPABASE_URL');
const admin = createClient(URL_, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false, autoRefreshToken: false } });
const DOMAIN = 'ovp.example.com'; // reserved domain: these addresses never receive mail
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const json = (o, status = 200) => new Response(JSON.stringify(o), { status, headers: { ...CORS, 'content-type': 'application/json' } });
const ROLES = ['admin', 'vp', 'staff'];
const cleanName = s => String(s || '').replace(/[\u0000-\u001f]/g, '').trim().slice(0, 60);
const cleanUser = s => String(s || '').trim().toLowerCase();
const okUser = u => /^[a-z0-9][a-z0-9._-]{2,31}$/.test(u);
const okPass = p => typeof p === 'string' && p.length >= 8 && p.length <= 72;

async function adminCount() { const { count } = await admin.from('vp_staff').select('user_id', { count: 'exact', head: true }).eq('role', 'admin'); return count || 0; }
async function makeUser({ username, name, password, role, title }) {
  const { data, error } = await admin.auth.admin.createUser({ email: `${username}@${DOMAIN}`, password, email_confirm: true, user_metadata: { username, name } });
  if (error) throw new Error(/already/i.test(error.message) ? 'That username is taken.' : error.message);
  const { error: e2 } = await admin.from('vp_staff').insert({ user_id: data.user.id, email: `${username}@${DOMAIN}`, username, name, role, title });
  if (e2) { await admin.auth.admin.deleteUser(data.user.id); throw new Error(/duplicate|unique/i.test(e2.message) ? 'That username is taken.' : e2.message); }
  return data.user.id;
}
// Only one current Vice President at a time. Naming a new one moves the old one to staff.
async function oneVp(keep) { await admin.from('vp_staff').update({ role: 'staff' }).eq('role', 'vp').neq('user_id', keep); }

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'POST only' }, 405);
  let b = {}; try { b = await req.json(); } catch {}
  try {
    if (b.action === 'status') return json({ needsSetup: (await adminCount()) === 0 });
    if (b.action === 'setup') {
      if ((await adminCount()) > 0) return json({ error: 'Setup is already done. Sign in instead.' }, 403);
      const username = cleanUser(b.username), name = cleanName(b.name);
      if (!okUser(username)) return json({ error: 'Username: 3 to 32 letters, numbers, dots, dashes, or underscores.' }, 400);
      if (!okPass(b.password)) return json({ error: 'Password: at least 8 characters.' }, 400);
      if (!name) return json({ error: 'Enter your name.' }, 400);
      await makeUser({ username, name, password: b.password, role: 'admin', title: cleanName(b.title) || 'Administrator' });
      return json({ ok: true, email: `${username}@${DOMAIN}` });
    }
    // Everything else needs a signed-in admin.
    const token = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
    const { data: who } = await admin.auth.getUser(token);
    const me = who && who.user; if (!me) return json({ error: 'Sign in first.' }, 401);
    const { data: row } = await admin.from('vp_staff').select('role').eq('user_id', me.id).maybeSingle();
    if (!row || row.role !== 'admin') return json({ error: 'Only an admin can manage accounts.' }, 403);

    if (b.action === 'add') {
      const username = cleanUser(b.username), name = cleanName(b.name), role = ROLES.includes(b.role) ? b.role : 'staff';
      if (!okUser(username)) return json({ error: 'Username: 3 to 32 letters, numbers, dots, dashes, or underscores.' }, 400);
      if (!okPass(b.password)) return json({ error: 'Password: at least 8 characters.' }, 400);
      if (!name) return json({ error: 'Enter a name.' }, 400);
      const id = await makeUser({ username, name, password: b.password, role, title: cleanName(b.title) });
      if (role === 'vp') await oneVp(id);
      return json({ ok: true, user_id: id });
    }
    const target = String(b.user_id || '');
    const { data: t } = await admin.from('vp_staff').select('user_id,role').eq('user_id', target).maybeSingle();
    if (!t) return json({ error: 'No such account.' }, 404);
    if (b.action === 'update') {
      const patch = {};
      if (b.name !== undefined) { const n = cleanName(b.name); if (!n) return json({ error: 'Enter a name.' }, 400); patch.name = n; }
      if (b.title !== undefined) patch.title = cleanName(b.title);
      if (b.role !== undefined) {
        if (!ROLES.includes(b.role)) return json({ error: 'Unknown role.' }, 400);
        if (t.role === 'admin' && b.role !== 'admin' && (await adminCount()) <= 1) return json({ error: 'Keep at least one admin.' }, 400);
        patch.role = b.role;
      }
      const { error } = await admin.from('vp_staff').update(patch).eq('user_id', target); if (error) throw error;
      if (patch.role === 'vp') await oneVp(target);
      return json({ ok: true });
    }
    if (b.action === 'password') {
      if (!okPass(b.password)) return json({ error: 'Password: at least 8 characters.' }, 400);
      const { error } = await admin.auth.admin.updateUserById(target, { password: b.password }); if (error) throw error;
      return json({ ok: true });
    }
    if (b.action === 'remove') {
      if (target === me.id) return json({ error: 'You cannot remove your own account.' }, 400);
      if (t.role === 'admin' && (await adminCount()) <= 1) return json({ error: 'Keep at least one admin.' }, 400);
      const { error } = await admin.auth.admin.deleteUser(target); if (error) throw error;
      await admin.from('vp_staff').delete().eq('user_id', target);
      return json({ ok: true });
    }
    return json({ error: 'Unknown action.' }, 400);
  } catch (e) { return json({ error: String(e.message || e).slice(0, 300) }, 500); }
});
