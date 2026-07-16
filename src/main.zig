//! Zeit's native application core. Native markup owns presentation; Zig owns
//! typed state, messages, domain policy, and host-event boundaries.

const std = @import("std");
const builtin = @import("builtin");
const runner = @import("runner");
const native_sdk = @import("native_sdk");

const calendar = @import("domain/calendar.zig");
const ranking = @import("domain/surface_ranking.zig");
const fixtures = @import("fixtures.zig");

pub const panic = std.debug.FullPanic(native_sdk.debug.capturePanic);

const canvas = native_sdk.canvas;
const geometry = native_sdk.geometry;

pub const header_natural_height: f32 = 52;
const app_name = "zeit-desktop";
const app_display_name = "Zeit";
const app_id = "app.zeit.desktop";
const canvas_label = "zeit-canvas";
const app_permissions = [_][]const u8{ native_sdk.security.permission_command, native_sdk.security.permission_view };
const shell_views = [_]native_sdk.ShellView{
    .{ .label = canvas_label, .kind = .gpu_surface, .fill = true, .role = "Calendar canvas", .accessibility_label = "Zeit calendar", .gpu_backend = .metal, .gpu_pixel_format = .bgra8_unorm, .gpu_present_mode = .timer, .gpu_alpha_mode = .@"opaque", .gpu_color_space = .srgb, .gpu_vsync = true },
};
const shell_windows = [_]native_sdk.ShellWindow{.{
    .label = "main",
    .title = app_display_name,
    .width = 1380,
    .height = 860,
    .min_width = 1040,
    .min_height = 640,
    .restore_state = true,
    .restore_policy = .center_on_primary,
    .titlebar = .hidden_inset_tall,
    .views = &shell_views,
}};
pub const shell_scene: native_sdk.ShellConfig = .{ .windows = &shell_windows };

pub const CalendarView = enum { week, month };

pub const WidgetEvent = struct {
    id: u64,
    title: []const u8,
    time_label: []const u8,
    pinned: bool,
};

pub const Msg = union(enum) {
    show_week,
    show_month,
    go_previous,
    go_next,
    go_today,
    toggle_sidebar,
    toggle_calendar: u64,
    select_event: u64,
    timeline_scrolled: canvas.ScrollState,
    chrome_changed: native_sdk.WindowChrome,

    pub const view_unbound = .{"chrome_changed"};
};

