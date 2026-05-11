/**
 * Feature flags - single source of truth.
 *
 * WINDOWS_BETA_PUBLIC: toggle ON when the Windows build has passed
 * user testing and is stable enough for public download.
 * Flipping to true restores: Hero secondary CTA, Download Windows tab,
 * Roadmap Windows milestones, metadata mentioning Windows, JSON-LD
 * operatingSystem entry, OG image bullet, FAQ wording.
 */
export const FEATURES = {
  WINDOWS_BETA_PUBLIC: false,
} as const;
