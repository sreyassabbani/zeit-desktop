import { describe, expect, test } from "bun:test";
import type { CalendarEvent } from "../src/domain/calendar.ts";
import {
  rankEventsForSurface,
  scoreForSurface,
  type SurfaceRule,
} from "../src/domain/surface-ranking.ts";

const EMPTY = new Uint8Array(0);
const NOW = 1_000_000;
const RULE: SurfaceRule = {
  surface: "desktop_widget",
  maxEvents: 3,
  horizonMinutes: 1440,
  includeAllDay: false,
  includeDeclined: false,
};

function event(
  id: number,
  startsAtMs: number,
  endsAtMs: number,
  override: "inherit" | "pin" | "hide",
): CalendarEvent {
  return {
    id,
    calendarId: 1,
    title: EMPTY,
    location: EMPTY,
    startsAtMs,
    endsAtMs,
    timing: "timed",
    eventKind: "meeting",
    participation: "accepted",
    availability: "busy",
    surfaces: { menuBar: "inherit", desktopWidget: override, upNext: "inherit" },
    source: null,
  };
}

describe("surface ranking", () => {
  test("a user pin decisively outranks a nearer inherited event", () => {
    const laterPinned = event(2, NOW + 4 * 60 * 60 * 1000, NOW + 5 * 60 * 60 * 1000, "pin");
    const imminent = event(1, NOW + 10 * 60 * 1000, NOW + 70 * 60 * 1000, "inherit");

    expect(rankEventsForSurface([imminent, laterPinned], RULE, NOW).map((item) => item.eventId)).toEqual([
      2,
      1,
    ]);
  });

  test("hide, declined, all-day, and beyond-horizon events are excluded", () => {
    const hidden = event(1, NOW + 1000, NOW + 2000, "hide");
    const declined = { ...event(2, NOW + 1000, NOW + 2000, "inherit"), participation: "declined" as const };
    const allDay = { ...event(3, NOW + 1000, NOW + 2000, "inherit"), timing: "all_day" as const };
    const distant = event(4, NOW + 2 * 24 * 60 * 60 * 1000, NOW + 3 * 24 * 60 * 60 * 1000, "inherit");

    expect(rankEventsForSurface([hidden, declined, allDay, distant], RULE, NOW)).toEqual([]);
  });

  test("an event in progress outranks an ordinary future event", () => {
    const active = event(1, NOW - 10_000, NOW + 10_000, "inherit");
    const future = event(2, NOW + 10_000, NOW + 20_000, "inherit");

    expect(scoreForSurface(active, RULE, NOW)).toBeGreaterThan(scoreForSurface(future, RULE, NOW));
  });
});
