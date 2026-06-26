import Nav, { Mark } from "@/components/Nav";
import NotchScroll from "@/components/NotchScroll";
import Pulse from "@/components/Pulse";
import Reveal from "@/components/Reveal";
import WordsUp from "@/components/WordsUp";
import MagneticButton from "@/components/MagneticButton";
import CoffeeSupport from "@/components/CoffeeSupport";
import { COFFEE_URL, DOWNLOAD_URL } from "@/lib/site";

const FEATURES = [
  { i: "01", k: "Live", t: "Agents you can watch", d: "Every Claude Code session gets its own lane — the task it's on, live progress, and a clear ✓ or ✗ when it lands. Run two at once and you see both, tagged by session." },
  { i: "02", k: "Ask", t: "Claude, in the strip", d: "Type a question or summarize your clipboard and get an answer in place — powered by your own Claude. No tab, no second login." },
  { i: "03", k: "Glance", t: "The essentials, always up", d: "A clock, a battery ring, live CPU and memory traces, and now-playing with album art — the things you keep checking, where your eyes already are." },
  { i: "04", k: "Reach", t: "Every window, one move", d: "Jump to any open window across every Space and display from one place. Your apps, a click away." },
  { i: "05", k: "Studio", t: "Read, record, focus", d: "A teleprompter you read straight down the lens, a live camera mirror, and a Pomodoro timer with a quiet chime." },
  { i: "06", k: "Yours", t: "Built to your shape", d: "Compose your own pages, drag widgets into order, choose an accent, switch on frosted glass. It becomes the instrument you want." },
];

