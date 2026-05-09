"use client";

import { useEffect, useState } from "react";

const PHRASES = [
  "Pisz dwa razy szybciej.",
  "Po polsku.",
  "Bez chmury.",
  "Za darmo.",
];

const TYPE_SPEED = 55;
const DELETE_SPEED = 30;
const PAUSE_AFTER_TYPE = 2200;
const PAUSE_AFTER_DELETE = 400;

export function Typewriter() {
  const [text, setText] = useState("");
  const [phraseIndex, setPhraseIndex] = useState(0);
  const [isDeleting, setIsDeleting] = useState(false);
  const [isPaused, setIsPaused] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    if (mq.matches) {
      setText(PHRASES[0]);
      return;
    }

    const phrase = PHRASES[phraseIndex];

    if (isPaused) {
      const timeout = setTimeout(
        () => {
          setIsPaused(false);
          if (!isDeleting) setIsDeleting(true);
        },
        isDeleting ? PAUSE_AFTER_DELETE : PAUSE_AFTER_TYPE
      );
      return () => clearTimeout(timeout);
    }

    if (!isDeleting) {
      if (text.length < phrase.length) {
        const timeout = setTimeout(() => {
          setText(phrase.slice(0, text.length + 1));
        }, TYPE_SPEED);
        return () => clearTimeout(timeout);
      }
      setIsPaused(true);
      return;
    }

    if (text.length > 0) {
      const timeout = setTimeout(() => {
        setText(text.slice(0, -1));
      }, DELETE_SPEED);
      return () => clearTimeout(timeout);
    }

    setIsDeleting(false);
    setIsPaused(true);
    setPhraseIndex((prev) => (prev + 1) % PHRASES.length);
  }, [text, phraseIndex, isDeleting, isPaused]);

  return (
    <span className="inline-block min-h-[1.2em]">
      {text}
      <span
        className="ml-0.5 inline-block w-[2px] h-[1em] bg-accent align-text-bottom animate-[blink_1s_step-end_infinite]"
        aria-hidden="true"
      />
      <style>{`@keyframes blink{0%,100%{opacity:1}50%{opacity:0}}`}</style>
    </span>
  );
}
