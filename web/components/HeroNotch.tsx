"use client";
import { useRef } from "react";
import { motion, useMotionValue, useSpring, useTransform } from "framer-motion";

/** A live product mockup of the expanded notch — tilts toward the cursor. */
export default function HeroNotch() {
  const ref = useRef<HTMLDivElement>(null);
  const mx = useMotionValue(0);
  const my = useMotionValue(0);
  const rx = useSpring(useTransform(my, [-0.5, 0.5], [7, -7]), { stiffness: 140, damping: 14 });
  const ry = useSpring(useTransform(mx, [-0.5, 0.5], [-9, 9]), { stiffness: 140, damping: 14 });

  return (
    <div
      ref={ref}
      className="relative mx-auto w-full max-w-[560px]"
      style={{ perspective: 1000 }}
      onPointerMove={(e) => {
        const r = ref.current!.getBoundingClientRect();
        mx.set((e.clientX - r.left) / r.width - 0.5);
        my.set((e.clientY - r.top) / r.height - 0.5);
      }}
      onPointerLeave={() => {
        mx.set(0);
        my.set(0);
      }}
    >
      {/* soft floor shadow */}
      <div className="absolute inset-x-10 bottom-2 h-10 rounded-full bg-ink/10 blur-2xl" />

      <motion.div
        style={{ rotateX: rx, rotateY: ry, transformStyle: "preserve-3d" }}
        className="relative"
        initial={{ opacity: 0, y: 26 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.9, ease: [0.16, 1, 0.3, 1], delay: 0.2 }}
      >
        {/* faux menu-bar that the notch hangs from */}
        <div className="rounded-t-2xl border border-line2 border-b-0 bg-paper2 px-4 py-2.5">
          <div className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-full bg-[#FF5F57]" />
            <span className="h-2.5 w-2.5 rounded-full bg-[#FEBC2E]" />
            <span className="h-2.5 w-2.5 rounded-full bg-[#28C840]" />
            <span className="ml-3 font-mono text-[10px] text-faint">menu bar</span>
          </div>
        </div>

        {/* the notch device, expanded */}
        <div className="overflow-hidden rounded-b-[26px] border border-line2 border-t-0 bg-device text-white shadow-[0_40px_120px_rgba(14,15,18,.22)]">
          <div className="flex h-10 items-center gap-2 border-b border-white/10 px-4 text-[11px] font-semibold text-white/55">
            <span className="h-1.5 w-1.5 rounded-full" style={{ background: "var(--live)", boxShadow: "0 0 8px var(--live)" }} />
            Dashboard
          </div>
          <div className="grid grid-cols-[1fr_1.3fr_1fr]">
            <Cell label="Clock">
              <div className="font-display text-[26px] font-semibold leading-none tracking-tight">2:08</div>
              <div className="text-[10px] text-white/45">Fri · 27 Jun</div>
            </Cell>
            <Cell label="Agent · 2 live">
              <Lane title="Editing ActivityStore" id="#a1b2" />
              <Lane title="pytest · running" id="#9f3c" delay=".5s" />
            </Cell>
            <Cell label="System" last>
              <Spark />
              <div className="flex h-5 items-end gap-[3px]">
                {[0, 0.15, 0.3, 0.45, 0.6].map((d, k) => (
                  <span key={k} className="w-1 rounded-sm bg-white/80" style={{ animation: `eqbar 1s ease-in-out ${d}s infinite` }} />
                ))}
              </div>
            </Cell>
          </div>
        </div>
      </motion.div>

      <style>{`@keyframes eqbar{0%,100%{height:5px}50%{height:20px}}@keyframes pdot{0%,100%{opacity:1}50%{opacity:.3}}`}</style>
    </div>
  );
}

function Cell({ label, children, last }: { label: string; children: React.ReactNode; last?: boolean }) {
  return (
    <div className={`flex flex-col gap-1.5 px-3.5 py-3 text-left ${last ? "" : "border-r border-white/10"}`}>
      <span className="font-mono text-[8px] uppercase tracking-[.12em] text-white/35">{label}</span>
      {children}
    </div>
  );
}
function Lane({ title, id, delay = "0s" }: { title: string; id: string; delay?: string }) {
  return (
    <div className="flex items-start gap-1.5">
      <span className="mt-1 h-1.5 w-1.5 rounded-full bg-[#E2E0D8]" style={{ animation: `pdot 1.4s infinite`, animationDelay: delay }} />
      <div className="min-w-0">
        <div className="truncate text-[11px] font-semibold leading-tight text-white/90">{title}</div>
        <div className="text-[9px] text-white/45">CC <span className="font-mono text-white/35">{id}</span></div>
      </div>
    </div>
  );
}
function Spark() {
  const n = 22;
  const pts = Array.from({ length: n }, (_, i) => 7 + Math.sin(i * 0.6) * 4 + (i > 14 ? i - 14 : 0));
  const d = pts.map((v, i) => `${i ? "L" : "M"}${((i / (n - 1)) * 120).toFixed(1)},${(30 - v).toFixed(1)}`).join(" ");
  return (
    <svg className="h-[28px] w-full" viewBox="0 0 120 30" preserveAspectRatio="none">
      <path d={`${d} L120,30 L0,30 Z`} fill="rgba(226,224,216,.16)" />
      <path d={d} fill="none" stroke="#E2E0D8" strokeWidth="1.6" strokeLinejoin="round" />
    </svg>
  );
}
