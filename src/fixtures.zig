//! Deterministic first-pass data. Canonical records remain pixel-free; week
//! blocks are an explicit presentation projection used by the prototype.

const calendar = @import("domain/calendar.zig");
const ranking = @import("domain/surface_ranking.zig");

pub const EventTone = enum { accent, surface, muted };

pub const WeekDayHeader = struct {
    id: u64,
    name: []const u8,
    day: u8,
    today: bool,
};

pub const HourRow = struct {
    id: u64,
    label: []const u8,
};

pub const WeekEventBlock = struct {
    event_id: u64,
    calendar_id: u64,
    day_index: u8,
    gap_before: f32,
    height: f32,
    title: []const u8,
    time_label: []const u8,
    location: []const u8,
    tone: EventTone,
    pinned: bool,
};

pub const MonthCell = struct {
    id: u64,
    day: u8,
    in_month: bool,
    today: bool,
    has_event1: bool,
    event1: []const u8,
    has_event2: bool,
    event2: []const u8,
};

pub const fixture_now_ms: i64 = 1_784_120_400_000;

pub const calendar_visibility = [_]calendar.CalendarVisibility{
    .{ .id = 1, .name = "Work", .color = .indigo, .visible = true },
    .{ .id = 2, .name = "Personal", .color = .plum, .visible = true },
    .{ .id = 3, .name = "Focus", .color = .sea, .visible = true },
    .{ .id = 4, .name = "Reminders", .color = .sand, .visible = false },
};

pub const calendar_events = [_]calendar.CalendarEvent{
    .{ .id = 101, .calendar_id = 1, .title = "Weekly planning", .location = "Desk", .starts_at_ms = 1_783_947_600_000, .ends_at_ms = 1_783_951_200_000, .timing = .timed, .event_kind = .meeting, .participation = .accepted, .availability = .busy, .surfaces = .{ .menu_bar = .hide, .desktop_widget = .hide, .up_next = .hide } },
    .{ .id = 102, .calendar_id = 1, .title = "Design review", .location = "Studio", .starts_at_ms = 1_784_037_600_000, .ends_at_ms = 1_784_041_200_000, .timing = .timed, .event_kind = .meeting, .participation = .accepted, .availability = .busy, .surfaces = .{ .menu_bar = .inherit, .desktop_widget = .inherit, .up_next = .inherit } },
    .{ .id = 103, .calendar_id = 3, .title = "Deep work — calendar layout", .location = "Focus mode", .starts_at_ms = 1_784_124_000_000, .ends_at_ms = 1_784_131_200_000, .timing = .timed, .event_kind = .focus, .participation = .accepted, .availability = .busy, .surfaces = .{ .menu_bar = .pin, .desktop_widget = .pin, .up_next = .pin } },
    .{ .id = 104, .calendar_id = 2, .title = "Dentist", .location = "Greenpoint Dental", .starts_at_ms = 1_784_138_400_000, .ends_at_ms = 1_784_142_000_000, .timing = .timed, .event_kind = .appointment, .participation = .accepted, .availability = .busy, .surfaces = .{ .menu_bar = .inherit, .desktop_widget = .inherit, .up_next = .inherit } },
    .{ .id = 105, .calendar_id = 1, .title = "Project review", .location = "Meet", .starts_at_ms = 1_784_210_400_000, .ends_at_ms = 1_784_214_000_000, .timing = .timed, .event_kind = .meeting, .participation = .tentative, .availability = .busy, .surfaces = .{ .menu_bar = .inherit, .desktop_widget = .inherit, .up_next = .inherit } },
    .{ .id = 106, .calendar_id = 3, .title = "Ship the first native pass", .location = "Focus mode", .starts_at_ms = 1_784_293_200_000, .ends_at_ms = 1_784_300_400_000, .timing = .timed, .event_kind = .focus, .participation = .accepted, .availability = .busy, .surfaces = .{ .menu_bar = .inherit, .desktop_widget = .pin, .up_next = .inherit } },
    .{ .id = 107, .calendar_id = 2, .title = "Dinner with Maya", .location = "Win Son", .starts_at_ms = 1_784_329_200_000, .ends_at_ms = 1_784_336_400_000, .timing = .timed, .event_kind = .personal, .participation = .accepted, .availability = .free, .surfaces = .{ .menu_bar = .hide, .desktop_widget = .inherit, .up_next = .hide } },
    .{ .id = 108, .calendar_id = 2, .title = "Yoga", .location = "McCarren Park", .starts_at_ms = 1_784_383_200_000, .ends_at_ms = 1_784_386_800_000, .timing = .timed, .event_kind = .personal, .participation = .accepted, .availability = .free, .surfaces = .{ .menu_bar = .inherit, .desktop_widget = .inherit, .up_next = .inherit } },
    .{ .id = 109, .calendar_id = 3, .title = "Weekly reset", .location = "Home", .starts_at_ms = 1_784_494_800_000, .ends_at_ms = 1_784_498_400_000, .timing = .timed, .event_kind = .task, .participation = .accepted, .availability = .busy, .surfaces = .{ .menu_bar = .inherit, .desktop_widget = .inherit, .up_next = .pin } },
    .{ .id = 110, .calendar_id = 4, .title = "Pay card", .location = "", .starts_at_ms = 1_784_073_600_000, .ends_at_ms = 1_784_160_000_000, .timing = .all_day, .event_kind = .task, .participation = .accepted, .availability = .free, .surfaces = .{ .menu_bar = .hide, .desktop_widget = .hide, .up_next = .hide } },
};

