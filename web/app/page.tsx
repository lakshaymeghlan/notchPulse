import Nav, { Mark } from "@/components/Nav";
import DayScroll from "@/components/DayScroll";
import Playground from "@/components/Playground";
import Macbook3D from "@/components/Macbook3D";
import Reveal from "@/components/Reveal";
import WordsUp from "@/components/WordsUp";
import MagneticButton from "@/components/MagneticButton";
import HeroNotch from "@/components/HeroNotch";
import LiveNotch from "@/components/LiveNotch";
import CoffeeSupport from "@/components/CoffeeSupport";
import CoffeeButton from "@/components/CoffeeButton";
import Faq from "@/components/Faq";
import { DOWNLOAD_URL } from "@/lib/site";

const FEATURES = [
  { i: "01", k: "Live", t: "Agents you can watch", d: "Every Claude Code session gets its own lane — the task it's on, live progress, and a clear ✓ or ✗ when it lands. Run two at once and you see both." },
  { i: "02", k: "Ask", t: "Claude, in the strip", d: "Type a question or summarize your clipboard and get an answer in place — powered by your own Claude. No tab, no second login." },
  { i: "03", k: "Glance", t: "The essentials, always up", d: "A clock, a battery ring, live CPU and memory traces, and now-playing with album art — where your eyes already are." },
  { i: "04", k: "Reach", t: "Every window, one move", d: "Jump to any open window across every Space and display from one place." },
  { i: "05", k: "Studio", t: "Read, record, focus", d: "A teleprompter you read straight down the lens, a live camera mirror, and a Pomodoro timer with a quiet chime." },
  { i: "06", k: "Yours", t: "Built to your shape", d: "Compose your own pages, drag widgets into order, pick an accent, switch on frosted glass." },
];

