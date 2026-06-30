"use client";
import confetti from "canvas-confetti";
import { SUPPORT_URL } from "@/lib/site";

/** Support CTA that pops confetti, then opens the payment link. */
export default function CoffeeButton({
  className = "",
  children,
  href = SUPPORT_URL,
}: {
  className?: string;
  children?: React.ReactNode;
  href?: string;
}) {
  const onClick = (e: React.MouseEvent) => {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const r = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const origin = { x: (r.left + r.width / 2) / innerWidth, y: (r.top + r.height / 2) / innerHeight };
    const opts = { spread: 70, ticks: 120, gravity: 1.1, scalar: 0.9, origin };
    confetti({ ...opts, particleCount: 30, startVelocity: 32, colors: ["#4D9BFF", "#9CC6FF", "#0E0F12"] });
    setTimeout(() => confetti({ ...opts, particleCount: 18, startVelocity: 24, colors: ["#4D9BFF", "#FFFFFF"] }), 120);
  };
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      onClick={onClick}
      className={`inline-flex items-center gap-2 rounded-full bg-razor font-semibold text-white shadow-[0_8px_24px_rgba(77,155,255,.32)] transition-all hover:-translate-y-0.5 hover:bg-razorHi ${className}`}
    >
      {children ?? <>Support NotchPulse →</>}
    </a>
  );
}
