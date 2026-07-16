/** Pure interval geometry; independent of Native SDK and calendar providers. */

export interface TimedInterval {
  readonly id: number;
  readonly startMinute: number;
  readonly endMinute: number;
}

export interface OverlapPlacement {
  readonly id: number;
  readonly lane: number;
  readonly laneCount: number;
}

/**
 * Assigns the first available horizontal lane and the maximum concurrent
 * lane count for each overlap cluster. Invalid zero/negative intervals are
 * ignored at this geometry boundary.
 */
export function placeOverlappingIntervals(
  intervals: readonly TimedInterval[],
): readonly OverlapPlacement[] {
  const ordered = intervals
    .filter((interval) => interval.endMinute > interval.startMinute)
    .toSorted((a, b) => {
      if (a.startMinute !== b.startMinute) return a.startMinute - b.startMinute;
      if (a.endMinute !== b.endMinute) return a.endMinute - b.endMinute;
      return a.id - b.id;
    });

  const placements: OverlapPlacement[] = [];
  let laneEnds: number[] = [];
  let groupStart = 0;
  let groupEnd = -1;
  let groupLaneCount = 0;

  for (const interval of ordered) {
    if (placements.length > groupStart && interval.startMinute >= groupEnd) {
      for (let i = groupStart; i < placements.length; i++) {
        const placement = placements[i];
        placements[i] = { ...placement, laneCount: groupLaneCount };
      }
      groupStart = placements.length;
      groupEnd = -1;
      groupLaneCount = 0;
      laneEnds = [];
    }

    let lane = 0;
    while (lane < laneEnds.length && laneEnds[lane] > interval.startMinute) lane += 1;

    if (lane === laneEnds.length) laneEnds.push(interval.endMinute);
    else laneEnds[lane] = interval.endMinute;

    if (lane + 1 > groupLaneCount) groupLaneCount = lane + 1;
    if (interval.endMinute > groupEnd) groupEnd = interval.endMinute;
    placements.push({ id: interval.id, lane: lane, laneCount: 1 });
  }

  if (placements.length > groupStart) {
    for (let i = groupStart; i < placements.length; i++) {
      const placement = placements[i];
      placements[i] = { ...placement, laneCount: groupLaneCount };
    }
  }
  return placements;
}
