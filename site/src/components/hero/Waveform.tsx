"use client";

import { useEffect, useRef } from "react";

const BAR_COUNT = 64;
const BAR_GAP = 3;
const MIN_HEIGHT = 0.08;

export function Waveform() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const frameRef = useRef<number>(0);
  const reducedMotion = useRef(false);

  useEffect(() => {
    reducedMotion.current = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;

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

    const phases = Array.from({ length: BAR_COUNT }, () => Math.random() * Math.PI * 2);
    const speeds = Array.from({ length: BAR_COUNT }, () => 0.3 + Math.random() * 0.7);
    const offsets = Array.from({ length: BAR_COUNT }, () => Math.random() * 0.3);

    let time = 0;

    const draw = () => {
      const rect = canvas.getBoundingClientRect();
      const w = rect.width;
      const h = rect.height;

      ctx.clearRect(0, 0, w, h);

      const barWidth = (w - (BAR_COUNT - 1) * BAR_GAP) / BAR_COUNT;
      const centerX = w / 2;

      for (let i = 0; i < BAR_COUNT; i++) {
        const x = i * (barWidth + BAR_GAP);
        const distFromCenter = Math.abs(x + barWidth / 2 - centerX) / (w / 2);
        const envelope = 1 - distFromCenter * distFromCenter;

        let barHeight: number;
        if (reducedMotion.current) {
          barHeight =
            MIN_HEIGHT + envelope * 0.6 * (0.5 + offsets[i] * 0.5);
        } else {
          const wave =
            Math.sin(time * speeds[i] + phases[i]) * 0.5 + 0.5;
          barHeight =
            MIN_HEIGHT + envelope * 0.6 * (wave * 0.7 + offsets[i] * 0.3);
        }

        const actualH = barHeight * h;
        const y = (h - actualH) / 2;

        const progress = i / BAR_COUNT;
        const isWhite = progress < 0.45 || progress > 0.85;

        if (isWhite) {
          ctx.fillStyle = `rgba(255, 255, 255, ${0.25 + envelope * 0.45})`;
        } else {
          const redIntensity = 0.35 + envelope * 0.55;
          ctx.fillStyle = `rgba(196, 30, 58, ${redIntensity})`;
        }

        const radius = Math.min(barWidth / 2, 2);
        ctx.beginPath();
        ctx.roundRect(x, y, barWidth, actualH, radius);
        ctx.fill();
      }

      time += 0.016;
      frameRef.current = requestAnimationFrame(draw);
    };

    frameRef.current = requestAnimationFrame(draw);

    return () => {
      cancelAnimationFrame(frameRef.current);
      window.removeEventListener("resize", resize);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="absolute inset-0 h-full w-full opacity-40 pointer-events-none"
      aria-hidden="true"
    />
  );
}
