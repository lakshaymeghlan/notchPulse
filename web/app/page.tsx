import Aurora from "@/components/Aurora";
import Nav, { Glyph } from "@/components/Nav";
import NotchDemo from "@/components/NotchDemo";
import Reveal from "@/components/Reveal";
import MagneticButton from "@/components/MagneticButton";
import { BUY_URL, PRICE } from "@/lib/site";

export default function Page() {
  return (
    <>
      <Aurora />
      <Nav />
      <main id="top" className="relative z-[2]">
        {/* HERO */}
        <header className="px-6 pb-16 pt-[150px] text-center">
          <div className="mx-auto max-w-content">
            <div className="eyebrow">For macOS · built for the age of agents</div>
            <h1 className="mx-auto mt-4 text-balance text-[clamp(44px,7.5vw,92px)] font-extrabold leading-[.98] tracking-[-.035em]">
              Your notch,
              <br />
              <span className="bg-gradient-to-r from-white via-pulse to-indigo bg-clip-text text-transparent">
                finally alive.
              </span>
            </h1>
            <p className="mx-auto mt-6 max-w-[600px] text-balance text-[clamp(17px,2.2vw,21px)] text-muted">
              NotchPulse turns the dead space around your MacBook notch into a live surface — watch your Claude Code
              agents work in real time, glance at widgets, and ask Claude anything without leaving what you&rsquo;re doing.
            </p>
            <div className="mt-9 flex flex-wrap justify-center gap-3.5">
              <MagneticButton href="#pricing" className="px-5 py-3 text-[15px]">
                Get NotchPulse <span className="opacity-60 font-medium">· $5 lifetime</span>
              </MagneticButton>
              <MagneticButton href="#features" variant="ghost" className="px-5 py-3 text-[15px]">
                See it work
              </MagneticButton>
            </div>
            <div className="mt-[18px] font-mono text-[12.5px] tracking-[.02em] text-faint">
              macOS 14+ · Apple Silicon &amp; Intel · ~6 MB · no account needed
            </div>
          </div>
          <NotchDemo />
        </header>

        {/* FEATURES */}
        <section id="features" className="px-6 py-24">
          <div className="mx-auto max-w-content">
            <SecHead
              eyebrow="What lives in your notch"
              title="One quiet strip. Everything you keep glancing at."
              sub="Hover to expand into a full dashboard. Leave it, and it melts back into the bezel — pitch black, invisible until you need it."
            />
            <div className="grid grid-cols-1 gap-4 md:grid-cols-6">
              <Card span="md:col-span-4">
                <Glowy />
                <Ic>◐</Ic>
                <H3>See your agents work — live</H3>
                <P>
                  Every Claude Code session shows as its own lane: what it&rsquo;s doing right now, progress, and a ✓ or ✗
                  the moment it finishes. Run two at once? You see both, tagged by session.
                </P>
                <div className="mt-4 rounded-xl border border-white/[.08] bg-black p-3.5 font-mono text-[13px]">
                  <div className="text-pulse">› claude is editing NotchView.swift…</div>
                  <div className="mt-2 text-muted">✓ done · 3 files · tests passed</div>
                </div>
              </Card>
              <Card span="md:col-span-2">
                <Glowy />
                <Ic>✦</Ic>
                <H3>Ask Claude, in the notch</H3>
                <P>Type a question or summarize your clipboard — answered by your own Claude, right here. No tab-switching.</P>
              </Card>

              <Card span="md:col-span-2"><Ic>◴</Ic><H3>Glanceable widgets</H3><P>Clock, battery ring, live CPU/memory graphs, now-playing with album art.</P></Card>
              <Card span="md:col-span-2"><Ic>▦</Ic><H3>Open apps &amp; windows</H3><P>Jump to any window across every Space and display — one click.</P></Card>
              <Card span="md:col-span-2"><Ic>◷</Ic><H3>Focus &amp; Pomodoro</H3><P>A work/break timer with a progress ring and a gentle chime.</P></Card>

              <Card span="md:col-span-3">
                <Glowy />
                <Ic>⛶</Ic><H3>Teleprompter &amp; camera</H3>
                <P>Read a script straight down the lens with a built-in teleprompter and live camera mirror — speed and text size on the fly.</P>
              </Card>
              <Card span="md:col-span-3">
                <Ic>✸</Ic><H3>Make it yours</H3>
                <P>Editable pages, drag-to-arrange widgets, seven accent colors and an optional frosted-glass look.</P>
                <div className="mt-4 flex flex-wrap gap-2">
                  {["Pages you build", "7 accents", "Frosted glass", "Drag & drop shelf"].map((c) => (
                    <span key={c} className="rounded-full border border-white/[.08] bg-white/[.02] px-2.5 py-1.5 font-mono text-[11px] text-muted">{c}</span>
                  ))}
                </div>
              </Card>
            </div>
          </div>
        </section>

        {/* HOW */}
        <section id="how" className="bg-gradient-to-b from-transparent via-indigo/[.04] to-transparent px-6 py-24">
          <div className="mx-auto max-w-content">
            <SecHead eyebrow="Up and running in a minute" title="It just sits there — until your tools have something to say." />
            <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
              <Card><IcNum>1</IcNum><H3>Install &amp; launch</H3><P>A tiny menu-bar app. No Dock icon, no account. The notch stays pitch black until something happens.</P></Card>
              <Card><IcNum>2</IcNum><H3>Connect Claude Code</H3><P>One hook line. Now every session you run lights up the notch — automatically, hands-off.</P></Card>
              <Card><IcNum>3</IcNum><H3>Wire up anything</H3><P>Builds, CI, scripts — anything that can <span className="font-mono text-pulse">POST</span> to a local port appears as a live activity.</P></Card>
            </div>
          </div>
        </section>

        {/* PRICING */}
        <section id="pricing" className="px-6 py-24">
          <div className="mx-auto max-w-content">
            <SecHead
              eyebrow="Launch price"
              title="Pay once. Yours forever."
              sub="No subscription. Every future update — new widgets, new integrations — lands right here at no extra cost."
            />
            <Reveal className="flex justify-center">
              <div className="relative w-[min(440px,100%)] overflow-hidden rounded-3xl border border-white/15 bg-gradient-to-b from-surface2 to-bg2 p-9">
                <div
                  className="pointer-events-none absolute inset-0 rounded-3xl p-px"
                  style={{
                    background: "linear-gradient(140deg,rgba(61,224,192,.6),rgba(110,99,255,.5),transparent 60%)",
                    WebkitMask: "linear-gradient(#000 0 0) content-box,linear-gradient(#000 0 0)",
                    WebkitMaskComposite: "xor",
                    maskComposite: "exclude",
                  }}
                />
                <span className="inline-flex items-center gap-1.5 rounded-full bg-hot px-3 py-1.5 font-mono text-[12px] font-semibold text-[#1A0907]">
                  ◆ 50% off · launch week
                </span>
                <div className="my-1 mt-5 flex items-baseline gap-3.5">
                  <span className="text-[64px] font-extrabold tracking-[-.04em]">${PRICE.now}</span>
                  <span className="text-[26px] font-semibold text-faint line-through">${PRICE.was}</span>
                  <span className="text-[15px] text-muted">one-time · lifetime</span>
                </div>
                <ul className="my-6 flex flex-col gap-3">
                  {[
                    "Lifetime license — pay once, no subscription",
                    "Every future update included, forever",
                    "Live Claude Code agent tracking + all widgets",
                    "Ask Claude, teleprompter, camera, Pomodoro & more",
                    "Works on all your personal Macs",
                  ].map((t) => (
                    <li key={t} className="flex items-start gap-3 text-[15px] text-[#D7DAE0]">
                      <span className="mt-0.5 flex-none text-pulse">✓</span>
                      {t}
                    </li>
                  ))}
                </ul>
                <MagneticButton href={BUY_URL} external className="w-full px-6 py-4 text-[16px]">
                  Buy NotchPulse — ${PRICE.now}
                </MagneticButton>
                <div className="mt-3.5 text-center text-[12.5px] text-faint">
                  Secure checkout · instant download · 14-day money-back guarantee
                </div>
              </div>
            </Reveal>
          </div>
        </section>

        {/* UPDATES */}
        <section id="updates" className="px-6 py-24">
          <div className="mx-auto max-w-content">
            <SecHead eyebrow="Always improving" title="Updates land here." sub="Buy once and check back — new releases show up automatically in the app." />
            <Reveal className="mx-auto flex max-w-[560px] flex-col">
              <Rel v="v1.0" head="Launch." rest=" Live agents, widgets, Ask Claude, teleprompter, Pomodoro, themes." />
              <Rel v="Next" head="Notifications & sounds" rest=" when an agent finishes, a global hotkey, and per-agent detail view." />
              <Rel v="Soon" head="Calendar & weather" rest=" widgets, plus VS Code / Cursor / Zed integrations." />
            </Reveal>
          </div>
        </section>

        <footer className="mt-10 border-t border-white/[.08] px-6 py-16 text-center text-[13.5px] text-faint">
          <div className="mb-3.5 flex items-center justify-center gap-2.5 font-bold text-ink"><Glyph size={22} /> NotchPulse</div>
          <div>Your notch, alive. · macOS 14+ · <a href="#pricing" className="text-muted hover:text-ink">Get it for ${PRICE.now}</a></div>
          <div className="mt-2.5">© 2026 NotchPulse · <a href="#top" className="text-muted hover:text-ink">Back to top</a></div>
        </footer>
      </main>
    </>
  );
}

