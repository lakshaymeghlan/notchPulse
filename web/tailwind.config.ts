import type { Config } from "tailwindcss";

export default {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        paper: "#FFFFFF",      // clean white ground
        paper2: "#F4F5F6",     // recessed surface
        card: "#FBFBFC",       // raised surface
        ink: "#0E0F12",        // near-black, cool
        ink2: "#565A63",       // cool grey secondary
        faint: "#9CA0A8",
        line: "#0E0F1210",     // hairline
        line2: "#0E0F1218",
        live: "#E23A2E",       // recording-tally red, used tiny
        device: "#0B0B0C",     // the notch black
        coffee: "#FFDD00",     // (legacy) Buy Me a Coffee yellow
        bean: "#3A2A1A",
        razor: "#4D9BFF",      // light Razorpay blue
        razorHi: "#3B86F0",    // hover
      },
      fontFamily: {
        display: ["var(--font-display)", "Georgia", "serif"],
        body: ["var(--font-body)", "system-ui", "sans-serif"],
        mono: ["var(--font-mono)", "ui-monospace", "monospace"],
      },
      maxWidth: { content: "1180px" },
      letterSpacing: { tightest: "-.04em" },
    },
  },
  plugins: [],
} satisfies Config;
