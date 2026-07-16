//! Provider-independent calendar vocabulary shared by every surface.

pub const CalendarColor = enum { indigo, plum, sea, sand };
pub const EventKind = enum { meeting, focus, appointment, personal, task };
pub const EventTiming = enum { timed, all_day };
pub const Participation = enum { accepted, tentative, declined, needs_action };
pub const Availability = enum { busy, free };
pub const Surface = enum { menu_bar, desktop_widget, up_next };
pub const SurfaceOverride = enum { inherit, pin, hide };

pub const CalendarDefinition = struct {
    id: u64,
    name: []const u8,
    color: CalendarColor,
};

pub const CalendarVisibility = struct {
    id: u64,
    name: []const u8,
    color: CalendarColor,
    visible: bool,
};

pub const SurfacePreferences = struct {
    menu_bar: SurfaceOverride,
    desktop_widget: SurfaceOverride,
    up_next: SurfaceOverride,
};

pub const EventSource = struct {
    provider_account_id: u64,
    external_calendar_id: []const u8,
    external_event_id: []const u8,
    revision: []const u8,
};

/// Canonical event after provider normalization. Provider-specific etags,
/// recurrence payloads, and attendee schemas do not cross this boundary.
pub const CalendarEvent = struct {
    id: u64,
    calendar_id: u64,
    title: []const u8,
    location: []const u8,
    starts_at_ms: i64,
    ends_at_ms: i64,
    timing: EventTiming,
    event_kind: EventKind,
    participation: Participation,
    availability: Availability,
    surfaces: SurfacePreferences,
    source: ?EventSource = null,
};

/// One occurrence after recurrence expansion and local-time-zone projection.
/// CalendarEvent stays canonical; layout consumes this local projection.
pub const EventOccurrence = struct {
    id: u64,
    event_id: u64,
    local_day_index: u8,
    local_start_minute: u16,
    local_end_minute: u16,
};
