"use client";
import { useEffect, useState } from "react";

type Mode = "light" | "dark";

export default function ThemeToggle() {
  const [mode, setMode] = useState<Mode>("light");

  useEffect(() => {
    const saved = (localStorage.getItem("np-theme") as Mode) || "light";
    setMode(saved);
    document.documentElement.dataset.theme = saved;
  }, []);

  const toggle = () => {
    const next: Mode = mode === "light" ? "dark" : "light";
    setMode(next);
    localStorage.setItem("np-theme", next);
    document.documentElement.dataset.theme = next;
  };

  return (
    <button
      onClick={toggle}
      aria-label={mode === "light" ? "Switch to dark" : "Switch to light"}
      title={mode === "light" ? "Dark mode" : "Light mode"}
      className="text-ink2 transition-colors hover:text-ink"
    >
      {mode === "light" ? (
        <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" /></svg>
      ) : (
        <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" /></svg>
      )}
    </button>
  );
}
