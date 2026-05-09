import { ImageResponse } from "next/og";

export const alt = "PolskiWhisper - dyktowanie po polsku offline";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OGImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: "#161618",
          fontFamily: "Inter, system-ui, sans-serif",
        }}
      >
        {/* Decorative waveform bars */}
        <div
          style={{
            position: "absolute",
            bottom: 0,
            left: 0,
            right: 0,
            height: "200px",
            display: "flex",
            alignItems: "flex-end",
            justifyContent: "center",
            gap: "6px",
            opacity: 0.15,
          }}
        >
          {Array.from({ length: 40 }).map((_, i) => {
            const center = 20;
            const dist = Math.abs(i - center) / center;
            const h = (1 - dist * 0.7) * 180;
            const isRed = dist < 0.4;
            return (
              <div
                key={i}
                style={{
                  width: "12px",
                  height: `${h}px`,
                  borderRadius: "4px 4px 0 0",
                  backgroundColor: isRed ? "#d63940" : "#ffffff",
                }}
              />
            );
          })}
        </div>

        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: "24px",
            position: "relative",
          }}
        >
          <div
            style={{
              fontSize: "96px",
              fontWeight: 800,
              color: "#f2f2f2",
              lineHeight: 0.95,
              letterSpacing: "-0.04em",
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
            }}
          >
            <span>Mówisz.</span>
            <span style={{ color: "#d63940" }}>Piszesz.</span>
          </div>

          <div
            style={{
              fontSize: "28px",
              color: "#8a8a8e",
              maxWidth: "600px",
              textAlign: "center",
              lineHeight: 1.4,
            }}
          >
            Darmowe dyktowanie po polsku. Offline. Open source.
          </div>
        </div>

        {/* Logo text */}
        <div
          style={{
            position: "absolute",
            bottom: "40px",
            display: "flex",
            alignItems: "center",
            gap: "8px",
            fontSize: "24px",
            fontWeight: 700,
          }}
        >
          <span style={{ color: "#d63940" }}>Polski</span>
          <span style={{ color: "#f2f2f2" }}>Whisper</span>
        </div>
      </div>
    ),
    { ...size }
  );
}
