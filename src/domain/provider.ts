import type { Availability, Bytes, EventKind, EventTiming, Participation } from "./calendar.ts";

export type ProviderKind = "google" | "microsoft" | "caldav" | "local";
export type ProviderConnectionState = "disconnected" | "authorizing" | "ready" | "error";
export type ProviderChangeKind = "upsert" | "delete";
export type ProviderMutationKind = "create" | "update" | "delete";

/** Safe account metadata. Credential material belongs in platform storage. */
export interface ProviderAccount {
  readonly id: number;
  readonly provider: ProviderKind;
  readonly displayName: Bytes;
  readonly state: ProviderConnectionState;
}

/** Opaque incremental-sync token; the provider adapter alone interprets it. */
export interface ProviderSyncCursor {
  readonly accountId: number;
  readonly value: Bytes;
}

/**
 * Provider adapter output before stable local ids are assigned. This is the
 * only vendor-facing event shape the domain ingestion path needs.
 */
export interface NormalizedProviderEvent {
  readonly accountId: number;
  readonly externalCalendarId: Bytes;
  readonly externalEventId: Bytes;
  readonly revision: Bytes;
  readonly title: Bytes;
  readonly location: Bytes;
  readonly startsAtMs: number;
  readonly endsAtMs: number;
  readonly timing: EventTiming;
  readonly eventKind: EventKind;
  readonly participation: Participation;
  readonly availability: Availability;
}

export interface ProviderChange {
  readonly kind: ProviderChangeKind;
  readonly event: NormalizedProviderEvent;
}

/**
 * Mutation envelope sent toward an adapter. The payload stays normalized;
 * each adapter translates it into the provider's request schema.
 */
export interface ProviderMutation {
  readonly id: number;
  readonly kind: ProviderMutationKind;
  readonly event: NormalizedProviderEvent;
}
