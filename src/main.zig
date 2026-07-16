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
const sidebar_natural_width: f32 = 232;
const separator_extent: f32 = 1;
const initial_surface_width: f32 = 1380;
const initial_surface_height: f32 = 860;
const month_page_extent: f32 = 778;
const month_page_count: f32 = 3;
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

pub const ViewportSize = struct {
    width: f32,
    height: f32,
};

const ScrollOverridePhase = enum {
    idle,
    primed,
    target,
};

pub const Msg = union(enum) {
    show_week,
    show_month,
    go_today,
    toggle_sidebar,
    toggle_calendar: u64,
    select_event: u64,
    chrome_changed: native_sdk.WindowChrome,
    viewport_changed: ViewportSize,
    settle_scroll_override,

    pub const view_unbound = .{ "chrome_changed", "viewport_changed", "settle_scroll_override" };
};

pub const Model = struct {
    view: CalendarView = .week,
    sidebar_open: bool = true,
    week_scroll_offset: f32 = initial_surface_width - sidebar_natural_width - separator_extent,
    month_scroll_offset: f32 = month_page_extent,
    selected_event_id: ?u64 = null,
    calendars: @TypeOf(fixtures.calendar_visibility) = fixtures.calendar_visibility,
    chrome_leading: f32 = 0,
    chrome_trailing: f32 = 0,
    header_height: f32 = header_natural_height,
    viewport_width: f32 = initial_surface_width,
    viewport_height: f32 = initial_surface_height,
    viewport_initialized: bool = false,
    week_scroll_target: f32 = initial_surface_width - sidebar_natural_width - separator_extent,
    month_scroll_target: f32 = month_page_extent,
    week_scroll_override: bool = false,
    month_scroll_override: bool = false,
    scroll_override_phase: ScrollOverridePhase = .idle,

    // These are intentionally private to derived bindings and update().
    pub const view_unbound = .{
        "selected_event_id",
        "viewport_width",
        "viewport_height",
        "viewport_initialized",
        "week_scroll_target",
        "month_scroll_target",
        "week_scroll_override",
        "month_scroll_override",
        "scroll_override_phase",
    };

    pub fn period_label(_: *const Model) []const u8 {
        return "July 2026";
    }

    pub fn week_page_width(model: *const Model) f32 {
        const sidebar_extent = if (model.sidebar_open) sidebar_natural_width + separator_extent else 0;
        return @max(320, model.viewport_width - sidebar_extent);
    }

    pub fn week_track_width(model: *const Model) f32 {
        return model.week_page_width() * 3;
    }

    pub fn month_page_height(_: *const Model) f32 {
        return month_page_extent;
    }

    pub fn month_track_height(_: *const Model) f32 {
        return month_page_extent * month_page_count;
    }

    pub fn weekday_labels(_: *const Model) []const fixtures.WeekDayHeader {
        return &fixtures.week_days_current;
    }

    pub fn hour_rows(_: *const Model) []const fixtures.HourRow {
        return &fixtures.hour_rows;
    }

    pub fn previous_week_days(_: *const Model) []const fixtures.WeekDayHeader {
        return &fixtures.week_days_previous;
    }

    pub fn current_week_days(_: *const Model) []const fixtures.WeekDayHeader {
        return &fixtures.week_days_current;
    }

    pub fn next_week_days(_: *const Model) []const fixtures.WeekDayHeader {
        return &fixtures.week_days_next;
    }

    pub fn empty_week_events(_: *const Model) []const fixtures.WeekEventBlock {
        return &.{};
    }

    pub fn monday_events(model: *const Model, arena: std.mem.Allocator) []const fixtures.WeekEventBlock {
        return model.visibleEventsForDay(arena, 0);
    }

    pub fn tuesday_events(model: *const Model, arena: std.mem.Allocator) []const fixtures.WeekEventBlock {
        return model.visibleEventsForDay(arena, 1);
    }

    pub fn wednesday_events(model: *const Model, arena: std.mem.Allocator) []const fixtures.WeekEventBlock {
        return model.visibleEventsForDay(arena, 2);
    }

    pub fn thursday_events(model: *const Model, arena: std.mem.Allocator) []const fixtures.WeekEventBlock {
        return model.visibleEventsForDay(arena, 3);
    }

    pub fn friday_events(model: *const Model, arena: std.mem.Allocator) []const fixtures.WeekEventBlock {
        return model.visibleEventsForDay(arena, 4);
    }

    pub fn saturday_events(model: *const Model, arena: std.mem.Allocator) []const fixtures.WeekEventBlock {
        return model.visibleEventsForDay(arena, 5);
    }

    pub fn sunday_events(model: *const Model, arena: std.mem.Allocator) []const fixtures.WeekEventBlock {
        return model.visibleEventsForDay(arena, 6);
    }

    pub fn previous_month_cells(_: *const Model) []const fixtures.MonthCell {
        return &fixtures.month_cells_previous;
    }

    pub fn current_month_cells(_: *const Model) []const fixtures.MonthCell {
        return &fixtures.month_cells;
    }

    pub fn next_month_cells(_: *const Model) []const fixtures.MonthCell {
        return &fixtures.month_cells_next;
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

    fn visibleEventsForDay(model: *const Model, arena: std.mem.Allocator, day_index: u8) []const fixtures.WeekEventBlock {
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
        .go_today => {
            scheduleWeekScroll(model, model.week_page_width());
            scheduleMonthScroll(model, month_page_extent);
        },
        .toggle_sidebar => {
            const old_page_width = model.week_page_width();
            model.sidebar_open = !model.sidebar_open;
            scheduleWeekScroll(model, scaledOffset(model.week_scroll_offset, old_page_width, model.week_page_width()));
        },
        .toggle_calendar => |id| for (&model.calendars) |*item| {
            if (item.id == id) {
                item.visible = !item.visible;
                break;
            }
        },
        .select_event => |id| model.selected_event_id = if (model.selected_event_id == id) null else id,
        .chrome_changed => |chrome| {
            model.chrome_leading = chrome.insets.left;
            model.chrome_trailing = chrome.insets.right;
            model.header_height = @max(header_natural_height, chrome.insets.top);
        },
        .viewport_changed => |viewport| {
            const was_initialized = model.viewport_initialized;
            const old_page_width = model.week_page_width();
            model.viewport_width = @max(1, viewport.width);
            model.viewport_height = @max(1, viewport.height);
            const target = if (was_initialized)
                scaledOffset(model.week_scroll_offset, old_page_width, model.week_page_width())
            else
                model.week_page_width();
            model.viewport_initialized = true;
            scheduleWeekScroll(model, target);
        },
        .settle_scroll_override => switch (model.scroll_override_phase) {
            .idle => {},
            .primed => {
                if (model.week_scroll_override) model.week_scroll_offset = model.week_scroll_target;
                if (model.month_scroll_override) model.month_scroll_offset = model.month_scroll_target;
                model.scroll_override_phase = .target;
            },
            .target => {
                model.week_scroll_override = false;
                model.month_scroll_override = false;
                model.scroll_override_phase = .idle;
            },
        },
    }
}

pub fn onChrome(chrome: native_sdk.WindowChrome) ?Msg {
    return .{ .chrome_changed = chrome };
}

pub fn onFrame(model: *const Model, frame: native_sdk.GpuFrame) ?Msg {
    if (model.scroll_override_phase != .idle) return .settle_scroll_override;
    if (@abs(model.viewport_width - frame.size.width) <= 0.5 and @abs(model.viewport_height - frame.size.height) <= 0.5) return null;
    return .{ .viewport_changed = .{ .width = frame.size.width, .height = frame.size.height } };
}

pub fn syncRuntimeState(model: *Model, layout: canvas.WidgetLayoutTree) void {
    for (layout.nodes) |node| {
        if (node.widget.kind != .scroll_view) continue;
        if (!model.week_scroll_override and std.mem.eql(u8, node.widget.semantics.label, "Week pages")) {
            model.week_scroll_offset = node.widget.value;
        } else if (!model.month_scroll_override and std.mem.eql(u8, node.widget.semantics.label, "Month pages")) {
            model.month_scroll_offset = node.widget.value;
        }
    }
}

fn scheduleWeekScroll(model: *Model, target: f32) void {
    model.week_scroll_target = target;
    model.week_scroll_offset = target + 1;
    model.week_scroll_override = true;
    model.scroll_override_phase = .primed;
}

fn scheduleMonthScroll(model: *Model, target: f32) void {
    model.month_scroll_target = target;
    model.month_scroll_offset = target + 1;
    model.month_scroll_override = true;
    model.scroll_override_phase = .primed;
}

fn scaledOffset(offset: f32, old_extent: f32, new_extent: f32) f32 {
    if (old_extent <= 0) return new_extent;
    return offset / old_extent * new_extent;
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
        .on_frame = onFrame,
        .sync = syncRuntimeState,
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
