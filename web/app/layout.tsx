import type { Metadata } from "next";
import { Bricolage_Grotesque, Hanken_Grotesk, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import SmoothScroll from "@/components/SmoothScroll";
import Backdrop from "@/components/Backdrop";

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
  title: { default: "NotchPulse — Your notch, alive", template: "%s · NotchPulse" },
  description:
    "A precision instrument for your MacBook notch. Watch your Claude Code agents work, glance at widgets, and ask Claude — all in the strip you already own. Free for macOS.",
  metadataBase: new URL("https://notchpulse.app"),
  keywords: ["macOS notch", "MacBook notch app", "Claude Code", "Dynamic Island Mac", "menu bar", "AI agents", "developer tools"],
  applicationName: "NotchPulse",
  openGraph: {
    title: "NotchPulse — Your notch, alive",
    description: "Watch your AI agents work, glance at what matters, and ask Claude — right in your MacBook notch.",
    type: "website",
    siteName: "NotchPulse",
  },
  twitter: {
    card: "summary_large_image",
    title: "NotchPulse — Your notch, alive",
    description: "Watch your AI agents work, right in your MacBook notch. Free for macOS.",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${display.variable} ${body.variable} ${mono.variable}`}>
      <body className="font-body antialiased">
        <Backdrop />
        <SmoothScroll />
        {children}
      </body>
    </html>
  );
}
