"use client";

import { useActionState } from "react";
import { Trash2 } from "lucide-react";
import { deleteAccount, type DeleteAccountState } from "@/app/actions/account";
import { Button } from "@/components/ui/button";

const initialState: DeleteAccountState = {};

export function DeleteAccountForm() {
  const [state, action, pending] = useActionState(deleteAccount, initialState);
  return (
    <form action={action} className="mt-6">
      <label htmlFor="confirmation" className="text-xs font-semibold">Type DELETE to confirm</label>
      <input id="confirmation" name="confirmation" required autoComplete="off" className="mt-2 h-11 w-full rounded-xl border border-[var(--line-strong)] px-3 text-sm outline-none focus:ring-2 focus:ring-[var(--error-soft)]" />
      {state.message && <p role="alert" className="mt-3 text-xs text-[var(--error)]">{state.message}</p>}
      <Button type="submit" disabled={pending} className="mt-5 bg-[var(--error)] shadow-none hover:bg-[#9f3f28]"><Trash2 className="size-4"/>{pending ? "Deleting…" : "Permanently delete account"}</Button>
    </form>
  );
}

