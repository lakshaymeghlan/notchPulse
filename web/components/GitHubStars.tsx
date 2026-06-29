"use client";
import { useEffect, useState } from "react";

const REPO = "lakshaymeghlan/notchPulse";

/** Live GitHub star count as quiet social proof. Hidden until it loads. */
export default function GitHubStars() {
  const [stars, setStars] = useState<number | null>(null);
  useEffect(() => {
    fetch(`https://api.github.com/repos/${REPO}`)
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => { if (d && typeof d.stargazers_count === "number") setStars(d.stargazers_count); })
      .catch(() => {});
  }, []);
  if (stars === null) return null;
  return (
    <a
      href={`https://github.com/${REPO}`}
      target="_blank"
      rel="noopener noreferrer"
      className="hidden items-center gap-1.5 font-mono text-[12.5px] text-ink2 hover:text-ink sm:inline-flex"
      title="Star on GitHub"
    >
      <span>★</span>
      <span className="tabular-nums">{stars.toLocaleString()}</span>
    </a>
  );
}