pub const Model = struct {
    view: CalendarView = .week,
    sidebar_open: bool = true,
    week_offset: i8 = 0,
    month_offset: i8 = 0,
    selected_event_id: ?u64 = null,
    calendars: @TypeOf(fixtures.calendar_visibility) = fixtures.calendar_visibility,
    timeline_scroll_top: f32 = 144,
    chrome_leading: f32 = 0,
    chrome_trailing: f32 = 0,
    header_height: f32 = header_natural_height,

    // These are intentionally private to derived bindings and update().
    pub const view_unbound = .{ "week_offset", "month_offset", "selected_event_id" };

    pub fn period_label(model: *const Model) []const u8 {
        return switch (model.view) {
            .month => if (model.month_offset < 0)
                "June 2026"
            else if (model.month_offset > 0)
                "August 2026"
            else
                "July 2026",
            .week => if (model.week_offset < 0)
                "July 6–12, 2026"
            else if (model.week_offset > 0)
                "July 20–26, 2026"
            else
                "July 13–19, 2026",
        };
    }

    pub fn cannot_go_previous(model: *const Model) bool {
        return switch (model.view) {
            .month => model.month_offset <= -1,
            .week => model.week_offset <= -1,
        };
    }

    pub fn cannot_go_next(model: *const Model) bool {
        return switch (model.view) {
            .month => model.month_offset >= 1,
            .week => model.week_offset >= 1,
        };
    }

    pub fn at_today(model: *const Model) bool {
        return switch (model.view) {
            .month => model.month_offset == 0,
            .week => model.week_offset == 0,
        };
    }

    pub fn week_days(model: *const Model) []const fixtures.WeekDayHeader {
        if (model.week_offset < 0) return &fixtures.week_days_previous;
        if (model.week_offset > 0) return &fixtures.week_days_next;
        return &fixtures.week_days_current;
    }

    pub fn weekday_labels(model: *const Model) []const fixtures.WeekDayHeader {
        if (model.view == .week) return model.week_days();
        return &fixtures.week_days_current;
    }

    pub fn hour_rows(_: *const Model) []const fixtures.HourRow {
        return &fixtures.hour_rows;
    }

    pub fn monday_events(model: *const Model, arena: std.mem.Allocator) []const fixtures.WeekEventBlock {
        return model.eventsForDay(arena, 0);
    }

    pub fn tuesday_events(model: *const Model, arena: std.mem.Allocator) []const fixtures.WeekEventBlock {
        return model.eventsForDay(arena, 1);
    }

    pub fn wednesday_events(model: *const Model, arena: std.mem.Allocator) []const fixtures.WeekEventBlock {
        return model.eventsForDay(arena, 2);
    }

    pub fn thursday_events(model: *const Model, arena: std.mem.Allocator) []const fixtures.WeekEventBlock {
        return model.eventsForDay(arena, 3);
    }

    pub fn friday_events(model: *const Model, arena: std.mem.Allocator) []const fixtures.WeekEventBlock {
        return model.eventsForDay(arena, 4);
    }

    pub fn saturday_events(model: *const Model, arena: std.mem.Allocator) []const fixtures.WeekEventBlock {
        return model.eventsForDay(arena, 5);
    }

    pub fn sunday_events(model: *const Model, arena: std.mem.Allocator) []const fixtures.WeekEventBlock {
        return model.eventsForDay(arena, 6);
    }

    pub fn month_cells(model: *const Model) []const fixtures.MonthCell {
        if (model.month_offset != 0) return &.{};
        return &fixtures.month_cells;
    }

    pub fn has_month_data(model: *const Model) bool {
        return model.month_offset == 0;
    }

    pub fn widget_events(model: *const Model, arena: std.mem.Allocator) []const WidgetEvent {
        const rank_buffer = arena.alloc(ranking.RankedSurfaceEvent, fixtures.calendar_events.len) catch return &.{};
        const ranked = ranking.rankEventsForSurface(&fixtures.calendar_events, fixtures.widget_rule, fixtures.fixture_now_ms, rank_buffer) catch return &.{};
        const visible = arena.alloc(WidgetEvent, ranked.len) catch return &.{};
        var visible_count: usize = 0;

        for (ranked) |item| {
            const event = eventById(item.event_id) orelse continue;
            if (!model.calendarVisible(event.calendar_id)) continue;
            const block = blockByEventId(event.id) orelse continue;
            visible[visible_count] = .{
                .id = event.id,
                .title = event.title,
                .time_label = block.time_label,
                .pinned = ranking.overrideForSurface(event, .desktop_widget) == .pin,
            };
            visible_count += 1;
        }
        return visible[0..visible_count];
    }

    pub fn selection_title(model: *const Model) []const u8 {
        const selected = model.selected_event_id orelse return "Select an event to inspect it";
        const event = eventById(selected) orelse return "Event unavailable";
        return event.title;
    }

    fn calendarVisible(model: *const Model, calendar_id: u64) bool {
        for (model.calendars) |item| {
            if (item.id == calendar_id) return item.visible;
        }
        return false;
    }

    fn eventsForDay(model: *const Model, arena: std.mem.Allocator, day_index: u8) []const fixtures.WeekEventBlock {
        if (model.week_offset != 0) return &.{};
        const output = arena.alloc(fixtures.WeekEventBlock, fixtures.week_event_blocks.len) catch return &.{};
        var count: usize = 0;
        for (fixtures.week_event_blocks) |event| {
            if (event.day_index == day_index and model.calendarVisible(event.calendar_id)) {
                output[count] = event;
                count += 1;
            }
        }
        return output[0..count];
    }
};

