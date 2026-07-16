//! Small, provider-independent Gregorian calendar arithmetic for bounded
//! calendar windows. Dates stay semantic here; pixels and scroll offsets do
//! not enter this module.

const std = @import("std");

pub const CivilDate = struct {
    year: i32,
    month: u8,
    day: u8,
};

pub const YearMonth = struct {
    year: i32,
    month: u8,
};

pub const month_names = [_][]const u8{
    "January", "February", "March",     "April",   "May",      "June",
    "July",    "August",   "September", "October", "November", "December",
};

pub fn eql(a: CivilDate, b: CivilDate) bool {
    return a.year == b.year and a.month == b.month and a.day == b.day;
}

pub fn isLeapYear(year: i32) bool {
    return @mod(year, 4) == 0 and (@mod(year, 100) != 0 or @mod(year, 400) == 0);
}

pub fn daysInMonth(value: YearMonth) u8 {
    return switch (value.month) {
        1, 3, 5, 7, 8, 10, 12 => 31,
        4, 6, 9, 11 => 30,
        2 => if (isLeapYear(value.year)) 29 else 28,
        else => 0,
    };
}

/// Days since 1970-01-01. This is Howard Hinnant's era-based civil-date
/// transform, using floor division so years before the Unix epoch remain
/// well-defined too.
pub fn daysFromCivil(date: CivilDate) i64 {
    var year: i64 = date.year;
    const month: i64 = date.month;
    const day: i64 = date.day;
    if (month <= 2) year -= 1;
    const era = @divFloor(year, 400);
    const year_of_era = year - era * 400;
    const shifted_month = month + (if (month > 2) @as(i64, -3) else 9);
    const day_of_year = @divFloor(153 * shifted_month + 2, 5) + day - 1;
    const day_of_era = year_of_era * 365 + @divFloor(year_of_era, 4) - @divFloor(year_of_era, 100) + day_of_year;
    return era * 146_097 + day_of_era - 719_468;
}

pub fn civilFromDays(days_since_epoch: i64) CivilDate {
    const shifted = days_since_epoch + 719_468;
    const era = @divFloor(shifted, 146_097);
    const day_of_era = shifted - era * 146_097;
    const year_of_era = @divFloor(day_of_era - @divFloor(day_of_era, 1_460) + @divFloor(day_of_era, 36_524) - @divFloor(day_of_era, 146_096), 365);
    var year = year_of_era + era * 400;
    const day_of_year = day_of_era - (365 * year_of_era + @divFloor(year_of_era, 4) - @divFloor(year_of_era, 100));
    const shifted_month = @divFloor(5 * day_of_year + 2, 153);
    const day = day_of_year - @divFloor(153 * shifted_month + 2, 5) + 1;
    const month = shifted_month + (if (shifted_month < 10) @as(i64, 3) else -9);
    if (month <= 2) year += 1;
    return .{ .year = @intCast(year), .month = @intCast(month), .day = @intCast(day) };
}

pub fn addDays(date: CivilDate, delta: i64) CivilDate {
    return civilFromDays(daysFromCivil(date) + delta);
}

pub fn addMonths(value: YearMonth, delta: i32) YearMonth {
    const absolute = @as(i64, value.year) * 12 + @as(i64, value.month) - 1 + delta;
    return .{
        .year = @intCast(@divFloor(absolute, 12)),
        .month = @intCast(@mod(absolute, 12) + 1),
    };
}

/// Monday = 0 through Sunday = 6.
pub fn mondayWeekday(date: CivilDate) u8 {
    return @intCast(@mod(daysFromCivil(date) + 3, 7));
}

pub fn monthName(month: u8) []const u8 {
    if (month == 0 or month > month_names.len) return "";
    return month_names[month - 1];
}

pub fn formatMonthYear(allocator: std.mem.Allocator, value: YearMonth) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s} {d}", .{ monthName(value.month), value.year });
}

pub fn formatWeekRange(allocator: std.mem.Allocator, monday: CivilDate) ![]const u8 {
    const sunday = addDays(monday, 6);
    if (monday.year == sunday.year and monday.month == sunday.month) {
        return std.fmt.allocPrint(allocator, "{s} {d}–{d}, {d}", .{ monthName(monday.month), monday.day, sunday.day, monday.year });
    }
    if (monday.year == sunday.year) {
        return std.fmt.allocPrint(allocator, "{s} {d}–{s} {d}, {d}", .{ monthName(monday.month), monday.day, monthName(sunday.month), sunday.day, monday.year });
    }
    return std.fmt.allocPrint(allocator, "{s} {d}, {d}–{s} {d}, {d}", .{ monthName(monday.month), monday.day, monday.year, monthName(sunday.month), sunday.day, sunday.year });
}
