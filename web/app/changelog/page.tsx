import type { Metadata } from "next";
import { Mark } from "@/components/Nav";
import { DOWNLOAD_URL } from "@/lib/site";

export const metadata: Metadata = {
  title: "Changelog",
  description: "What's new in NotchPulse — every release and what's coming next.",
};

const RELEASES = [
  {
    v: "1.0",
    date: "Launch",
    status: "now",
    items: [
      "Live Claude Code agent tracking — one lane per session, with progress and finish state",
      "Ask Claude in the notch + summarize clipboard",
      "Widgets: clock, battery ring, live CPU/memory graphs, now-playing, open apps & windows",
      "Studio: teleprompter + camera mirror, Pomodoro focus timer",
      "Editable pages, accent colors, optional frosted glass",
    ],
  },
  {
    v: "Next",
    date: "Coming soon",
    status: "planned",
    items: [
      "Notifications and a sound when an agent finishes or fails",
      "A global hotkey to summon the notch",
      "Per-agent detail view — full task history, files touched",
    ],
  },
  {
    v: "Later",
    date: "On the roadmap",
    status: "planned",
    items: ["Calendar & weather widgets", "VS Code / Cursor / Zed integrations", "Signed & notarized build"],
  },
];

export default function Changelog() {
  return (
    <main className="mx-auto max-w-[800px] px-6 py-28">
      <a href="/" className="flex items-center gap-2.5 font-display text-[17px] font-semibold tracking-tight">
        <Mark /> NotchPulse
      </a>

      <span className="idx mt-16 block">Changelog</span>
      <h1 className="mt-3 font-display text-[clamp(34px,6vw,64px)] font-semibold leading-[.96] tracking-tightest">
        What&rsquo;s new.
      </h1>
      <p className="mt-5 max-w-[52ch] text-[17px] leading-relaxed text-ink2">
        NotchPulse is free and updated often. New releases show up automatically in the app — this is the record.
      </p>

      <div className="mt-16 flex flex-col gap-px overflow-hidden rounded-3xl glass">
        {RELEASES.map((r) => (
          <section key={r.v} className="p-8 sm:p-10">
            <div className="flex items-center gap-3">
              <h2 className="font-display text-[26px] font-semibold tracking-tight">{r.v}</h2>
              <span
                className={`rounded-full px-2.5 py-1 font-mono text-[11px] ${
                  r.status === "now" ? "bg-ink text-paper" : "border border-line2 text-ink2"
                }`}
              >
                {r.date}
              </span>
            </div>
            <ul className="mt-5 flex flex-col gap-3">
              {r.items.map((it) => (
                <li key={it} className="flex items-start gap-3 text-[15.5px] leading-relaxed text-ink2">
                  <span className="mt-2 inline-block h-1 w-1 flex-none rounded-full bg-ink" />
                  {it}
                </li>
              ))}
            </ul>
          </section>
        ))}
      </div>

      <div className="mt-12 flex flex-wrap items-center gap-4">
        <a href={DOWNLOAD_URL} download className="rounded-full bg-ink px-6 py-3.5 text-[15px] font-medium text-paper">
          ↓ Download — it&rsquo;s free
        </a>
        <a href="/" className="text-[15px] text-ink underline decoration-line2 underline-offset-[6px] hover:decoration-ink">
          Back home
        </a>
      </div>
    </main>
  );
}
