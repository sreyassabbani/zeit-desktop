/** Provider-independent calendar vocabulary shared by every surface. */

export type Bytes = Uint8Array;

export type CalendarColor = "indigo" | "plum" | "sea" | "sand";
export type EventKind = "meeting" | "focus" | "appointment" | "personal" | "task";
export type EventTiming = "timed" | "all_day";
export type Participation = "accepted" | "tentative" | "declined" | "needs_action";
export type Availability = "busy" | "free";
export type Surface = "menu_bar" | "desktop_widget" | "up_next";
export type SurfaceOverride = "inherit" | "pin" | "hide";

export interface CalendarDefinition {
  readonly id: number;
  readonly name: Bytes;
  readonly color: CalendarColor;
}

export interface CalendarVisibility {
  readonly id: number;
  readonly name: Bytes;
  readonly color: CalendarColor;
  readonly visible: boolean;
}

export interface SurfacePreferences {
  readonly menuBar: SurfaceOverride;
  readonly desktopWidget: SurfaceOverride;
  readonly upNext: SurfaceOverride;
}

/**
 * Canonical event after provider normalization. Provider-specific etags,
 * recurrence payloads, and attendee schemas do not cross this boundary.
 */
export interface CalendarEvent {
  readonly id: number;
  readonly calendarId: number;
  readonly title: Bytes;
  readonly location: Bytes;
  readonly startsAtMs: number;
  readonly endsAtMs: number;
  readonly timing: EventTiming;
  readonly eventKind: EventKind;
  readonly participation: Participation;
  readonly availability: Availability;
  readonly surfaces: SurfacePreferences;
  readonly source: EventSource | null;
}

export interface EventSource {
  readonly providerAccountId: number;
  readonly externalCalendarId: Bytes;
  readonly externalEventId: Bytes;
  readonly revision: Bytes;
}

/**
 * One occurrence after recurrence expansion and local-time-zone projection.
 * CalendarEvent stays canonical; layout consumes this local projection.
 */
export interface EventOccurrence {
  readonly id: number;
  readonly eventId: number;
  readonly localDayIndex: number;
  readonly localStartMinute: number;
  readonly localEndMinute: number;
}
