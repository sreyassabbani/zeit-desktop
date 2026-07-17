//! Zeit's native application core. Native markup owns presentation; Zig owns
//! typed state, messages, domain policy, and host-event boundaries.

const std = @import("std");
const builtin = @import("builtin");
const runner = @import("runner");
const native_sdk = @import("native_sdk");

const calendar = @import("domain/calendar.zig");
const civil = @import("domain/civil_date.zig");
const fixtures = @import("fixtures.zig");

pub const panic = std.debug.FullPanic(native_sdk.debug.capturePanic);

const canvas = native_sdk.canvas;
const geometry = native_sdk.geometry;

pub const header_natural_height: f32 = 96;
const sidebar_natural_width: f32 = 204;
const separator_extent: f32 = 1;
const initial_surface_width: f32 = 1380;
const initial_surface_height: f32 = 860;
const time_gutter_width: f32 = 52;
const calendar_page_count: usize = 5;
const calendar_page_count_extent: f32 = 5;
const recycler_center_slot: i32 = 2;
const recycler_center_extent: f32 = 2;
const month_page_extent: f32 = 772;
const initial_fortnight_page_width = initial_surface_width - sidebar_natural_width - separator_extent - time_gutter_width;
const fixture_fortnight_start: civil.CivilDate = .{ .year = 2026, .month = 7, .day = 13 };
const fixture_month: civil.YearMonth = .{ .year = 2026, .month = 7 };
const fixture_today: civil.CivilDate = .{ .year = 2026, .month = 7, .day = 15 };
const weekday_names = [_][]const u8{ "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN" };
const app_name = "zeit-desktop";
const app_display_name = "Zeit";
const app_id = "app.zeit.desktop";
pub const toggle_sidebar_command = "calendar.toggle-sidebar";
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

pub const CalendarView = enum { days14, month };

pub const ViewportSize = struct {
    width: f32,
    height: f32,
};

pub const FortnightDay = struct {
    id: u64,
    name: []const u8,
    day: u8,
    today: bool,
    events: []const fixtures.WeekEventBlock,
};

pub const FortnightPage = struct {
    slot_id: u64,
    label: []const u8,
    days: []const FortnightDay,
};

pub const MonthPage = struct {
    slot_id: u64,
    label: []const u8,
    cells: []const fixtures.MonthCell,
};

const ScrollOverridePhase = enum {
    idle,
    primed,
    target,
};

pub const Msg = union(enum) {
    show_days14,
    show_month,
    go_today,
    toggle_sidebar,
    toggle_calendar: u64,
    select_event: u64,
    chrome_changed: native_sdk.WindowChrome,
    viewport_changed: ViewportSize,
    recycle_fortnight_backward,
    recycle_fortnight_forward,
    recycle_month_backward,
    recycle_month_forward,
    settle_scroll_override,
    appearance_changed: native_sdk.Appearance,

    pub const view_unbound = .{ "chrome_changed", "viewport_changed", "settle_scroll_override", "appearance_changed" };
};

