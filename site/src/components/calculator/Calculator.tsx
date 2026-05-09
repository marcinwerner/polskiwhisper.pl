"use client";

import { useState, useMemo, useEffect, useRef } from "react";
import {
  motion,
  useMotionValue,
  useSpring,
  useTransform,
  useInView,
} from "motion/react";

const TYPING_WPM = 40;
const SPEAKING_WPM = 130;
const EFFICIENCY = 0.7;

export function Calculator() {
  const [minutesPerDay, setMinutesPerDay] = useState(90);
  const sectionRef = useRef<HTMLElement>(null);
  const inView = useInView(sectionRef, { once: true, margin: "-80px" });

  const savings = useMemo(() => {
    const typingWordsPerDay = minutesPerDay * TYPING_WPM;
    const speakingMinutes = (typingWordsPerDay / SPEAKING_WPM) * EFFICIENCY;
    const savedMinutesPerDay = (minutesPerDay - speakingMinutes) * EFFICIENCY;
    const savedHoursPerWeek = (savedMinutesPerDay * 5) / 60;
    const savedDaysPerYear = (savedMinutesPerDay * 250) / 60 / 8;

    return {
      minutesPerDay: Math.round(savedMinutesPerDay),
      hoursPerWeek: Math.round(savedHoursPerWeek * 10) / 10,
      daysPerYear: Math.round(savedDaysPerYear * 10) / 10,
    };
  }, [minutesPerDay]);

  return (
    <section ref={sectionRef} className="py-[var(--spacing-section)]">
      <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={inView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
          className="text-center"
        >
          <h2 className="text-3xl font-bold sm:text-4xl">
            Ile czasu zaoszczędzisz
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-[var(--color-fg-muted)]">
            Mowa jest <strong className="text-[var(--color-fg)]">3× szybsza</strong> niż
            klawiatura - i ma 20% mniej literówek.
            <br className="hidden sm:block" />
            Sprawdź ile to dla Ciebie.
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 40 }}
          animate={inView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.7, delay: 0.15, ease: [0.16, 1, 0.3, 1] }}
          className="relative mt-12 rounded-2xl border border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] p-6 sm:p-8"
        >
          {/* Slider */}
          <div>
            <label
              htmlFor="typing-minutes"
              className="block text-sm font-medium text-[var(--color-fg-muted)]"
            >
              Ile minut dziennie piszesz na klawiaturze?
            </label>
            <div className="mt-3 flex items-center gap-4">
              <input
                id="typing-minutes"
                type="range"
                min={15}
                max={480}
                step={5}
                value={minutesPerDay}
                onChange={(e) => setMinutesPerDay(Number(e.target.value))}
                className="w-full accent-[var(--color-accent)] h-2 rounded-full bg-[var(--color-border)] appearance-none cursor-pointer
                  [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:h-5 [&::-webkit-slider-thumb]:w-5 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-accent [&::-webkit-slider-thumb]:shadow-[var(--shadow-glow)] [&::-webkit-slider-thumb]:transition-transform [&::-webkit-slider-thumb]:active:scale-125 [&::-webkit-slider-thumb]:hover:scale-110"
              />
              <span className="min-w-[4rem] text-right text-lg font-bold tabular-nums">
                {minutesPerDay} min
              </span>
            </div>
          </div>

          {/* Results */}
          <div className="mt-8 grid gap-4 sm:grid-cols-3">
            <ResultCard
              value={savings.minutesPerDay}
              unit="min / dzień"
              delay={0}
              decimals={0}
              animate={inView}
            />
            <ResultCard
              value={savings.hoursPerWeek}
              unit="godz. / tydzień"
              delay={0.1}
              decimals={1}
              animate={inView}
            />
            <ResultCard
              value={savings.daysPerYear}
              unit="dni / rok"
              delay={0.2}
              decimals={1}
              highlight
              animate={inView}
            />
          </div>

          <div className="mt-8 text-center">
            <motion.a
              href="#download"
              whileHover={{ scale: 1.04 }}
              whileTap={{ scale: 0.97 }}
              className="inline-flex items-center gap-2 rounded-xl bg-accent px-6 py-3 text-sm font-semibold text-[var(--color-accent-fg)] shadow-[var(--shadow-glow)] transition-shadow hover:shadow-[0_0_48px_oklch(0.55_0.22_18/0.4)]"
            >
              Pobierz teraz, oszczędzaj jutro
            </motion.a>
          </div>

          {/* Research source */}
          <p className="mt-6 text-center text-xs text-[var(--color-fg-subtle)]">
            Źródło:{" "}
            <a
              href="https://arxiv.org/abs/1608.07323"
              target="_blank"
              rel="noopener noreferrer"
              className="underline decoration-[var(--color-border)] underline-offset-2 transition-colors hover:text-[var(--color-fg-muted)] hover:decoration-[var(--color-fg-subtle)]"
            >
              Stanford / Baidu / UW (2016)
            </a>{" "}
            - n=32, mowa 3× szybsza, 20% mniej błędów niż klawiatura
          </p>
        </motion.div>
      </div>
    </section>
  );
}

function ResultCard({
  value,
  unit,
  delay,
  decimals,
  highlight,
  animate,
}: {
  value: number;
  unit: string;
  delay: number;
  decimals: number;
  highlight?: boolean;
  animate: boolean;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.9, y: 20 }}
      animate={animate ? { opacity: 1, scale: 1, y: 0 } : {}}
      transition={{ duration: 0.5, delay: delay + 0.3, ease: [0.16, 1, 0.3, 1] }}
      whileHover={{ y: -4, transition: { duration: 0.2 } }}
      className={`relative overflow-hidden rounded-xl border p-5 text-center transition-shadow ${
        highlight
          ? "border-accent/30 bg-accent-subtle hover:shadow-[0_8px_32px_oklch(0.55_0.22_18/0.2)]"
          : "border-[var(--color-border-subtle)] bg-[var(--color-bg)] hover:shadow-lg"
      }`}
    >
      {highlight && (
        <div className="absolute -inset-1 -z-10 bg-gradient-to-br from-accent/0 via-accent/10 to-accent/0 opacity-50 blur-xl" />
      )}
      <SpringNumber
        value={value}
        decimals={decimals}
        className={`text-3xl font-bold tabular-nums sm:text-4xl ${
          highlight ? "text-accent" : ""
        }`}
      />
      <p className="mt-1 text-sm text-[var(--color-fg-muted)]">{unit}</p>
    </motion.div>
  );
}

function SpringNumber({
  value,
  decimals,
  className,
}: {
  value: number;
  decimals: number;
  className: string;
}) {
  const motionValue = useMotionValue(value);
  const spring = useSpring(motionValue, {
    stiffness: 90,
    damping: 30,
    mass: 1,
  });
  const display = useTransform(spring, (v) => v.toFixed(decimals));

  useEffect(() => {
    motionValue.set(value);
  }, [value, motionValue]);

  return <motion.p className={className}>{display}</motion.p>;
}
