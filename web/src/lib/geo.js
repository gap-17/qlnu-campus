/**
 * 平面几何工具：全部使用校园坐标 (x, z)，单位米。
 * 不使用 three.js，方便 Node 测试复用。
 */

const DEG = Math.PI / 180;

/** 矩形（可绕自身中心旋转 rot 度）→ 四个角点 */
export function rectToPolygon({ x, z, w, d, rot = 0 }) {
  const hw = w / 2;
  const hd = d / 2;
  const a = rot * DEG;
  const c = Math.cos(a);
  const s = Math.sin(a);
  return [
    [-hw, -hd],
    [hw, -hd],
    [hw, hd],
    [-hw, hd]
  ].map(([px, pz]) => [x + px * c - pz * s, z + px * s + pz * c]);
}

export function footprintPolygon(building) {
  if (building.rect) return rectToPolygon(building.rect);
  return building.polygon ?? [];
}

/** 射线法：点是否在多边形内 */
export function pointInPolygon(x, z, polygon) {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const [xi, zi] = polygon[i];
    const [xj, zj] = polygon[j];
    const crosses = zi > z !== zj > z;
    if (crosses && x < ((xj - xi) * (z - zi)) / (zj - zi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

export function polygonArea(polygon) {
  let area = 0;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    area += polygon[j][0] * polygon[i][1] - polygon[i][0] * polygon[j][1];
  }
  return Math.abs(area / 2);
}

export function polygonBounds(polygon) {
  const bounds = {
    minX: Infinity,
    maxX: -Infinity,
    minZ: Infinity,
    maxZ: -Infinity
  };
  for (const [x, z] of polygon) {
    bounds.minX = Math.min(bounds.minX, x);
    bounds.maxX = Math.max(bounds.maxX, x);
    bounds.minZ = Math.min(bounds.minZ, z);
    bounds.maxZ = Math.max(bounds.maxZ, z);
  }
  return bounds;
}

/** 点在未旋转/旋转矩形内（不计边缘余量） */
export function rectContains(rect, x, z) {
  const a = -(rect.rot ?? 0) * DEG;
  const dx = x - rect.x;
  const dz = z - rect.z;
  const lx = dx * Math.cos(a) - dz * Math.sin(a);
  const lz = dx * Math.sin(a) + dz * Math.cos(a);
  return Math.abs(lx) <= rect.w / 2 && Math.abs(lz) <= rect.d / 2;
}

export function distancePointToSegment(px, pz, ax, az, bx, bz) {
  const abx = bx - ax;
  const abz = bz - az;
  const lengthSq = abx * abx + abz * abz;
  if (lengthSq < 1e-9) return Math.hypot(px - ax, pz - az);
  let t = ((px - ax) * abx + (pz - az) * abz) / lengthSq;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(px - (ax + abx * t), pz - (az + abz * t));
}

export function polygonCentroid(polygon) {
  let x = 0;
  let z = 0;
  for (const [px, pz] of polygon) {
    x += px;
    z += pz;
  }
  return [x / polygon.length, z / polygon.length];
}

export function expandBounds(bounds, margin) {
  return {
    minX: bounds.minX - margin,
    maxX: bounds.maxX + margin,
    minZ: bounds.minZ - margin,
    maxZ: bounds.maxZ + margin
  };
}

export function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}