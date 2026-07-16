import type {
  CalendarEvent,
  Surface,
  SurfaceOverride,
} from "./calendar.ts";

export interface SurfaceRule {
  readonly surface: Surface;
  readonly maxEvents: number;
  readonly horizonMinutes: number;
  readonly includeAllDay: boolean;
  readonly includeDeclined: boolean;
}

export interface RankedSurfaceEvent {
  readonly eventId: number;
  readonly score: number;
}

const HIDDEN_SCORE = -1000000;
const PINNED_SCORE = 500000;

export function overrideForSurface(event: CalendarEvent, surface: Surface): SurfaceOverride {
  switch (surface) {
    case "menu_bar":
      return event.surfaces.menuBar;
    case "desktop_widget":
      return event.surfaces.desktopWidget;
    case "up_next":
      return event.surfaces.upNext;
  }
}

export function scoreForSurface(event: CalendarEvent, rule: SurfaceRule, nowMs: number): number {
  const override = overrideForSurface(event, rule.surface);
  if (override === "hide") return HIDDEN_SCORE;
  if (!rule.includeDeclined && event.participation === "declined") return HIDDEN_SCORE;
  if (!rule.includeAllDay && event.timing === "all_day") return HIDDEN_SCORE;

  const untilStart = event.startsAtMs - nowMs;
  const beyondHorizon = untilStart > rule.horizonMinutes * 60000;
  if (beyondHorizon && override !== "pin") return HIDDEN_SCORE;

  let score = 0;
  if (override === "pin") score += PINNED_SCORE;

  if (event.startsAtMs <= nowMs && event.endsAtMs > nowMs) {
    score += 100000;
  } else if (untilStart >= 0 && untilStart <= 3600000) {
    score += 50000;
  } else if (untilStart > 3600000 && untilStart <= 14400000) {
    score += 40000;
  } else if (untilStart > 14400000 && untilStart <= 86400000) {
    score += 30000;
  } else if (untilStart > 86400000) {
    score += 20000;
  } else {
    score -= 100000;
  }

  if (event.eventKind === "focus") score += 4000;
  if (event.eventKind === "appointment") score += 3000;
  if (event.participation === "accepted") score += 1000;
  if (event.participation === "tentative") score -= 500;
  if (event.availability === "free") score -= 750;
  if (event.timing === "all_day") score -= 1500;

  return score;
}

export function rankEventsForSurface(
  events: readonly CalendarEvent[],
  rule: SurfaceRule,
  nowMs: number,
): readonly RankedSurfaceEvent[] {
  const ranked: RankedSurfaceEvent[] = [];
  for (const event of events) {
    const score = scoreForSurface(event, rule, nowMs);
    if (score > HIDDEN_SCORE) ranked.push({ eventId: event.id, score: score });
  }
  ranked.sort((a, b) => {
    if (a.score !== b.score) return b.score - a.score;
    return a.eventId - b.eventId;
  });
  return ranked.slice(0, rule.maxEvents);
}
