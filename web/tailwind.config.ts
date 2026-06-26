import type { Config } from "tailwindcss";

export default {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: "#07080A",
        bg2: "#0B0D11",
        surface: "#121419",
        surface2: "#171A21",
        ink: "#F4F5F7",
        muted: "#9AA0AB",
        faint: "#5C616C",
        pulse: "#3DE0C0",
        indigo: "#6E63FF",
        hot: "#FF6B5E",
      },
      fontFamily: {
        sans: ['-apple-system', 'BlinkMacSystemFont', '"SF Pro Display"', '"SF Pro Text"', 'system-ui', 'sans-serif'],
        mono: ['ui-monospace', '"SF Mono"', 'Menlo', 'monospace'],
      },
      maxWidth: { content: "1120px" },
      keyframes: {
        blink: { "0%,100%": { opacity: "1" }, "50%": { opacity: ".35" } },
        spin: { to: { transform: "rotate(360deg)" } },
        eq: { "0%,100%": { height: "6px" }, "50%": { height: "24px" } },
      },
      animation: {
        blink: "blink 2.4s infinite",
        spin: "spin .8s linear infinite",
        eq: "eq 1s ease-in-out infinite",
      },
    },
  },
  plugins: [],
} satisfies Config;
