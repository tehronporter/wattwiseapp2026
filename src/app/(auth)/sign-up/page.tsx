import type { Metadata } from "next";
import { AuthForm } from "@/components/auth-form";

export const metadata: Metadata = { title: "Create account", description: "Create your personalized WattWise study plan." };

export default function SignUpPage() {
  return <AuthForm mode="sign-up" />;
}

