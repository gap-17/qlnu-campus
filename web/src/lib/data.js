/**
 * 校园数据契约。
 * 同时服务于浏览器端（加载 JSON 后校验）与 Node 测试（直接 import）。
 */

export const CATEGORIES = [
  "gate",
  "teaching",
  "lab",
  "library",
  "public",
  "canteen",
  "dorm",
  "gym",
  "logistics"
];

export const CATEGORY_LABELS = Object.freeze({
  gate: "校门",
  teaching: "教学",
  lab: "实验实训",
  library: "图书馆",
  public: "公共建筑",
  canteen: "餐饮",
  dorm: "学生公寓",
  gym: "体育",
  logistics: "后勤商业"
});

export const STATUSES = ["built", "planned", "construction"];

export const STATUS_LABELS = Object.freeze({
  built: "已建成",
  planned: "规划",
  construction: "在建"
});

const REQUIRED_FIELDS = [
  "name",
  "category",
  "status",
  "floors",
  "height_m",
  "entrance",
  "description"
];

function isFiniteNumber(value) {
  return typeof value === "number" && Number.isFinite(value);
}

export function buildingById(doc, id) {
  return (doc?.buildings ?? []).find((building) => building.id === id);
}

function validateRect(id, rect, errors) {
  if (!rect || typeof rect !== "object") {
    errors.push(`${id}: rect 必须是对象`);
    return;
  }
  for (const key of ["x", "z", "w", "d"]) {
    if (!isFiniteNumber(rect[key])) errors.push(`${id}: rect.${key} 必须是数字`);
  }
  if (isFiniteNumber(rect.w) && rect.w <= 0) errors.push(`${id}: rect.w 必须大于 0`);
  if (isFiniteNumber(rect.d) && rect.d <= 0) errors.push(`${id}: rect.d 必须大于 0`);
  if (rect.rot !== undefined && !isFiniteNumber(rect.rot)) {
    errors.push(`${id}: rect.rot 必须是数字（角度）`);
  }
}

function validatePolygon(id, polygon, errors) {
  if (!Array.isArray(polygon) || polygon.length < 3) {
    errors.push(`${id}: polygon 至少需要 3 个点`);
    return;
  }
  polygon.forEach((point, index) => {
    if (!Array.isArray(point) || point.length < 2 || !isFiniteNumber(point[0]) || !isFiniteNumber(point[1])) {
      errors.push(`${id}: polygon[${index}] 必须是 [x, z] 数字对`);
    }
  });
}

