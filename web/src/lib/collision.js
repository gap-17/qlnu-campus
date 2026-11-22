/**
 * 2D 圆 vs 轴对齐矩形（AABB）碰撞。
 * 玩家被当作半径为 radius 的圆，建筑被当作 AABB。
 */

export function resolveCircleAabb(pos, radius, box) {
  const nx = Math.max(box.minX, Math.min(pos.x, box.maxX));
  const nz = Math.max(box.minZ, Math.min(pos.z, box.maxZ));
  const dx = pos.x - nx;
  const dz = pos.z - nz;
  const distSq = dx * dx + dz * dz;

  if (distSq > radius * radius) {
    return { x: pos.x, z: pos.z, hit: false };
  }

  if (distSq > 1e-9) {
    const dist = Math.sqrt(distSq);
    return {
      x: nx + (dx / dist) * radius,
      z: nz + (dz / dist) * radius,
      hit: true
    };
  }

  // 圆心在矩形内部：沿最近的一条边推出
  const left = pos.x - box.minX;
  const right = box.maxX - pos.x;
  const up = pos.z - box.minZ;
  const down = box.maxZ - pos.z;
  const min = Math.min(left, right, up, down);

  if (min === left) return { x: box.minX - radius, z: pos.z, hit: true };
  if (min === right) return { x: box.maxX + radius, z: pos.z, hit: true };
  if (min === up) return { x: pos.x, z: box.minZ - radius, hit: true };
  return { x: pos.x, z: box.maxZ + radius, hit: true };
}

export function collidesAt(x, z, radius, boxes) {
  return boxes.some((box) => resolveCircleAabb({ x, z }, radius, box).hit);
}

/**
 * 带碰撞与边界约束的位移。
 * 迭代 3 次以处理墙角与多个障碍同时接触的情况。
 */
export function moveWithCollisions(pos, dx, dz, radius, boxes, bounds) {
  let x = pos.x + dx;
  let z = pos.z + dz;
  let hit = false;

  if (bounds) {
    x = Math.min(bounds.maxX - radius, Math.max(bounds.minX + radius, x));
    z = Math.min(bounds.maxZ - radius, Math.max(bounds.minZ + radius, z));
  }

  for (let iteration = 0; iteration < 3; iteration += 1) {
    let moved = false;
    for (const box of boxes) {
      const result = resolveCircleAabb({ x, z }, radius, box);
      if (result.hit) {
        x = result.x;
        z = result.z;
        moved = true;
        hit = true;
      }
    }
    if (!moved) break;
  }

  if (bounds) {
    x = Math.min(bounds.maxX - radius, Math.max(bounds.minX + radius, x));
    z = Math.min(bounds.maxZ - radius, Math.max(bounds.minZ + radius, z));
  }

  return { x, z, hit };
}