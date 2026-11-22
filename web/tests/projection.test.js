import test from "node:test";
import assert from "node:assert/strict";
import { worldToMinimap, minimapToWorld, minimapScale } from "../src/lib/projection.js";

const bounds = { minX: -440, maxX: 440, minZ: -30, maxZ: 740 };

test("正方形尺寸下边界点映射正确", () => {
  assert.deepEqual(worldToMinimap(-440, -30, bounds, 100), { u: 0, v: 0 });
  assert.deepEqual(worldToMinimap(440, 740, bounds, 100), { u: 100, v: 100 });
});

test("矩形尺寸下地图不拉伸坐标范围", () => {
  const size = { width: 240, height: 210 };
  const center = worldToMinimap(0, 355, bounds, size);
  assert.ok(Math.abs(center.u - 120) < 1e-9);
  assert.ok(Math.abs(center.v - 105) < 1e-9);
});

test("世界坐标与地图像素可逆", () => {
  const size = { width: 240, height: 210 };
  const source = { x: 123.4, z: 456.7 };
  const pixel = worldToMinimap(source.x, source.z, bounds, size);
  const back = minimapToWorld(pixel.u, pixel.v, bounds, size);
  assert.ok(Math.abs(back.x - source.x) < 1e-9);
  assert.ok(Math.abs(back.z - source.z) < 1e-9);
});

test("地图比例因子按宽高分别计算", () => {
  const scale = minimapScale(bounds, { width: 240, height: 210 });
  assert.ok(Math.abs(scale.x - 240 / 880) < 1e-12);
  assert.ok(Math.abs(scale.z - 210 / 770) < 1e-12);
  assert.ok(Math.abs(scale.x - scale.z) < 1e-12, "校园包围盒与画布宽高比一致时应等比");
});