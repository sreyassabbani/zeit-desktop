const std = @import("std");
const native_sdk = @import("native_sdk");
const main = @import("main.zig");
const calendar = @import("domain/calendar.zig");
const civil = @import("domain/civil_date.zig");
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

fn findByLabel(widget: canvas.Widget, kind: canvas.WidgetKind, expected: []const u8) ?canvas.Widget {
    if (widget.kind == kind and std.mem.eql(u8, widget.semantics.label, expected)) return widget;
    for (widget.children) |child| {
        if (findByLabel(child, kind, expected)) |found| return found;
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

test "month fixtures are complete Monday-first six-week grids" {
    try testing.expectEqual(@as(usize, 42), fixtures.month_cells_previous.len);
    try testing.expectEqual(@as(usize, 42), fixtures.month_cells.len);
    try testing.expectEqual(@as(usize, 42), fixtures.month_cells_next.len);
    const first_week = [_]u8{ 29, 30, 1, 2, 3, 4, 5 };
    for (first_week, 0..) |day, index| try testing.expectEqual(day, fixtures.month_cells[index].day);
    try testing.expectEqual(@as(u8, 8), fixtures.month_cells[40].day);
    try testing.expectEqual(@as(u8, 9), fixtures.month_cells[41].day);

    var today: ?fixtures.MonthCell = null;
    for (fixtures.month_cells) |cell| if (cell.today) {
        today = cell;
        break;
    };
    try testing.expect(today != null);
    try testing.expectEqual(@as(u64, 17), today.?.id);
    try testing.expectEqual(@as(u64, 2), (today.?.id - 1) % 7);
}

test "civil date arithmetic crosses leap, month, and year boundaries" {
    try testing.expect(civil.eql(
        .{ .year = 2024, .month = 2, .day = 29 },
        civil.addDays(.{ .year = 2024, .month = 2, .day = 28 }, 1),
    ));
    try testing.expect(civil.eql(
        .{ .year = 2027, .month = 1, .day = 1 },
        civil.addDays(.{ .year = 2026, .month = 12, .day = 31 }, 1),
    ));
    try testing.expectEqualDeep(
        civil.YearMonth{ .year = 2025, .month = 12 },
        civil.addMonths(.{ .year = 2026, .month = 1 }, -1),
    );
    try testing.expectEqual(@as(u8, 0), civil.mondayWeekday(.{ .year = 2026, .month = 7, .day = 13 }));
}

test "five recycled calendar pages remain chronologically ordered" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    var model = main.initialModel();

    const weeks = model.week_pages(arena_state.allocator());
    try testing.expectEqual(@as(usize, 5), weeks.len);
    try testing.expectEqualStrings("June 29–July 5, 2026", weeks[0].label);
    try testing.expectEqualStrings("July 13–19, 2026", weeks[2].label);
    try testing.expectEqualStrings("July 27–August 2, 2026", weeks[4].label);
    try testing.expectEqual(@as(u64, 2), weeks[2].slot_id);
    try testing.expect(weeks[2].wednesday_events.len > 0);
    try testing.expectEqual(@as(usize, 0), weeks[1].wednesday_events.len);

    const months = model.month_pages(arena_state.allocator());
    try testing.expectEqual(@as(usize, 5), months.len);
    try testing.expectEqualStrings("May 2026", months[0].label);
    try testing.expectEqualStrings("July 2026", months[2].label);
    try testing.expectEqualStrings("September 2026", months[4].label);
    try testing.expectEqual(@as(usize, 42), months[4].cells.len);
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
    try testing.expectEqualStrings("July 2026", model.period_label(arena_state.allocator()));
}

test "week scrolling remains runtime-owned and dispatches no model message" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const model = main.initialModel();
    const tree = try buildTree(arena_state.allocator(), &model);
    const pages = findByLabel(tree.root, .scroll_view, "Week pages") orelse return error.WidgetNotFound;
    try testing.expectEqual(canvas.WidgetScrollAxis.horizontal, pages.scroll_axis);
    try testing.expectEqual(@as(u64, 1), pages.scroll_sync_group);
    try testing.expectEqual(model.week_page_width() * 2, pages.value);
    try testing.expect(tree.msgForScroll(pages.id, .{ .offset = 240 }) == null);
}

test "month view mounts adjacent months in one runtime-owned scroll region" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    var model = main.initialModel();
    main.update(&model, .show_month);
    const tree = try buildTree(arena_state.allocator(), &model);
    const pages = findByLabel(tree.root, .scroll_view, "Month pages") orelse return error.WidgetNotFound;
    try testing.expectEqual(canvas.WidgetScrollAxis.vertical, pages.scroll_axis);
    try testing.expectEqual(model.month_page_height() * 2, pages.value);
    try testing.expect(tree.msgForScroll(pages.id, .{ .offset = 320 }) == null);
}

