import test from "node:test";
import assert from "node:assert/strict";
import { resolveCircleAabb, collidesAt, moveWithCollisions } from "../src/lib/collision.js";

const box = { minX: -5, maxX: 5, minZ: -5, maxZ: 5 };

test("圆心在盒外且距离大于半径时无碰撞", () => {
  const result = resolveCircleAabb({ x: 20, z: 0 }, 1, box);
  assert.equal(result.hit, false);
  assert.deepEqual({ x: result.x, z: result.z }, { x: 20, z: 0 });
});

test("圆与盒边相交时被推回到半径处", () => {
  const result = resolveCircleAabb({ x: 5.5, z: 0 }, 1, box);
  assert.equal(result.hit, true);
  assert.ok(Math.abs(result.x - 6) < 1e-9);
  assert.ok(Math.abs(result.z) < 1e-9);
});

test("圆心在盒内时沿最近的边推出", () => {
  const result = resolveCircleAabb({ x: 4.6, z: 0 }, 0.5, box);
  assert.equal(result.hit, true);
  assert.ok(result.x >= 5.5 - 1e-9);
});

test("collidesAt 批量判断", () => {
  assert.equal(collidesAt(0, 0, 0.5, [box]), true);
  assert.equal(collidesAt(30, 30, 0.5, [box]), false);
});

test("moveWithCollisions 撞墙后被推出且保留切向位移", () => {
  const start = { x: 0, z: 8 };
  const result = moveWithCollisions(start, 5.2, -3.2, 0.5, [box], null);
  assert.equal(result.hit, true);
  assert.ok(result.x <= 5.5 + 1e-9, `x=${result.x}`);
  assert.ok(result.z < 8, "切向位移应当保留");
  assert.ok(result.z > 4.5, `z=${result.z}`);
});

test("moveWithCollisions 遵守场景边界", () => {
  const bounds = { minX: -20, maxX: 20, minZ: -20, maxZ: 20 };
  const result = moveWithCollisions({ x: 0, z: 0 }, 999, -999, 1, [], bounds);
  assert.equal(result.x, 19);
  assert.equal(result.z, -19);
});

test("穿过门洞的路径不被误挡（无碰撞盒）", () => {
  const result = moveWithCollisions({ x: 0, z: 10 }, 0, 10, 0.5, [], null);
  assert.deepEqual({ x: result.x, z: result.z }, { x: 0, z: 20 });
});