import type { Config } from "tailwindcss";

export default {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Themeable (light/dark) — driven by CSS vars in globals.css.
        paper: "var(--c-paper)",      // ground
        paper2: "var(--c-paper2)",    // recessed surface
        card: "var(--c-card)",        // raised surface
        ink: "rgb(var(--c-ink) / <alpha-value>)", // text (supports /opacity)
        ink2: "var(--c-ink2)",        // secondary
        faint: "var(--c-faint)",
        line: "var(--c-line)",        // hairline
        line2: "var(--c-line2)",
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