export default function Page() {
  return (
    <>
      <Nav />
      <main id="top">
        {/* HERO */}
        <header className="px-6 pt-40 pb-10">
          <div className="mx-auto max-w-content">
            <Reveal>
              <div className="idx flex items-center gap-3">
                <span className="inline-flex items-center gap-2">
                  <span className="inline-block h-1.5 w-1.5 rounded-full" style={{ background: "var(--live)", boxShadow: "0 0 6px var(--live)" }} />
                  NotchPulse
                </span>
                <span className="text-faint">— a precision instrument for macOS</span>
              </div>
            </Reveal>
            <h1 className="mt-6 max-w-[14ch] font-display text-[clamp(52px,9vw,120px)] font-semibold leading-[.92] tracking-tightest">
              <WordsUp text="Your notch, alive." delay={0.15} />
            </h1>
            <Reveal delay={0.12}>
              <p className="mt-7 max-w-[52ch] text-[clamp(17px,2vw,21px)] leading-relaxed text-ink2">
                The dark strip around your camera has done nothing for years. NotchPulse turns it into a living readout —
                watch your AI agents work, glance at what matters, and ask Claude without leaving the screen you&rsquo;re on.
              </p>
            </Reveal>
            <Reveal delay={0.18}>
              <div className="mt-9 flex flex-wrap items-center gap-4">
                <MagneticButton href={DOWNLOAD_URL} external className="px-6 py-3.5 text-[15px]">
                  Download — it&rsquo;s free
                </MagneticButton>
                <a href={COFFEE_URL} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-2 text-[15px] text-ink underline decoration-line2 decoration-1 underline-offset-[6px] hover:decoration-ink">
                  ☕ Buy me a coffee
                </a>
                <span className="font-mono text-[12.5px] text-faint">macOS 14+ · ~6&nbsp;MB · no account</span>
              </div>
            </Reveal>
          </div>

          <Reveal delay={0.24} className="mx-auto mt-16 max-w-content">
            <div className="border-y border-line2">
              <Pulse height={130} />
            </div>
          </Reveal>
        </header>

        {/* TOUR — scroll-scrubbed notch */}
        <div id="tour">
          <NotchScroll />
        </div>

        {/* FEATURES — editorial index */}
        <section id="features" className="px-6 py-28">
          <div className="mx-auto max-w-content">
            <Reveal>
              <div className="flex items-end justify-between gap-6 border-b border-line2 pb-6">
                <h2 className="max-w-[18ch] text-balance font-display text-[clamp(30px,4.6vw,52px)] font-semibold leading-[1.02] tracking-tight">
                  Everything you keep glancing at, in one quiet strip.
                </h2>
                <span className="idx hidden whitespace-nowrap pb-2 sm:block">Six things it does</span>
              </div>
            </Reveal>

            <div>
              {FEATURES.map((f, n) => (
                <Reveal key={f.i} delay={(n % 2) * 0.05}>
                  <article className="grid grid-cols-1 items-baseline gap-y-3 border-b border-line2 py-9 md:grid-cols-[120px_1fr_1.1fr] md:gap-x-10">
                    <div className="idx pt-1">{f.i} / {f.k}</div>
                    <h3 className="font-display text-[clamp(22px,2.6vw,30px)] font-medium tracking-tight">{f.t}</h3>
                    <p className="max-w-[52ch] text-[16px] leading-relaxed text-ink2">{f.d}</p>
                  </article>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* HOW */}
        <section id="how" className="border-y border-line2 bg-paper2/40 px-6 py-28">
          <div className="mx-auto max-w-content">
            <Reveal>
              <span className="idx">Setup</span>
              <h2 className="mt-3 max-w-[20ch] text-balance font-display text-[clamp(28px,4.2vw,46px)] font-semibold leading-[1.04] tracking-tight">
                It sits silent — until your tools have something to say.
              </h2>
            </Reveal>
            <div className="mt-14 grid grid-cols-1 gap-px overflow-hidden rounded-2xl border border-line2 bg-line2 md:grid-cols-3">
              {[
                { n: "1", t: "Install & launch", d: "A tiny menu-bar app — no Dock icon, no account. The notch stays black until something happens." },
                { n: "2", t: "Connect Claude Code", d: "Add one hook line. Every session you run lights up the notch, automatically." },
                { n: "3", t: "Wire up anything", d: "Builds, CI, scripts — anything that can POST to a local port shows up as a live activity." },
              ].map((s) => (
                <div key={s.n} className="bg-card p-8">
                  <div className="font-mono text-[13px] text-live">0{s.n}</div>
                  <h3 className="mt-5 font-display text-[20px] font-medium tracking-tight">{s.t}</h3>
                  <p className="mt-2 text-[15px] leading-relaxed text-ink2">{s.d}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* SUPPORT — buy me a coffee */}
        <section id="support" className="px-6 py-28">
          <div className="mx-auto max-w-content">
            <CoffeeSupport />
          </div>
        </section>

        {/* UPDATES */}
        <section id="updates" className="border-t border-line2 px-6 py-24">
          <div className="mx-auto max-w-content">
            <Reveal>
              <span className="idx">Roadmap</span>
              <h2 className="mt-3 font-display text-[clamp(26px,3.6vw,40px)] font-semibold tracking-tight">Updates land here.</h2>
            </Reveal>
            <div className="mt-10">
              {[
                { v: "v1.0", h: "Out now.", r: " Live agents, widgets, Ask Claude, teleprompter, Pomodoro, themes." },
                { v: "Next", h: "Finish alerts.", r: " Notifications and a sound when an agent completes, plus a global hotkey." },
                { v: "Soon", h: "More glances.", r: " Calendar and weather widgets, and VS Code / Cursor / Zed support." },
              ].map((u) => (
                <Reveal key={u.v}>
                  <div className="grid grid-cols-[80px_1fr] gap-5 border-b border-line2 py-5">
                    <span className="font-mono text-[13px] text-live">{u.v}</span>
                    <span className="text-[16px] text-ink2"><b className="font-semibold text-ink">{u.h}</b>{u.r}</span>
                  </div>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        <footer className="px-6 py-16">
          <div className="mx-auto flex max-w-content flex-col items-center gap-3 text-center">
            <div className="flex items-center gap-2.5 font-display text-[18px] font-semibold"><Mark /> NotchPulse</div>
            <div className="text-[13.5px] text-ink2">Your notch, alive · macOS 14+ · free · <a href={COFFEE_URL} target="_blank" rel="noopener noreferrer" className="underline decoration-line2 underline-offset-4 hover:decoration-ink">buy me a coffee ☕</a></div>
            <div className="font-mono text-[12px] text-faint">© 2026 NotchPulse</div>
          </div>
        </footer>
      </main>
    </>
  );
}
