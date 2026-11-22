import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildingById, validateCampusData, CATEGORIES } from "../src/lib/data.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, "..");

function load(name) {
  return JSON.parse(readFileSync(path.join(root, "src", "data", name), "utf8"));
}

const buildingsDoc = load("buildings.json");
const campusDoc = load("campus.json");

test("仓库内的 buildings.json 与 campus.json 通过校验", () => {
  const result = validateCampusData(buildingsDoc, campusDoc);
  assert.deepEqual(result.errors, []);
  assert.equal(result.ok, true);
});

test("建筑清单覆盖完整校区（不少于 40 栋）", () => {
  assert.ok(buildingsDoc.buildings.length >= 40, `实际 ${buildingsDoc.buildings.length} 栋`);
  const ids = new Set(buildingsDoc.buildings.map((b) => b.id));
  for (const required of ["gate-north", "gate-east", "library", "gym", "teach-1", "dorm-1", "canteen-1"]) {
    assert.ok(ids.has(required), `缺少 ${required}`);
  }
});

test("北门位于坐标原点，出生点面向校园", () => {
  const gate = buildingById(buildingsDoc, "gate-north");
  assert.ok(gate);
  assert.deepEqual(gate.entrance, { x: 0, z: 0 });
  assert.equal(campusDoc.spawn.x, 0);
  assert.ok(campusDoc.spawn.z > 0);
  assert.equal(campusDoc.spawn.yawDeg, 180);
});

test("建筑分类与状态都在枚举范围内", () => {
  for (const building of buildingsDoc.buildings) {
    assert.ok(CATEGORIES.includes(building.category), `${building.id} 分类非法`);
    assert.equal(building.status, "built", `${building.id} 状态应为已建成`);
  }
});

test("重复 id 会被校验捕获", () => {
  const broken = { buildings: [buildingsDoc.buildings[0], { ...buildingsDoc.buildings[0] }] };
  const result = validateCampusData(broken, campusDoc);
  assert.equal(result.ok, false);
  assert.ok(result.errors.some((message) => message.includes("重复")));
});

test("非法分类会被校验捕获", () => {
  const broken = {
    buildings: [{ ...buildingsDoc.buildings[0], category: "castle" }]
  };
  const result = validateCampusData(broken, campusDoc);
  assert.equal(result.ok, false);
  assert.ok(result.errors.some((message) => message.includes("未知分类")));
});

test("缺少北门会被校验捕获", () => {
  const broken = {
    buildings: buildingsDoc.buildings.filter((building) => building.id !== "gate-north")
  };
  const result = validateCampusData(broken, campusDoc);
  assert.equal(result.ok, false);
  assert.ok(result.errors.some((message) => message.includes("gate-north")));
});

test("出生点跑出边界会被校验捕获", () => {
  const brokenCampus = { ...campusDoc, spawn: { ...campusDoc.spawn, x: 99999 } };
  const result = validateCampusData(buildingsDoc, brokenCampus);
  assert.equal(result.ok, false);
  assert.ok(result.errors.some((message) => message.includes("spawn")));
});