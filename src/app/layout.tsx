import type { Metadata } from "next";
import localFont from "next/font/local";
import "./globals.css";

const inter = localFont({
  src: "../../wattwise/wattwise/Resources/Fonts/Inter-VariableFont.ttf",
  variable: "--font-inter",
  display: "swap",
});

export const metadata: Metadata = {
  title: { default: "WattWise — Pass with confidence", template: "%s · WattWise" },
  description: "A focused electrician exam prep workspace built around the NEC, adaptive practice, and clear explanations.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={inter.variable}>
      <body>{children}</body>
    </html>
  );
}
