"use client";
import confetti from "canvas-confetti";
import { COFFEE_URL } from "@/lib/site";

/** Coffee CTA that pops a little celebration, then opens Buy Me a Coffee. */
export default function CoffeeButton({ className = "", children }: { className?: string; children?: React.ReactNode }) {
  const onClick = (e: React.MouseEvent) => {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const r = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const origin = { x: (r.left + r.width / 2) / innerWidth, y: (r.top + r.height / 2) / innerHeight };
    const opts = { spread: 70, ticks: 120, gravity: 1.1, scalar: 0.9, origin };
    confetti({ ...opts, particleCount: 30, startVelocity: 32, colors: ["#FFDD00", "#3A2A1A", "#0E0F12"] });
    setTimeout(() => confetti({ ...opts, particleCount: 18, startVelocity: 24, colors: ["#FFDD00", "#E23A2E"] }), 120);
  };
  return (
    <a
      href={COFFEE_URL}
      target="_blank"
      rel="noopener noreferrer"
      onClick={onClick}
      className={`inline-flex items-center gap-2 rounded-full bg-coffee font-semibold text-bean transition-transform hover:-translate-y-0.5 ${className}`}
    >
      {children ?? <>☕ Buy me a coffee</>}
    </a>
  );
}
