// ============================================================================
// Edge Function : admin-update-user (mission §2.5/§7 — exigences #7/#8)
// Mise à jour email / mot de passe d'un compte par un administrateur.
//
// Pourquoi une Edge Function : avec la clé anon, impossible de modifier
// l'auth d'un AUTRE compte. La service_role (capable de
// auth.admin.updateUserById) ne doit JAMAIS être embarquée dans l'app —
// elle vit ici, côté serveur, avec vérification du rôle appelant.
//
// Déploiement :
//   supabase functions deploy admin-update-user --no-verify-jwt
//   (le JWT est vérifié MANUELLEMENT ci-dessous pour lire l'appelant ;
//   --no-verify-jwt seul laisserait la fonction ouverte à tout appelant
//   authentifié — la garde `role == admin` compense exactement cela).
// Secrets requis côté projet Supabase : SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
// ============================================================================
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors });
  }
  try {
    const url = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    if (!url || !serviceKey) {
      return Response.json({ erreur: 'Serveur mal configuré' }, { status: 500, headers: cors });
    }
    // Appelant : JWT transmis par l'app (jamais la service_role).
    const jwt = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
    if (!jwt) {
      return Response.json({ erreur: 'Non authentifié' }, { status: 401, headers: cors });
    }
    const admin = createClient(url, serviceKey);
    const { data: { user: appelant }, error: errAppelant } =
      await admin.auth.getUser(jwt);
    if (errAppelant || !appelant) {
      return Response.json({ erreur: 'Session invalide' }, { status: 401, headers: cors });
    }
    // Garde : seul un admin (table métier public.users) peut modifier.
    const { data: profil } = await admin
      .from('users').select('role').eq('id', appelant.id).limit(1);
    const role = (profil as Array<{ role: string }> | null)?.[0]?.role;
    if (role !== 'admin') {
      return Response.json({ erreur: 'Réservé à l’administrateur' }, { status: 403, headers: cors });
    }

    const corps = await req.json() as {
      userId?: string; email?: string; password?: string;
    };
    if (!corps.userId || typeof corps.userId !== 'string') {
      return Response.json({ erreur: 'userId requis' }, { status: 400, headers: cors });
    }
    const attrs: { email?: string; password?: string } = {};
    if (typeof corps.email === 'string' && /.+@.+\..+/.test(corps.email)) {
      attrs.email = corps.email.trim();
    }
    if (typeof corps.password === 'string' && corps.password.length >= 6) {
      attrs.password = corps.password;
    }
    if (attrs.email === undefined && attrs.password === undefined) {
      return Response.json(
        { erreur: 'Email invalide et mot de passe trop court (6 min.)' },
        { status: 400, headers: cors });
    }
    const { error: errMaj } =
      await admin.auth.admin.updateUserById(corps.userId, attrs);
    if (errMaj) {
      return Response.json({ erreur: errMaj.message }, { status: 400, headers: cors });
    }
    // Audit trail : la table journal_activite est alimentée par triggers
    // sur les tables métier, pas sur auth.users — on trace explicitement.
    await admin.from('journal_activite').insert({
      user_id: appelant.id,
      action: 'update',
      table_nom: 'auth.users',
      ligne_id: corps.userId,
      detail: {
        via: 'admin-update-user',
        email_modifie: attrs.email !== undefined,
        password_modifie: attrs.password !== undefined,
      },
    });
    return Response.json({ ok: true }, { headers: cors });
  } catch (e) {
    return Response.json(
      { erreur: `Échec : ${e instanceof Error ? e.message : e}` },
      { status: 500, headers: cors });
  }
});
