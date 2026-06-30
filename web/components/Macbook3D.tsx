"use client";
import { useRef } from "react";
import { motion, useMotionValue, useSpring, useTransform } from "framer-motion";

/** Pure-CSS 3D MacBook (no model): a real desktop — menu bar, the notch app
 *  expanded, and a dock — on a screen that tilts toward the cursor. */
export default function Macbook3D() {
  const ref = useRef<HTMLDivElement>(null);
  const mx = useMotionValue(0);
  const my = useMotionValue(0);
  const rx = useSpring(useTransform(my, [-0.5, 0.5], [10, -3]), { stiffness: 120, damping: 16 });
  const ry = useSpring(useTransform(mx, [-0.5, 0.5], [-12, 12]), { stiffness: 120, damping: 16 });

  return (
    <div
      ref={ref}
      className="mx-auto w-full max-w-[720px]"
      style={{ perspective: 1600 }}
      onPointerMove={(e) => {
        const r = ref.current!.getBoundingClientRect();
        mx.set((e.clientX - r.left) / r.width - 0.5);
        my.set((e.clientY - r.top) / r.height - 0.5);
      }}
      onPointerLeave={() => { mx.set(0); my.set(0); }}
    >
      <motion.div style={{ rotateX: rx, rotateY: ry, transformStyle: "preserve-3d" }}>
        {/* ===== lid / screen ===== */}
        <div className="rounded-[22px] bg-[#0c0d10] p-[12px] shadow-[0_60px_140px_rgba(0,0,0,.45)] ring-1 ring-white/10">
          <div
            className="relative overflow-hidden rounded-[12px]"
            style={{
              aspectRatio: "16 / 10.3",
              background:
                "radial-gradient(120% 120% at 50% -10%, #36406a 0%, #1a1d2b 45%, #0c0e16 100%)",
            }}
          >
            {/* desktop sheen */}
            <div className="pointer-events-none absolute inset-0" style={{ background: "radial-gradient(50% 40% at 25% 12%, rgba(120,150,255,.22), transparent), radial-gradient(45% 35% at 82% 22%, rgba(180,120,255,.16), transparent)" }} />

            {/* menu bar */}
            <div className="absolute inset-x-0 top-0 z-10 flex h-[26px] items-center justify-between px-3 text-[9px] font-medium text-white/80 backdrop-blur-md" style={{ background: "rgba(0,0,0,.18)" }}>
              <div className="flex items-center gap-3">
                <span className="inline-block h-2.5 w-2.5 rounded-full bg-white/85" />
                <span className="font-semibold">NotchPulse</span>
                <span className="hidden text-white/55 sm:inline">File</span>
                <span className="hidden text-white/55 sm:inline">Edit</span>
                <span className="hidden text-white/55 sm:inline">View</span>
              </div>
              <div className="flex items-center gap-2.5 text-white/75">
                {/* wifi */}
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M5 12.5a10 10 0 0 1 14 0M8 16a5 5 0 0 1 8 0" /><circle cx="12" cy="19.5" r=".6" fill="currentColor" /></svg>
                {/* battery */}
                <svg width="20" height="13" viewBox="0 0 26 14" fill="none" stroke="currentColor" strokeWidth="1.4"><rect x="1" y="2" width="20" height="10" rx="2.5" /><rect x="3" y="4" width="13" height="6" rx="1" fill="currentColor" stroke="none" /><rect x="23" y="5" width="2" height="4" rx="1" fill="currentColor" stroke="none" /></svg>
                <span className="tabular-nums">2:08</span>
              </div>
            </div>

            {/* the notch app, expanded — top flush, hanging from the bezel */}
            <div className="absolute left-1/2 top-0 z-20 w-[58%] -translate-x-1/2 overflow-hidden rounded-b-[18px] bg-black text-white shadow-[0_20px_50px_rgba(0,0,0,.5)]">
              <div className="flex h-7 items-center justify-center gap-1.5 text-[9px] font-semibold text-white/55">
                <span className="h-1.5 w-1.5 rounded-full" style={{ background: "var(--live)", boxShadow: "0 0 8px var(--live)" }} />
                Dashboard
              </div>
              <div className="grid grid-cols-3 border-t border-white/10 text-left">
                <Cell><Cap>Clock</Cap><div className="font-display text-[16px] font-semibold leading-none">2:08</div></Cell>
                <Cell mid><Cap>Agent</Cap><div className="flex items-center gap-1.5"><span className="h-1.5 w-1.5 rounded-full bg-[#3DE0C0]" style={{ animation: "mbblink 1.4s infinite" }} /><span className="text-[10px] font-medium">running</span></div><div className="truncate text-[9px] text-white/50">editing ActivityStore</div></Cell>
                <Cell><Cap>Sys</Cap><div className="flex h-4 items-end gap-[2px]">{[0, .12, .24, .36, .48].map((d, k) => <span key={k} className="w-[3px] rounded-sm bg-white/80" style={{ animation: `mbeq 1s ease-in-out ${d}s infinite` }} />)}</div></Cell>
              </div>
            </div>

            {/* dock — glassy bar, colorful app icons, hover bounce */}
            <div
              className="absolute bottom-2.5 left-1/2 z-10 flex -translate-x-1/2 items-end gap-[7px] rounded-[16px] px-2.5 py-2 backdrop-blur-xl"
              style={{
                background: "rgba(255,255,255,.16)",
                border: "1px solid rgba(255,255,255,.28)",
                boxShadow: "inset 0 1px 0 rgba(255,255,255,.4), 0 12px 30px rgba(0,0,0,.35)",
              }}
            >
              {DOCK.map((d, i) => (
                <span key={i} className="group/icon relative">
                  <span
                    className="flex h-7 w-7 items-center justify-center rounded-[8px] text-[14px] leading-none shadow-[0_3px_6px_rgba(0,0,0,.3)] transition-transform duration-200 ease-out group-hover/icon:-translate-y-2 group-hover/icon:scale-125"
                    style={{ background: d.bg }}
                  >
                    <span className="opacity-95">{d.g}</span>
                    {/* glossy top highlight */}
                    <span className="pointer-events-none absolute inset-x-[2px] top-[2px] h-1/3 rounded-t-[6px] bg-white/25" />
                  </span>
                  {d.dot && <span className="absolute -bottom-1 left-1/2 h-[3px] w-[3px] -translate-x-1/2 rounded-full bg-white/80" />}
                </span>
              ))}
            </div>
          </div>
        </div>

        {/* ===== hinge + base ===== */}
        <div className="relative mx-auto h-[10px] w-[106%] -translate-x-[2.8%] rounded-b-[6px] bg-gradient-to-b from-[#3a3c42] to-[#26272c]" />
        <div className="relative mx-auto h-[12px] w-[112%] -translate-x-[5.4%] rounded-b-[16px] bg-gradient-to-b from-[#d6d9de] via-[#b9bcc2] to-[#9a9da4] shadow-[0_30px_50px_rgba(0,0,0,.25)]">
          <div className="absolute left-1/2 top-0 h-[7px] w-24 -translate-x-1/2 rounded-b-[10px] bg-black/10" />
        </div>
      </motion.div>

      <style>{`@keyframes mbeq{0%,100%{height:4px}50%{height:15px}}@keyframes mbblink{0%,100%{opacity:1}50%{opacity:.3}}`}</style>
    </div>
  );
}

