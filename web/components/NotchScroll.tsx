"use client";
import { useRef } from "react";
import { motion, useScroll, useTransform, MotionValue } from "framer-motion";

/**
 * A tall section that pins the notch and scrubs it through its three states as
 * you scroll: idle → a Claude Code session running → the full dashboard.
 */
export default function NotchScroll() {
  const ref = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end end"] });

  // morph geometry across the scroll (with plateaus so each state reads)
  const width = useTransform(scrollYProgress, [0, 0.28, 0.34, 0.6, 0.68, 1], [232, 232, 440, 440, 700, 700]);
  const height = useTransform(scrollYProgress, [0, 0.28, 0.34, 0.6, 0.68, 1], [44, 44, 44, 44, 264, 264]);
  const radius = useTransform(scrollYProgress, [0, 0.6, 0.7], [16, 18, 32]);

  const idleO = useTransform(scrollYProgress, [0, 0.22, 0.3], [1, 1, 0]);
  const compactO = useTransform(scrollYProgress, [0.3, 0.36, 0.58, 0.64], [0, 1, 1, 0]);
  const expandedO = useTransform(scrollYProgress, [0.66, 0.74, 1], [0, 1, 1]);

  const captionIdle = useTransform(scrollYProgress, [0, 0.2, 0.28], [1, 1, 0]);
  const captionRun = useTransform(scrollYProgress, [0.32, 0.4, 0.58, 0.64], [0, 1, 1, 0]);
  const captionExp = useTransform(scrollYProgress, [0.68, 0.76, 1], [0, 1, 1]);

  return (
    <section ref={ref} className="relative h-[320vh]" aria-label="How the notch works">
      <div className="sticky top-0 flex h-screen flex-col items-center justify-center overflow-hidden">
        {/* the faux bezel edge */}
        <div className="absolute left-1/2 top-0 h-px w-screen -translate-x-1/2 bg-line2" />

        <motion.div
          className="relative -mt-24 overflow-hidden border border-white/[.06] border-t-0 bg-device text-white shadow-[0_40px_120px_rgba(0,0,0,.28)]"
          style={{
            width,
            height,
            borderBottomLeftRadius: radius,
            borderBottomRightRadius: radius,
          }}
        >
          <motion.div style={{ opacity: compactO }} className="absolute inset-0 flex items-center justify-between gap-3 px-5">
            <span className="flex items-center gap-2.5">
              <span className="h-3 w-3 animate-[spin_.8s_linear_infinite] rounded-full border-2 border-white/25 border-t-[#E2E0D8]" />
              <span className="text-[13px] font-semibold tracking-tight">Claude&nbsp;Code</span>
            </span>
            <span className="font-mono text-[13px] tabular-nums text-white/70">running</span>
          </motion.div>

          <motion.div style={{ opacity: idleO }} className="absolute inset-0 flex items-center justify-center">
            <span className="h-1.5 w-1.5 rounded-full bg-white/30" />
          </motion.div>

          <motion.div style={{ opacity: expandedO }} className="absolute inset-0 flex flex-col">
            <div className="flex h-11 items-center gap-2 border-b border-white/10 px-5 text-[12px] font-semibold text-white/55">
              Dashboard
            </div>
            <div className="grid flex-1 grid-cols-[1fr_1.3fr_1fr]">
              <Cell label="Clock">
                <div className="font-display text-[30px] font-semibold leading-none tracking-tight">2:08</div>
                <div className="text-[11px] text-white/45">Friday · 26 June</div>
              </Cell>
              <Cell label="Agent · 2 running">
                <Lane title="Editing ActivityStore.swift" id="#a1b2" />
                <Lane title="Running tests · pytest" id="#9f3c" delay=".5s" />
              </Cell>
              <Cell label="System" last>
                <Spark />
                <div className="flex h-6 items-end gap-[3px]">
                  {[0, 0.15, 0.3, 0.45, 0.6].map((d, k) => (
                    <span key={k} className="w-1 animate-[eq_1s_ease-in-out_infinite] rounded-sm bg-white/80" style={{ animationDelay: `${d}s` }} />
                  ))}
                </div>
              </Cell>
            </div>
          </motion.div>
        </motion.div>

        {/* captions tied to scroll */}
        <div className="relative mt-16 h-16 w-full max-w-[560px] px-6 text-center">
          <Caption o={captionIdle} idx="01 / IDLE" text="Resting, it's pitch black — invisible against the bezel." />
          <Caption o={captionRun} idx="02 / LIVE" text="The moment an agent starts, it wakes — and tells you what it's doing." />
          <Caption o={captionExp} idx="03 / OPEN" text="Lean in and the whole dashboard unfolds. Then it tucks away again." />
        </div>

        <div className="absolute bottom-7 left-1/2 -translate-x-1/2 idx">scroll</div>
      </div>

      <style>{`@keyframes eq{0%,100%{height:6px}50%{height:24px}}`}</style>
    </section>
  );
}

function Caption({ o, idx, text }: { o: MotionValue<number>; idx: string; text: string }) {
  return (
    <motion.div style={{ opacity: o }} className="absolute inset-x-0 mx-auto flex flex-col items-center gap-2">
      <span className="idx">{idx}</span>
      <p className="text-balance font-display text-[19px] font-medium leading-snug text-ink">{text}</p>
    </motion.div>
  );
}

function Cell({ label, children, last }: { label: string; children: React.ReactNode; last?: boolean }) {
  return (
    <div className={`flex flex-col gap-2 px-4 py-3 text-left ${last ? "" : "border-r border-white/10"}`}>
      <span className="font-mono text-[9px] uppercase tracking-[.12em] text-white/35">{label}</span>
      {children}
    </div>
  );
}
function Lane({ title, id, delay = "0s" }: { title: string; id: string; delay?: string }) {
  return (
    <div className="flex items-start gap-2">
      <span className="mt-1 h-1.5 w-1.5 animate-[blink_1.4s_infinite] rounded-full bg-[#E2E0D8]" style={{ animationDelay: delay }} />
      <div>
        <div className="text-[12px] font-semibold leading-tight text-white/90">{title}</div>
        <div className="text-[10px] text-white/45">Claude Code <span className="font-mono text-white/35">{id}</span></div>
      </div>
      <style>{`@keyframes blink{0%,100%{opacity:1}50%{opacity:.3}}`}</style>
    </div>
  );
}
function Spark() {
  const n = 22;
  const pts = Array.from({ length: n }, (_, i) => 8 + Math.sin(i * 0.6) * 5 + (i > 14 ? i - 14 : 0));
  const d = pts.map((v, i) => `${i ? "L" : "M"}${((i / (n - 1)) * 120).toFixed(1)},${(34 - v).toFixed(1)}`).join(" ");
  return (
    <svg className="h-[34px] w-full" viewBox="0 0 120 34" preserveAspectRatio="none">
      <path d={`${d} L120,34 L0,34 Z`} fill="rgba(226,224,216,.16)" />
      <path d={d} fill="none" stroke="#E2E0D8" strokeWidth="1.6" strokeLinejoin="round" />
    </svg>
  );
}
