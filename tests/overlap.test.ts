import { describe, expect, test } from "bun:test";
import { placeOverlappingIntervals } from "../src/layout/overlap.ts";

describe("placeOverlappingIntervals", () => {
  test("keeps independent intervals in one lane", () => {
    expect(
      placeOverlappingIntervals([
        { id: 1, startMinute: 60, endMinute: 120 },
        { id: 2, startMinute: 120, endMinute: 180 },
      ]),
    ).toEqual([
      { id: 1, lane: 0, laneCount: 1 },
      { id: 2, lane: 0, laneCount: 1 },
    ]);
  });

  test("assigns lanes per overlap cluster and reuses released lanes", () => {
    expect(
      placeOverlappingIntervals([
        { id: 3, startMinute: 90, endMinute: 150 },
        { id: 1, startMinute: 60, endMinute: 120 },
        { id: 2, startMinute: 75, endMinute: 90 },
        { id: 4, startMinute: 240, endMinute: 300 },
      ]),
    ).toEqual([
      { id: 1, lane: 0, laneCount: 2 },
      { id: 2, lane: 1, laneCount: 2 },
      { id: 3, lane: 1, laneCount: 2 },
      { id: 4, lane: 0, laneCount: 1 },
    ]);
  });

  test("ignores invalid intervals at the geometry boundary", () => {
    expect(
      placeOverlappingIntervals([
        { id: 1, startMinute: 100, endMinute: 100 },
        { id: 2, startMinute: 120, endMinute: 90 },
      ]),
    ).toEqual([]);
  });
});