export default function Page() {
  return (
    <>
      <Nav />
      <main id="top">
        {/* HERO — text + live product */}
        <header className="px-6 pb-24 pt-36">
          <div className="mx-auto grid max-w-content items-center gap-16 lg:grid-cols-[1.05fr_.95fr]">
            <div>
              <Reveal>
                <div className="idx flex items-center gap-2">
                  <span className="inline-block h-1.5 w-1.5 rounded-full" style={{ background: "var(--live)", boxShadow: "0 0 6px var(--live)" }} />
                  NotchPulse — a precision instrument for macOS
                </div>
              </Reveal>
              <h1 className="mt-6 font-display text-[clamp(48px,7.5vw,104px)] font-semibold leading-[.92] tracking-tightest">
                <WordsUp text="Your notch, alive." delay={0.15} />
              </h1>
              <Reveal delay={0.12}>
                <p className="mt-7 max-w-[48ch] text-[clamp(17px,1.6vw,20px)] leading-relaxed text-ink2">
                  The dark strip around your camera has done nothing for years. NotchPulse turns it into a living
                  readout — watch your AI agents work, glance at what matters, and ask Claude without leaving the screen.
                </p>
              </Reveal>
              <Reveal delay={0.18}>
                <div className="mt-9 flex flex-wrap items-center gap-4">
                  <MagneticButton href={DOWNLOAD_URL} download className="px-6 py-3.5 text-[15px]">
                    ↓ Download — it&rsquo;s free
                  </MagneticButton>
                  <a href="#support" className="inline-flex items-center gap-2 text-[15px] text-ink underline decoration-line2 decoration-1 underline-offset-[6px] hover:decoration-ink">
                    Fuel the dev ⚡
                  </a>
                </div>
                <div className="mt-4 font-mono text-[12.5px] text-faint">macOS 14+ · ~6&nbsp;MB · no account · open it from the menu bar</div>
              </Reveal>
            </div>

            <HeroNotch />
          </div>
        </header>

        {/* TOUR — "a day in the notch" scrollytelling */}
        <div id="tour">
          <DayScroll />
        </div>

        {/* PLAYGROUND — drive a simulated notch */}
        <section id="playground" className="px-6 py-24">
          <div className="mx-auto max-w-content">
            <Reveal>
              <div className="mb-10 text-center">
                <span className="idx">Try it here</span>
                <h2 className="mt-3 text-balance font-display text-[clamp(28px,4.2vw,46px)] font-semibold leading-[1.04] tracking-tight">
                  Take the notch for a spin.
                </h2>
                <p className="mx-auto mt-3 max-w-[42ch] text-[16px] text-ink2">No install needed — flip between states and poke at it.</p>
              </div>
            </Reveal>
            <Reveal delay={0.05}>
              <Playground />
            </Reveal>
          </div>
        </section>

        {/* LIVE — the site reaches into your real notch */}
        <section id="live" className="px-6 py-20">
          <div className="mx-auto max-w-content">
            <Reveal>
              <LiveNotch />
            </Reveal>
          </div>
        </section>

        {/* ON YOUR MAC — CSS-3D macbook */}
        <section id="mac" className="overflow-hidden px-6 py-28">
          <div className="mx-auto max-w-content">
            <Reveal>
              <div className="mb-12 text-center">
                <span className="idx">On your Mac</span>
                <h2 className="mt-3 text-balance font-display text-[clamp(28px,4.4vw,50px)] font-semibold leading-[1.02] tracking-tight">
                  It lives where you already look.
                </h2>
              </div>
            </Reveal>
            <Reveal delay={0.05}>
              <Macbook3D />
            </Reveal>
          </div>
        </section>

        {/* FEATURES — editorial index in a glass panel */}
        <section id="features" className="px-6 py-24">
          <div className="mx-auto max-w-content">
            <Reveal>
              <div className="mb-10 flex items-end justify-between gap-6">
                <h2 className="max-w-[18ch] text-balance font-display text-[clamp(30px,4.6vw,52px)] font-semibold leading-[1.02] tracking-tight">
                  Everything you keep glancing at, in one quiet strip.
                </h2>
                <span className="idx hidden whitespace-nowrap pb-2 sm:block">Six things it does</span>
              </div>
            </Reveal>
            <Reveal delay={0.05}>
              <div className="rounded-3xl glass px-6 sm:px-9">
                {FEATURES.map((f, n) => (
                  <article
                    key={f.i}
                    className={`grid grid-cols-1 items-baseline gap-y-2 py-8 md:grid-cols-[120px_1fr_1.1fr] md:gap-x-10 ${n ? "border-t border-line2" : ""}`}
                  >
                    <div className="idx pt-1">{f.i} / {f.k}</div>
                    <h3 className="font-display text-[clamp(21px,2.4vw,28px)] font-medium tracking-tight">{f.t}</h3>
                    <p className="max-w-[52ch] text-[15.5px] leading-relaxed text-ink2">{f.d}</p>
                  </article>
                ))}
              </div>
            </Reveal>
          </div>
        </section>

        {/* HOW */}
        <section id="how" className="px-6 py-24">
          <div className="mx-auto max-w-content">
            <Reveal>
              <span className="idx">Setup</span>
              <h2 className="mt-3 max-w-[20ch] text-balance font-display text-[clamp(28px,4.2vw,46px)] font-semibold leading-[1.04] tracking-tight">
                It sits silent — until your tools have something to say.
              </h2>
            </Reveal>
            <div className="mt-12 grid grid-cols-1 gap-5 md:grid-cols-3">
              {[
                { n: "1", t: "Download & open", d: "A tiny menu-bar app — no Dock icon, no account. Right-click → Open the first time." },
                { n: "2", t: "Connect Claude Code", d: "Add one hook line. Every session you run lights up the notch, automatically." },
                { n: "3", t: "Wire up anything", d: "Builds, CI, scripts — anything that can POST to a local port shows as a live activity." },
              ].map((s) => (
                <Reveal key={s.n}>
                  <div className="h-full rounded-2xl glass p-7">
                    <div className="font-mono text-[13px] text-live">0{s.n}</div>
                    <h3 className="mt-5 font-display text-[20px] font-medium tracking-tight">{s.t}</h3>
                    <p className="mt-2 text-[15px] leading-relaxed text-ink2">{s.d}</p>
                  </div>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* SUPPORT */}
        <section id="support" className="px-6 py-24">
          <div className="mx-auto max-w-content">
            <CoffeeSupport />
          </div>
        </section>

        {/* FAQ */}
        <section id="faq" className="px-6 py-24">
          <div className="mx-auto max-w-content">
            <Reveal>
              <div className="mb-10 text-center">
                <span className="idx">Questions</span>
                <h2 className="mt-3 font-display text-[clamp(28px,4.2vw,46px)] font-semibold tracking-tight">Good to know.</h2>
              </div>
            </Reveal>
            <Reveal delay={0.05}>
              <div className="mx-auto max-w-[760px]">
                <Faq />
              </div>
            </Reveal>
          </div>
        </section>

        {/* CLOSER */}
        <section className="px-6 py-24">
          <Reveal className="mx-auto max-w-content">
            <div className="rounded-[28px] glass px-8 py-16 text-center">
              <h2 className="mx-auto max-w-[16ch] text-balance font-display text-[clamp(30px,5vw,58px)] font-semibold leading-[.98] tracking-tightest">
                Give your notch a job.
              </h2>
              <div className="mt-8 flex flex-wrap items-center justify-center gap-4">
                <MagneticButton href={DOWNLOAD_URL} download className="px-7 py-4 text-[16px]">
                  ↓ Download NotchPulse — free
                </MagneticButton>
                <CoffeeButton className="px-5 py-3.5 text-[15px]" />
              </div>
            </div>
          </Reveal>
        </section>

        <footer className="px-6 py-16">
          <div className="mx-auto flex max-w-content flex-col items-center gap-3 text-center">
            <div className="flex items-center gap-2.5 font-display text-[18px] font-semibold"><Mark /> NotchPulse</div>
            <div className="text-[13.5px] text-ink2">
              Your notch, alive · macOS 14+ · free ·{" "}
              <a href="/changelog" className="underline decoration-line2 underline-offset-4 hover:decoration-ink">changelog</a> ·{" "}
              <a href="#support" className="underline decoration-line2 underline-offset-4 hover:decoration-ink">fuel the dev ⚡</a>
            </div>
            <div className="font-mono text-[12px] text-faint">© 2026 NotchPulse</div>
          </div>
        </footer>
      </main>
    </>
  );
}