test "page recycling advances chronology while preserving the visual coordinate" {
    var model = main.initialModel();
    const week_width = model.week_page_width();
    model.week_scroll_offset = week_width * 3.25;
    const week_coordinate_before = @as(f32, @floatFromInt(model.week_window_start)) + model.week_scroll_offset / week_width;
    main.update(&model, .recycle_week_forward);
    const week_coordinate_after = @as(f32, @floatFromInt(model.week_window_start)) + model.week_scroll_offset / week_width;
    try testing.expectEqual(@as(i32, -1), model.week_window_start);
    try testing.expectApproxEqAbs(week_coordinate_before, week_coordinate_after, 0.0001);
    try testing.expectApproxEqAbs(week_width * 2.25, model.week_scroll_target, 0.0001);

    model.month_scroll_offset = model.month_page_height() * 0.75;
    const month_coordinate_before = @as(f32, @floatFromInt(model.month_window_start)) + model.month_scroll_offset / model.month_page_height();
    main.update(&model, .recycle_month_backward);
    const month_coordinate_after = @as(f32, @floatFromInt(model.month_window_start)) + model.month_scroll_offset / model.month_page_height();
    try testing.expectEqual(@as(i32, -3), model.month_window_start);
    try testing.expectApproxEqAbs(month_coordinate_before, month_coordinate_after, 0.0001);
    try testing.expectApproxEqAbs(model.month_page_height() * 1.75, model.month_scroll_target, 0.0001);
}

test "Today targets the current period after runtime offsets are synced" {
    var model = main.initialModel();
    model.week_scroll_offset = 42;
    model.month_scroll_offset = 91;
    main.update(&model, .go_today);
    try testing.expectEqual(model.week_page_width() * 2, model.week_scroll_target);
    try testing.expectEqual(model.month_page_height() * 2, model.month_scroll_target);
    try testing.expectEqual(model.week_scroll_target + 1, model.week_scroll_offset);
    try testing.expectEqual(model.month_scroll_target + 1, model.month_scroll_offset);

    main.update(&model, .settle_scroll_override);
    try testing.expectEqual(model.week_scroll_target, model.week_scroll_offset);
    try testing.expectEqual(model.month_scroll_target, model.month_scroll_offset);
    main.update(&model, .settle_scroll_override);
    try testing.expect(!model.week_scroll_override);
    try testing.expect(!model.month_scroll_override);
}

test "first viewport measurement centers the current week before resize scaling" {
    var model = main.initialModel();
    main.update(&model, .{ .viewport_changed = .{ .width = 1710, .height = 1073 } });
    try testing.expect(model.viewport_initialized);
    try testing.expect(model.week_scroll_override);
    try testing.expectEqual(model.week_page_width() * 2, model.week_scroll_target);
    main.update(&model, .settle_scroll_override);
    main.update(&model, .settle_scroll_override);

    const old_page_width = model.week_page_width();
    model.week_scroll_offset = old_page_width * 1.25;
    main.update(&model, .{ .viewport_changed = .{ .width = 1510, .height = 973 } });
    try testing.expectApproxEqAbs(@as(f32, 1.25), model.week_scroll_target / model.week_page_width(), 0.0001);
}

test "programmatic scroll targets survive one runtime sync then release ownership" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    var model = main.initialModel();
    main.update(&model, .go_today);

    const tree = try buildTree(arena_state.allocator(), &model);
    var nodes: [1024]canvas.WidgetLayoutNode = undefined;
    const layout = try canvas.layoutWidgetTree(tree.root, native_sdk.geometry.RectF.init(0, 0, 1710, 1073), &nodes);
    const week = findByLabel(tree.root, .scroll_view, "Week pages") orelse return error.WidgetNotFound;
    for (nodes[0..layout.nodes.len]) |*node| {
        if (node.widget.id == week.id) node.widget.value = 42;
    }
    main.syncRuntimeState(&model, layout);
    try testing.expectEqual(model.week_scroll_target + 1, model.week_scroll_offset);

    const settle = main.onFrame(&model, .{ .size = .{ .width = model.viewport_width, .height = model.viewport_height } }) orelse return error.ExpectedMessage;
    main.update(&model, settle);
    try testing.expectEqual(model.week_scroll_target, model.week_scroll_offset);
    main.syncRuntimeState(&model, layout);
    try testing.expectEqual(model.week_scroll_target, model.week_scroll_offset);

    main.update(&model, .settle_scroll_override);
    try testing.expect(!model.week_scroll_override);
    main.syncRuntimeState(&model, layout);
    try testing.expectEqual(@as(f32, 42), model.week_scroll_offset);
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
