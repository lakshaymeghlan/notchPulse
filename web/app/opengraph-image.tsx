import { ImageResponse } from "next/og";

export const runtime = "edge";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";
export const alt = "NotchPulse — Your notch, alive";

export default function OG() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          background: "#FFFFFF",
          padding: 80,
          fontFamily: "sans-serif",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 14, color: "#565A63", fontSize: 26 }}>
          <div style={{ position: "relative", width: 40, height: 24, background: "#0E0F12", borderRadius: "0 0 10px 10px", display: "flex" }}>
            <div style={{ position: "absolute", left: 16, top: 5, width: 8, height: 8, borderRadius: 8, background: "#E23A2E" }} />
          </div>
          NotchPulse
        </div>

        <div style={{ display: "flex", flexDirection: "column" }}>
          <div style={{ fontSize: 104, fontWeight: 700, letterSpacing: -4, color: "#0E0F12", lineHeight: 1 }}>
            Your notch, alive.
          </div>
          <div style={{ fontSize: 34, color: "#565A63", marginTop: 28, maxWidth: 900 }}>
            Watch your AI agents work, glance at what matters, and ask Claude — in the strip you already own.
          </div>
        </div>

        <div style={{ display: "flex", alignItems: "center", gap: 16, fontSize: 24, color: "#565A63" }}>
          <span style={{ background: "#0E0F12", color: "#fff", padding: "10px 20px", borderRadius: 999 }}>Free for macOS 14+</span>
          <span>· no account · powered by coffee ☕</span>
        </div>
      </div>
    ),
    { ...size }
  );
}
