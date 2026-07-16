const std = @import("std");
const native_sdk = @import("native_sdk");
const main = @import("main.zig");
const calendar = @import("domain/calendar.zig");
const provider = @import("domain/provider.zig");
const ranking = @import("domain/surface_ranking.zig");
const overlap = @import("layout/overlap.zig");
const fixtures = @import("fixtures.zig");

const canvas = native_sdk.canvas;
const testing = std.testing;
const AppMarkup = canvas.MarkupView(main.Model, main.Msg);

fn buildTree(arena: std.mem.Allocator, model: *const main.Model) !main.AppUi.Tree {
    var view = try AppMarkup.init(arena, main.app_markup);
    var ui = main.AppUi.init(arena);
    const node = view.build(&ui, model) catch |err| {
        if (err == error.MarkupBuild) {
            std.debug.print("app.native:{d}:{d}: {s}\n", .{ view.diagnostic.line, view.diagnostic.column, view.diagnostic.message });
        }
        return err;
    };
    return ui.finalize(node);
}

fn findByText(widget: canvas.Widget, kind: canvas.WidgetKind, expected: []const u8) ?canvas.Widget {
    if (widget.kind == kind and std.mem.eql(u8, widget.text, expected)) return widget;
    for (widget.children) |child| {
        if (findByText(child, kind, expected)) |found| return found;
    }
    return null;
}

fn findByKind(widget: canvas.Widget, kind: canvas.WidgetKind) ?canvas.Widget {
    if (widget.kind == kind) return widget;
    for (widget.children) |child| {
        if (findByKind(child, kind)) |found| return found;
    }
    return null;
}

fn testEvent(id: u64, starts_at_ms: i64, ends_at_ms: i64, override: calendar.SurfaceOverride) calendar.CalendarEvent {
    return .{
        .id = id,
        .calendar_id = 1,
        .title = "",
        .location = "",
        .starts_at_ms = starts_at_ms,
        .ends_at_ms = ends_at_ms,
        .timing = .timed,
        .event_kind = .meeting,
        .participation = .accepted,
        .availability = .busy,
        .surfaces = .{ .menu_bar = .inherit, .desktop_widget = override, .up_next = .inherit },
    };
}

test "month fixture is a complete Monday-first five-week grid" {
    try testing.expectEqual(@as(usize, 35), fixtures.month_cells.len);
    const first_week = [_]u8{ 29, 30, 1, 2, 3, 4, 5 };
    for (first_week, 0..) |day, index| try testing.expectEqual(day, fixtures.month_cells[index].day);
    try testing.expectEqual(@as(u8, 1), fixtures.month_cells[33].day);
    try testing.expectEqual(@as(u8, 2), fixtures.month_cells[34].day);

    var today: ?fixtures.MonthCell = null;
    for (fixtures.month_cells) |cell| if (cell.today) {
        today = cell;
        break;
    };
    try testing.expect(today != null);
    try testing.expectEqual(@as(u64, 17), today.?.id);
    try testing.expectEqual(@as(u64, 2), (today.?.id - 1) % 7);
}

test "surface ranking gives explicit pins precedence" {
    const now: i64 = 1_000_000;
    const rule: ranking.SurfaceRule = .{ .surface = .desktop_widget, .max_events = 3, .horizon_minutes = 1_440, .include_all_day = false, .include_declined = false };
    const events = [_]calendar.CalendarEvent{
        testEvent(1, now + 10 * 60 * 1_000, now + 70 * 60 * 1_000, .inherit),
        testEvent(2, now + 4 * 60 * 60 * 1_000, now + 5 * 60 * 60 * 1_000, .pin),
    };
    var output: [events.len]ranking.RankedSurfaceEvent = undefined;
    const ranked = try ranking.rankEventsForSurface(&events, rule, now, &output);
    try testing.expectEqual(@as(usize, 2), ranked.len);
    try testing.expectEqual(@as(u64, 2), ranked[0].event_id);
    try testing.expectEqual(@as(u64, 1), ranked[1].event_id);
}

test "surface ranking excludes policy-ineligible events" {
    const now: i64 = 1_000_000;
    const rule: ranking.SurfaceRule = .{ .surface = .desktop_widget, .max_events = 3, .horizon_minutes = 1_440, .include_all_day = false, .include_declined = false };
    const hidden = testEvent(1, now + 1_000, now + 2_000, .hide);
    var declined = testEvent(2, now + 1_000, now + 2_000, .inherit);
    declined.participation = .declined;
    var all_day = testEvent(3, now + 1_000, now + 2_000, .inherit);
    all_day.timing = .all_day;
    const distant = testEvent(4, now + 2 * 24 * 60 * 60 * 1_000, now + 3 * 24 * 60 * 60 * 1_000, .inherit);
    const events = [_]calendar.CalendarEvent{ hidden, declined, all_day, distant };
    var output: [events.len]ranking.RankedSurfaceEvent = undefined;
    const ranked = try ranking.rankEventsForSurface(&events, rule, now, &output);
    try testing.expectEqual(@as(usize, 0), ranked.len);

    var too_small: [3]ranking.RankedSurfaceEvent = undefined;
    try testing.expectError(error.OutputTooSmall, ranking.rankEventsForSurface(&events, rule, now, &too_small));
}

