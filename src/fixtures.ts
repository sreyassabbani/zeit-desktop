import { asciiBytes } from "@native-sdk/core";
import type {
  Bytes,
  CalendarEvent,
  CalendarVisibility,
} from "./domain/calendar.ts";
import type { SurfaceRule } from "./domain/surface-ranking.ts";

export type EventTone = "accent" | "surface" | "muted";

export interface WeekDayHeader {
  readonly id: number;
  readonly name: Bytes;
  readonly day: number;
  readonly today: boolean;
}

export interface HourRow {
  readonly id: number;
  readonly label: Bytes;
}

/** A bounded presentation projection; canonical events remain pixel-free. */
export interface WeekEventBlock {
  readonly eventId: number;
  readonly calendarId: number;
  readonly dayIndex: number;
  readonly gapBefore: number;
  readonly height: number;
  readonly title: Bytes;
  readonly timeLabel: Bytes;
  readonly location: Bytes;
  readonly tone: EventTone;
  readonly pinned: boolean;
}

export interface MonthCell {
  readonly id: number;
  readonly day: number;
  readonly inMonth: boolean;
  readonly today: boolean;
  readonly hasEvent1: boolean;
  readonly event1: Bytes;
  readonly hasEvent2: boolean;
  readonly event2: Bytes;
}

export const FIXTURE_NOW_MS = 1784120400000;

export const CALENDAR_VISIBILITY: readonly CalendarVisibility[] = [
  { id: 1, name: asciiBytes("Work"), color: "indigo", visible: true },
  { id: 2, name: asciiBytes("Personal"), color: "plum", visible: true },
  { id: 3, name: asciiBytes("Focus"), color: "sea", visible: true },
  { id: 4, name: asciiBytes("Reminders"), color: "sand", visible: false },
];

export const CALENDAR_EVENTS: readonly CalendarEvent[] = [
  {
    id: 101,
    calendarId: 1,
    title: asciiBytes("Weekly planning"),
    location: asciiBytes("Desk"),
    startsAtMs: 1783947600000,
    endsAtMs: 1783951200000,
    timing: "timed",
    eventKind: "meeting",
    participation: "accepted",
    availability: "busy",
    surfaces: { menuBar: "hide", desktopWidget: "hide", upNext: "hide" },
    source: null,
  },
  {
    id: 102,
    calendarId: 1,
    title: asciiBytes("Design review"),
    location: asciiBytes("Studio"),
    startsAtMs: 1784037600000,
    endsAtMs: 1784041200000,
    timing: "timed",
    eventKind: "meeting",
    participation: "accepted",
    availability: "busy",
    surfaces: { menuBar: "inherit", desktopWidget: "inherit", upNext: "inherit" },
    source: null,
  },
  {
    id: 103,
    calendarId: 3,
    title: asciiBytes("Deep work — calendar layout"),
    location: asciiBytes("Focus mode"),
    startsAtMs: 1784124000000,
    endsAtMs: 1784131200000,
    timing: "timed",
    eventKind: "focus",
    participation: "accepted",
    availability: "busy",
    surfaces: { menuBar: "pin", desktopWidget: "pin", upNext: "pin" },
    source: null,
  },
  {
    id: 104,
    calendarId: 2,
    title: asciiBytes("Dentist"),
    location: asciiBytes("Greenpoint Dental"),
    startsAtMs: 1784138400000,
    endsAtMs: 1784142000000,
    timing: "timed",
    eventKind: "appointment",
    participation: "accepted",
    availability: "busy",
    surfaces: { menuBar: "inherit", desktopWidget: "inherit", upNext: "inherit" },
    source: null,
  },
  {
    id: 105,
    calendarId: 1,
    title: asciiBytes("Project review"),
    location: asciiBytes("Meet"),
    startsAtMs: 1784210400000,
    endsAtMs: 1784214000000,
    timing: "timed",
    eventKind: "meeting",
    participation: "tentative",
    availability: "busy",
    surfaces: { menuBar: "inherit", desktopWidget: "inherit", upNext: "inherit" },
    source: null,
  },
  {
    id: 106,
    calendarId: 3,
    title: asciiBytes("Ship the first native pass"),
    location: asciiBytes("Focus mode"),
    startsAtMs: 1784293200000,
    endsAtMs: 1784300400000,
    timing: "timed",
    eventKind: "focus",
    participation: "accepted",
    availability: "busy",
    surfaces: { menuBar: "inherit", desktopWidget: "pin", upNext: "inherit" },
    source: null,
  },
  {
    id: 107,
    calendarId: 2,
    title: asciiBytes("Dinner with Maya"),
    location: asciiBytes("Win Son"),
    startsAtMs: 1784329200000,
    endsAtMs: 1784336400000,
    timing: "timed",
    eventKind: "personal",
    participation: "accepted",
    availability: "free",
    surfaces: { menuBar: "hide", desktopWidget: "inherit", upNext: "hide" },
    source: null,
  },
  {
    id: 108,
    calendarId: 2,
    title: asciiBytes("Yoga"),
    location: asciiBytes("McCarren Park"),
    startsAtMs: 1784383200000,
    endsAtMs: 1784386800000,
    timing: "timed",
    eventKind: "personal",
    participation: "accepted",
    availability: "free",
    surfaces: { menuBar: "inherit", desktopWidget: "inherit", upNext: "inherit" },
    source: null,
  },
  {
    id: 109,
    calendarId: 3,
    title: asciiBytes("Weekly reset"),
    location: asciiBytes("Home"),
    startsAtMs: 1784494800000,
    endsAtMs: 1784498400000,
    timing: "timed",
    eventKind: "task",
    participation: "accepted",
    availability: "busy",
    surfaces: { menuBar: "inherit", desktopWidget: "inherit", upNext: "pin" },
    source: null,
  },
  {
    id: 110,
    calendarId: 4,
    title: asciiBytes("Pay card"),
    location: asciiBytes(""),
    startsAtMs: 1784073600000,
    endsAtMs: 1784160000000,
    timing: "all_day",
    eventKind: "task",
    participation: "accepted",
    availability: "free",
    surfaces: { menuBar: "hide", desktopWidget: "hide", upNext: "hide" },
    source: null,
  },
];

