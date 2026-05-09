"use client";

import { useState, useMemo } from "react";
import { motion } from "motion/react";

const TYPING_WPM = 40;
const SPEAKING_WPM = 130;
const EFFICIENCY = 0.7; // not all typing can be replaced

export function Calculator() {
  const [minutesPerDay, setMinutesPerDay] = useState(90);

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
    <section className="py-[var(--spacing-section)]">
      <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
        <div className="text-center">
          <h2 className="text-3xl font-bold sm:text-4xl">
            Ile czasu zaoszczędzisz
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-[var(--color-fg-muted)]">
            Średnio piszemy 40 słów na minutę. Mówimy - 130. Policz sam.
          </p>
        </div>

        <div className="mt-12 rounded-2xl border border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] p-6 sm:p-8">
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
                  [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:h-5 [&::-webkit-slider-thumb]:w-5 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-accent [&::-webkit-slider-thumb]:shadow-[var(--shadow-glow)] [&::-webkit-slider-thumb]:transition-transform [&::-webkit-slider-thumb]:active:scale-125"
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
            />
            <ResultCard
              value={savings.hoursPerWeek}
              unit="godz. / tydzień"
              delay={0.08}
            />
            <ResultCard
              value={savings.daysPerYear}
              unit="dni / rok"
              delay={0.16}
              highlight
            />
          </div>

          <div className="mt-6 text-center">
            <a
              href="#download"
              className="inline-flex items-center gap-2 rounded-xl bg-accent px-6 py-3 text-sm font-semibold text-[var(--color-accent-fg)] transition-all hover:bg-accent-hover active:scale-[0.98]"
            >
              Pobierz teraz, oszczędzaj jutro
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}

function ResultCard({
  value,
  unit,
  delay,
  highlight,
}: {
  value: number;
  unit: string;
  delay: number;
  highlight?: boolean;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      whileInView={{ opacity: 1, scale: 1 }}
      viewport={{ once: true }}
      transition={{ duration: 0.4, delay, ease: [0.16, 1, 0.3, 1] }}
      className={`rounded-xl border p-5 text-center ${
        highlight
          ? "border-accent/30 bg-accent-subtle"
          : "border-[var(--color-border-subtle)] bg-[var(--color-bg)]"
      }`}
    >
      <motion.p
        key={value}
        initial={{ opacity: 0.5, y: -4 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.2 }}
        className={`text-3xl font-bold tabular-nums ${
          highlight ? "text-accent" : ""
        }`}
      >
        {value}
      </motion.p>
      <p className="mt-1 text-sm text-[var(--color-fg-muted)]">{unit}</p>
    </motion.div>
  );
}
