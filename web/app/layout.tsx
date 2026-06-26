import type { Metadata } from "next";
import { Bricolage_Grotesque, Hanken_Grotesk, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import SmoothScroll from "@/components/SmoothScroll";

const display = Bricolage_Grotesque({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
  variable: "--font-display",
});
const body = Hanken_Grotesk({
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  variable: "--font-body",
});
const mono = JetBrains_Mono({
  subsets: ["latin"],
  weight: ["400", "500"],
  variable: "--font-mono",
});

export const metadata: Metadata = {
  title: "NotchPulse — Your notch, alive",
  description:
    "A precision instrument for your MacBook notch. Watch your Claude Code agents work, glance at widgets, and ask Claude — all in the strip you already own. $5 lifetime.",
  metadataBase: new URL("https://notchpulse.app"),
  openGraph: {
    title: "NotchPulse — Your notch, alive",
    description: "Watch your AI agents work, right in your MacBook notch.",
    type: "website",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${display.variable} ${body.variable} ${mono.variable}`}>
      <body className="font-body antialiased">
        <SmoothScroll />
        {children}
      </body>
    </html>
  );
}
