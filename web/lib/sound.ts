// Tiny opt-in UI sound (Web Audio). Off by default; preference persists.
let ctx: AudioContext | null = null;
let enabled = false;

export function loadSound() {
  if (typeof window !== "undefined") enabled = localStorage.getItem("np-sound") === "1";
}
export function soundOn() {
  return enabled;
}
export function setSound(on: boolean) {
  enabled = on;
  try {
    localStorage.setItem("np-sound", on ? "1" : "0");
  } catch {}
  if (on) tick(680, 0.05);
}
export function tick(freq = 620, vol = 0.035) {
  if (!enabled) return;
  try {
    ctx = ctx || new (window.AudioContext || (window as any).webkitAudioContext)();
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.type = "sine";
    o.frequency.value = freq;
    g.gain.value = vol;
    o.connect(g).connect(ctx.destination);
    const t = ctx.currentTime;
    o.start(t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 0.12);
    o.stop(t + 0.13);
  } catch {}
}
