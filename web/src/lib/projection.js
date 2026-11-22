/**
 * 世界坐标 ↔ 小地图像素。
 * size 支持数字（正方形）或 { width, height }（矩形）。
 */

function sizeToPixels(size) {
  if (typeof size === "number") return { width: size, height: size };
  return { width: size.width, height: size.height };
}

export function worldToMinimap(x, z, bounds, size) {
  const { width, height } = sizeToPixels(size);
  return {
    u: ((x - bounds.minX) / (bounds.maxX - bounds.minX)) * width,
    v: ((z - bounds.minZ) / (bounds.maxZ - bounds.minZ)) * height
  };
}

export function minimapToWorld(u, v, bounds, size) {
  const { width, height } = sizeToPixels(size);
  return {
    x: bounds.minX + (u / width) * (bounds.maxX - bounds.minX),
    z: bounds.minZ + (v / height) * (bounds.maxZ - bounds.minZ)
  };
}

/** 每米对应的地图像素（用于道路宽度、比例尺） */
export function minimapScale(bounds, size) {
  const { width, height } = sizeToPixels(size);
  return {
    x: width / (bounds.maxX - bounds.minX),
    z: height / (bounds.maxZ - bounds.minZ)
  };
}