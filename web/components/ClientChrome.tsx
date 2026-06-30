"use client";
import { useEffect, useRef, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { loadSound, soundOn, tick } from "@/lib/sound";
import { Mark } from "./Nav";
import { SUPPORT_URL } from "@/lib/site";

/** Site-wide interactive chrome: cinematic intro, custom cursor, section rail,
 *  ⌘K command palette, and click sounds. All respect reduced-motion. */
export default function ClientChrome() {
  const reduce = typeof window !== "undefined" && matchMedia("(prefers-reduced-motion: reduce)").matches;
  useEffect(() => {
    loadSound();
    const onClick = (e: MouseEvent) => {
      const el = (e.target as HTMLElement)?.closest("a,button");
      if (el && soundOn()) tick(560, 0.03);
    };
    addEventListener("click", onClick);
    return () => removeEventListener("click", onClick);
  }, []);
  return (
    <>
      {!reduce && <Cursor />}
      <SectionRail />
      <CommandPalette />
      <Intro />
    </>
  );
}

/* ---------- cinematic intro ---------- */
function Intro() {
  const [done, setDone] = useState(false);
  useEffect(() => {
    if (sessionStorage.getItem("np-intro") || matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setDone(true);
      return;
    }
    const t = setTimeout(() => {
      setDone(true);
      sessionStorage.setItem("np-intro", "1");
    }, 1500);
    return () => clearTimeout(t);
  }, []);
  return (
    <AnimatePresence>
      {!done && (
        <motion.div
          className="fixed inset-0 z-[200] flex items-center justify-center bg-paper"
          initial={{ opacity: 1 }}
          exit={{ y: "-100%" }}
          transition={{ duration: 0.8, ease: [0.76, 0, 0.24, 1] }}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            className="flex items-center gap-3 font-display text-[26px] font-semibold tracking-tight"
          >
            <Mark size={28} /> NotchPulse
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

/* ---------- custom cursor + soft spotlight ---------- */
function Cursor() {
  const dot = useRef<HTMLDivElement>(null);
  const ring = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (matchMedia("(pointer: coarse)").matches) return;
    let rx = innerWidth / 2, ry = innerHeight / 2, x = rx, y = ry, raf = 0;
    const move = (e: PointerEvent) => {
      x = e.clientX; y = e.clientY;
      if (dot.current) dot.current.style.transform = `translate(${x}px,${y}px)`;
    };
    const loop = () => {
      rx += (x - rx) * 0.18; ry += (y - ry) * 0.18;
      if (ring.current) ring.current.style.transform = `translate(${rx}px,${ry}px)`;
      raf = requestAnimationFrame(loop);
    };
    addEventListener("pointermove", move, { passive: true });
    raf = requestAnimationFrame(loop);
    const over = (e: MouseEvent) => {
      const hit = (e.target as HTMLElement)?.closest("a,button,[role=button]");
      ring.current?.classList.toggle("cursor-ring--hot", !!hit);
    };
    addEventListener("pointerover", over);
    return () => { removeEventListener("pointermove", move); removeEventListener("pointerover", over); cancelAnimationFrame(raf); };
  }, []);
  return (
    <div className="pointer-events-none fixed inset-0 z-[150] hidden md:block">
      <div ref={ring} className="cursor-ring absolute -ml-4 -mt-4 h-8 w-8 rounded-full border border-ink/30 transition-[width,height,background] duration-200" />
      <div ref={dot} className="absolute -ml-1 -mt-1 h-2 w-2 rounded-full bg-ink" />
    </div>
  );
}

/* ---------- right-side section rail ---------- */
const SECTIONS = [
  { id: "top", label: "Top" },
  { id: "tour", label: "Tour" },
  { id: "live", label: "Live" },
  { id: "features", label: "Features" },
  { id: "support", label: "Support" },
  { id: "faq", label: "FAQ" },
];
function SectionRail() {
  const [active, setActive] = useState("top");
  useEffect(() => {
    const io = new IntersectionObserver(
      (es) => es.forEach((e) => e.isIntersecting && setActive(e.target.id)),
      { rootMargin: "-45% 0px -45% 0px" }
    );
    SECTIONS.forEach((s) => { const el = document.getElementById(s.id); if (el) io.observe(el); });
    return () => io.disconnect();
  }, []);
  return (
    <div className="fixed right-6 top-1/2 z-40 hidden -translate-y-1/2 flex-col items-end gap-3 lg:flex">
      {SECTIONS.map((s) => (
        <a key={s.id} href={`#${s.id}`} className="group flex items-center gap-2.5" aria-label={s.label}>
          <span className={`font-mono text-[10px] uppercase tracking-[.12em] transition-opacity ${active === s.id ? "text-ink opacity-100" : "text-faint opacity-0 group-hover:opacity-100"}`}>{s.label}</span>
          <span className={`h-1.5 rounded-full transition-all ${active === s.id ? "w-6 bg-ink" : "w-1.5 bg-ink/25 group-hover:bg-ink/50"}`} />
        </a>
      ))}
    </div>
  );
}

/* ---------- ⌘K command palette ---------- */
const COMMANDS = [
  { label: "Download NotchPulse", hint: "free", href: "/downloads/NotchPulse.zip", download: true },
  { label: "Support NotchPulse", hint: "tip", href: SUPPORT_URL, external: true },
  { label: "Take the tour", href: "#tour" },
  { label: "Make my notch react", href: "#live" },
  { label: "Features", href: "#features" },
  { label: "FAQ", href: "#faq" },
  { label: "Changelog", href: "/changelog" },
];
function CommandPalette() {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") { e.preventDefault(); setOpen((o) => !o); }
      if (e.key === "Escape") setOpen(false);
    };
    addEventListener("keydown", onKey);
    return () => removeEventListener("keydown", onKey);
  }, []);
  const items = COMMANDS.filter((c) => c.label.toLowerCase().includes(q.toLowerCase()));
  return (
    <AnimatePresence>
      {open && (
        <motion.div className="fixed inset-0 z-[180] flex items-start justify-center px-4 pt-[18vh]" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
          <div className="absolute inset-0 bg-ink/10 backdrop-blur-sm" onClick={() => setOpen(false)} />
          <motion.div initial={{ scale: 0.96, y: 8 }} animate={{ scale: 1, y: 0 }} exit={{ scale: 0.97, y: 6 }} transition={{ duration: 0.18 }} className="relative w-full max-w-[520px] overflow-hidden rounded-2xl glass">
            <input autoFocus value={q} onChange={(e) => setQ(e.target.value)} placeholder="Type a command…" className="w-full bg-transparent px-5 py-4 text-[15px] text-ink outline-none placeholder:text-faint" />
            <div className="max-h-[320px] overflow-y-auto border-t border-line2">
              {items.map((c) => (
                <a key={c.label} href={c.href} download={(c as any).download ? "" : undefined} target={(c as any).external ? "_blank" : undefined} rel={(c as any).external ? "noopener noreferrer" : undefined} onClick={() => setOpen(false)} className="flex items-center justify-between px-5 py-3 text-[14.5px] text-ink hover:bg-ink/[.05]">
                  <span>{c.label}</span>
                  {c.hint && <span className="font-mono text-[11px] text-faint">{c.hint}</span>}
                </a>
              ))}
              {items.length === 0 && <div className="px-5 py-4 text-[14px] text-faint">No matches.</div>}
            </div>
            <div className="flex items-center justify-between border-t border-line2 px-5 py-2.5 font-mono text-[11px] text-faint">
              <span>NotchPulse</span><span>esc to close</span>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
