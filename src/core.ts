import { asciiBytes } from "@native-sdk/core";
import {
  type ChromeButtons,
  type ChromeInsets,
  type ScrollState,
} from "@native-sdk/core/events";
import type {
  Bytes,
  CalendarVisibility,
} from "./domain/calendar.ts";
import {
  overrideForSurface,
  rankEventsForSurface,
} from "./domain/surface-ranking.ts";
import {
  CALENDAR_EVENTS,
  CALENDAR_VISIBILITY,
  FIXTURE_NOW_MS,
  HOUR_ROWS,
  MONTH_CELLS,
  WEEK_DAYS_CURRENT,
  WEEK_DAYS_NEXT,
  WEEK_DAYS_PREVIOUS,
  WEEK_EVENT_BLOCKS,
  WIDGET_RULE,
  type HourRow,
  type MonthCell,
  type WeekDayHeader,
  type WeekEventBlock,
} from "./fixtures.ts";

export type CalendarView = "week" | "month";

export interface WidgetEvent {
  readonly id: number;
  readonly title: Bytes;
  readonly timeLabel: Bytes;
  readonly pinned: boolean;
}

export interface Model {
  readonly view: CalendarView;
  readonly sidebarOpen: boolean;
  readonly weekOffset: number;
  readonly monthOffset: number;
  readonly selectedEventId: number | null;
  readonly calendars: readonly CalendarVisibility[];
  readonly timelineScrollTop: number;
  readonly chromeLeading: number;
  readonly chromeTrailing: number;
  readonly headerHeight: number;
}

export type Msg =
  | { readonly kind: "show_week" }
  | { readonly kind: "show_month" }
  | { readonly kind: "go_previous" }
  | { readonly kind: "go_next" }
  | { readonly kind: "go_today" }
  | { readonly kind: "toggle_sidebar" }
  | { readonly kind: "toggle_calendar"; readonly id: number }
  | { readonly kind: "select_event"; readonly id: number }
  | { readonly kind: "timeline_scrolled"; readonly scroll: ScrollState }
  | {
      readonly kind: "chrome_changed";
      readonly insets: ChromeInsets;
      readonly buttons: ChromeButtons;
      readonly tabsProjected: boolean;
    };

const HEADER_NATURAL_HEIGHT = 52;

export const chromeMsg = "chrome_changed";

export const viewUnbound = [
  "weekOffset",
  "monthOffset",
  "selectedEventId",
  "chrome_changed",
] as const;

export function initialModel(): Model {
  return {
    view: "week",
    sidebarOpen: true,
    weekOffset: 0,
    monthOffset: 0,
    selectedEventId: null,
    calendars: CALENDAR_VISIBILITY,
    timelineScrollTop: 144,
    chromeLeading: 0,
    chromeTrailing: 0,
    headerHeight: HEADER_NATURAL_HEIGHT,
  };
}

function calendarVisible(model: Model, calendarId: number): boolean {
  const calendar = model.calendars.find((item) => item.id === calendarId);
  if (calendar === undefined) return false;
  return calendar.visible;
}

function eventsForDay(model: Model, dayIndex: number): readonly WeekEventBlock[] {
  if (model.weekOffset !== 0) return [];
  return WEEK_EVENT_BLOCKS.filter(
    (event) => event.dayIndex === dayIndex && calendarVisible(model, event.calendarId),
  );
}

export function periodLabel(model: Model): Bytes {
  if (model.view === "month") {
    if (model.monthOffset < 0) return asciiBytes("June 2026");
    if (model.monthOffset > 0) return asciiBytes("August 2026");
    return asciiBytes("July 2026");
  }
  if (model.weekOffset < 0) return asciiBytes("July 6–12, 2026");
  if (model.weekOffset > 0) return asciiBytes("July 20–26, 2026");
  return asciiBytes("July 13–19, 2026");
}

export function cannotGoPrevious(model: Model): boolean {
  if (model.view === "month") return model.monthOffset <= -1;
  return model.weekOffset <= -1;
}

export function cannotGoNext(model: Model): boolean {
  if (model.view === "month") return model.monthOffset >= 1;
  return model.weekOffset >= 1;
}

export function atToday(model: Model): boolean {
  if (model.view === "month") return model.monthOffset === 0;
  return model.weekOffset === 0;
}

