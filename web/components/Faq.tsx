"use client";
import { useState } from "react";
import { AnimatePresence, motion } from "framer-motion";

const ITEMS = [
  { q: "Is it really free?", a: "Yes — download it, keep it forever, get every update. If it earns a place in your menu bar, you can buy me a coffee. No subscription, no account, no catch." },
  { q: "How does it know my Claude Code is running?", a: "NotchPulse runs a tiny local server. A one-line hook in Claude Code posts events to it as your session works — start, progress, finish — and the notch reflects them live. Anything else that can POST locally (builds, CI, scripts) works too." },
  { q: "Does it send my data anywhere?", a: "No. Everything stays on your Mac. The server only listens on localhost (127.0.0.1) and there's no analytics or account." },
  { q: "What about Macs without a notch?", a: "It still works — on a non-notched Mac the surface sits as a floating pill at the top-center of your screen." },
  { q: "The download says it's from an unidentified developer.", a: "Until notarization ships, right-click the app and choose Open the first time (System Settings → Privacy & Security will also offer an Open Anyway button). After that it launches normally." },
  { q: "Which Macs are supported?", a: "macOS 14 (Sonoma) and later, on both Apple Silicon and Intel. The app is about 6 MB." },
];

export default function Faq() {
  const [open, setOpen] = useState<number | null>(0);
  return (
    <div className="overflow-hidden rounded-3xl glass">
      {ITEMS.map((it, i) => {
        const isOpen = open === i;
        return (
          <div key={i} className={i ? "border-t border-line2" : ""}>
            <button
              onClick={() => setOpen(isOpen ? null : i)}
              className="flex w-full items-center justify-between gap-6 px-7 py-5 text-left"
              aria-expanded={isOpen}
            >
              <span className="font-display text-[18px] font-medium tracking-tight text-ink">{it.q}</span>
              <motion.span animate={{ rotate: isOpen ? 45 : 0 }} transition={{ duration: 0.25 }} className="text-[22px] font-light text-ink2">
                +
              </motion.span>
            </button>
            <AnimatePresence initial={false}>
              {isOpen && (
                <motion.div
                  initial={{ height: 0, opacity: 0 }}
                  animate={{ height: "auto", opacity: 1 }}
                  exit={{ height: 0, opacity: 0 }}
                  transition={{ duration: 0.32, ease: [0.16, 1, 0.3, 1] }}
                  className="overflow-hidden"
                >
                  <p className="max-w-[62ch] px-7 pb-6 text-[15.5px] leading-relaxed text-ink2">{it.a}</p>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        );
      })}
    </div>
  );
}
