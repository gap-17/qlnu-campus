import { footprintPolygon, polygonBounds } from "./geo.js";

/**
 * 从建筑数据生成碰撞盒。
 * 旋转建筑用其外接 AABB 近似（v0.1 的矩形基本为 0°，误差可忽略）。
 * 校门有意不加碰撞，保证可以从门洞穿行。
 */
export function collidersFromBuildings(buildings) {
  return buildings
    .filter((building) => building.category !== "gate")
    .map((building) => {
      const polygon = footprintPolygon(building);
      const bounds = polygonBounds(polygon);
      return {
        id: building.id,
        minX: bounds.minX,
        maxX: bounds.maxX,
        minZ: bounds.minZ,
        maxZ: bounds.maxZ
      };
    });
}

export function waterColliders(waterPolygons) {
  return waterPolygons.map((polygon, index) => {
    const bounds = polygonBounds(polygon);
    return {
      id: `water-${index}`,
      minX: bounds.minX,
      maxX: bounds.maxX,
      minZ: bounds.minZ,
      maxZ: bounds.maxZ
    };
  });
}