pub const widget_rule: ranking.SurfaceRule = .{
    .surface = .desktop_widget,
    .max_events = 3,
    .horizon_minutes = 10_080,
    .include_all_day = false,
    .include_declined = false,
};

pub const week_days_previous = [_]WeekDayHeader{
    dayHeader(1, "MON", 6, false),  dayHeader(2, "TUE", 7, false),  dayHeader(3, "WED", 8, false),
    dayHeader(4, "THU", 9, false),  dayHeader(5, "FRI", 10, false), dayHeader(6, "SAT", 11, false),
    dayHeader(7, "SUN", 12, false),
};

pub const week_days_current = [_]WeekDayHeader{
    dayHeader(1, "MON", 13, false), dayHeader(2, "TUE", 14, false), dayHeader(3, "WED", 15, true),
    dayHeader(4, "THU", 16, false), dayHeader(5, "FRI", 17, false), dayHeader(6, "SAT", 18, false),
    dayHeader(7, "SUN", 19, false),
};

pub const week_days_next = [_]WeekDayHeader{
    dayHeader(1, "MON", 20, false), dayHeader(2, "TUE", 21, false), dayHeader(3, "WED", 22, false),
    dayHeader(4, "THU", 23, false), dayHeader(5, "FRI", 24, false), dayHeader(6, "SAT", 25, false),
    dayHeader(7, "SUN", 26, false),
};

pub const hour_rows = [_]HourRow{
    .{ .id = 6, .label = "6 AM" },   .{ .id = 7, .label = "7 AM" },   .{ .id = 8, .label = "8 AM" },   .{ .id = 9, .label = "9 AM" },
    .{ .id = 10, .label = "10 AM" }, .{ .id = 11, .label = "11 AM" }, .{ .id = 12, .label = "12 PM" }, .{ .id = 13, .label = "1 PM" },
    .{ .id = 14, .label = "2 PM" },  .{ .id = 15, .label = "3 PM" },  .{ .id = 16, .label = "4 PM" },  .{ .id = 17, .label = "5 PM" },
    .{ .id = 18, .label = "6 PM" },  .{ .id = 19, .label = "7 PM" },  .{ .id = 20, .label = "8 PM" },  .{ .id = 21, .label = "9 PM" },
};

