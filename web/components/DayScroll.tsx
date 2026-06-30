"use client";
import { useRef } from "react";
import { motion, useScroll, useTransform, MotionValue } from "framer-motion";

/** "A day in the notch" — scroll becomes time of day; the notch plays a real
 *  workflow: morning calendar → focused agents → a break → evening music. */
export default function DayScroll() {
  const ref = useRef<HTMLDivElement>(null);
  const { scrollYProgress: p } = useScroll({ target: ref, offset: ["start start", "end end"] });

  const o1 = useTransform(p, [0, 0.16, 0.22], [1, 1, 0]);
  const o2 = useTransform(p, [0.22, 0.3, 0.46, 0.52], [0, 1, 1, 0]);
  const o3 = useTransform(p, [0.52, 0.6, 0.72, 0.78], [0, 1, 1, 0]);
  const o4 = useTransform(p, [0.78, 0.86, 1], [0, 1, 1]);

  return (
    <section ref={ref} className="relative h-[400vh]" aria-label="A day in the notch">
      <div className="sticky top-0 flex h-screen flex-col items-center justify-center overflow-hidden">
        {/* ambient time-of-day glows */}
        <Glow o={o1} color="rgba(255,196,120,.20)" pos="50% 8%" />
        <Glow o={o2} color="rgba(77,155,255,.18)" pos="50% 8%" />
        <Glow o={o3} color="rgba(255,150,90,.18)" pos="50% 8%" />
        <Glow o={o4} color="rgba(150,110,255,.20)" pos="50% 8%" />

        <span className="idx mb-6">A day in the notch</span>

        {/* the notch (fixed expanded), content crossfades by scene */}
        <div className="relative h-[176px] w-[min(560px,92vw)] overflow-hidden rounded-b-[26px] rounded-t-[6px] border border-white/[.06] bg-device text-white shadow-[0_40px_120px_rgba(0,0,0,.35)]">
          <div className="flex h-10 items-center gap-2 border-b border-white/10 px-4 text-[11px] font-semibold text-white/55">
            <span className="h-1.5 w-1.5 rounded-full" style={{ background: "var(--live)", boxShadow: "0 0 8px var(--live)" }} />
            NotchPulse
          </div>
          <div className="relative h-[calc(176px-40px)]">
            <Scene o={o1}><Morning /></Scene>
            <Scene o={o2}><Focus /></Scene>
            <Scene o={o3}><Break /></Scene>
            <Scene o={o4}><Evening /></Scene>
          </div>
        </div>

        {/* captions */}
        <div className="relative mt-10 h-20 w-[min(620px,92vw)] text-center">
          <Caption o={o1} time="7:30 AM" text="Morning. Your day and your next meeting, before you've even opened a thing." />
          <Caption o={o2} time="11:00 AM" text="Deep work. Two agents racing — you watch both finish without breaking flow." />
          <Caption o={o3} time="2:00 PM" text="A break. The notch nudges you to breathe before the next sprint." />
          <Caption o={o4} time="7:00 PM" text="Winding down. Whatever's playing, right where your eyes already are." />
        </div>
        <div className="absolute bottom-7 left-1/2 -translate-x-1/2 idx">scroll</div>
      </div>
      <style>{`@keyframes dseq{0%,100%{height:6px}50%{height:22px}}@keyframes dsblink{0%,100%{opacity:1}50%{opacity:.3}}`}</style>
    </section>
  );
}

function Glow({ o, color, pos }: { o: MotionValue<number>; color: string; pos: string }) {
  return <motion.div style={{ opacity: o, background: `radial-gradient(50% 45% at ${pos}, ${color}, transparent 70%)` }} className="pointer-events-none absolute inset-0" />;
}
function Scene({ o, children }: { o: MotionValue<number>; children: React.ReactNode }) {
  return <motion.div style={{ opacity: o }} className="absolute inset-0 grid grid-cols-[1fr_1.2fr] gap-0">{children}</motion.div>;
}
function Cell({ children, last }: { children: React.ReactNode; last?: boolean }) {
  return <div className={`flex flex-col justify-center gap-2 px-5 ${last ? "" : "border-r border-white/10"}`}>{children}</div>;
}
function Cap({ children }: { children: React.ReactNode }) {
  return <span className="font-mono text-[9px] uppercase tracking-[.12em] text-white/35">{children}</span>;
}