export const WIDGET_RULE: SurfaceRule = {
  surface: "desktop_widget",
  maxEvents: 3,
  horizonMinutes: 10080,
  includeAllDay: false,
  includeDeclined: false,
};

export const WEEK_DAYS_PREVIOUS: readonly WeekDayHeader[] = [
  { id: 1, name: asciiBytes("MON"), day: 6, today: false },
  { id: 2, name: asciiBytes("TUE"), day: 7, today: false },
  { id: 3, name: asciiBytes("WED"), day: 8, today: false },
  { id: 4, name: asciiBytes("THU"), day: 9, today: false },
  { id: 5, name: asciiBytes("FRI"), day: 10, today: false },
  { id: 6, name: asciiBytes("SAT"), day: 11, today: false },
  { id: 7, name: asciiBytes("SUN"), day: 12, today: false },
];

export const WEEK_DAYS_CURRENT: readonly WeekDayHeader[] = [
  { id: 1, name: asciiBytes("MON"), day: 13, today: false },
  { id: 2, name: asciiBytes("TUE"), day: 14, today: false },
  { id: 3, name: asciiBytes("WED"), day: 15, today: true },
  { id: 4, name: asciiBytes("THU"), day: 16, today: false },
  { id: 5, name: asciiBytes("FRI"), day: 17, today: false },
  { id: 6, name: asciiBytes("SAT"), day: 18, today: false },
  { id: 7, name: asciiBytes("SUN"), day: 19, today: false },
];

export const WEEK_DAYS_NEXT: readonly WeekDayHeader[] = [
  { id: 1, name: asciiBytes("MON"), day: 20, today: false },
  { id: 2, name: asciiBytes("TUE"), day: 21, today: false },
  { id: 3, name: asciiBytes("WED"), day: 22, today: false },
  { id: 4, name: asciiBytes("THU"), day: 23, today: false },
  { id: 5, name: asciiBytes("FRI"), day: 24, today: false },
  { id: 6, name: asciiBytes("SAT"), day: 25, today: false },
  { id: 7, name: asciiBytes("SUN"), day: 26, today: false },
];

export const HOUR_ROWS: readonly HourRow[] = [
  { id: 6, label: asciiBytes("6 AM") },
  { id: 7, label: asciiBytes("7 AM") },
  { id: 8, label: asciiBytes("8 AM") },
  { id: 9, label: asciiBytes("9 AM") },
  { id: 10, label: asciiBytes("10 AM") },
  { id: 11, label: asciiBytes("11 AM") },
  { id: 12, label: asciiBytes("12 PM") },
  { id: 13, label: asciiBytes("1 PM") },
  { id: 14, label: asciiBytes("2 PM") },
  { id: 15, label: asciiBytes("3 PM") },
  { id: 16, label: asciiBytes("4 PM") },
  { id: 17, label: asciiBytes("5 PM") },
  { id: 18, label: asciiBytes("6 PM") },
  { id: 19, label: asciiBytes("7 PM") },
  { id: 20, label: asciiBytes("8 PM") },
  { id: 21, label: asciiBytes("9 PM") },
];