pub fn initialModel() Model {
    return .{};
}

pub fn update(model: *Model, msg: Msg) void {
    switch (msg) {
        .show_week => model.view = .week,
        .show_month => model.view = .month,
        .go_previous => switch (model.view) {
            .month => if (model.month_offset > -1) {
                model.month_offset -= 1;
                model.selected_event_id = null;
            },
            .week => if (model.week_offset > -1) {
                model.week_offset -= 1;
                model.selected_event_id = null;
            },
        },
        .go_next => switch (model.view) {
            .month => if (model.month_offset < 1) {
                model.month_offset += 1;
                model.selected_event_id = null;
            },
            .week => if (model.week_offset < 1) {
                model.week_offset += 1;
                model.selected_event_id = null;
            },
        },
        .go_today => {
            model.week_offset = 0;
            model.month_offset = 0;
        },
        .toggle_sidebar => model.sidebar_open = !model.sidebar_open,
        .toggle_calendar => |id| for (&model.calendars) |*item| {
            if (item.id == id) {
                item.visible = !item.visible;
                break;
            }
        },
        .select_event => |id| model.selected_event_id = if (model.selected_event_id == id) null else id,
        .timeline_scrolled => |scroll| model.timeline_scroll_top = scroll.offset,
        .chrome_changed => |chrome| {
            model.chrome_leading = chrome.insets.left;
            model.chrome_trailing = chrome.insets.right;
            model.header_height = @max(header_natural_height, chrome.insets.top);
        },
    }
}

pub fn onChrome(chrome: native_sdk.WindowChrome) ?Msg {
    return .{ .chrome_changed = chrome };
}

fn eventById(id: u64) ?calendar.CalendarEvent {
    for (fixtures.calendar_events) |event| if (event.id == id) return event;
    return null;
}

fn blockByEventId(id: u64) ?fixtures.WeekEventBlock {
    for (fixtures.week_event_blocks) |block| if (block.event_id == id) return block;
    return null;
}

// Release builds compile markup at comptime. Debug keeps the interpreter only
// for file watching and swaps to it after the first hot-reload edit.
pub const AppUi = canvas.Ui(Msg);
pub const app_markup = @embedFile("app.native");
pub const CompiledZeitView = canvas.CompiledMarkupView(Model, Msg, app_markup);
const dev_markup_reload = builtin.mode == .Debug;
const ZeitApp = native_sdk.UiAppWithFeatures(Model, Msg, .{ .runtime_markup = dev_markup_reload });

pub fn main(init: std.process.Init) !void {
    const app_state = try std.heap.page_allocator.create(ZeitApp);
    defer std.heap.page_allocator.destroy(app_state);
    app_state.* = ZeitApp.init(std.heap.page_allocator, initialModel(), .{
        .name = app_name,
        .scene = shell_scene,
        .canvas_label = canvas_label,
        .update = update,
        .on_chrome = onChrome,
        .view = CompiledZeitView.build,
        .markup = if (dev_markup_reload)
            .{ .source = app_markup, .watch_path = "src/app.native", .io = init.io }
        else
            null,
        .theme = .geist,
        .theme_accent = canvas.Color.rgb8(95, 99, 216),
    });
    defer app_state.deinit();

    const window = shell_scene.windows[0];
    try runner.runWithOptions(app_state.app(), .{
        .app_name = app_name,
        .window_title = window.title orelse app_display_name,
        .bundle_id = app_id,
        .icon_path = "assets/icon.png",
        .default_frame = geometry.RectF.init(window.x orelse 0, window.y orelse 0, window.width, window.height),
        .restore_state = window.restore_state,
        .js_window_api = false,
        .security = .{
            .permissions = &app_permissions,
            .navigation = .{ .allowed_origins = &.{ "zero://inline", "zero://app" } },
        },
    }, init);
}

test {
    _ = @import("tests.zig");
}
