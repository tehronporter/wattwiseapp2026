import { strict as assert } from "node:assert";
import { test } from "node:test";
// @ts-expect-error Node's native TypeScript test runner requires the explicit extension.
import { evaluateCircuit, evaluateRoom, expectedWires, wireKey } from "./labs.ts";

test("connection direction does not change topology", () => {
  assert.equal(wireKey({ from: "a", to: "b" }), wireKey({ from: "b", to: "a" }));
  const result = evaluateCircuit(expectedWires.map(w => ({ from: w.to, to: w.from })), true, 600);
  assert.equal(result.ok, true); assert.equal(result.current, 5);
});
test("missing protective path, open switch, and unexpected connection cannot pass", () => {
  assert.equal(evaluateCircuit(expectedWires.slice(0, 3), true, 600).ok, false);
  assert.equal(evaluateCircuit(expectedWires, false, 600).current, 0);
  assert.equal(evaluateCircuit([...expectedWires, { from: "Source L", to: "Source N" }], true, 600).ok, false);
});
test("overload boundary is explicitly modeled", () => {
  assert.equal(evaluateCircuit(expectedWires, true, 1800).ok, true);
  assert.equal(evaluateCircuit(expectedWires, true, 1920).state, "Overload");
});
test("room coverage checks both ends and interior gaps", () => {
  assert.equal(evaluateRoom([]).ok, false);
  assert.equal(evaluateRoom([2, 7]).ok, true);
  assert.equal(evaluateRoom([0, 9]).ok, false);
  assert.equal(evaluateRoom([3, 7]).ok, false);
  assert.equal(evaluateRoom([2, 6]).ok, false);
  assert.equal(evaluateRoom([2, 2, 7]).count, 2);
});
