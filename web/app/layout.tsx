import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import "./globals.css";

// Klim Martina Plantijn — serif for display/headlines (DESIGN.md: serif display type).
const martinaPlantijn = localFont({
  src: [
    { path: "./fonts/MartinaPlantijn-Regular.woff2", weight: "400", style: "normal" },
    { path: "./fonts/MartinaPlantijn-Medium.woff2", weight: "500", style: "normal" },
    { path: "./fonts/MartinaPlantijn-Bold.woff2", weight: "700", style: "normal" },
  ],
  variable: "--font-serif",
  display: "swap",
});

// Klim Söhne — sans for chrome/metadata/controls (DESIGN.md: SF-equivalent role).
const soehne = localFont({
  src: [
    { path: "./fonts/Soehne-Buch.woff2", weight: "400", style: "normal" },
    { path: "./fonts/Soehne-Buch-Kursiv.woff2", weight: "400", style: "italic" },
    { path: "./fonts/Soehne-Halbfett.woff2", weight: "600", style: "normal" },
    { path: "./fonts/Soehne-Dreiviertelfett.woff2", weight: "700", style: "normal" },
  ],
  variable: "--font-sans",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Monocle Radio",
  description: "Live stream and on-demand episodes from Monocle 24.",
  manifest: "/manifest.json",
  icons: {
    apple: "/icons/icon-180.png",
    icon: "/icons/icon-192.png",
  },
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "Monocle Radio",
  },
  other: {
    // Legacy key still honored by older iOS Safari builds
    "apple-mobile-web-app-capable": "yes",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#FAF7F1" },
    { media: "(prefers-color-scheme: dark)", color: "#141210" },
  ],
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${martinaPlantijn.variable} ${soehne.variable}`}>
      <body>{children}</body>
    </html>
  );
}
