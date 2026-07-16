//! Allocation-free attention policy for menu-bar and widget surfaces.

const calendar = @import("calendar.zig");

pub const SurfaceRule = struct {
    surface: calendar.Surface,
    max_events: usize,
    horizon_minutes: u32,
    include_all_day: bool,
    include_declined: bool,
};

pub const RankedSurfaceEvent = struct {
    event_id: u64,
    score: i64,
};

pub const RankError = error{OutputTooSmall};
pub const hidden_score: i64 = -1_000_000;
const pinned_score: i64 = 500_000;

pub fn overrideForSurface(event: calendar.CalendarEvent, surface: calendar.Surface) calendar.SurfaceOverride {
    return switch (surface) {
        .menu_bar => event.surfaces.menu_bar,
        .desktop_widget => event.surfaces.desktop_widget,
        .up_next => event.surfaces.up_next,
    };
}

pub fn scoreForSurface(event: calendar.CalendarEvent, rule: SurfaceRule, now_ms: i64) i64 {
    const override = overrideForSurface(event, rule.surface);
    if (override == .hide) return hidden_score;
    if (!rule.include_declined and event.participation == .declined) return hidden_score;
    if (!rule.include_all_day and event.timing == .all_day) return hidden_score;

    const until_start = event.starts_at_ms - now_ms;
    const horizon_ms = @as(i64, @intCast(rule.horizon_minutes)) * 60_000;
    if (until_start > horizon_ms and override != .pin) return hidden_score;

    var score: i64 = if (override == .pin) pinned_score else 0;
    if (event.starts_at_ms <= now_ms and event.ends_at_ms > now_ms) {
        score += 100_000;
    } else if (until_start >= 0 and until_start <= 3_600_000) {
        score += 50_000;
    } else if (until_start > 3_600_000 and until_start <= 14_400_000) {
        score += 40_000;
    } else if (until_start > 14_400_000 and until_start <= 86_400_000) {
        score += 30_000;
    } else if (until_start > 86_400_000) {
        score += 20_000;
    } else {
        score -= 100_000;
    }

    if (event.event_kind == .focus) score += 4_000;
    if (event.event_kind == .appointment) score += 3_000;
    if (event.participation == .accepted) score += 1_000;
    if (event.participation == .tentative) score -= 500;
    if (event.availability == .free) score -= 750;
    if (event.timing == .all_day) score -= 1_500;
    return score;
}

/// Ranks into caller-owned storage. Requiring a full-size buffer prevents a
/// hidden allocation and ensures a small buffer can never silently drop a
/// higher-scoring event that appears later in the input.
pub fn rankEventsForSurface(
    events: []const calendar.CalendarEvent,
    rule: SurfaceRule,
    now_ms: i64,
    output: []RankedSurfaceEvent,
) RankError![]RankedSurfaceEvent {
    if (output.len < events.len) return error.OutputTooSmall;

    var count: usize = 0;
    for (events) |event| {
        const score = scoreForSurface(event, rule, now_ms);
        if (score > hidden_score) {
            output[count] = .{ .event_id = event.id, .score = score };
            count += 1;
        }
    }

    // Stable insertion sort: tiny surface queues stay bounded, predictable,
    // and independent of std sorting API churn in a pre-1.0 toolchain.
    var index: usize = 1;
    while (index < count) : (index += 1) {
        const item = output[index];
        var position = index;
        while (position > 0 and ranksBefore(item, output[position - 1])) : (position -= 1) {
            output[position] = output[position - 1];
        }
        output[position] = item;
    }

    return output[0..@min(count, rule.max_events)];
}

fn ranksBefore(left: RankedSurfaceEvent, right: RankedSurfaceEvent) bool {
    if (left.score != right.score) return left.score > right.score;
    return left.event_id < right.event_id;
}