export function weekDays(model: Model): readonly WeekDayHeader[] {
  if (model.weekOffset < 0) return WEEK_DAYS_PREVIOUS;
  if (model.weekOffset > 0) return WEEK_DAYS_NEXT;
  return WEEK_DAYS_CURRENT;
}

export function weekdayLabels(model: Model): readonly WeekDayHeader[] {
  if (model.view === "week") return weekDays(model);
  return WEEK_DAYS_CURRENT;
}

export function hourRows(model: Model): readonly HourRow[] {
  if (model.view === "month") return HOUR_ROWS;
  return HOUR_ROWS;
}

export function mondayEvents(model: Model): readonly WeekEventBlock[] {
  return eventsForDay(model, 0);
}

export function tuesdayEvents(model: Model): readonly WeekEventBlock[] {
  return eventsForDay(model, 1);
}

export function wednesdayEvents(model: Model): readonly WeekEventBlock[] {
  return eventsForDay(model, 2);
}

export function thursdayEvents(model: Model): readonly WeekEventBlock[] {
  return eventsForDay(model, 3);
}

export function fridayEvents(model: Model): readonly WeekEventBlock[] {
  return eventsForDay(model, 4);
}

export function saturdayEvents(model: Model): readonly WeekEventBlock[] {
  return eventsForDay(model, 5);
}

export function sundayEvents(model: Model): readonly WeekEventBlock[] {
  return eventsForDay(model, 6);
}

export function monthCells(model: Model): readonly MonthCell[] {
  if (model.monthOffset !== 0) return [];
  return MONTH_CELLS;
}

export function hasMonthData(model: Model): boolean {
  return model.monthOffset === 0;
}

export function widgetEvents(model: Model): readonly WidgetEvent[] {
  const ranked = rankEventsForSurface(CALENDAR_EVENTS, WIDGET_RULE, FIXTURE_NOW_MS);
  const visible: WidgetEvent[] = [];
  for (const item of ranked) {
    for (const event of CALENDAR_EVENTS) {
      if (event.id === item.eventId && calendarVisible(model, event.calendarId)) {
        for (const block of WEEK_EVENT_BLOCKS) {
          if (block.eventId === event.id) {
            visible.push({
              id: event.id,
              title: event.title,
              timeLabel: block.timeLabel,
              pinned: overrideForSurface(event, "desktop_widget") === "pin",
            });
            break;
          }
        }
      }
    }
  }
  return visible;
}

export function selectionTitle(model: Model): Bytes {
  if (model.selectedEventId === null) return asciiBytes("Select an event to inspect it");
  const event = CALENDAR_EVENTS.find((candidate) => candidate.id === model.selectedEventId);
  if (event === undefined) return asciiBytes("Event unavailable");
  return event.title;
}

export function update(model: Model, msg: Msg): Model {
  switch (msg.kind) {
    case "show_week":
      return { ...model, view: "week" };
    case "show_month":
      return { ...model, view: "month" };
    case "go_previous":
      if (model.view === "month") {
        if (model.monthOffset <= -1) return model;
        return { ...model, monthOffset: model.monthOffset - 1, selectedEventId: null };
      } else {
        if (model.weekOffset <= -1) return model;
        return { ...model, weekOffset: model.weekOffset - 1, selectedEventId: null };
      }
    case "go_next":
      if (model.view === "month") {
        if (model.monthOffset >= 1) return model;
        return { ...model, monthOffset: model.monthOffset + 1, selectedEventId: null };
      } else {
        if (model.weekOffset >= 1) return model;
        return { ...model, weekOffset: model.weekOffset + 1, selectedEventId: null };
      }
    case "go_today":
      return { ...model, weekOffset: 0, monthOffset: 0 };
    case "toggle_sidebar":
      return { ...model, sidebarOpen: !model.sidebarOpen };
    case "toggle_calendar":
      return {
        ...model,
        calendars: model.calendars.map((calendar) =>
          calendar.id === msg.id ? { ...calendar, visible: !calendar.visible } : calendar,
        ),
      };
    case "select_event":
      return {
        ...model,
        selectedEventId: model.selectedEventId === msg.id ? null : msg.id,
      };
    case "timeline_scrolled":
      return { ...model, timelineScrollTop: msg.scroll.offset };
    case "chrome_changed":
      return {
        ...model,
        chromeLeading: msg.insets.left,
        chromeTrailing: msg.insets.right,
        headerHeight: Math.max(HEADER_NATURAL_HEIGHT, msg.insets.top),
      };
  }
}