const DOCK: { bg: string; g: string; dot?: boolean }[] = [
  { bg: "linear-gradient(160deg,#4aa3ff,#1f6fe0)", g: "🧭" }, // Safari
  { bg: "linear-gradient(160deg,#3ad15f,#1e9e44)", g: "💬" }, // Messages
  { bg: "linear-gradient(160deg,#ff7a5a,#ff4d6d)", g: "🎵" }, // Music
  { bg: "linear-gradient(160deg,#c07bff,#7a4dff)", g: "📷" }, // Photos
  { bg: "linear-gradient(160deg,#ffd64a,#ffb300)", g: "🗒️" }, // Notes
  { bg: "linear-gradient(160deg,#2ccfcf,#0e9aa0)", g: "📅" }, // Calendar
  { bg: "linear-gradient(160deg,#0e0f12,#000)", g: "✦", dot: true }, // NotchPulse
  { bg: "linear-gradient(160deg,#9aa0aa,#5b626d)", g: "⚙️" }, // Settings
];

function Cell({ children, mid }: { children: React.ReactNode; mid?: boolean }) {
  return <div className={`flex flex-col gap-1 px-2.5 py-2 ${mid ? "border-x border-white/10" : ""}`}>{children}</div>;
}
function Cap({ children }: { children: React.ReactNode }) {
  return <span className="font-mono text-[7px] uppercase tracking-[.12em] text-white/35">{children}</span>;
}
