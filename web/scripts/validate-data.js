import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { CATEGORY_LABELS, validateCampusData } from "../src/lib/data.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, "..", "src", "data");

const buildingsDoc = JSON.parse(await readFile(path.join(root, "buildings.json"), "utf8"));
const campusDoc = JSON.parse(await readFile(path.join(root, "campus.json"), "utf8"));

const result = validateCampusData(buildingsDoc, campusDoc);

if (result.warnings.length > 0) {
  for (const warning of result.warnings) console.warn(`警告：${warning}`);
}

if (!result.ok) {
  console.error(`数据校验失败，共 ${result.errors.length} 个问题：`);
  for (const error of result.errors) console.error(`- ${error}`);
  process.exit(1);
}

const counts = new Map();
for (const building of buildingsDoc.buildings) {
  counts.set(building.category, (counts.get(building.category) ?? 0) + 1);
}

console.log(`数据校验通过：${buildingsDoc.buildings.length} 栋建筑，${campusDoc.roads.length} 条道路，${campusDoc.tracks.length} 块运动场地。`);
for (const [category, count] of [...counts.entries()].sort()) {
  console.log(`  ${CATEGORY_LABELS[category] ?? category}：${count}`);
}
const treeTotal = campusDoc.treeZones.reduce((sum, zone) => sum + zone.count, 0);
console.log(`  树木计划：${treeTotal} 棵（分区 ${campusDoc.treeZones.length} 个）`);