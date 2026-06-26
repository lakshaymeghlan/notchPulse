"use client";
import { useEffect, useRef } from "react";

/**
 * A live oscilloscope line — a thin baseline that ripples with a travelling
 * pulse and lifts with pointer activity. The signature motif of the page.
 */
export default function Pulse({
  height = 120,
  stroke = "#17181A",
  weight = 1.4,
  className = "",
}: {
  height?: number;
  stroke?: string;
  weight?: number;
  className?: string;
}) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current!;
    const ctx = canvas.getContext("2d")!;
    const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
    let raf = 0;
    let energy = 0.12; // ambient amplitude
    let target = 0.12;
    let w = 0,
      h = 0,
      dpr = Math.min(2, devicePixelRatio || 1);

    const resize = () => {
      const r = canvas.getBoundingClientRect();
      w = r.width;
      h = r.height;
      canvas.width = w * dpr;
      canvas.height = h * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);

    const onMove = () => {
      target = 0.5;
    };
    addEventListener("pointermove", onMove, { passive: true });

    let t = 0;
    const draw = () => {
      t += 0.018;
      energy += (target - energy) * 0.05;
      target += (0.12 - target) * 0.03; // decay toward ambient
      ctx.clearRect(0, 0, w, h);
      const mid = h / 2;
      // travelling pulse position
      const px = ((t * 0.12) % 1) * w;

      ctx.beginPath();
      for (let x = 0; x <= w; x += 2) {
        const base = Math.sin(x * 0.018 + t) * 4 * energy * 6;
        const ripple = Math.sin(x * 0.06 - t * 2) * 2 * energy * 6;
        // gaussian bump that travels
        const d = x - px;
        const bump = Math.exp(-(d * d) / 1400) * 26 * (0.4 + energy);
        const y = mid - base - ripple - bump;
        if (x === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.strokeStyle = stroke;
      ctx.globalAlpha = 0.5;
      ctx.lineWidth = weight;
      ctx.lineJoin = "round";
      ctx.stroke();

      // pulse head dot
      ctx.globalAlpha = 1;
      ctx.beginPath();
      ctx.arc(px, mid - Math.exp(0) * 0, 2.4, 0, Math.PI * 2);
      ctx.fillStyle = "#E23A2E";
      ctx.fill();

      raf = requestAnimationFrame(draw);
    };

    if (reduce) {
      // static centered line
      resize();
      ctx.clearRect(0, 0, w, h);
      ctx.beginPath();
      ctx.moveTo(0, h / 2);
      ctx.lineTo(w, h / 2);
      ctx.strokeStyle = stroke;
      ctx.globalAlpha = 0.4;
      ctx.lineWidth = weight;
      ctx.stroke();
    } else {
      raf = requestAnimationFrame(draw);
    }

    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
      removeEventListener("pointermove", onMove);
    };
  }, [stroke, weight]);

  return <canvas ref={ref} className={className} style={{ width: "100%", height }} />;
}
