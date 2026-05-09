import { ImageResponse } from "next/og";

export const size = { width: 180, height: 180 };
export const contentType = "image/png";

export default function AppleIcon() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: "#161618",
          borderRadius: "36px",
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "flex-end",
            gap: "6px",
            height: "100px",
          }}
        >
          <div
            style={{
              width: "14px",
              height: "50px",
              borderRadius: "4px",
              backgroundColor: "rgba(255,255,255,0.5)",
            }}
          />
          <div
            style={{
              width: "14px",
              height: "70px",
              borderRadius: "4px",
              backgroundColor: "rgba(255,255,255,0.6)",
            }}
          />
          <div
            style={{
              width: "14px",
              height: "90px",
              borderRadius: "4px",
              backgroundColor: "#d63940",
            }}
          />
          <div
            style={{
              width: "14px",
              height: "100px",
              borderRadius: "4px",
              backgroundColor: "#d63940",
            }}
          />
          <div
            style={{
              width: "14px",
              height: "65px",
              borderRadius: "4px",
              backgroundColor: "rgba(255,255,255,0.6)",
            }}
          />
        </div>
      </div>
    ),
    { ...size }
  );
}