function Morning() {
  return (
    <>
      <Cell><Cap>Clock</Cap><div className="font-display text-[30px] font-semibold leading-none">7:30</div><div className="text-[11px] text-white/50">Tuesday · clear, 21°</div></Cell>
      <Cell last><Cap>Up next</Cap>
        <div className="text-[13px] font-semibold">Standup</div>
        <div className="text-[11px] text-white/55">9:00 · 15 min · Meet</div>
        <div className="mt-1 text-[11px] text-white/40">then: 1:1 with Priya · 11:30</div>
      </Cell>
    </>
  );
}
function Focus() {
  return (
    <>
      <Cell><Cap>Agent · 2 running</Cap>
        <Lane title="Refactor ActivityStore" />
        <Lane title="pytest · 38 passing" delay=".4s" />
      </Cell>
      <Cell last><Cap>Throughput</Cap>
        <div className="flex h-7 items-end gap-[3px]">{[0,.1,.2,.3,.4,.5,.6].map((d,k)=><span key={k} className="w-1.5 rounded-sm bg-[#3DE0C0]" style={{animation:`dseq 1s ease-in-out ${d}s infinite`}}/>)}</div>
        <div className="text-[11px] text-white/50">2 agents · 0 stuck</div>
      </Cell>
    </>
  );
}
function Break() {
  return (
    <>
      <Cell><Cap>Pomodoro</Cap>
        <div className="flex items-center gap-3">
          <div className="relative h-12 w-12">
            <svg viewBox="0 0 36 36" className="h-12 w-12 -rotate-90"><circle cx="18" cy="18" r="15" fill="none" stroke="rgba(255,255,255,.15)" strokeWidth="3"/><circle cx="18" cy="18" r="15" fill="none" stroke="#FF965A" strokeWidth="3" strokeLinecap="round" strokeDasharray="94" strokeDashoffset="34"/></svg>
            <span className="absolute inset-0 grid place-items-center font-display text-[12px] font-bold">4:32</span>
          </div>
          <div><div className="text-[12px] font-semibold text-[#FF965A]">Break</div><div className="text-[10px] text-white/50">2 done today</div></div>
        </div>
      </Cell>
      <Cell last><Cap>Reminder</Cap><div className="text-[13px] font-medium">Stretch &amp; hydrate 💧</div><div className="text-[11px] text-white/50">back to focus in 4:32</div></Cell>
    </>
  );
}
function Evening() {
  return (
    <>
      <Cell><Cap>Now playing</Cap>
        <div className="flex items-center gap-2.5">
          <div className="h-9 w-9 rounded-md" style={{ background: "linear-gradient(135deg,#966eff,#4d9bff)" }} />
          <div><div className="text-[12px] font-semibold">Nightcall</div><div className="text-[10px] text-white/55">Kavinsky</div></div>
        </div>
      </Cell>
      <Cell last><Cap>Battery</Cap><div className="font-display text-[24px] font-semibold leading-none">38%</div><div className="text-[11px] text-white/50">unplugged · ~2h left</div></Cell>
    </>
  );
}
function Lane({ title, delay = "0s" }: { title: string; delay?: string }) {
  return (
    <div className="flex items-center gap-2">
      <span className="h-1.5 w-1.5 rounded-full bg-[#3DE0C0]" style={{ animation: `dsblink 1.4s infinite`, animationDelay: delay }} />
      <span className="truncate text-[12px] font-medium text-white/90">{title}</span>
    </div>
  );
}
function Caption({ o, time, text }: { o: MotionValue<number>; time: string; text: string }) {
  return (
    <motion.div style={{ opacity: o }} className="absolute inset-x-0 mx-auto flex flex-col items-center gap-2">
      <span className="font-mono text-[12px] text-live">{time}</span>
      <p className="text-balance font-display text-[clamp(18px,2.4vw,24px)] font-medium leading-snug">{text}</p>
    </motion.div>
  );
}