/* ---- small presentational helpers ---- */
function SecHead({ eyebrow, title, sub }: { eyebrow: string; title: string; sub?: string }) {
  return (
    <Reveal className="mx-auto mb-12 max-w-[640px] text-center">
      <div className="eyebrow">{eyebrow}</div>
      <h2 className="mt-3.5 text-balance text-[clamp(30px,4.4vw,46px)] font-extrabold leading-[1.04] tracking-[-.03em]">{title}</h2>
      {sub && <p className="mt-3.5 text-balance text-[18px] text-muted">{sub}</p>}
    </Reveal>
  );
}
function Card({ children, span = "" }: { children: React.ReactNode; span?: string }) {
  return (
    <Reveal className={span}>
      <div className="relative h-full overflow-hidden rounded-[18px] border border-white/[.08] bg-gradient-to-b from-surface to-bg2 p-6">
        {children}
      </div>
    </Reveal>
  );
}
function Glowy() {
  return <div className="pointer-events-none absolute -right-8 -top-8 h-36 w-36 rounded-full" style={{ background: "radial-gradient(closest-side,rgba(110,99,255,.2),transparent)" }} />;
}
function Ic({ children }: { children: React.ReactNode }) {
  return <div className="mb-4 grid h-[34px] w-[34px] place-items-center rounded-[10px] border border-pulse/25 bg-pulse/10 text-[17px] text-pulse">{children}</div>;
}
function IcNum({ children }: { children: React.ReactNode }) {
  return <div className="mb-4 grid h-[34px] w-[34px] place-items-center rounded-[10px] border border-pulse/25 bg-pulse/10 font-mono text-pulse">{children}</div>;
}
function H3({ children }: { children: React.ReactNode }) {
  return <h3 className="mb-1.5 text-[19px] font-bold tracking-[-.01em]">{children}</h3>;
}
function P({ children }: { children: React.ReactNode }) {
  return <p className="text-[14.5px] text-muted">{children}</p>;
}
function Rel({ v, head, rest }: { v: string; head: string; rest: string }) {
  return (
    <div className="flex gap-4 border-b border-white/[.08] py-4">
      <span className="w-16 flex-none font-mono text-[13px] font-semibold text-pulse">{v}</span>
      <span className="text-[14.5px] text-muted">
        <b className="font-semibold text-ink">{head}</b>
        {rest}
      </span>
    </div>
  );
}
