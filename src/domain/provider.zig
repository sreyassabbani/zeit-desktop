//! Typed contracts at the provider effect boundary.

const calendar = @import("calendar.zig");

pub const ProviderKind = enum { google, microsoft, caldav, local };
pub const ProviderConnectionState = enum { disconnected, authorizing, ready, error_state };
pub const ProviderChangeKind = enum { upsert, delete };
pub const ProviderMutationKind = enum { create, update, delete };

/// Safe account metadata. Credential material belongs in platform storage.
pub const ProviderAccount = struct {
    id: u64,
    provider: ProviderKind,
    display_name: []const u8,
    state: ProviderConnectionState,
};

/// Opaque incremental-sync token; the provider adapter alone interprets it.
pub const ProviderSyncCursor = struct {
    account_id: u64,
    value: []const u8,
};

/// Provider adapter output before stable local ids are assigned.
pub const NormalizedProviderEvent = struct {
    account_id: u64,
    external_calendar_id: []const u8,
    external_event_id: []const u8,
    revision: []const u8,
    title: []const u8,
    location: []const u8,
    starts_at_ms: i64,
    ends_at_ms: i64,
    timing: calendar.EventTiming,
    event_kind: calendar.EventKind,
    participation: calendar.Participation,
    availability: calendar.Availability,
};

pub const ProviderChange = struct {
    kind: ProviderChangeKind,
    event: NormalizedProviderEvent,
};

/// Mutation sent toward an adapter; each adapter owns vendor translation.
pub const ProviderMutation = struct {
    id: u64,
    kind: ProviderMutationKind,
    event: NormalizedProviderEvent,
};
