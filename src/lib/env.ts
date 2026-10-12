const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim() ?? "";
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.trim() ?? "";

export const env = {
  supabaseUrl,
  supabaseAnonKey,
  appUrl: process.env.NEXT_PUBLIC_APP_URL?.trim() || "http://localhost:3000",
  demoMode:
    process.env.NEXT_PUBLIC_WATTWISE_DEMO_MODE === "true" ||
    (process.env.NODE_ENV !== "production" && (!supabaseUrl || !supabaseAnonKey)),
};

export function isSupabaseConfigured() {
  return Boolean(env.supabaseUrl && env.supabaseAnonKey);
}

