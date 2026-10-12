import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const base = process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000";
  return ["", "/pricing", "/sign-up", "/terms", "/privacy", "/refund-policy", "/support"].map((path, index) => ({ url: `${base}${path}`, lastModified: new Date(), changeFrequency: "monthly" as const, priority: index === 0 ? 1 : 0.7 }));
}
