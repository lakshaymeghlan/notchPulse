"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";

type Mode = "idle" | "agent" | "ask" | "music";
const MODES: { id: Mode; label: string }[] = [
  { id: "idle", label: "Idle" },
  { id: "agent", label: "Agent running" },
  { id: "ask", label: "Ask Claude" },
  { id: "music", label: "Now playing" },
];

export default function Playground() {
  const [mode, setMode] = useState<Mode>("agent");
  const [q, setQ] = useState("");
  const [answer, setAnswer] = useState<string | null>(null);

  const expanded = mode !== "idle";

  return (
    <div className="flex flex-col items-center">
      {/* faux screen top with the notch */}
      <div className="relative w-full max-w-[640px] overflow-hidden rounded-t-2xl border border-line2 border-b-0 bg-paper2">
        <div className="flex items-center gap-2 px-4 py-2.5">
          <span className="h-2.5 w-2.5 rounded-full bg-[#FF5F57]" />
          <span className="h-2.5 w-2.5 rounded-full bg-[#FEBC2E]" />
          <span className="h-2.5 w-2.5 rounded-full bg-[#28C840]" />
          <span className="ml-2 font-mono text-[10px] text-faint">your menu bar — try the controls below</span>
        </div>
        {/* the notch hangs from the top center */}
        <div className="flex justify-center pb-10">
          <motion.div
            layout
            transition={{ type: "spring", stiffness: 240, damping: 26 }}
            className="overflow-hidden border border-white/[.06] border-t-0 bg-device text-white shadow-[0_24px_60px_rgba(0,0,0,.3)]"
            style={{
              width: expanded ? 360 : 190,
              height: expanded ? 150 : 34,
              borderBottomLeftRadius: expanded ? 22 : 12,
              borderBottomRightRadius: expanded ? 22 : 12,
            }}
          >
            <AnimatePresence mode="wait">
              {mode === "idle" && <Fade key="i" />}
              {mode === "agent" && (
                <Fade key="a">
                  <Pad>
                    <Cap>Agent · live</Cap>
                    <Lane title="Editing ActivityStore.swift" />
                    <Lane title="Running tests · pytest" delay=".4s" />
                    <Bar />
                  </Pad>
                </Fade>
              )}
              {mode === "ask" && (
                <Fade key="q">
                  <Pad>
                    <Cap>Ask Claude</Cap>
                    <div className="flex items-center gap-2">
                      <input
                        value={q}
                        onChange={(e) => setQ(e.target.value)}
                        onKeyDown={(e) => e.key === "Enter" && setAnswer(reply(q))}
                        placeholder="Ask anything…"
                        className="w-full rounded-md bg-white/10 px-2.5 py-1.5 text-[12px] text-white outline-none placeholder:text-white/40"
                      />
                      <button onClick={() => setAnswer(reply(q))} className="rounded-md bg-white/15 px-2 py-1.5 text-[12px]">↑</button>
                    </div>
                    <div className="mt-1 text-[11px] leading-snug text-white/70">{answer ?? "Type a question and hit ↑ — your own Claude answers here."}</div>
                  </Pad>
                </Fade>
              )}
              {mode === "music" && (
                <Fade key="m">
                  <Pad>
                    <Cap>Now playing</Cap>
                    <div className="flex items-center gap-2.5">
                      <div className="h-8 w-8 rounded-md" style={{ background: "linear-gradient(135deg,#5b9dff,#b06aff)" }} />
                      <div className="min-w-0">
                        <div className="truncate text-[12px] font-semibold">Midnight City</div>
                        <div className="text-[10px] text-white/55">M83</div>
                      </div>
                      <div className="ml-auto flex h-5 items-end gap-[3px]">
                        {[0, .15, .3, .45].map((d, k) => <span key={k} className="w-1 rounded-sm bg-white/80" style={{ animation: `pgeq 1s ease-in-out ${d}s infinite` }} />)}
                      </div>
                    </div>
                  </Pad>
                </Fade>
              )}
            </AnimatePresence>
          </motion.div>
        </div>
      </div>

      {/* controls */}
      <div className="mt-5 flex flex-wrap justify-center gap-2">
        {MODES.map((m) => (
          <button
            key={m.id}
            onClick={() => { setMode(m.id); setAnswer(null); }}
            className={`rounded-full px-4 py-2 text-[13px] font-medium transition-colors ${
              mode === m.id ? "bg-ink text-paper" : "border border-line2 text-ink2 hover:text-ink"
            }`}
          >
            {m.label}
          </button>
        ))}
      </div>
      <style>{`@keyframes pgeq{0%,100%{height:5px}50%{height:18px}}`}</style>
    </div>
  );
}

function Fade({ children }: { children?: React.ReactNode }) {
  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: 0.25 }} className="h-full">
      {children}
    </motion.div>
  );
}
function Pad({ children }: { children: React.ReactNode }) {
  return <div className="flex h-full flex-col gap-2 p-3.5">{children}</div>;
}
function Cap({ children }: { children: React.ReactNode }) {
  return <span className="font-mono text-[9px] uppercase tracking-[.12em] text-white/35">{children}</span>;
}
function Lane({ title, delay = "0s" }: { title: string; delay?: string }) {
  return (
    <div className="flex items-center gap-2">
      <span className="h-1.5 w-1.5 rounded-full bg-[#3DE0C0]" style={{ animation: `pgblink 1.4s infinite`, animationDelay: delay }} />
      <span className="truncate text-[12px] font-medium text-white/90">{title}</span>
      <style>{`@keyframes pgblink{0%,100%{opacity:1}50%{opacity:.3}}`}</style>
    </div>
  );
}
function Bar() {
  return (
    <div className="mt-1 h-1 w-full overflow-hidden rounded-full bg-white/10">
      <motion.div className="h-full rounded-full bg-[#3DE0C0]" initial={{ width: "10%" }} animate={{ width: "70%" }} transition={{ duration: 2, repeat: Infinity, repeatType: "reverse" }} />
    </div>
  );
}
function reply(q: string) {
  const s = q.trim().toLowerCase();
  if (!s) return "Type a question first 🙂";
  if (s.includes("notch")) return "Your notch becomes a live dashboard — agents, widgets, and quick actions.";
  return "In the real app, your own Claude answers right here. (This is a demo reply.)";
}
