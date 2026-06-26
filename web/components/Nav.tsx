"use client";
import { useEffect, useState } from "react";

export default function Nav() {
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    const on = () => setScrolled(window.scrollY > 12);
    addEventListener("scroll", on, { passive: true });
    return () => removeEventListener("scroll", on);
  }, []);
  return (
    <nav
      className={`fixed inset-x-0 top-0 z-50 backdrop-blur-xl backdrop-saturate-150 transition-colors ${
        scrolled ? "border-b border-white/[.08] bg-bg/80" : "border-b border-transparent bg-bg/50"
      }`}
    >
      <div className="mx-auto flex h-[62px] max-w-content items-center justify-between px-6">
        <a href="#top" className="flex items-center gap-2.5 font-bold tracking-tight">
          <Glyph />
          NotchPulse
        </a>
        <div className="flex items-center gap-6 text-sm text-muted">
          <a href="#features" className="hidden hover:text-ink sm:block">Features</a>
          <a href="#how" className="hidden hover:text-ink sm:block">How it works</a>
          <a href="#pricing" className="hover:text-ink">Pricing</a>
          <a
            href="#pricing"
            className="rounded-full bg-gradient-to-b from-[#4ff0d2] to-[#28c3a6] px-4 py-2 text-sm font-semibold text-[#03130E]"
          >
            Get it · $5
          </a>
        </div>
      </div>
    </nav>
  );
}

export function Glyph({ size = 26 }: { size?: number }) {
  return (
    <span
      className="relative inline-block rounded-b-lg border border-white/15 border-t-0 bg-black"
      style={{ width: size, height: size * 0.62 }}
    >
      <span className="absolute left-1/2 top-1 h-1.5 w-1.5 -translate-x-1/2 animate-blink rounded-full bg-pulse shadow-[0_0_10px_var(--pulse)]" />
    </span>
  );
}
