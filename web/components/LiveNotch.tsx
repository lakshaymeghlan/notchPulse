"use client";
import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import MagneticButton from "./MagneticButton";
import { DOWNLOAD_URL } from "@/lib/site";

const LOCAL = "http://localhost:7842";

type State = "checking" | "live" | "absent";

export default function LiveNotch() {
  const [state, setState] = useState<State>("checking");
  const [busy, setBusy] = useState(false);
  const [pinged, setPinged] = useState(false);

  async function detect() {
    try {
      const c = new AbortController();
      const t = setTimeout(() => c.abort(), 1200);
      const r = await fetch(`${LOCAL}/ping`, { signal: c.signal });
      clearTimeout(t);
      setState(r.ok ? "live" : "absent");
    } catch {
      setState("absent");
    }
  }
  useEffect(() => {
    detect();
  }, []);

  async function ping() {
    setBusy(true);
    const post = (body: object) =>
      fetch(`${LOCAL}/event`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      }).catch(() => {});
    await post({ event: "start", id: "web", title: "Hello from notchpulse.app 👋", source: "Website", detail: "your notch reacted to a click on the site", progress: 0.4 });
    setPinged(true);
    setTimeout(() => post({ event: "progress", id: "web", progress: 0.8, detail: "still you, on the website" }), 1200);
    setTimeout(() => post({ event: "complete", id: "web", detail: "neat, right?" }), 2600);
    setTimeout(() => setBusy(false), 2800);
  }

  return (
    <div className="overflow-hidden rounded-3xl glass p-9 sm:p-12">
      <div className="flex flex-col items-start gap-6 md:flex-row md:items-center md:justify-between">
        <div>
          <span className="idx flex items-center gap-2">
            <span className={`inline-block h-1.5 w-1.5 rounded-full ${state === "live" ? "bg-[#1FBF75]" : "bg-faint"}`} style={state === "live" ? { boxShadow: "0 0 8px #1FBF75" } : undefined} />
            {state === "checking" ? "Looking for your Mac…" : state === "live" ? "NotchPulse is live on this Mac" : "NotchPulse isn't running here"}
          </span>
          <h2 className="mt-3 max-w-[20ch] text-balance font-display text-[clamp(28px,4vw,46px)] font-semibold leading-[1.02] tracking-tight">
            {state === "live" ? "Watch this page reach into your notch." : "A website that talks to your notch."}
          </h2>
          <p className="mt-4 max-w-[46ch] text-[16px] leading-relaxed text-ink2">
            {state === "live"
              ? "You've got it running. Press the button and your real menu-bar notch will light up — fired straight from this page."
              : "Once NotchPulse is running, this very button makes your real notch react — a marketing page that controls the app you installed. Download it, then come back."}
          </p>
        </div>

        <div className="flex flex-none flex-col items-stretch gap-3">
          {state === "live" ? (
            <motion.button
              onClick={ping}
              disabled={busy}
              whileTap={{ scale: 0.96 }}
              className="inline-flex items-center justify-center gap-2 rounded-full bg-ink px-7 py-4 text-[16px] font-medium text-paper disabled:opacity-60"
            >
              {busy ? "Look up at your notch ↑" : "Ping my notch ↑"}
            </motion.button>
          ) : (
            <MagneticButton href={DOWNLOAD_URL} download className="px-7 py-4 text-[16px]">
              ↓ Download to try it
            </MagneticButton>
          )}
          {pinged && state === "live" && (
            <span className="text-center font-mono text-[12px] text-ink2">sent ✓ — check the top of your screen</span>
          )}
          {state === "absent" && (
            <button onClick={() => { setState("checking"); detect(); }} className="text-center font-mono text-[12px] text-faint underline underline-offset-4">
              re-check
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
