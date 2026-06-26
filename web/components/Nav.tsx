"use client";
import { useEffect, useState } from "react";
import { COFFEE_URL } from "@/lib/site";

export default function Nav() {
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    const on = () => setScrolled(window.scrollY > 12);
    addEventListener("scroll", on, { passive: true });
    return () => removeEventListener("scroll", on);
  }, []);
  return (
    <nav
      className={`fixed inset-x-0 top-0 z-50 transition-all duration-300 ${
        scrolled ? "glass-soft" : "border-b border-transparent"
      }`}
    >
      <div className="mx-auto flex h-16 max-w-content items-center justify-between px-6">
        <a href="#top" className="flex items-center gap-2.5 font-display text-[17px] font-semibold tracking-tight">
          <Mark />
          NotchPulse
        </a>
        <div className="flex items-center gap-7 text-[13.5px] text-ink2">
          <a href="#tour" className="hidden hover:text-ink sm:block">Tour</a>
          <a href="#features" className="hidden hover:text-ink sm:block">Features</a>
          <a href="#support" className="hover:text-ink">Support</a>
          <a
            href={COFFEE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 rounded-full bg-coffee px-4 py-2 text-[13px] font-semibold text-bean transition-transform hover:-translate-y-0.5"
          >
            ☕ Buy me a coffee
          </a>
        </div>
      </div>
    </nav>
  );
}

export function Mark({ size = 22 }: { size?: number }) {
  return (
    <span
      className="relative inline-block rounded-b-[6px] bg-device"
      style={{ width: size, height: size * 0.6 }}
      aria-hidden
    >
      <span
        className="absolute left-1/2 top-[3px] h-1 w-1 -translate-x-1/2 rounded-full"
        style={{ background: "var(--live)", boxShadow: "0 0 6px var(--live)" }}
      />
    </span>
  );
}
