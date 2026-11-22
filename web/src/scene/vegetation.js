import * as THREE from "three";
import { distancePointToSegment, pointInPolygon, polygonBounds, rectContains } from "../lib/geo.js";

function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function expand(bounds, margin) {
  return {
    minX: bounds.minX - margin,
    maxX: bounds.maxX + margin,
    minZ: bounds.minZ - margin,
    maxZ: bounds.maxZ + margin
  };
}

function insideBounds(x, z, bounds) {
  return x >= bounds.minX && x <= bounds.maxX && z >= bounds.minZ && z <= bounds.maxZ;
}

function nearRoad(x, z, roads) {
  for (const road of roads) {
    for (let i = 0; i < road.points.length - 1; i += 1) {
      const [ax, az] = road.points[i];
      const [bx, bz] = road.points[i + 1];
      if (distancePointToSegment(x, z, ax, az, bx, bz) < road.width / 2 + 5) return true;
    }
  }
  return false;
}

/**
 * 在指定分区内撒树，剔除落在建筑、道路、水系、场地、广场上的点。
 * 树干与树冠各用一个 InstancedMesh，整片树林只有 2 次绘制调用。
 */
export function buildVegetation(campus, buildingColliders, quality) {
  const group = new THREE.Group();
  group.name = "vegetation";

  const blockedBuildings = buildingColliders.map((box) => expand(box, 3));
  const blockedTracks = (campus.tracks ?? []).map((track) =>
    expand(
      {
        minX: track.x - track.w / 2,
        maxX: track.x + track.w / 2,
        minZ: track.z - track.d / 2,
        maxZ: track.z + track.d / 2
      },
      4
    )
  );
  const waterBounds = (campus.water ?? []).map((polygon) => expand(polygonBounds(polygon), 3));
  const blockedCorridors = (campus.corridors ?? []).map((corridor) =>
    expand(
      {
        minX: corridor.x - corridor.w / 2,
        maxX: corridor.x + corridor.w / 2,
        minZ: corridor.z - corridor.d / 2,
        maxZ: corridor.z + corridor.d / 2
      },
      3
    )
  );
  const courtyardWings = (campus.corridors ?? []).filter((corridor) => corridor.courtyard);
  if (courtyardWings.length >= 2) {
    blockedCorridors.push({
      minX: Math.min(...courtyardWings.map((corridor) => corridor.x - corridor.w / 2)),
      maxX: Math.max(...courtyardWings.map((corridor) => corridor.x + corridor.w / 2)),
      minZ: Math.min(...courtyardWings.map((corridor) => corridor.z - corridor.d / 2)),
      maxZ: Math.max(...courtyardWings.map((corridor) => corridor.z + corridor.d / 2))
    });
  }
  const plazas = campus.plazas ?? [];

  const density = quality.mobile ? 0.45 : 1;
  const trees = [];

  for (const zone of campus.treeZones ?? []) {
    const target = Math.round(zone.count * density);
    if (target === 0) continue;
    const rng = mulberry32(zone.seed ?? 1);
    const rect = zone.rect;
    let attempts = 0;
    let placed = 0;

    while (placed < target && attempts < target * 90) {
      attempts += 1;
      const x = rect.x - rect.w / 2 + rng() * rect.w;
      const z = rect.z - rect.d / 2 + rng() * rect.d;

      if (!insideBounds(x, z, expand(campus.bounds, -6))) continue;
      if (blockedBuildings.some((box) => insideBounds(x, z, box))) continue;
      if (blockedTracks.some((box) => insideBounds(x, z, box))) continue;
      if (waterBounds.some((box) => insideBounds(x, z, box))) continue;
      if (blockedCorridors.some((box) => insideBounds(x, z, box))) continue;
      if (plazas.some((plaza) => pointInPolygon(x, z, plaza.polygon))) continue;
      if (nearRoad(x, z, campus.roads)) continue;
      if (!rectContains(rect, x, z)) continue;
      if (trees.some((tree) => Math.hypot(tree.x - x, tree.z - z) < 3.4)) continue;

      trees.push({ x, z, scale: 0.78 + rng() * 0.62, rotation: rng() * Math.PI * 2, hue: rng() });
      placed += 1;
    }
  }

  if (trees.length === 0) return group;

  const trunkGeometry = new THREE.CylinderGeometry(0.14, 0.28, 2.7, 5);
  trunkGeometry.translate(0, 1.35, 0);
  const trunkMaterial = new THREE.MeshStandardMaterial({ color: 0x6d5540, roughness: 0.95 });
  const trunks = new THREE.InstancedMesh(trunkGeometry, trunkMaterial, trees.length);

  const canopyGeometry = new THREE.IcosahedronGeometry(2.15, 0);
  canopyGeometry.translate(0, 4.6, 0);
  const canopyMaterial = new THREE.MeshStandardMaterial({
    color: 0xffffff,
    roughness: 0.9,
    flatShading: true
  });
  const canopies = new THREE.InstancedMesh(canopyGeometry, canopyMaterial, trees.length);

  const matrix = new THREE.Matrix4();
  const quaternion = new THREE.Quaternion();
  const position = new THREE.Vector3();
  const scale = new THREE.Vector3();
  const color = new THREE.Color();

  trees.forEach((tree, index) => {
    quaternion.setFromAxisAngle(new THREE.Vector3(0, 1, 0), tree.rotation);
    position.set(tree.x, 0, tree.z);
    scale.set(tree.scale, tree.scale * (0.92 + tree.hue * 0.3), tree.scale);
    matrix.compose(position, quaternion, scale);
    trunks.setMatrixAt(index, matrix);
    canopies.setMatrixAt(index, matrix);
    color.setHSL(0.26 + tree.hue * 0.07, 0.32 + tree.hue * 0.12, 0.32 + tree.hue * 0.12);
    canopies.setColorAt(index, color);
  });

  trunks.castShadow = quality.shadows;
  trunks.receiveShadow = true;
  canopies.castShadow = quality.shadows;
  canopies.receiveShadow = true;
  if (canopies.instanceColor) canopies.instanceColor.needsUpdate = true;

  group.add(trunks, canopies);
  group.userData.treeCount = trees.length;
  return group;
}