pub const week_event_blocks = [_]WeekEventBlock{
    weekBlock(101, 1, 0, 216, 72, "Weekly planning", "9:00–10:00", "Desk", .surface, false),
    weekBlock(102, 1, 1, 288, 72, "Design review", "10:00–11:00", "Studio", .surface, false),
    weekBlock(103, 3, 2, 288, 132, "Deep work — calendar layout", "10:00–12:00", "Focus mode", .accent, true),
    weekBlock(104, 2, 2, 144, 72, "Dentist", "2:00–3:00", "Greenpoint Dental", .muted, false),
    weekBlock(105, 1, 3, 288, 72, "Project review", "10:00–11:00 · tentative", "Meet", .surface, false),
    weekBlock(106, 3, 4, 216, 132, "Ship the first native pass", "9:00–11:00", "Focus mode", .accent, true),
    weekBlock(107, 2, 4, 576, 96, "Dinner with Maya", "7:00–9:00", "Win Son", .muted, false),
    weekBlock(108, 2, 5, 288, 72, "Yoga", "10:00–11:00", "McCarren Park", .muted, false),
    weekBlock(109, 3, 6, 792, 72, "Weekly reset", "5:00–6:00", "Home", .surface, true),
};

pub const month_cells = [_]MonthCell{
    monthCell(1, 29, false, false, "", ""),                                monthCell(2, 30, false, false, "", ""),                        monthCell(3, 1, true, false, "", ""),
    monthCell(4, 2, true, false, "", ""),                                  monthCell(5, 3, true, false, "Independence Day observed", ""), monthCell(6, 4, true, false, "", ""),
    monthCell(7, 5, true, false, "", ""),                                  monthCell(8, 6, true, false, "", ""),                          monthCell(9, 7, true, false, "Call Mom", ""),
    monthCell(10, 8, true, false, "", ""),                                 monthCell(11, 9, true, false, "Writing block", ""),            monthCell(12, 10, true, false, "", ""),
    monthCell(13, 11, true, false, "", ""),                                monthCell(14, 12, true, false, "", ""),                        monthCell(15, 13, true, false, "Weekly planning", ""),
    monthCell(16, 14, true, false, "Design review", ""),                   monthCell(17, 15, true, true, "Deep work", "Dentist"),         monthCell(18, 16, true, false, "Project review", ""),
    monthCell(19, 17, true, false, "Ship first pass", "Dinner with Maya"), monthCell(20, 18, true, false, "Yoga", ""),                    monthCell(21, 19, true, false, "Weekly reset", ""),
    monthCell(22, 20, true, false, "", ""),                                monthCell(23, 21, true, false, "Research", ""),                monthCell(24, 22, true, false, "", ""),
    monthCell(25, 23, true, false, "Therapy", ""),                         monthCell(26, 24, true, false, "", ""),                        monthCell(27, 25, true, false, "Farmers market", ""),
    monthCell(28, 26, true, false, "", ""),                                monthCell(29, 27, true, false, "Plan August", ""),             monthCell(30, 28, true, false, "", ""),
    monthCell(31, 29, true, false, "Deep work", ""),                       monthCell(32, 30, true, false, "", ""),                        monthCell(33, 31, true, false, "Month review", ""),
    monthCell(34, 1, false, false, "", ""),                                monthCell(35, 2, false, false, "", ""),
};

fn dayHeader(id: u64, name: []const u8, day: u8, today: bool) WeekDayHeader {
    return .{ .id = id, .name = name, .day = day, .today = today };
}

fn weekBlock(id: u64, calendar_id: u64, day_index: u8, gap: f32, height: f32, title: []const u8, time_label: []const u8, location: []const u8, tone: EventTone, pinned: bool) WeekEventBlock {
    return .{ .event_id = id, .calendar_id = calendar_id, .day_index = day_index, .gap_before = gap, .height = height, .title = title, .time_label = time_label, .location = location, .tone = tone, .pinned = pinned };
}

fn monthCell(id: u64, day: u8, in_month: bool, today: bool, event1: []const u8, event2: []const u8) MonthCell {
    return .{ .id = id, .day = day, .in_month = in_month, .today = today, .has_event1 = event1.len > 0, .event1 = event1, .has_event2 = event2.len > 0, .event2 = event2 };
}
