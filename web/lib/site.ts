// NotchPulse is free. Tips/support go through Razorpay (India + international).
// The link is public (not a secret), so it lives here as the default and can be
// overridden per-deploy with NEXT_PUBLIC_SUPPORT_URL. Enable "International
// Payments" in Razorpay to accept foreign cards.
export const SUPPORT_URL =
  process.env.NEXT_PUBLIC_SUPPORT_URL ?? "https://razorpay.me/@lakshaymeghlan";
export const COFFEE_URL = SUPPORT_URL; // alias used by nav/hero/footer/⌘K
export const DOWNLOAD_URL = "/downloads/NotchPulse.zip";

// A deliberately absurd, escalating wishlist — the joke is the conversion.
// Give a tier its own `url` (e.g. an amount-specific Razorpay link) or it
// falls back to SUPPORT_URL (pay-what-you-want).
export const TIERS: { emoji: string; title: string; amount: string; note: string; url?: string }[] = [
  { emoji: "☕", title: "A coffee", amount: "₹99", note: "Keeps me awake long enough to squash one more bug." },
  { emoji: "🍕", title: "A pizza", amount: "₹299", note: "Premium, artisanal, deeply necessary debugging fuel." },
  { emoji: "⌨️", title: "A mechanical keyboard", amount: "₹4,999", note: "So my typing sounds as expensive as it clearly is." },
  { emoji: "🪑", title: "A real office chair", amount: "₹14,999", note: "My spine has officially filed a bug report." },
  { emoji: "🏎️", title: "A Porsche", amount: "₹1.2 Cr", note: "A developer can dream. You, specifically, can make it real." },
  { emoji: "🌝", title: "The moon", amount: "name your price", note: "Genuinely just shoot your shot. I will accept it." },
];
