import type { Metadata, Viewport } from "next";
import { Cormorant_Garamond, DM_Sans, Noto_Sans_Arabic } from "next/font/google";
import "./globals.css";
import "./bilingual.css";
import "./learning.css";

const sans = DM_Sans({ variable: "--font-sans", subsets: ["latin"] });
const arabic = Noto_Sans_Arabic({ variable: "--font-arabic", subsets: ["arabic"], display: "swap" });
const serif = Cormorant_Garamond({ variable: "--font-serif", subsets: ["latin"] });

const OG_IMAGE = {
  url: "/og.jpg",
  width: 1200,
  height: 675,
  alt: "An anatomical heart specimen floating above a plinth, beside the Anatomy Atelier wordmark",
};

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ??
  (process.env.VERCEL_PROJECT_PRODUCTION_URL ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}` : "https://anatomy-atelier.openai.site");

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: { default: "Anatomy Atelier — Interactive 3D medical learning", template: "%s | Anatomy Atelier" },
  description: "Explore nine medically structured 3D organ specimens, guided lessons, clinical context, and knowledge checks in Arabic and English.",
  applicationName: "Anatomy Atelier",
  keywords: ["anatomy", "3D anatomy", "human body", "medical education", "interactive learning", "clinical anatomy", "organs", "تشريح", "أطلس تشريحي", "تعليم طبي", "نماذج ثلاثية الأبعاد"],
  alternates: { canonical: "/", languages: { "en": "/", "ar": "/?lang=ar" } },
  robots: { index: true, follow: true, googleBot: { index: true, follow: true, "max-image-preview": "large" } },
  category: "education",
  icons: {
    icon: [
      { url: "/favicon.svg", type: "image/svg+xml" },
      { url: "/icon-192.png", sizes: "192x192", type: "image/png" },
      { url: "/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
    shortcut: "/favicon.svg",
    apple: { url: "/apple-touch-icon.png", sizes: "180x180" },
  },
  openGraph: {
    type: "website", siteName: "Anatomy Atelier",
    title: { default: "Anatomy Atelier — Interactive 3D medical learning", template: "%s | Anatomy Atelier" },
    description: "Bilingual interactive anatomy with 3D specimens, structured lessons, and clinical knowledge checks.",
    images: [OG_IMAGE], locale: "en_US", alternateLocale: ["ar_AR"],
  },
  twitter: {
    card: "summary_large_image",
    title: { default: "Anatomy Atelier — Interactive 3D medical learning", template: "%s | Anatomy Atelier" },
    description: "Bilingual interactive anatomy with structured lessons and clinical context.", images: [OG_IMAGE],
  },
};

export const viewport: Viewport = { themeColor: "#f7f0e7", colorScheme: "light" };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body className={`${sans.variable} ${serif.variable} ${arabic.variable}`}>{children}</body></html>;
}
