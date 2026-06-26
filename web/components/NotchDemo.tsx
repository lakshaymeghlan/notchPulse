"use client";
import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";

type Phase = "idle" | "compact" | "expanded";
const SEQ: { phase: Phase; hold: number }[] = [
  { phase: "idle", hold: 1500 },
  { phase: "compact", hold: 2600 },
  { phase: "expanded", hold: 4400 },
];

const SIZES: Record<Phase, { w: number; h: number; r: number }> = {
  idle: { w: 230, h: 42, r: 16 },
  compact: { w: 430, h: 42, r: 16 },
  expanded: { w: 680, h: 250, r: 30 },
};

export default function NotchDemo() {
  const [i, setI] = useState(0);
  const [pct, setPct] = useState(62);
  const [clock, setClock] = useState("2:08");
  const phase = SEQ[i].phase;
  const reduce = typeof window !== "undefined" && matchMedia("(prefers-reduced-motion: reduce)").matches;

  useEffect(() => {
    if (reduce) {
      setI(2);
      return;
    }
    const t = setTimeout(() => setI((p) => (p + 1) % SEQ.length), SEQ[i].hold);
    return () => clearTimeout(t);
  }, [i, reduce]);

  useEffect(() => {
    const p = setInterval(() => setPct((v) => (v >= 99 ? 8 : v + Math.floor(Math.random() * 7 + 1))), 900);
    const c = setInterval(() => {
      const d = new Date();
      setClock(`${d.getHours() % 12 || 12}:${`${d.getMinutes()}`.padStart(2, "0")}`);
    }, 1000);
    return () => {
      clearInterval(p);
      clearInterval(c);
    };
  }, []);

  const size = SIZES[phase];

  return (
    <div className="relative mx-auto mt-16 flex h-[300px] max-w-[760px] justify-center">
      <div className="absolute left-1/2 top-0 h-px w-full -translate-x-1/2 bg-gradient-to-r from-transparent via-white/15 to-transparent" />
      {/* glow */}
      <AnimatePresence>
        {phase === "expanded" && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="pointer-events-none absolute -top-10 left-1/2 h-[200px] w-[520px] -translate-x-1/2 blur-2xl"
            style={{
              background:
                "radial-gradient(closest-side,rgba(61,224,192,.22),rgba(110,99,255,.12) 45%,transparent 72%)",
            }}
          />
        )}
      </AnimatePresence>

      <motion.div
        className="relative overflow-hidden border border-white/[.06] border-t-0 bg-black shadow-[0_30px_80px_rgba(0,0,0,.6)]"
        animate={{ width: size.w, height: size.h, borderBottomLeftRadius: size.r, borderBottomRightRadius: size.r }}
        transition={{ type: "spring", stiffness: 220, damping: 26 }}
      >
        <AnimatePresence mode="wait">
          {phase === "compact" && (
            <motion.div
              key="compact"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="flex h-full items-center justify-between gap-3 px-[18px] text-white"
            >
              <span className="flex items-center gap-2">
                <span className="h-[13px] w-[13px] animate-spin rounded-full border-2 border-white/25 border-t-pulse" />
                <span className="text-[13px] font-semibold">Claude&nbsp;Code</span>
              </span>
              <span className="font-mono text-[13px] text-pulse tabular-nums">{pct}%</span>
            </motion.div>
          )}

          {phase === "expanded" && (
            <motion.div
              key="expanded"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ delay: 0.12 }}
              className="flex h-full flex-col text-white"
            >
              <div className="flex h-[42px] items-center gap-2 border-b border-white/10 px-4 text-[12px] font-semibold text-muted">
                <span className="h-[11px] w-[18px] rounded-b-[5px] border border-white/15 border-t-0 bg-black" />
                Dashboard
              </div>
              <div className="grid flex-1 grid-cols-[1fr_1.25fr_1fr]">
                <Cell label="Clock">
                  <div className="text-[26px] font-bold tracking-tight">{clock}</div>
                  <div className="text-[11px] text-muted">Friday · 26 June</div>
                </Cell>
                <Cell label="Agent · 2 running">
                  <Lane title="Editing ActivityStore.swift" id="#a1b2" />
                  <Lane title="Running tests · pytest" id="#9f3c" d=".5s" />
                </Cell>
                <Cell label="System" last>
                  <Spark />
                  <div className="flex h-6 items-end gap-[3px]">
                    {[0, 0.15, 0.3, 0.45, 0.6].map((d, k) => (
                      <span
                        key={k}
                        className="w-1 animate-eq rounded-sm bg-pulse"
                        style={{ animationDelay: `${d}s` }}
                      />
                    ))}
                  </div>
                </Cell>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>
    </div>
  );
}

function Cell({ label, children, last }: { label: string; children: React.ReactNode; last?: boolean }) {
  return (
    <div className={`flex flex-col gap-[7px] px-[14px] py-3 text-left ${last ? "" : "border-r border-white/10"}`}>
      <span className="font-mono text-[9px] uppercase tracking-[.12em] text-faint">{label}</span>
      {children}
    </div>
  );
}

function Lane({ title, id, d = "0s" }: { title: string; id: string; d?: string }) {
  return (
    <div className="flex items-start gap-[7px]">
      <span
        className="mt-1 h-[7px] w-[7px] animate-blink rounded-full bg-pulse shadow-[0_0_8px_var(--pulse)]"
        style={{ animationDelay: d, animationDuration: "1.4s" }}
      />
      <div>
        <div className="text-[12px] font-semibold leading-tight">{title}</div>
        <div className="text-[10px] text-muted">
          Claude Code <span className="font-mono text-faint">{id}</span>
        </div>
      </div>
    </div>
  );
}

function Spark() {
  const n = 22;
  const pts = Array.from({ length: n }, (_, i) => 8 + Math.sin(i * 0.6) * 5 + (i > 14 ? i - 14 : 0) + Math.random() * 3);
  const d = pts.map((v, i) => `${i ? "L" : "M"}${((i / (n - 1)) * 120).toFixed(1)},${(34 - v).toFixed(1)}`).join(" ");
  return (
    <svg className="h-[34px] w-full" viewBox="0 0 120 34" preserveAspectRatio="none">
      <path d={`${d} L120,34 L0,34 Z`} fill="rgba(61,224,192,.18)" />
      <path d={d} fill="none" stroke="#3DE0C0" strokeWidth="1.6" strokeLinejoin="round" />
    </svg>
  );
}
