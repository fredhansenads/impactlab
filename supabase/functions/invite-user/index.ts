import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (status: number, body: unknown) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, "Content-Type": "application/json" },
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Método inválido." });
  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) return reply(401, { error: "Entre novamente." });
    const url = Deno.env.get("SUPABASE_URL")!;
    const publicKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const adminKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const userClient = createClient(url, publicKey, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } });
    const { data: auth, error: authError } = await userClient.auth.getUser();
    if (authError || !auth.user) return reply(401, { error: "Sessão inválida." });
    const { data: snapshot, error: profileError } = await userClient.rpc("school_snapshot");
    if (profileError || snapshot?.account?.role !== "coordinator") return reply(403, { error: "Somente a coordenação cadastra contas." });
    const { name, email, role } = await req.json();
    if (typeof name !== "string" || name.trim().length < 1 || name.length > 100 ||
        typeof email !== "string" || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
        !["student", "teacher", "guardian", "delivery"].includes(role)) {
      return reply(400, { error: "Confira nome, e-mail e perfil." });
    }
    const admin = createClient(url, adminKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const redirectTo = Deno.env.get("INVITE_REDIRECT_URL");
    if (!redirectTo) return reply(503, { error: "A escola precisa configurar o endereço de ativação." });
    const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email.trim(), { redirectTo });
    if (inviteError || !invited.user) return reply(409, { error: "Não foi possível convidar. Confira se a conta já existe ou se o serviço de e-mail está configurado." });
    const { error: provisioningError } = await admin.rpc("provision_school_user", {
      actor: auth.user.id, target: invited.user.id, display_name: name.trim(), access_role: role,
    });
    if (provisioningError) {
      // Only the account created by this request is eligible for compensation.
      const { error: cleanupError } = await admin.auth.admin.deleteUser(invited.user.id);
      if (cleanupError) console.error("Provisioning compensation requires administrator attention", invited.user.id);
      return reply(500, { error: "Não foi possível concluir o cadastro. A secretaria deve conferir o convite antes de repetir." });
    }
    return reply(201, { ok: true });
  } catch {
    return reply(500, { error: "Não foi possível processar o cadastro. Tente novamente mais tarde." });
  }
});