export function validateCampusData(buildingsDoc, campusDoc) {
  const errors = [];
  const warnings = [];

  const buildings = buildingsDoc?.buildings;
  if (!Array.isArray(buildings) || buildings.length === 0) {
    errors.push("buildings.json 缺少 buildings 数组");
    return { ok: false, errors, warnings };
  }

  const seen = new Set();
  for (const building of buildings) {
    const id = building.id;
    if (!id) {
      errors.push("存在缺少 id 的建筑");
      continue;
    }
    if (seen.has(id)) errors.push(`建筑 id 重复：${id}`);
    seen.add(id);

    for (const key of REQUIRED_FIELDS) {
      if (building[key] === undefined) errors.push(`${id}: 缺少字段 ${key}`);
    }

    if (building.category && !CATEGORIES.includes(building.category)) {
      errors.push(`${id}: 未知分类 ${building.category}`);
    }
    if (building.status && !STATUSES.includes(building.status)) {
      errors.push(`${id}: 未知状态 ${building.status}`);
    }
    if (building.floors !== undefined && (!Number.isInteger(building.floors) || building.floors <= 0)) {
      errors.push(`${id}: floors 必须是正整数`);
    }
    if (building.height_m !== undefined && (!isFiniteNumber(building.height_m) || building.height_m <= 0)) {
      errors.push(`${id}: height_m 必须是正数`);
    }

    if (building.rect) validateRect(id, building.rect, errors);
    if (building.polygon) validatePolygon(id, building.polygon, errors);
    if (!building.rect && !building.polygon) errors.push(`${id}: 需要 rect 或 polygon`);

    if (building.entrance) {
      if (!isFiniteNumber(building.entrance.x) || !isFiniteNumber(building.entrance.z)) {
        errors.push(`${id}: entrance 必须是 {x, z} 数字对`);
      }
    }

    if (typeof building.description !== "string" || building.description.trim() === "") {
      errors.push(`${id}: description 不能为空`);
    }
  }

  const gate = buildingById(buildingsDoc, "gate-north");
  if (!gate) {
    errors.push("缺少北门 gate-north");
  } else if (gate.entrance && (gate.entrance.x !== 0 || gate.entrance.z !== 0)) {
    errors.push("gate-north 的 entrance 必须是坐标原点 (0, 0)");
  }

  if (!campusDoc || typeof campusDoc !== "object") {
    errors.push("campus.json 内容为空");
    return { ok: errors.length === 0, errors, warnings };
  }

  const bounds = campusDoc.bounds;
  if (!bounds) {
    errors.push("campus 缺少 bounds");
  } else {
    for (const key of ["minX", "maxX", "minZ", "maxZ"]) {
      if (!isFiniteNumber(bounds[key])) errors.push(`campus.bounds.${key} 必须是数字`);
    }
    if (bounds.minX >= bounds.maxX) errors.push("campus.bounds.minX 必须小于 maxX");
    if (bounds.minZ >= bounds.maxZ) errors.push("campus.bounds.minZ 必须小于 maxZ");
  }

  const spawn = campusDoc.spawn;
  if (!spawn) {
    errors.push("campus 缺少 spawn");
  } else {
    if (!isFiniteNumber(spawn.x) || !isFiniteNumber(spawn.z)) {
      errors.push("campus.spawn 必须是 {x, z}");
    } else if (
      bounds &&
      (spawn.x < bounds.minX || spawn.x > bounds.maxX || spawn.z < bounds.minZ || spawn.z > bounds.maxZ)
    ) {
      errors.push("campus.spawn 必须位于 bounds 内");
    }
  }

  if (!Array.isArray(campusDoc.roads) || campusDoc.roads.length === 0) {
    errors.push("campus 缺少 roads");
  } else {
    for (const road of campusDoc.roads) {
      if (!road.id) errors.push("道路缺少 id");
      if (!Array.isArray(road.points) || road.points.length < 2) {
        errors.push(`道路 ${road.id ?? "?"}: points 至少需要 2 个点`);
      } else {
        road.points.forEach((point, index) => {
          if (!Array.isArray(point) || point.length < 2 || !isFiniteNumber(point[0]) || !isFiniteNumber(point[1])) {
            errors.push(`道路 ${road.id ?? "?"}: points[${index}] 必须是 [x, z]`);
          }
        });
      }
      if (!isFiniteNumber(road.width) || road.width <= 0) {
        errors.push(`道路 ${road.id ?? "?"}: width 必须是正数`);
      }
    }
  }

  if (campusDoc.water !== undefined) {
    if (!Array.isArray(campusDoc.water)) {
      errors.push("campus.water 必须是面数组");
    } else {
      campusDoc.water.forEach((polygon, index) => validatePolygon(`water[${index}]`, polygon, errors));
    }
  }

  if (campusDoc.plazas !== undefined) {
    if (!Array.isArray(campusDoc.plazas)) {
      errors.push("campus.plazas 必须是数组");
    } else {
      campusDoc.plazas.forEach((plaza) => validatePolygon(`plaza ${plaza.id ?? "?"}`, plaza.polygon, errors));
    }
  }

  if (campusDoc.tracks !== undefined) {
    if (!Array.isArray(campusDoc.tracks)) {
      errors.push("campus.tracks 必须是数组");
    } else {
      for (const track of campusDoc.tracks) {
        for (const key of ["x", "z", "w", "d"]) {
          if (!isFiniteNumber(track[key])) errors.push(`场地 ${track.id ?? "?"}: ${key} 必须是数字`);
        }
      }
    }
  }

  if (campusDoc.corridors !== undefined) {
    if (!Array.isArray(campusDoc.corridors)) {
      errors.push("campus.corridors 必须是数组");
    } else {
      for (const corridor of campusDoc.corridors) {
        if (!corridor.id) errors.push("文化长廊缺少 id");
        for (const key of ["x", "z", "w", "d"]) {
          if (!isFiniteNumber(corridor[key])) errors.push(`文化长廊 ${corridor.id ?? "?"}: ${key} 必须是数字`);
        }
        if (corridor.w <= 0 || corridor.d <= 0) errors.push(`文化长廊 ${corridor.id ?? "?"}: w/d 必须是正数`);
      }
    }
  }

  if (campusDoc.treeZones !== undefined) {
    if (!Array.isArray(campusDoc.treeZones)) {
      errors.push("campus.treeZones 必须是数组");
    } else {
      for (const zone of campusDoc.treeZones) {
        if (!zone.id) errors.push("树木分区缺少 id");
        if (!zone.rect) errors.push(`树木分区 ${zone.id ?? "?"}: 缺少 rect`);
        else validateRect(`树木分区 ${zone.id}`, zone.rect, errors);
        if (!Number.isInteger(zone.count) || zone.count < 0) {
          errors.push(`树木分区 ${zone.id ?? "?"}: count 必须是非负整数`);
        }
      }
    }
  }

  if (buildings.length < 30) {
    warnings.push(`建筑数量偏少（${buildings.length}），请确认数据是否完整`);
  }

  return { ok: errors.length === 0, errors, warnings };
}