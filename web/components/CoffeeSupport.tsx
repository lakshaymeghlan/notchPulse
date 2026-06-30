"use client";
import { motion } from "framer-motion";
import CoffeeButton from "./CoffeeButton";
import { TIERS } from "@/lib/site";

/** The free-app "wishlist": a deliberately absurd, escalating set of gifts. */
export default function CoffeeSupport() {
  return (
    <div>
      <div className="mx-auto mb-12 max-w-[640px] text-center">
        <span className="idx">The pitch</span>
        <h2 className="mt-3 text-balance font-display text-[clamp(34px,5vw,60px)] font-semibold leading-[.98] tracking-tightest">
          It&rsquo;s free. My wishlist isn&rsquo;t.
        </h2>
        <p className="mx-auto mt-5 max-w-[48ch] text-[17px] leading-relaxed text-ink2">
          NotchPulse costs you nothing — download it, keep it forever, get every update. But if it saved you a glance
          (or your sanity), here&rsquo;s my completely reasonable list of things you could get me. No pressure. I&rsquo;ll just
          be refreshing my bank app.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {TIERS.map((t, i) => (
          <motion.div
            key={t.title}
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.3 }}
            transition={{ duration: 0.5, delay: (i % 3) * 0.06, ease: [0.16, 1, 0.3, 1] }}
            whileHover={{ y: -4 }}
            className={`group relative flex flex-col rounded-3xl glass p-7 ${i === 4 ? "sm:col-span-2 lg:col-span-1" : ""}`}
          >
            <div className="flex items-start justify-between">
              <span className="text-[40px] leading-none transition-transform duration-300 group-hover:scale-110 group-hover:-rotate-6">{t.emoji}</span>
              <span className="font-mono text-[13px] text-ink2 tabular-nums">{t.amount}</span>
            </div>
            <h3 className="mt-5 font-display text-[20px] font-semibold tracking-tight">{t.title}</h3>
            <p className="mt-1.5 flex-1 text-[14px] leading-relaxed text-ink2">{t.note}</p>
            <CoffeeButton href={t.url} className="mt-5 justify-center px-5 py-3 text-[14px]">
              Gift this →
            </CoffeeButton>
          </motion.div>
        ))}
      </div>

      <p className="mt-8 text-center font-mono text-[12.5px] text-faint">
        Secure payments via Razorpay · India &amp; international · UPI, cards &amp; more · seriously, the app is free
      </p>
    </div>
  );
}