pub const Model = struct {
    view: CalendarView = .days14,
    sidebar_open: bool = true,
    fortnight_scroll_offset: f32 = initial_fortnight_page_width * recycler_center_extent,
    fortnight_vertical_offset: f32 = 0,
    month_scroll_offset: f32 = month_page_extent * recycler_center_extent,
    fortnight_window_start: i32 = -recycler_center_slot,
    month_window_start: i32 = -recycler_center_slot,
    selected_event_id: ?u64 = null,
    calendars: @TypeOf(fixtures.calendar_visibility) = fixtures.calendar_visibility,
    chrome_leading: f32 = 0,
    chrome_trailing: f32 = 0,
    header_height: f32 = header_natural_height,
    viewport_width: f32 = initial_surface_width,
    viewport_height: f32 = initial_surface_height,
    viewport_initialized: bool = false,
    fortnight_scroll_target: f32 = initial_fortnight_page_width * recycler_center_extent,
    month_scroll_target: f32 = month_page_extent * recycler_center_extent,
    fortnight_scroll_override: bool = false,
    month_scroll_override: bool = false,
    scroll_override_phase: ScrollOverridePhase = .idle,
    appearance: native_sdk.Appearance = .{},

    // These are intentionally private to derived bindings and update().
    pub const view_unbound = .{
        "selected_event_id",
        "viewport_width",
        "viewport_height",
        "viewport_initialized",
        "fortnight_window_start",
        "month_window_start",
        "fortnight_scroll_target",
        "month_scroll_target",
        "fortnight_scroll_override",
        "month_scroll_override",
        "scroll_override_phase",
        "appearance",
    };

    pub fn period_label(model: *const Model, arena: std.mem.Allocator) []const u8 {
        const visible_month = switch (model.view) {
            .days14 => days14: {
                const start = civil.addDays(fixture_fortnight_start, @as(i64, model.fortnight_window_start + recycler_center_slot) * 14);
                const focus = civil.addDays(start, 6);
                break :days14 civil.YearMonth{ .year = focus.year, .month = focus.month };
            },
            .month => civil.addMonths(fixture_month, model.month_window_start + recycler_center_slot),
        };
        return civil.formatMonthYear(arena, visible_month) catch "Calendar";
    }

    pub fn fortnight_page_width(model: *const Model) f32 {
        const sidebar_extent = if (model.sidebar_open) sidebar_natural_width + separator_extent else 0;
        return @max(320, model.viewport_width - sidebar_extent - time_gutter_width);
    }

    pub fn fortnight_track_width(model: *const Model) f32 {
        return model.fortnight_page_width() * calendar_page_count_extent;
    }

    pub fn month_page_height(_: *const Model) f32 {
        return month_page_extent;
    }

    pub fn month_track_height(_: *const Model) f32 {
        return month_page_extent * calendar_page_count_extent;
    }

    pub fn weekday_labels(_: *const Model) []const fixtures.WeekDayHeader {
        return &fixtures.week_days_current;
    }

    pub fn hour_rows(_: *const Model) []const fixtures.HourRow {
        return &fixtures.hour_rows;
    }

    pub fn fortnight_pages(model: *const Model, arena: std.mem.Allocator) []const FortnightPage {
        const pages = arena.alloc(FortnightPage, calendar_page_count) catch return &.{};
        for (pages, 0..) |*page, slot| {
            page.* = model.buildFortnightPage(arena, @intCast(slot));
        }
        return pages;
    }

    pub fn month_pages(model: *const Model, arena: std.mem.Allocator) []const MonthPage {
        const pages = arena.alloc(MonthPage, calendar_page_count) catch return &.{};
        for (pages, 0..) |*page, slot| {
            const month_offset = model.month_window_start + @as(i32, @intCast(slot));
            const value = civil.addMonths(fixture_month, month_offset);
            page.* = .{
                .slot_id = @intCast(slot),
                .label = civil.formatMonthYear(arena, value) catch "Month",
                .cells = monthCellsForOffset(arena, month_offset, value),
            };
        }
        return pages;
    }

    pub fn status_summary(model: *const Model, arena: std.mem.Allocator) []const u8 {
        if (model.selected_event_id) |selected| {
            const event = eventById(selected) orelse return "Event unavailable";
            const block = blockByEventId(selected) orelse return event.title;
            const calendar_name = calendarName(event.calendar_id);
            const widget_policy = surfacePolicyLabel(event.surfaces.desktop_widget);
            return std.fmt.allocPrint(arena, "{s}  ·  {s}  ·  {s}  ·  Widget {s}", .{
                event.title,
                block.time_label,
                calendar_name,
                widget_policy,
            }) catch event.title;
        }

        var visible_calendars: usize = 0;
        var visible_events: usize = 0;
        for (model.calendars) |item| {
            if (item.visible) visible_calendars += 1;
        }
        for (fixtures.week_event_blocks) |event| {
            if (model.calendarVisible(event.calendar_id)) visible_events += 1;
        }
        const view_label = switch (model.view) {
            .days14 => "14-day",
            .month => "Month",
        };
        return std.fmt.allocPrint(arena, "{s} view  ·  {d} events  ·  {d} calendars", .{
            view_label,
            visible_events,
            visible_calendars,
        }) catch view_label;
    }

    fn calendarVisible(model: *const Model, calendar_id: u64) bool {
        for (model.calendars) |item| {
            if (item.id == calendar_id) return item.visible;
        }
        return false;
    }

    fn buildFortnightPage(model: *const Model, arena: std.mem.Allocator, slot: i32) FortnightPage {
        const fortnight_offset = model.fortnight_window_start + slot;
        const start = civil.addDays(fixture_fortnight_start, @as(i64, fortnight_offset) * 14);
        const days = arena.alloc(FortnightDay, 14) catch return emptyFortnightPage(@intCast(slot));
        for (days, 0..) |*day, day_index| {
            const date = civil.addDays(start, @intCast(day_index));
            day.* = .{
                .id = day_index + 1,
                .name = weekday_names[day_index % weekday_names.len],
                .day = date.day,
                .today = civil.eql(date, fixture_today),
                .events = if (fortnight_offset == 0) model.visibleEventsForDay(arena, @intCast(day_index)) else &.{},
            };
        }

        return .{
            .slot_id = @intCast(slot),
            .label = civil.formatDayRange(arena, start, 14) catch "14 days",
            .days = days,
        };
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

fn emptyFortnightPage(slot_id: u64) FortnightPage {
    return .{
        .slot_id = slot_id,
        .label = "14 days",
        .days = &.{},
    };
}

fn monthCellsForOffset(arena: std.mem.Allocator, month_offset: i32, value: civil.YearMonth) []const fixtures.MonthCell {
    return switch (month_offset) {
        -1 => &fixtures.month_cells_previous,
        0 => &fixtures.month_cells,
        1 => &fixtures.month_cells_next,
        else => generatedMonthCells(arena, value),
    };
}

fn generatedMonthCells(arena: std.mem.Allocator, value: civil.YearMonth) []const fixtures.MonthCell {
    const cells = arena.alloc(fixtures.MonthCell, 42) catch return &.{};
    const first = civil.CivilDate{ .year = value.year, .month = value.month, .day = 1 };
    const grid_start = civil.addDays(first, -@as(i64, civil.mondayWeekday(first)));
    for (cells, 0..) |*cell, index| {
        const date = civil.addDays(grid_start, @intCast(index));
        cell.* = .{
            .id = index + 1,
            .day = date.day,
            .in_month = date.year == value.year and date.month == value.month,
            .today = civil.eql(date, fixture_today),
            .has_event1 = false,
            .event1 = "",
            .has_event2 = false,
            .event2 = "",
        };
    }
    return cells;
}

pub fn initialModel() Model {
    return .{};
}

pub fn update(model: *Model, msg: Msg) void {
    switch (msg) {
        .show_days14 => model.view = .days14,
        .show_month => model.view = .month,
        .go_today => {
            model.fortnight_window_start = -recycler_center_slot;
            model.month_window_start = -recycler_center_slot;
            scheduleFortnightScroll(model, model.fortnight_page_width() * recycler_center_extent);
            scheduleMonthScroll(model, month_page_extent * recycler_center_extent);
        },
        .toggle_sidebar => {
            const old_page_width = model.fortnight_page_width();
            model.sidebar_open = !model.sidebar_open;
            scheduleFortnightScroll(model, scaledOffset(model.fortnight_scroll_offset, old_page_width, model.fortnight_page_width()));
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
            const old_page_width = model.fortnight_page_width();
            model.viewport_width = @max(1, viewport.width);
            model.viewport_height = @max(1, viewport.height);
            const target = if (was_initialized)
                scaledOffset(model.fortnight_scroll_offset, old_page_width, model.fortnight_page_width())
            else
                model.fortnight_page_width() * recycler_center_extent;
            model.viewport_initialized = true;
            scheduleFortnightScroll(model, target);
        },
        .recycle_fortnight_backward => recycleFortnight(model, -1),
        .recycle_fortnight_forward => recycleFortnight(model, 1),
        .recycle_month_backward => recycleMonth(model, -1),
        .recycle_month_forward => recycleMonth(model, 1),
        .settle_scroll_override => switch (model.scroll_override_phase) {
            .idle => {},
            .primed => {
                if (model.fortnight_scroll_override) model.fortnight_scroll_offset = model.fortnight_scroll_target;
                if (model.month_scroll_override) model.month_scroll_offset = model.month_scroll_target;
                model.scroll_override_phase = .target;
            },
            .target => {
                model.fortnight_scroll_override = false;
                model.month_scroll_override = false;
                model.scroll_override_phase = .idle;
            },
        },
        .appearance_changed => |appearance| model.appearance = appearance,
    }
}

pub fn onAppearance(appearance: native_sdk.Appearance) ?Msg {
    return .{ .appearance_changed = appearance };
}

pub fn onCommand(name: []const u8) ?Msg {
    if (std.mem.eql(u8, name, toggle_sidebar_command)) return .toggle_sidebar;
    return null;
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
        if (!model.fortnight_scroll_override and std.mem.eql(u8, node.widget.semantics.label, "14-day pages")) {
            model.fortnight_scroll_offset = node.widget.value;
        } else if (std.mem.eql(u8, node.widget.semantics.label, "14-day grids")) {
            model.fortnight_vertical_offset = node.widget.value;
        } else if (!model.month_scroll_override and std.mem.eql(u8, node.widget.semantics.label, "Month pages")) {
            model.month_scroll_offset = node.widget.value;
        }
    }
}

fn recycleFortnight(model: *Model, delta: i32) void {
    model.fortnight_window_start += delta;
    const target = model.fortnight_scroll_offset - @as(f32, @floatFromInt(delta)) * model.fortnight_page_width();
    scheduleFortnightRebase(model, target);
}

fn recycleMonth(model: *Model, delta: i32) void {
    model.month_window_start += delta;
    const target = model.month_scroll_offset - @as(f32, @floatFromInt(delta)) * month_page_extent;
    scheduleMonthRebase(model, target);
}

fn scheduleFortnightScroll(model: *Model, target: f32) void {
    model.fortnight_scroll_target = target;
    model.fortnight_scroll_offset = target + 1;
    model.fortnight_scroll_override = true;
    model.scroll_override_phase = .primed;
}

fn scheduleMonthScroll(model: *Model, target: f32) void {
    model.month_scroll_target = target;
    model.month_scroll_offset = target + 1;
    model.month_scroll_override = true;
    model.scroll_override_phase = .primed;
}

fn scheduleFortnightRebase(model: *Model, target: f32) void {
    model.fortnight_scroll_target = target;
    model.fortnight_scroll_offset = target;
    model.fortnight_scroll_override = true;
    model.scroll_override_phase = .target;
}

fn scheduleMonthRebase(model: *Model, target: f32) void {
    model.month_scroll_target = target;
    model.month_scroll_offset = target;
    model.month_scroll_override = true;
    model.scroll_override_phase = .target;
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

fn calendarName(id: u64) []const u8 {
    for (fixtures.calendar_visibility) |item| if (item.id == id) return item.name;
    return "Unknown calendar";
}

fn surfacePolicyLabel(policy: calendar.SurfaceOverride) []const u8 {
    return switch (policy) {
        .inherit => "automatic",
        .pin => "pinned",
        .hide => "hidden",
    };
}

fn tokensFromModel(model: *const Model) canvas.DesignTokens {
    var tokens = canvas.DesignTokens.theme(.{
        .pack = .geist,
        .color_scheme = switch (model.appearance.color_scheme) {
            .light => .light,
            .dark => .dark,
        },
        .contrast = if (model.appearance.high_contrast) .high else .standard,
        .density = .compact,
        .reduce_motion = model.appearance.reduce_motion,
    });
    if (!model.appearance.high_contrast) {
        tokens = tokens.withOverrides(canvas.accentOverrides(canvas.Color.rgb8(95, 99, 216)));
    }
    tokens.radius = .{ .sm = 4, .md = 4, .lg = 6, .xl = 8 };
    return tokens;
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
        .on_command = onCommand,
        .on_chrome = onChrome,
        .on_appearance = onAppearance,
        .on_frame = onFrame,
        .sync = syncRuntimeState,
        .view = CompiledZeitView.build,
        .markup = if (dev_markup_reload)
            .{ .source = app_markup, .watch_path = "src/app.native", .io = init.io }
        else
            null,
        .tokens_fn = tokensFromModel,
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
