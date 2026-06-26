"use client";
import { useRef } from "react";
import { motion, useMotionValue, useSpring } from "framer-motion";

type Props = {
  href: string;
  children: React.ReactNode;
  variant?: "primary" | "ghost";
  className?: string;
  external?: boolean;
  download?: boolean;
};

export default function MagneticButton({ href, children, variant = "primary", className = "", external, download }: Props) {
  const ref = useRef<HTMLAnchorElement>(null);
  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const sx = useSpring(x, { stiffness: 250, damping: 18 });
  const sy = useSpring(y, { stiffness: 250, damping: 18 });

  const base = "relative inline-flex items-center justify-center gap-2 rounded-full font-medium select-none";
  const look =
    variant === "primary"
      ? "bg-ink text-paper shadow-[0_10px_30px_rgba(23,24,26,.18)]"
      : "text-ink border border-line2 bg-card hover:bg-paper2";

  return (
    <motion.a
      ref={ref}
      href={href}
      target={external ? "_blank" : undefined}
      rel={external ? "noopener noreferrer" : undefined}
      download={download ? "" : undefined}
      className={`${base} ${look} ${className}`}
      style={{ x: sx, y: sy }}
      onPointerMove={(e) => {
        const r = ref.current!.getBoundingClientRect();
        x.set((e.clientX - r.left - r.width / 2) / 5);
        y.set((e.clientY - r.top - r.height / 2) / 5);
      }}
      onPointerLeave={() => {
        x.set(0);
        y.set(0);
      }}
      whileHover={{ scale: 1.025 }}
      whileTap={{ scale: 0.97 }}
    >
      {children}
    </motion.a>
  );
}
