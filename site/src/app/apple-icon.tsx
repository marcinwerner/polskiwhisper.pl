import { ImageResponse } from "next/og";

export const size = { width: 180, height: 180 };
export const contentType = "image/png";

const ACCENT = "#dc4150";
const ACCENT_LIGHT = "#e64a5a";

export default function AppleIcon() {
  // 11 bars - heights mirror around center, 3 middle are red, edges fade
  const BAR_W = 8;
  const GAP = 5;
  const heights = [28, 46, 67, 84, 98, 112, 98, 84, 67, 46, 28];
  const reds = [false, false, false, false, true, true, true, false, false, false, false];
  const opacities = [0.78, 0.85, 0.92, 0.96, 1, 1, 1, 0.96, 0.92, 0.85, 0.78];

  const totalW = 11 * BAR_W + 10 * GAP;
  const startX = (180 - totalW) / 2;
  const centerY = 90;

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          position: "relative",
          background:
            "linear-gradient(135deg, #221820 0%, #100a10 55%, #080406 100%)",
          borderRadius: "40px",
        }}
      >
        {/* Red ambient glow */}
        <div
          style={{
            position: "absolute",
            left: "50%",
            top: "62%",
            width: "180px",
            height: "180px",
            marginLeft: "-90px",
            marginTop: "-90px",
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(220,65,80,0.32) 0%, rgba(220,65,80,0.08) 55%, rgba(220,65,80,0) 100%)",
            display: "flex",
          }}
        />

        {/* Bars container */}
        <div
          style={{
            position: "relative",
            width: "100%",
            height: "100%",
            display: "flex",
          }}
        >
          {heights.map((h, i) => {
            const isRed = reds[i];
            const op = opacities[i];
            return (
              <div
                key={i}
                style={{
                  position: "absolute",
                  left: `${startX + i * (BAR_W + GAP)}px`,
                  top: `${centerY - h / 2}px`,
                  width: `${BAR_W}px`,
                  height: `${h}px`,
                  borderRadius: `${BAR_W / 2}px`,
                  background: isRed
                    ? i === 5
                      ? ACCENT_LIGHT
                      : ACCENT
                    : `rgba(255,255,255,${op})`,
                  display: "flex",
                }}
              />
            );
          })}
        </div>
      </div>
    ),
    { ...size }
  );
}
