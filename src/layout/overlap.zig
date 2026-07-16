//! Pure interval geometry; independent of Native SDK and providers.

const std = @import("std");

pub const TimedInterval = struct {
    id: u64,
    start_minute: i32,
    end_minute: i32,
};

pub const OverlapPlacement = struct {
    id: u64,
    lane: usize,
    lane_count: usize,
};

/// Assigns the first available lane and maximum concurrent lane count for
/// each cluster. The returned slice is owned by `allocator`.
pub fn placeOverlappingIntervals(
    allocator: std.mem.Allocator,
    intervals: []const TimedInterval,
) std.mem.Allocator.Error![]OverlapPlacement {
    var valid_count: usize = 0;
    for (intervals) |interval| {
        if (interval.end_minute > interval.start_minute) valid_count += 1;
    }

    const ordered = try allocator.alloc(TimedInterval, valid_count);
    defer allocator.free(ordered);
    var next: usize = 0;
    for (intervals) |interval| {
        if (interval.end_minute > interval.start_minute) {
            ordered[next] = interval;
            next += 1;
        }
    }
    sortIntervals(ordered);

    const placements = try allocator.alloc(OverlapPlacement, valid_count);
    errdefer allocator.free(placements);
    const lane_ends = try allocator.alloc(i32, valid_count);
    defer allocator.free(lane_ends);

    var placement_count: usize = 0;
    var lane_count: usize = 0;
    var group_start: usize = 0;
    var group_end: i32 = -1;
    var group_lane_count: usize = 0;

    for (ordered) |interval| {
        if (placement_count > group_start and interval.start_minute >= group_end) {
            setLaneCount(placements[group_start..placement_count], group_lane_count);
            group_start = placement_count;
            group_end = -1;
            group_lane_count = 0;
            lane_count = 0;
        }

        var lane: usize = 0;
        while (lane < lane_count and lane_ends[lane] > interval.start_minute) : (lane += 1) {}
        if (lane == lane_count) {
            lane_ends[lane] = interval.end_minute;
            lane_count += 1;
        } else {
            lane_ends[lane] = interval.end_minute;
        }

        group_lane_count = @max(group_lane_count, lane + 1);
        group_end = @max(group_end, interval.end_minute);
        placements[placement_count] = .{ .id = interval.id, .lane = lane, .lane_count = 1 };
        placement_count += 1;
    }

    if (placement_count > group_start) {
        setLaneCount(placements[group_start..placement_count], group_lane_count);
    }
    return placements[0..placement_count];
}

fn setLaneCount(placements: []OverlapPlacement, count: usize) void {
    for (placements) |*placement| placement.lane_count = count;
}

fn sortIntervals(intervals: []TimedInterval) void {
    var index: usize = 1;
    while (index < intervals.len) : (index += 1) {
        const item = intervals[index];
        var position = index;
        while (position > 0 and intervalBefore(item, intervals[position - 1])) : (position -= 1) {
            intervals[position] = intervals[position - 1];
        }
        intervals[position] = item;
    }
}

fn intervalBefore(left: TimedInterval, right: TimedInterval) bool {
    if (left.start_minute != right.start_minute) return left.start_minute < right.start_minute;
    if (left.end_minute != right.end_minute) return left.end_minute < right.end_minute;
    return left.id < right.id;
}
