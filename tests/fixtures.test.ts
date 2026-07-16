import { describe, expect, test } from "bun:test";
import { MONTH_CELLS } from "../src/fixtures.ts";

describe("July 2026 month fixture", () => {
  test("uses a complete Monday-first five-week grid", () => {
    expect(MONTH_CELLS).toHaveLength(35);
    expect(MONTH_CELLS.slice(0, 7).map((cell) => cell.day)).toEqual([
      29,
      30,
      1,
      2,
      3,
      4,
      5,
    ]);
    expect(MONTH_CELLS.slice(-2).map((cell) => cell.day)).toEqual([1, 2]);
  });

  test("places Wednesday July 15 in the third column", () => {
    const today = MONTH_CELLS.find((cell) => cell.today);

    expect(today).toBeDefined();
    expect(today?.id).toBe(17);
    expect((today!.id - 1) % 7).toBe(2);
  });
});
