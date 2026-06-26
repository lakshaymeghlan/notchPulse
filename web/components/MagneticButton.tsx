"use client";
import { useRef } from "react";
import { motion, useMotionValue, useSpring } from "framer-motion";

type Props = {
  href: string;
  children: React.ReactNode;
  variant?: "primary" | "ghost";
  className?: string;
  external?: boolean;
};

export default function MagneticButton({ href, children, variant = "primary", className = "", external }: Props) {
  const ref = useRef<HTMLAnchorElement>(null);
  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const sx = useSpring(x, { stiffness: 250, damping: 18 });
  const sy = useSpring(y, { stiffness: 250, damping: 18 });

  const base =
    "relative inline-flex items-center justify-center gap-2 rounded-full font-semibold cursor-pointer select-none";
  const styles =
    variant === "primary"
      ? "text-[#03130E] shadow-[0_8px_30px_rgba(61,224,192,.28),inset_0_1px_0_rgba(255,255,255,.4)]"
      : "text-ink bg-white/5 border border-white/15 hover:bg-white/10";

  return (
    <motion.a
      ref={ref}
      href={href}
      target={external ? "_blank" : undefined}
      rel={external ? "noopener noreferrer" : undefined}
      className={`${base} ${styles} ${className}`}
      style={{
        x: sx,
        y: sy,
        background:
          variant === "primary" ? "linear-gradient(180deg,#4ff0d2,#28c3a6)" : undefined,
      }}
      onPointerMove={(e) => {
        const r = ref.current!.getBoundingClientRect();
        x.set((e.clientX - r.left - r.width / 2) / 5);
        y.set((e.clientY - r.top - r.height / 2) / 5);
      }}
      onPointerLeave={() => {
        x.set(0);
        y.set(0);
      }}
      whileHover={{ scale: 1.03 }}
      whileTap={{ scale: 0.97 }}
    >
      {children}
    </motion.a>
  );
}
