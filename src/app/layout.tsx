import type { Metadata } from "next";
import localFont from "next/font/local";
import { Analytics } from "@vercel/analytics/next";
import { SpeedInsights } from "@vercel/speed-insights/next";
import "./globals.css";

const inter = localFont({
  src: "../../wattwise/wattwise/Resources/Fonts/Inter-VariableFont.ttf",
  variable: "--font-inter",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000"),
  title: { default: "WattWise — Electrician exam prep", template: "%s · WattWise" },
  description: "A focused electrician exam prep workspace built around the NEC, adaptive practice, and clear explanations.",
  openGraph: {
    title: "WattWise — Electrician exam prep",
    description: "Build NEC knowledge with focused lessons, practice, and clear explanations.",
    type: "website",
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={inter.variable}>
      <body>{children}<Analytics /><SpeedInsights /></body>
    </html>
  );
}
