import type { Config } from "tailwindcss";

export default {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        paper: "#E7E7E1",      // cool porcelain (chosen: slight green-grey bias)
        paper2: "#DEDED7",     // recessed surface
        card: "#EFEFEA",       // raised surface
        ink: "#17181A",        // near-black, cool
        ink2: "#5B5C57",       // warm-grey secondary
        faint: "#9A9A92",
        line: "#1718200F",     // hairline
        line2: "#17182022",
        live: "#E23A2E",       // recording-tally red, used tiny
        device: "#0B0B0C",     // the notch black
        coffee: "#FFDD00",     // Buy Me a Coffee yellow
        bean: "#3A2A1A",       // warm espresso brown
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
