import { ImageResponse } from "next/og";

export const alt = "PolskiWhisper - dyktowanie po polsku offline";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

const ACCENT = "#dc4150";
const ACCENT_LIGHT = "#ff5a6e";
const FG = "#f5f5f7";
const FG_MUTED = "#a8a8b3";

export default function OGImage() {
  // Right-side waveform - smaller, contained
  const BAR_COUNT = 40;
  const bars = Array.from({ length: BAR_COUNT }, (_, i) => {
    const center = (BAR_COUNT - 1) / 2;
    const dist = Math.abs(i - center) / center;
    const envelope = Math.pow(1 - dist * 0.85, 1.8);
    const seed = Math.sin(i * 1.7 + 0.3) * 0.5 + 0.5;
    const seed2 = Math.sin(i * 2.9 + 1.1) * 0.5 + 0.5;
    const heightFactor = 0.15 + envelope * (0.4 + seed * 0.4 + seed2 * 0.2);
    const isRed = dist < 0.55;
    return { heightFactor, isRed };
  });

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          position: "relative",
          background:
            "linear-gradient(140deg, #0f0e14 0%, #181520 50%, #2a1820 100%)",
          fontFamily:
            'Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif',
        }}
      >
        {/* Soft accent glow - top-right corner */}
        <div
          style={{
            position: "absolute",
            top: -250,
            right: -200,
            width: 800,
            height: 800,
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(220,65,80,0.5) 0%, rgba(220,65,80,0) 65%)",
            display: "flex",
          }}
        />

        {/* Soft secondary glow - bottom-left */}
        <div
          style={{
            position: "absolute",
            bottom: -200,
            left: -150,
            width: 600,
            height: 600,
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(255,90,110,0.18) 0%, rgba(255,90,110,0) 70%)",
            display: "flex",
          }}
        />

        {/* Subtle grid pattern overlay - left side */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            background:
              "radial-gradient(circle at 20% 50%, rgba(255,255,255,0.025) 1px, transparent 1px)",
            backgroundSize: "40px 40px",
            opacity: 0.5,
            display: "flex",
          }}
        />

        {/* === LEFT COLUMN - text content === */}
        <div
          style={{
            position: "relative",
            display: "flex",
            flexDirection: "column",
            padding: "70px 80px",
            width: "65%",
            height: "100%",
            zIndex: 10,
          }}
        >
          {/* Brand */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 12,
            }}
          >
            <div
              style={{
                display: "flex",
                alignItems: "flex-end",
                gap: 3,
                height: 26,
              }}
            >
              <div
                style={{
                  width: 4,
                  height: 12,
                  borderRadius: 2,
                  background: "rgba(255,255,255,0.4)",
                  display: "flex",
                }}
              />
              <div
                style={{
                  width: 4,
                  height: 20,
                  borderRadius: 2,
                  background: ACCENT,
                  display: "flex",
                }}
              />
              <div
                style={{
                  width: 4,
                  height: 26,
                  borderRadius: 2,
                  background: ACCENT,
                  display: "flex",
                }}
              />
              <div
                style={{
                  width: 4,
                  height: 16,
                  borderRadius: 2,
                  background: "rgba(255,255,255,0.4)",
                  display: "flex",
                }}
              />
            </div>
            <div
              style={{
                display: "flex",
                fontSize: 22,
                fontWeight: 700,
                letterSpacing: "-0.01em",
              }}
            >
              <span style={{ color: ACCENT }}>Polski</span>
              <span style={{ color: FG }}>Whisper</span>
            </div>
          </div>

          {/* Spacer */}
          <div style={{ flex: 1, display: "flex" }} />

          {/* Eyebrow pill */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 10,
              padding: "8px 18px",
              borderRadius: 999,
              background: "rgba(220,65,80,0.18)",
              border: "1px solid rgba(220,65,80,0.35)",
              alignSelf: "flex-start",
              marginBottom: 28,
            }}
          >
            <div
              style={{
                width: 8,
                height: 8,
                borderRadius: 999,
                background: ACCENT,
                display: "flex",
              }}
            />
            <span
              style={{
                fontSize: 15,
                color: ACCENT_LIGHT,
                fontWeight: 600,
                letterSpacing: "0.04em",
                textTransform: "uppercase",
              }}
            >
              Darmowa · Open source · Offline
            </span>
          </div>

          {/* Headline */}
          <div
            style={{
              fontSize: 116,
              fontWeight: 800,
              color: FG,
              lineHeight: 0.98,
              letterSpacing: "-0.045em",
              display: "flex",
              marginBottom: 6,
            }}
          >
            Mówisz.
          </div>
          <div
            style={{
              fontSize: 116,
              fontWeight: 800,
              lineHeight: 0.98,
              letterSpacing: "-0.045em",
              display: "flex",
              background: `linear-gradient(135deg, ${ACCENT_LIGHT} 0%, ${ACCENT} 60%, #b8323e 100%)`,
              backgroundClip: "text",
              color: "transparent",
            }}
          >
            Piszesz.
          </div>

          {/* Subhead */}
          <div
            style={{
              fontSize: 26,
              color: FG_MUTED,
              marginTop: 26,
              lineHeight: 1.35,
              letterSpacing: "-0.005em",
              display: "flex",
              maxWidth: 620,
            }}
          >
            Dyktowanie po polsku 3× szybsze niż klawiatura.
          </div>

          {/* Spacer */}
          <div style={{ flex: 1, display: "flex" }} />

          {/* Bottom row - features */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 28,
              fontSize: 17,
              color: "rgba(255,255,255,0.55)",
              fontWeight: 500,
            }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <span style={{ color: ACCENT, fontSize: 18, display: "flex" }}>●</span>
              <span style={{ display: "flex" }}>macOS · Windows</span>
            </div>
            <div
              style={{
                width: 1,
                height: 14,
                background: "rgba(255,255,255,0.15)",
                display: "flex",
              }}
            />
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <span style={{ color: ACCENT, fontSize: 18, display: "flex" }}>●</span>
              <span style={{ display: "flex" }}>Whisper Large</span>
            </div>
            <div
              style={{
                width: 1,
                height: 14,
                background: "rgba(255,255,255,0.15)",
                display: "flex",
              }}
            />
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <span style={{ color: ACCENT, fontSize: 18, display: "flex" }}>●</span>
              <span style={{ display: "flex" }}>Zero telemetrii</span>
            </div>
          </div>
        </div>

        {/* === RIGHT COLUMN - visual === */}
        <div
          style={{
            position: "relative",
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            alignItems: "center",
            width: "35%",
            height: "100%",
            padding: "70px 60px 70px 0",
            zIndex: 10,
          }}
        >
          {/* URL pill */}
          <div
            style={{
              position: "absolute",
              top: 70,
              right: 60,
              display: "flex",
              alignItems: "center",
              padding: "10px 18px",
              borderRadius: 999,
              background: "rgba(255,255,255,0.06)",
              border: "1px solid rgba(255,255,255,0.12)",
              fontSize: 17,
              color: FG_MUTED,
              fontWeight: 500,
            }}
          >
            polskiwhisper.pl
          </div>

          {/* Waveform card */}
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              gap: 18,
              padding: "32px 30px",
              borderRadius: 20,
              background: "rgba(220,65,80,0.10)",
              border: "1px solid rgba(220,65,80,0.25)",
              boxShadow: "0 20px 60px rgba(220,65,80,0.2)",
            }}
          >
            {/* Mic indicator dot */}
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: 8,
              }}
            >
              <div
                style={{
                  width: 10,
                  height: 10,
                  borderRadius: 999,
                  background: ACCENT,
                  display: "flex",
                  boxShadow: "0 0 12px rgba(220,65,80,0.8)",
                }}
              />
              <span
                style={{
                  fontSize: 14,
                  color: ACCENT_LIGHT,
                  fontWeight: 600,
                  letterSpacing: "0.05em",
                  textTransform: "uppercase",
                }}
              >
                Słucham
              </span>
            </div>

            {/* Waveform */}
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: 4,
                height: 100,
              }}
            >
              {bars.map((b, i) => (
                <div
                  key={i}
                  style={{
                    width: 5,
                    height: `${b.heightFactor * 100}px`,
                    borderRadius: 3,
                    background: b.isRed
                      ? `linear-gradient(180deg, ${ACCENT_LIGHT}, ${ACCENT})`
                      : "rgba(255,255,255,0.5)",
                    display: "flex",
                  }}
                />
              ))}
            </div>

            {/* Big label */}
            <div
              style={{
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                marginTop: 6,
              }}
            >
              <div
                style={{
                  fontSize: 56,
                  fontWeight: 800,
                  color: FG,
                  lineHeight: 1,
                  letterSpacing: "-0.03em",
                  display: "flex",
                }}
              >
                3×
              </div>
              <div
                style={{
                  fontSize: 14,
                  color: FG_MUTED,
                  fontWeight: 500,
                  letterSpacing: "0.05em",
                  textTransform: "uppercase",
                  marginTop: 4,
                  display: "flex",
                }}
              >
                Szybciej
              </div>
            </div>
          </div>
        </div>
      </div>
    ),
    { ...size }
  );
}
