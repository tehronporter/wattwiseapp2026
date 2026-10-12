"use client";

import Link from "next/link";
import { useActionState } from "react";
import {
  requestPasswordReset,
  signIn,
  signUp,
  updatePassword,
  type AuthFormState,
} from "@/app/actions/auth";
import { BrandMark } from "@/components/brand-mark";
import { Button } from "@/components/ui/button";

type Mode = "sign-in" | "sign-up" | "forgot-password" | "reset-password";

const initialState: AuthFormState = {};

export function AuthForm({ mode, next = "/dashboard" }: { mode: Mode; next?: string }) {
  const action = mode === "sign-up" ? signUp : mode === "forgot-password" ? requestPasswordReset : mode === "reset-password" ? updatePassword : signIn;
  const [state, formAction, pending] = useActionState(action, initialState);
  const isSignUp = mode === "sign-up";
  const isReset = mode === "forgot-password";
  const isUpdate = mode === "reset-password";

  return (
    <main className="grid min-h-screen place-items-center bg-[var(--surface-warm)] px-4 py-10">
      <section className="w-full max-w-md rounded-[28px] border border-[var(--line)] bg-white p-6 shadow-[0_24px_80px_rgba(25,30,45,.08)] sm:p-8">
        <Link href="/" className="inline-flex"><BrandMark /></Link>
        <p className="mt-8 text-[10px] font-bold uppercase tracking-[.14em] text-[var(--blue)]">
          {isSignUp ? "Create your plan" : isReset || isUpdate ? "Account recovery" : "Welcome back"}
        </p>
        <h1 className="mt-2 text-3xl font-bold tracking-[-.05em]">
          {isSignUp ? "Start studying with a plan." : isReset ? "Reset your password." : isUpdate ? "Choose a new password." : "Sign in to WattWise."}
        </h1>
        <p className="mt-3 text-sm leading-6 text-[var(--ink-soft)]">
          {isSignUp
            ? "Set your license track, jurisdiction, exam date, and daily goal after creating your account."
            : isReset
              ? "We’ll email a secure link if an account matches this address."
              : isUpdate ? "Use at least eight characters with a letter and a number." : "Your lessons, attempts, and readiness stay synchronized across devices."}
        </p>

        <form action={formAction} className="mt-7 space-y-4">
          <input type="hidden" name="next" value={next} />
          {isSignUp && <AuthField label="Name" name="name" autoComplete="name" errors={state.errors?.name} />}
          {!isUpdate && <AuthField label="Email" name="email" type="email" autoComplete="email" errors={state.errors?.email} />}
          {!isReset && (
            <AuthField
              label="Password"
              name="password"
              type="password"
              autoComplete={isSignUp || isUpdate ? "new-password" : "current-password"}
              errors={state.errors?.password}
            />
          )}
          {state.message && (
            <p role="status" className="rounded-xl bg-[var(--surface)] px-3 py-2.5 text-xs leading-5 text-[var(--ink-soft)]">
              {state.message}
            </p>
          )}
          <Button className="w-full" disabled={pending} type="submit">
            {pending ? "Working…" : isSignUp ? "Create account" : isReset ? "Send reset link" : isUpdate ? "Save new password" : "Sign in"}
          </Button>
        </form>

        <div className="mt-6 flex items-center justify-between text-xs">
          {isReset || isUpdate ? (
            <Link href="/sign-in" className="font-semibold text-[var(--blue)]">Back to sign in</Link>
          ) : (
            <>
              <Link href={isSignUp ? "/sign-in" : "/sign-up"} className="font-semibold text-[var(--blue)]">
                {isSignUp ? "Already have an account?" : "Create an account"}
              </Link>
              {!isSignUp && <Link href="/forgot-password" className="text-[var(--ink-soft)]">Forgot password?</Link>}
            </>
          )}
        </div>
      </section>
    </main>
  );
}

function AuthField({
  label,
  name,
  type = "text",
  autoComplete,
  errors,
}: {
  label: string;
  name: string;
  type?: string;
  autoComplete: string;
  errors?: string[];
}) {
  const errorId = errors?.length ? `${name}-error` : undefined;
  return (
    <label className="block text-xs font-semibold" htmlFor={name}>
      {label}
      <input
        id={name}
        name={name}
        type={type}
        autoComplete={autoComplete}
        aria-describedby={errorId}
        aria-invalid={Boolean(errors?.length)}
        required
        className="mt-2 h-11 w-full rounded-xl border border-[var(--line-strong)] bg-white px-3 text-sm outline-none focus:border-[var(--blue)] focus:ring-2 focus:ring-[var(--blue-soft)]"
      />
      {errors?.map((error) => <span id={errorId} key={error} className="mt-1 block text-[11px] font-normal text-[var(--error)]">{error}</span>)}
    </label>
  );
}
