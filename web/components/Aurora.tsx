"use client";
import { useEffect, useRef } from "react";

/** Ambient aurora glow that drifts toward the cursor. */
export default function Aurora() {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduce) return;
    const onMove = (e: PointerEvent) => {
      const el = ref.current;
      if (!el) return;
      el.style.setProperty("--mx", e.clientX + "px");
      el.style.setProperty("--my", e.clientY * 0.6 + "px");
    };
    addEventListener("pointermove", onMove, { passive: true });
    return () => removeEventListener("pointermove", onMove);
  }, []);

  return (
    <>
      <div ref={ref} className="pointer-events-none fixed inset-0 z-0 overflow-hidden">
        <div
          className="absolute"
          style={{
            width: "120vmax",
            height: "120vmax",
            left: "var(--mx,50%)",
            top: "var(--my,12%)",
            transform: "translate(-50%,-50%)",
            background:
              "radial-gradient(closest-side, rgba(110,99,255,.16), rgba(61,224,192,.08) 40%, transparent 70%)",
            transition: "left .6s cubic-bezier(.2,.7,.2,1), top .6s cubic-bezier(.2,.7,.2,1)",
          }}
        />
      </div>
      <div className="grain pointer-events-none fixed inset-0 z-[1] opacity-[.035] mix-blend-overlay" />
    </>
  );
}
