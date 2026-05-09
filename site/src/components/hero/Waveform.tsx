"use client";

import { useEffect, useRef } from "react";

const BAR_COUNT = 72;
const BAR_GAP = 3;
const MIN_HEIGHT = 0.04;
const MAX_HEIGHT = 0.85;

function readThemeColors() {
  const isLight = document.documentElement.classList.contains("light");
  return isLight
    ? { neutralR: 25, neutralG: 25, neutralB: 30, redR: 214, redG: 57, redB: 64 }
    : { neutralR: 245, neutralG: 245, neutralB: 245, redR: 220, redG: 65, redB: 75 };
}

export function Waveform() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const frameRef = useRef<number>(0);
  const reducedMotion = useRef(false);
  const colorsRef = useRef(
    typeof window !== "undefined"
      ? readThemeColors()
      : { neutralR: 245, neutralG: 245, neutralB: 245, redR: 220, redG: 65, redB: 75 }
  );

  useEffect(() => {
    reducedMotion.current = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;

    colorsRef.current = readThemeColors();

    const observer = new MutationObserver(() => {
      colorsRef.current = readThemeColors();
    });
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    });

    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const resize = () => {
      const dpr = window.devicePixelRatio || 1;
      const rect = canvas.getBoundingClientRect();
      canvas.width = rect.width * dpr;
      canvas.height = rect.height * dpr;
      ctx.scale(dpr, dpr);
    };

    resize();
    window.addEventListener("resize", resize);

    // Per-bar parameters - multiple frequency components for organic look
    const lowFreq = Array.from({ length: BAR_COUNT }, () => 1.5 + Math.random() * 2.5);
    const midFreq = Array.from({ length: BAR_COUNT }, () => 4 + Math.random() * 4);
    const highFreq = Array.from({ length: BAR_COUNT }, () => 8 + Math.random() * 6);
    const phase1 = Array.from({ length: BAR_COUNT }, () => Math.random() * Math.PI * 2);
    const phase2 = Array.from({ length: BAR_COUNT }, () => Math.random() * Math.PI * 2);
    const phase3 = Array.from({ length: BAR_COUNT }, () => Math.random() * Math.PI * 2);

    // Per-bar smoothed height (for natural attack/decay)
    const heights = new Float32Array(BAR_COUNT);

    // Burst events - simulate moments of "speech" with energy spikes
    const burstUntil = new Float32Array(BAR_COUNT);

    let lastFrameTime = performance.now();
    let nextBurstTime = 0;

    const draw = (now: number) => {
      const dt = Math.min(0.05, (now - lastFrameTime) / 1000); // delta time in seconds
      lastFrameTime = now;
      const t = now / 1000;

      const rect = canvas.getBoundingClientRect();
      const w = rect.width;
      const h = rect.height;

      ctx.clearRect(0, 0, w, h);

      const barWidth = (w - (BAR_COUNT - 1) * BAR_GAP) / BAR_COUNT;
      const centerX = w / 2;
      const { neutralR, neutralG, neutralB, redR, redG, redB } = colorsRef.current;

      // Trigger burst events to simulate speech rhythm
      if (!reducedMotion.current && now > nextBurstTime) {
        // Burst affects a contiguous range of bars (like a syllable)
        const center = Math.floor(Math.random() * BAR_COUNT);
        const spread = 8 + Math.floor(Math.random() * 12);
        const intensity = 0.4 + Math.random() * 0.6;
        const duration = 80 + Math.random() * 200;
        for (let b = -spread; b <= spread; b++) {
          const idx = center + b;
          if (idx >= 0 && idx < BAR_COUNT) {
            const falloff = 1 - Math.abs(b) / spread;
            burstUntil[idx] = Math.max(
              burstUntil[idx],
              now + duration * falloff * intensity
            );
          }
        }
        nextBurstTime = now + 60 + Math.random() * 280; // dense bursts - feels alive
      }

      for (let i = 0; i < BAR_COUNT; i++) {
        const x = i * (barWidth + BAR_GAP);
        const distFromCenter = Math.abs(x + barWidth / 2 - centerX) / (w / 2);
        // Envelope: stronger in center (like real audio peaks at speech freq)
        const envelope = Math.pow(1 - distFromCenter * 0.95, 1.4);

        let target: number;

        if (reducedMotion.current) {
          target = MIN_HEIGHT + envelope * 0.5 * (0.5 + (i % 3) * 0.15);
        } else {
          // Layered sines - low (slow body) + mid (texture) + high (sparkle)
          const low = Math.sin(t * lowFreq[i] + phase1[i]);
          const mid = Math.sin(t * midFreq[i] + phase2[i]) * 0.5;
          const high = Math.sin(t * highFreq[i] + phase3[i]) * 0.25;

          // Burst boost - jumps up sharply when active
          const burstActive = burstUntil[i] > now;
          const burstBoost = burstActive ? 0.45 + Math.random() * 0.25 : 0;

          // Combined wave - normalized to roughly 0-1
          const combined = (low + mid + high + 1.75) / 3.5;

          target = MIN_HEIGHT + envelope * (combined * 0.5 + burstBoost);
          target = Math.min(MAX_HEIGHT, Math.max(MIN_HEIGHT, target));
        }

        // Smoothed transition - asymmetric attack/decay (real audio: snappy attack, slower decay)
        const current = heights[i];
        const isAttacking = target > current;
        // Fast attack ~14/s, slower decay ~6/s - feels like real audio meter
        const rate = isAttacking ? 14 : 6;
        const smoothed = current + (target - current) * Math.min(1, dt * rate);
        heights[i] = smoothed;

        const actualH = smoothed * h;
        const y = (h - actualH) / 2;

        const progress = i / BAR_COUNT;
        const isRed = progress >= 0.4 && progress <= 0.85;

        if (isRed) {
          // Red bars: brighter when burst-active
          const burstActive = burstUntil[i] > now;
          const intensity =
            (burstActive ? 0.65 : 0.4) + envelope * 0.35;
          ctx.fillStyle = `rgba(${redR}, ${redG}, ${redB}, ${intensity})`;
        } else {
          const burstActive = burstUntil[i] > now;
          const intensity =
            (burstActive ? 0.45 : 0.22) + envelope * 0.35;
          ctx.fillStyle = `rgba(${neutralR}, ${neutralG}, ${neutralB}, ${intensity})`;
        }

        const radius = Math.min(barWidth / 2, 2);
        ctx.beginPath();
        ctx.roundRect(x, y, barWidth, actualH, radius);
        ctx.fill();
      }

      frameRef.current = requestAnimationFrame(draw);
    };

    frameRef.current = requestAnimationFrame(draw);

    return () => {
      cancelAnimationFrame(frameRef.current);
      window.removeEventListener("resize", resize);
      observer.disconnect();
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="absolute inset-0 h-full w-full pointer-events-none"
      style={{ opacity: "var(--waveform-opacity, 0.55)" }}
      aria-hidden="true"
    />
  );
}
