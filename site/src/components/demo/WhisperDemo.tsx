"use client";

import { useState, useRef, useCallback, useEffect } from "react";
import { Mic, Square, Loader2, Download, Volume2 } from "lucide-react";
import { motion, AnimatePresence } from "motion/react";
import { cn } from "@/lib/cn";

type DemoState =
  | "idle"
  | "loading-model"
  | "ready"
  | "recording"
  | "transcribing"
  | "done"
  | "error";

const MODEL_ID = "onnx-community/whisper-tiny";

export function WhisperDemo() {
  const [state, setState] = useState<DemoState>("idle");
  const [transcript, setTranscript] = useState("");
  const [progress, setProgress] = useState(0);
  const [progressLabel, setProgressLabel] = useState("");
  const [error, setError] = useState("");
  const [duration, setDuration] = useState(0);
  const [visualizerData, setVisualizerData] = useState<number[]>(
    new Array(32).fill(0)
  );

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const pipelineRef = useRef<any>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const animFrameRef = useRef<number>(0);
  const timerRef = useRef<ReturnType<typeof setInterval>>(null!);

  useEffect(() => {
    return () => {
      cancelAnimationFrame(animFrameRef.current);
      clearInterval(timerRef.current);
    };
  }, []);

  const loadModel = useCallback(async () => {
    setState("loading-model");
    setProgress(0);
    setProgressLabel("Pobieranie modelu Whisper Tiny (~40 MB)...");
    setError("");

    try {
      const { pipeline, env } = await import("@huggingface/transformers");
      env.allowLocalModels = false;

      const pipe = await pipeline(
        "automatic-speech-recognition",
        MODEL_ID,
        {
          dtype: "q8",
          device: "wasm",
          progress_callback: (p: { status: string; progress?: number; file?: string }) => {
            if (p.status === "progress" && p.progress != null) {
              setProgress(Math.round(p.progress));
              setProgressLabel(
                `Pobieranie: ${p.file?.split("/").pop() ?? "model"}`
              );
            }
            if (p.status === "done") {
              setProgressLabel("Model gotowy");
            }
          },
        }
      );

      pipelineRef.current = pipe;
      setState("ready");
    } catch (err) {
      console.error("Model load error:", err);
      setError(
        "Nie udało się pobrać modelu. Sprawdź połączenie z internetem."
      );
      setState("error");
    }
  }, []);

  const startRecording = useCallback(async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          channelCount: 1,
          sampleRate: 16000,
        },
      });

      const audioCtx = new AudioContext();
      const source = audioCtx.createMediaStreamSource(stream);
      const analyser = audioCtx.createAnalyser();
      analyser.fftSize = 64;
      source.connect(analyser);
      analyserRef.current = analyser;

      const dataArray = new Uint8Array(analyser.frequencyBinCount);
      function updateVisualizer() {
        analyser.getByteFrequencyData(dataArray);
        const normalized = Array.from(dataArray).map((v) => v / 255);
        setVisualizerData(normalized);
        animFrameRef.current = requestAnimationFrame(updateVisualizer);
      }
      updateVisualizer();

      const mediaRecorder = new MediaRecorder(stream, {
        mimeType: MediaRecorder.isTypeSupported("audio/webm;codecs=opus")
          ? "audio/webm;codecs=opus"
          : "audio/webm",
      });

      audioChunksRef.current = [];
      mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) audioChunksRef.current.push(e.data);
      };

      mediaRecorder.onstop = async () => {
        cancelAnimationFrame(animFrameRef.current);
        clearInterval(timerRef.current);
        stream.getTracks().forEach((t) => t.stop());
        audioCtx.close();
        setVisualizerData(new Array(32).fill(0));

        const audioBlob = new Blob(audioChunksRef.current, {
          type: "audio/webm",
        });
        await transcribe(audioBlob);
      };

      mediaRecorderRef.current = mediaRecorder;
      mediaRecorder.start(250);
      setState("recording");
      setDuration(0);
      setTranscript("");

      timerRef.current = setInterval(() => {
        setDuration((d) => d + 0.1);
      }, 100);
    } catch (err) {
      console.error("Mic error:", err);
      setError(
        "Brak dostępu do mikrofonu. Zezwól na użycie mikrofonu w przeglądarce."
      );
      setState("error");
    }
  }, []);

  const stopRecording = useCallback(() => {
    if (mediaRecorderRef.current?.state === "recording") {
      mediaRecorderRef.current.stop();
    }
  }, []);

  async function transcribe(audioBlob: Blob) {
    setState("transcribing");
    setProgressLabel("Transkrybuję...");

    try {
      const arrayBuffer = await audioBlob.arrayBuffer();

      const audioCtx = new AudioContext({ sampleRate: 16000 });
      const decoded = await audioCtx.decodeAudioData(arrayBuffer);
      const float32 = decoded.getChannelData(0);
      audioCtx.close();

      const result = await pipelineRef.current(float32, {
        language: "polish",
        task: "transcribe",
      });

      const text =
        typeof result === "object" && "text" in result
          ? (result as { text: string }).text
          : String(result);

      setTranscript(text.trim());
      setState("done");
    } catch (err) {
      console.error("Transcription error:", err);
      setError("Błąd transkrypcji. Spróbuj ponownie.");
      setState("error");
    }
  }

  const reset = useCallback(() => {
    setTranscript("");
    setError("");
    setState(pipelineRef.current ? "ready" : "idle");
  }, []);

  return (
    <section id="demo" className="py-[var(--spacing-section)]">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        <div className="text-center">
          <h2 className="text-3xl font-bold sm:text-4xl">
            Wypróbuj w przeglądarce
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-[var(--color-fg-muted)]">
            Ten sam silnik Whisper, działający bezpośrednio w Twojej
            przeglądarce. Żadne audio nie opuszcza komputera.
          </p>
        </div>

        <div className="mt-12 rounded-2xl border border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] p-6 sm:p-8">
          {/* Idle state - invite to load model */}
          {state === "idle" && (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className="flex flex-col items-center gap-6 py-8"
            >
              <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-accent-subtle">
                <Volume2 className="h-8 w-8 text-accent" />
              </div>
              <div className="text-center">
                <p className="text-lg font-semibold">
                  Przetestuj rozpoznawanie mowy
                </p>
                <p className="mt-2 text-sm text-[var(--color-fg-muted)]">
                  Model Whisper Tiny (~40 MB) zostanie pobrany i uruchomiony
                  lokalnie w przeglądarce.
                </p>
              </div>
              <button
                onClick={loadModel}
                className="inline-flex h-12 items-center gap-2.5 rounded-xl bg-accent px-6 text-base font-semibold text-[var(--color-accent-fg)] shadow-[var(--shadow-glow)] transition-all hover:bg-accent-hover active:scale-[0.98]"
              >
                <Download className="h-5 w-5" />
                Załaduj model i spróbuj
              </button>
            </motion.div>
          )}

          {/* Loading model */}
          {state === "loading-model" && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="flex flex-col items-center gap-6 py-8"
            >
              <Loader2 className="h-10 w-10 animate-spin text-accent" />
              <div className="w-full max-w-sm">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-[var(--color-fg-muted)]">
                    {progressLabel}
                  </span>
                  <span className="font-mono text-accent">{progress}%</span>
                </div>
                <div className="mt-2 h-2 overflow-hidden rounded-full bg-[var(--color-bg)]">
                  <motion.div
                    className="h-full rounded-full bg-accent"
                    initial={{ width: 0 }}
                    animate={{ width: `${progress}%` }}
                    transition={{ duration: 0.3 }}
                  />
                </div>
              </div>
              <p className="text-xs text-[var(--color-fg-subtle)]">
                Pierwszy raz trwa dłużej. Kolejne uruchomienia korzystają z
                cache przeglądarki.
              </p>
            </motion.div>
          )}

          {/* Ready / Recording / Transcribing */}
          {(state === "ready" ||
            state === "recording" ||
            state === "transcribing") && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="flex flex-col items-center gap-6 py-4"
            >
              {/* Visualizer */}
              <div className="flex h-20 items-end gap-[3px]">
                {visualizerData.map((v, i) => (
                  <div
                    key={i}
                    className={cn(
                      "w-2 rounded-t-sm transition-all duration-75",
                      state === "recording"
                        ? "bg-accent"
                        : "bg-[var(--color-border)]"
                    )}
                    style={{
                      height: `${Math.max(4, v * 80)}px`,
                    }}
                  />
                ))}
              </div>

              {/* Timer */}
              {state === "recording" && (
                <p className="font-mono text-2xl tabular-nums text-accent">
                  {duration.toFixed(1)}s
                </p>
              )}

              {state === "transcribing" && (
                <div className="flex items-center gap-2 text-[var(--color-fg-muted)]">
                  <Loader2 className="h-4 w-4 animate-spin" />
                  <span className="text-sm">Transkrybuję...</span>
                </div>
              )}

              {/* Controls */}
              <div className="flex items-center gap-4">
                {state === "ready" && (
                  <button
                    onClick={startRecording}
                    className="inline-flex h-14 items-center gap-2.5 rounded-xl bg-accent px-8 text-base font-semibold text-[var(--color-accent-fg)] shadow-[var(--shadow-glow)] transition-all hover:bg-accent-hover active:scale-[0.98]"
                  >
                    <Mic className="h-5 w-5" />
                    Nagrywaj
                  </button>
                )}
                {state === "recording" && (
                  <button
                    onClick={stopRecording}
                    className="inline-flex h-14 items-center gap-2.5 rounded-xl border-2 border-accent bg-accent/10 px-8 text-base font-semibold text-accent transition-all hover:bg-accent/20 active:scale-[0.98]"
                  >
                    <Square className="h-5 w-5" />
                    Zatrzymaj
                  </button>
                )}
              </div>

              {state === "ready" && (
                <p className="text-xs text-[var(--color-fg-subtle)]">
                  Powiedz coś po polsku, np. &quot;Dzień dobry, to jest
                  test.&quot;
                </p>
              )}
            </motion.div>
          )}

          {/* Result */}
          <AnimatePresence>
            {state === "done" && transcript && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0 }}
                className="flex flex-col items-center gap-6 py-4"
              >
                <div className="w-full rounded-xl border border-accent/20 bg-accent-subtle p-6">
                  <p className="text-xs font-medium uppercase tracking-wider text-accent">
                    Transkrypcja
                  </p>
                  <p className="mt-3 text-lg leading-relaxed">{transcript}</p>
                </div>
                <div className="flex gap-3">
                  <button
                    onClick={() => {
                      setTranscript("");
                      setState("ready");
                    }}
                    className="inline-flex h-11 items-center gap-2 rounded-lg bg-accent px-5 text-sm font-semibold text-[var(--color-accent-fg)] transition-all hover:bg-accent-hover active:scale-[0.98]"
                  >
                    <Mic className="h-4 w-4" />
                    Spróbuj ponownie
                  </button>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Error */}
          <AnimatePresence>
            {state === "error" && (
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="flex flex-col items-center gap-4 py-8"
              >
                <p className="text-sm text-[var(--color-warning)]">{error}</p>
                <button
                  onClick={reset}
                  className="rounded-lg border border-[var(--color-border)] px-4 py-2 text-sm font-medium transition-colors hover:bg-[var(--color-bg-subtle)]"
                >
                  Spróbuj ponownie
                </button>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Footer note */}
          <div className="mt-4 border-t border-[var(--color-border-subtle)] pt-4 text-center text-xs text-[var(--color-fg-subtle)]">
            Model działa w 100% w przeglądarce (WASM). Audio nie jest
            wysyłane na żaden serwer.
          </div>
        </div>
      </div>
    </section>
  );
}
