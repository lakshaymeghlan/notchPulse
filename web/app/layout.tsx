import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "NotchPulse — Your notch, alive",
  description:
    "NotchPulse turns your MacBook notch into a live surface for your AI agents, widgets, and a built-in Ask Claude. $5 lifetime, all updates included.",
  metadataBase: new URL("https://notchpulse.app"),
  openGraph: {
    title: "NotchPulse — Your notch, alive",
    description:
      "Watch your Claude Code agents work, glance at widgets, and ask Claude — right in your MacBook notch.",
    type: "website",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="font-sans antialiased">{children}</body>
    </html>
  );
}