export const WEEK_EVENT_BLOCKS: readonly WeekEventBlock[] = [
  { eventId: 101, calendarId: 1, dayIndex: 0, gapBefore: 216, height: 72, title: asciiBytes("Weekly planning"), timeLabel: asciiBytes("9:00–10:00"), location: asciiBytes("Desk"), tone: "surface", pinned: false },
  { eventId: 102, calendarId: 1, dayIndex: 1, gapBefore: 288, height: 72, title: asciiBytes("Design review"), timeLabel: asciiBytes("10:00–11:00"), location: asciiBytes("Studio"), tone: "surface", pinned: false },
  { eventId: 103, calendarId: 3, dayIndex: 2, gapBefore: 288, height: 132, title: asciiBytes("Deep work — calendar layout"), timeLabel: asciiBytes("10:00–12:00"), location: asciiBytes("Focus mode"), tone: "accent", pinned: true },
  { eventId: 104, calendarId: 2, dayIndex: 2, gapBefore: 144, height: 72, title: asciiBytes("Dentist"), timeLabel: asciiBytes("2:00–3:00"), location: asciiBytes("Greenpoint Dental"), tone: "muted", pinned: false },
  { eventId: 105, calendarId: 1, dayIndex: 3, gapBefore: 288, height: 72, title: asciiBytes("Project review"), timeLabel: asciiBytes("10:00–11:00 · tentative"), location: asciiBytes("Meet"), tone: "surface", pinned: false },
  { eventId: 106, calendarId: 3, dayIndex: 4, gapBefore: 216, height: 132, title: asciiBytes("Ship the first native pass"), timeLabel: asciiBytes("9:00–11:00"), location: asciiBytes("Focus mode"), tone: "accent", pinned: true },
  { eventId: 107, calendarId: 2, dayIndex: 4, gapBefore: 576, height: 96, title: asciiBytes("Dinner with Maya"), timeLabel: asciiBytes("7:00–9:00"), location: asciiBytes("Win Son"), tone: "muted", pinned: false },
  { eventId: 108, calendarId: 2, dayIndex: 5, gapBefore: 288, height: 72, title: asciiBytes("Yoga"), timeLabel: asciiBytes("10:00–11:00"), location: asciiBytes("McCarren Park"), tone: "muted", pinned: false },
  { eventId: 109, calendarId: 3, dayIndex: 6, gapBefore: 792, height: 72, title: asciiBytes("Weekly reset"), timeLabel: asciiBytes("5:00–6:00"), location: asciiBytes("Home"), tone: "surface", pinned: true },
];

export const MONTH_CELLS: readonly MonthCell[] = [
  { id: 1, day: 29, inMonth: false, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 2, day: 30, inMonth: false, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 3, day: 1, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 4, day: 2, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 5, day: 3, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Independence Day observed"), hasEvent2: false, event2: asciiBytes("") },
  { id: 6, day: 4, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 7, day: 5, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 8, day: 6, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 9, day: 7, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Call Mom"), hasEvent2: false, event2: asciiBytes("") },
  { id: 10, day: 8, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 11, day: 9, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Writing block"), hasEvent2: false, event2: asciiBytes("") },
  { id: 12, day: 10, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 13, day: 11, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 14, day: 12, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 15, day: 13, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Weekly planning"), hasEvent2: false, event2: asciiBytes("") },
  { id: 16, day: 14, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Design review"), hasEvent2: false, event2: asciiBytes("") },
  { id: 17, day: 15, inMonth: true, today: true, hasEvent1: true, event1: asciiBytes("Deep work"), hasEvent2: true, event2: asciiBytes("Dentist") },
  { id: 18, day: 16, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Project review"), hasEvent2: false, event2: asciiBytes("") },
  { id: 19, day: 17, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Ship first pass"), hasEvent2: true, event2: asciiBytes("Dinner with Maya") },
  { id: 20, day: 18, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Yoga"), hasEvent2: false, event2: asciiBytes("") },
  { id: 21, day: 19, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Weekly reset"), hasEvent2: false, event2: asciiBytes("") },
  { id: 22, day: 20, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 23, day: 21, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Research"), hasEvent2: false, event2: asciiBytes("") },
  { id: 24, day: 22, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 25, day: 23, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Therapy"), hasEvent2: false, event2: asciiBytes("") },
  { id: 26, day: 24, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 27, day: 25, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Farmers market"), hasEvent2: false, event2: asciiBytes("") },
  { id: 28, day: 26, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 29, day: 27, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Plan August"), hasEvent2: false, event2: asciiBytes("") },
  { id: 30, day: 28, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 31, day: 29, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Deep work"), hasEvent2: false, event2: asciiBytes("") },
  { id: 32, day: 30, inMonth: true, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 33, day: 31, inMonth: true, today: false, hasEvent1: true, event1: asciiBytes("Month review"), hasEvent2: false, event2: asciiBytes("") },
  { id: 34, day: 1, inMonth: false, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
  { id: 35, day: 2, inMonth: false, today: false, hasEvent1: false, event1: asciiBytes(""), hasEvent2: false, event2: asciiBytes("") },
];
