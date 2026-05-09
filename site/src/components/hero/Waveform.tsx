"use client";

import { useEffect, useRef } from "react";

const BAR_COUNT = 64;
const BAR_GAP = 3;
const MIN_HEIGHT = 0.08;

function readThemeColors() {
  const isLight = document.documentElement.classList.contains("light");
  return isLight
    ? { neutralR: 30, neutralG: 30, neutralB: 35, redR: 214, redG: 57, redB: 64 }
    : { neutralR: 255, neutralG: 255, neutralB: 255, redR: 214, redG: 57, redB: 64 };
}

export function Waveform() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const frameRef = useRef<number>(0);
  const reducedMotion = useRef(false);
  const colorsRef = useRef(
    typeof window !== "undefined"
      ? readThemeColors()
      : { neutralR: 255, neutralG: 255, neutralB: 255, redR: 214, redG: 57, redB: 64 }
  );

  useEffect(() => {
    reducedMotion.current = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;

    colorsRef.current = readThemeColors();

    // React to theme toggle
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
      const { neutralR, neutralG, neutralB, redR, redG, redB } = colorsRef.current;

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
        const isRed = progress >= 0.4 && progress <= 0.85;

        if (isRed) {
          const intensity = 0.35 + envelope * 0.55;
          ctx.fillStyle = `rgba(${redR}, ${redG}, ${redB}, ${intensity})`;
        } else {
          const intensity = 0.2 + envelope * 0.4;
          ctx.fillStyle = `rgba(${neutralR}, ${neutralG}, ${neutralB}, ${intensity})`;
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
      observer.disconnect();
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="absolute inset-0 h-full w-full pointer-events-none"
      style={{ opacity: "var(--waveform-opacity, 0.45)" }}
      aria-hidden="true"
    />
  );
}
