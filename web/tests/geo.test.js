import test from "node:test";
import assert from "node:assert/strict";
import {
  rectToPolygon,
  rectContains,
  pointInPolygon,
  polygonArea,
  polygonBounds,
  distancePointToSegment,
  polygonCentroid,
  expandBounds
} from "../src/lib/geo.js";

test("未旋转矩形转成四个角点", () => {
  const polygon = rectToPolygon({ x: 10, z: 20, w: 4, d: 2 });
  assert.deepEqual(polygon, [
    [8, 19],
    [12, 19],
    [12, 21],
    [8, 21]
  ]);
});

test("旋转 90° 后长宽方向互换", () => {
  const polygon = rectToPolygon({ x: 0, z: 0, w: 4, d: 2, rot: 90 });
  const bounds = polygonBounds(polygon);
  assert.ok(Math.abs(bounds.maxX - bounds.minX - 2) < 1e-9);
  assert.ok(Math.abs(bounds.maxZ - bounds.minZ - 4) < 1e-9);
});

test("矩形面积与多边形面积一致", () => {
  const polygon = rectToPolygon({ x: -5, z: 3, w: 8, d: 6, rot: 33 });
  assert.ok(Math.abs(polygonArea(polygon) - 48) < 1e-9);
});

test("pointInPolygon 判定内外", () => {
  const polygon = rectToPolygon({ x: 0, z: 0, w: 10, d: 10 });
  assert.equal(pointInPolygon(0, 0, polygon), true);
  assert.equal(pointInPolygon(-4.9, 4.9, polygon), true);
  assert.equal(pointInPolygon(6, 0, polygon), false);
});

test("rectContains 支持旋转", () => {
  const rect = { x: 0, z: 0, w: 20, d: 4, rot: 90 };
  assert.equal(rectContains(rect, 0, 8), true);
  assert.equal(rectContains(rect, 8, 0), false);
  assert.equal(rectContains(rect, 0, 0), true);
});

test("rectContains 缺少 rot 字段时按未旋转处理", () => {
  const rect = { x: -80, z: 48, w: 120, d: 26 };
  assert.equal(rectContains(rect, -80, 48), true);
  assert.equal(rectContains(rect, -80, 70), false);
  assert.equal(rectContains(rect, 100, 48), false);
});

test("点到线段距离", () => {
  assert.equal(distancePointToSegment(0, 5, -10, 0, 10, 0), 5);
  assert.equal(distancePointToSegment(-20, 0, -10, 0, 10, 0), 10);
  assert.equal(distancePointToSegment(0, 0, 0, 0, 0, 0), 0);
});

test("多边形重心与包围盒", () => {
  const polygon = rectToPolygon({ x: 4, z: -2, w: 6, d: 2 });
  assert.deepEqual(polygonCentroid(polygon), [4, -2]);
  assert.deepEqual(polygonBounds(polygon), { minX: 1, maxX: 7, minZ: -3, maxZ: -1 });
});

test("expandBounds 向外扩展", () => {
  assert.deepEqual(expandBounds({ minX: 0, maxX: 10, minZ: 0, maxZ: 10 }, 5), {
    minX: -5,
    maxX: 15,
    minZ: -5,
    maxZ: 15
  });
});