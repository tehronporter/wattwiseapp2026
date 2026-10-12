"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { isSupabaseConfigured } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";

export type DeleteAccountState = { message?: string };

export async function deleteAccount(
  _state: DeleteAccountState,
  formData: FormData,
): Promise<DeleteAccountState> {
  const parsed = z.literal("DELETE").safeParse(formData.get("confirmation"));
  if (!parsed.success) return { message: "Type DELETE exactly to confirm." };
  if (!isSupabaseConfigured()) return { message: "Demo accounts cannot be deleted." };

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { message: "Your session expired. Sign in again." };

  const { error } = await supabase.functions.invoke("delete_account", { body: {} });
  if (error) return { message: "We could not delete the account. Contact support if this continues." };
  await supabase.auth.signOut();
  redirect("/?account=deleted");
}

