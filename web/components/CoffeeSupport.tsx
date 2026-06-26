"use client";
import { motion } from "framer-motion";
import MagneticButton from "./MagneticButton";
import { COFFEE_URL } from "@/lib/site";

export default function CoffeeSupport() {
  return (
    <div className="grid items-center gap-14 md:grid-cols-2">
      <div>
        <span className="idx">Support</span>
        <h2 className="mt-3 text-balance font-display text-[clamp(34px,5vw,60px)] font-semibold leading-[.98] tracking-tightest">
          Free to use.<br />Powered by coffee.
        </h2>
        <p className="mt-6 max-w-[44ch] text-[17px] leading-relaxed text-ink2">
          NotchPulse costs nothing — download it, keep it forever, get every update. If it earns a spot in your menu bar
          and you want to say thanks, buy me a coffee. That&rsquo;s the whole business model.
        </p>
        <ul className="mt-8 flex flex-wrap gap-x-8 gap-y-2 font-mono text-[13px] text-ink2">
          <li>· no subscription</li>
          <li>· no account</li>
          <li>· no tracking</li>
          <li>· tip if you like it</li>
        </ul>
      </div>

      {/* the cup */}
      <motion.div
        initial={{ opacity: 0, y: 24 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
        className="relative flex flex-col items-center rounded-3xl border border-line2 bg-card px-8 py-12 shadow-[0_30px_80px_rgba(23,24,26,.08)]"
      >
        <Cup />
        <div className="mt-8 text-center font-display text-[20px] font-medium tracking-tight">
          Like it? Buy me a coffee.
        </div>
        <p className="mt-1 text-[14px] text-ink2">A couple bucks keeps the updates coming.</p>
        <MagneticButton
          href={COFFEE_URL}
          external
          variant="ghost"
          className="mt-6 gap-2.5 border-bean/20 bg-coffee px-7 py-3.5 text-[15px] font-semibold text-bean hover:bg-coffee"
        >
          <span className="text-[18px]">☕</span> Buy me a coffee
        </MagneticButton>
      </motion.div>
    </div>
  );
}

function Cup() {
  return (
    <div className="relative h-[120px] w-[150px]">
      {/* steam */}
      <div className="absolute inset-x-0 top-0 flex justify-center gap-3">
        {[0, 0.6, 1.2].map((d, i) => (
          <span
            key={i}
            className="block h-7 w-1.5 rounded-full bg-bean/30 blur-[2px]"
            style={{ animation: `steam 2.6s ease-in-out ${d}s infinite`, transformOrigin: "bottom" }}
          />
        ))}
      </div>
      {/* cup body */}
      <svg viewBox="0 0 150 120" className="absolute bottom-0" width="150" height="100">
        <path d="M22 44 h86 v30 a30 30 0 0 1 -30 30 h-26 a30 30 0 0 1 -30 -30 z" fill="#17181A" />
        <path d="M108 52 h10 a16 16 0 0 1 0 32 h-6" fill="none" stroke="#17181A" strokeWidth="7" />
        <ellipse cx="65" cy="44" rx="43" ry="8" fill="#0B0B0C" />
        <ellipse cx="65" cy="43" rx="34" ry="5" fill="#3A2A1A" />
      </svg>
    </div>
  );
}