test "an active event outranks an ordinary future event" {
    const now: i64 = 1_000_000;
    const rule: ranking.SurfaceRule = .{ .surface = .desktop_widget, .max_events = 3, .horizon_minutes = 1_440, .include_all_day = false, .include_declined = false };
    const active = testEvent(1, now - 10_000, now + 10_000, .inherit);
    const future = testEvent(2, now + 10_000, now + 20_000, .inherit);
    try testing.expect(ranking.scoreForSurface(active, rule, now) > ranking.scoreForSurface(future, rule, now));
}

test "overlap geometry assigns and reuses lanes by cluster" {
    const intervals = [_]overlap.TimedInterval{
        .{ .id = 3, .start_minute = 90, .end_minute = 150 },
        .{ .id = 1, .start_minute = 60, .end_minute = 120 },
        .{ .id = 2, .start_minute = 75, .end_minute = 90 },
        .{ .id = 4, .start_minute = 240, .end_minute = 300 },
    };
    const placed = try overlap.placeOverlappingIntervals(testing.allocator, &intervals);
    defer testing.allocator.free(placed);
    try testing.expectEqual(@as(usize, 4), placed.len);
    const expected = [_]overlap.OverlapPlacement{
        .{ .id = 1, .lane = 0, .lane_count = 2 },
        .{ .id = 2, .lane = 1, .lane_count = 2 },
        .{ .id = 3, .lane = 1, .lane_count = 2 },
        .{ .id = 4, .lane = 0, .lane_count = 1 },
    };
    for (expected, placed) |want, got| try testing.expectEqualDeep(want, got);
}

test "overlap geometry ignores invalid intervals" {
    const intervals = [_]overlap.TimedInterval{
        .{ .id = 1, .start_minute = 100, .end_minute = 100 },
        .{ .id = 2, .start_minute = 120, .end_minute = 90 },
    };
    const placed = try overlap.placeOverlappingIntervals(testing.allocator, &intervals);
    defer testing.allocator.free(placed);
    try testing.expectEqual(@as(usize, 0), placed.len);
}

test "typed provider boundary stays independent from vendor wire records" {
    const normalized: provider.NormalizedProviderEvent = .{
        .account_id = 7,
        .external_calendar_id = "work",
        .external_event_id = "vendor-42",
        .revision = "etag-9",
        .title = "Review",
        .location = "Studio",
        .starts_at_ms = 10,
        .ends_at_ms = 20,
        .timing = .timed,
        .event_kind = .meeting,
        .participation = .accepted,
        .availability = .busy,
    };
    const mutation: provider.ProviderMutation = .{ .id = 1, .kind = .update, .event = normalized };
    try testing.expectEqual(provider.ProviderKind.google, provider.ProviderKind.google);
    try testing.expectEqual(@as(u64, 7), mutation.event.account_id);
}

test "typed markup dispatch drives view navigation" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    var model = main.initialModel();
    const tree = try buildTree(arena_state.allocator(), &model);
    const month = findByText(tree.root, .button, "Month") orelse return error.WidgetNotFound;
    main.update(&model, tree.msgForPointer(month.id, .up) orelse return error.MessageNotFound);
    try testing.expectEqual(main.CalendarView.month, model.view);
    try testing.expectEqualStrings("July 2026", model.period_label());
}

test "week scrolling remains runtime-owned and dispatches no model message" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const model = main.initialModel();
    const tree = try buildTree(arena_state.allocator(), &model);
    const timeline = findByKind(tree.root, .scroll_view) orelse return error.WidgetNotFound;
    try testing.expect(tree.msgForScroll(timeline.id, .{ .offset = 240 }) == null);
}

test "calendar view lays out within the SDK node budget" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    var model = main.initialModel();
    const tree = try buildTree(arena_state.allocator(), &model);
    var nodes: [1024]canvas.WidgetLayoutNode = undefined;
    const layout = try canvas.layoutWidgetTree(tree.root, native_sdk.geometry.RectF.init(0, 0, 1380, 860), &nodes);
    try testing.expect(layout.nodes.len > 0);
    try testing.expect(layout.nodes.len < nodes.len);
}

test "chrome geometry updates the native titlebar clearance" {
    var model = main.initialModel();
    const msg = main.onChrome(.{ .insets = .{ .top = 60, .left = 78, .right = 12 } }) orelse return error.MessageNotFound;
    main.update(&model, msg);
    try testing.expectEqual(@as(f32, 78), model.chrome_leading);
    try testing.expectEqual(@as(f32, 12), model.chrome_trailing);
    try testing.expectEqual(@as(f32, 60), model.header_height);
}
