"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { env, isSupabaseConfigured } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";

export type AuthFormState = {
  message?: string;
  errors?: Partial<Record<"name" | "email" | "password", string[]>>;
};

const emailSchema = z.email("Enter a valid email address.").trim().toLowerCase();
const passwordSchema = z
  .string()
  .min(8, "Use at least 8 characters.")
  .regex(/[A-Za-z]/, "Include at least one letter.")
  .regex(/[0-9]/, "Include at least one number.");

const signUpSchema = z.object({
  name: z.string().trim().min(2, "Enter your name."),
  email: emailSchema,
  password: passwordSchema,
});

const signInSchema = z.object({
  email: emailSchema,
  password: z.string().min(1, "Enter your password."),
});

function safeNext(value: FormDataEntryValue | null, fallback: string) {
  if (typeof value !== "string" || !value.startsWith("/") || value.startsWith("//")) {
    return fallback;
  }
  return value;
}

export async function signIn(
  _state: AuthFormState,
  formData: FormData,
): Promise<AuthFormState> {
  if (!isSupabaseConfigured()) return { message: "Authentication is not configured yet." };

  const parsed = signInSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword(parsed.data);
  if (error) return { message: error.message };

  redirect(safeNext(formData.get("next"), "/dashboard"));
}

export async function signUp(
  _state: AuthFormState,
  formData: FormData,
): Promise<AuthFormState> {
  if (!isSupabaseConfigured()) return { message: "Authentication is not configured yet." };

  const parsed = signUpSchema.safeParse({
    name: formData.get("name"),
    email: formData.get("email"),
    password: formData.get("password"),
  });
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
    email: parsed.data.email,
    password: parsed.data.password,
    options: {
      data: { full_name: parsed.data.name },
      emailRedirectTo: `${env.appUrl}/auth/callback?next=/onboarding`,
    },
  });
  if (error) return { message: error.message };
  if (!data.session) {
    return { message: "Check your email to confirm your account, then return to sign in." };
  }

  redirect("/onboarding");
}

export async function requestPasswordReset(
  _state: AuthFormState,
  formData: FormData,
): Promise<AuthFormState> {
  if (!isSupabaseConfigured()) return { message: "Authentication is not configured yet." };
  const parsed = emailSchema.safeParse(formData.get("email"));
  if (!parsed.success) return { errors: { email: parsed.error.issues.map((issue) => issue.message) } };

  const supabase = await createClient();
  const { error } = await supabase.auth.resetPasswordForEmail(parsed.data, {
    redirectTo: `${env.appUrl}/auth/callback?next=/reset-password`,
  });
  if (error) return { message: error.message };
  return { message: "If that account exists, a password-reset link is on its way." };
}

export async function updatePassword(
  _state: AuthFormState,
  formData: FormData,
): Promise<AuthFormState> {
  const parsed = passwordSchema.safeParse(formData.get("password"));
  if (!parsed.success) return { errors: { password: parsed.error.issues.map((issue) => issue.message) } };
  if (!isSupabaseConfigured()) return { message: "Authentication is not configured yet." };
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { message: "This recovery link is no longer valid. Request a new one." };
  const { error } = await supabase.auth.updateUser({ password: parsed.data });
  if (error) return { message: error.message };
  redirect("/dashboard");
}

export async function signOut() {
  if (isSupabaseConfigured()) {
    const supabase = await createClient();
    await supabase.auth.signOut();
  }
  redirect("/sign-in");
}
