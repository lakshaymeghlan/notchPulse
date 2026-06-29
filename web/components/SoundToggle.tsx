"use client";
import { useEffect, useState } from "react";
import { loadSound, setSound, soundOn } from "@/lib/sound";

export default function SoundToggle() {
  const [on, setOn] = useState(false);
  useEffect(() => {
    loadSound();
    setOn(soundOn());
  }, []);
  return (
    <button
      onClick={() => { const v = !on; setSound(v); setOn(v); }}
      aria-label={on ? "Mute interface sounds" : "Enable interface sounds"}
      title={on ? "Sound on" : "Sound off"}
      className="text-ink2 transition-colors hover:text-ink"
    >
      {on ? (
        <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M11 5 6 9H2v6h4l5 4z"/><path d="M15.5 8.5a5 5 0 0 1 0 7"/><path d="M18.5 5.5a9 9 0 0 1 0 13"/></svg>
      ) : (
        <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M11 5 6 9H2v6h4l5 4z"/><path d="m22 9-6 6"/><path d="m16 9 6 6"/></svg>
      )}
    </button>
  );
}
