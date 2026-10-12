import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return { name: "WattWise", short_name: "WattWise", description: "Electrician licensing exam preparation", start_url: "/dashboard", display: "standalone", background_color: "#fbfbfa", theme_color: "#2e53ff", icons: [] };
}

