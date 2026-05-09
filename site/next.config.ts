import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  serverExternalPackages: ["onnxruntime-node"],
  turbopack: {},
};

export default nextConfig;
