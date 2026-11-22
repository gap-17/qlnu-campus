import * as THREE from "three";

function makeCanvas(width, height) {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  return canvas;
}

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

function createGrassTexture() {
  const size = 128;
  const canvas = makeCanvas(size, size);
  const ctx = canvas.getContext("2d");
  const rng = mulberry32(20261122);

  ctx.fillStyle = "#80996b";
  ctx.fillRect(0, 0, size, size);
  for (let i = 0; i < 900; i += 1) {
    const tone = 118 + Math.floor(rng() * 42);
    ctx.fillStyle = `rgba(${tone - 40},${tone},${tone - 55},${0.25 + rng() * 0.4})`;
    ctx.fillRect(rng() * size, rng() * size, 1 + rng() * 2, 1 + rng() * 3);
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(46, 40);
  texture.anisotropy = 4;
  return texture;
}

function createDashTexture() {
  const canvas = makeCanvas(64, 8);
  const ctx = canvas.getContext("2d");
  ctx.clearRect(0, 0, 64, 8);
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(4, 1, 30, 6);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.ClampToEdgeWrapping;
  return texture;
}

export function shapeFromXZ(points) {
  const shape = new THREE.Shape();
  points.forEach(([x, z], index) => {
    if (index === 0) shape.moveTo(x, -z);
    else shape.lineTo(x, -z);
  });
  shape.closePath();
  return shape;
}

export function planarMesh(shapeOrPoints, material, y = 0.02) {
  const shape = Array.isArray(shapeOrPoints) ? shapeFromXZ(shapeOrPoints) : shapeOrPoints;
  const geometry = new THREE.ShapeGeometry(shape);
  geometry.rotateX(-Math.PI / 2);
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.y = y;
  mesh.receiveShadow = true;
  return mesh;
}

function addStrip(group, a, b, width, material, y) {
  const dx = b[0] - a[0];
  const dz = b[1] - a[1];
  const length = Math.hypot(dx, dz);
  if (length < 1e-6) return;

  const geometry = new THREE.PlaneGeometry(length, width);
  geometry.rotateX(-Math.PI / 2);
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.set((a[0] + b[0]) / 2, y, (a[1] + b[1]) / 2);
  mesh.rotation.y = -Math.atan2(dz, dx);
  mesh.receiveShadow = true;
  group.add(mesh);
}

function addDashes(group, a, b, y, opacity = 0.5) {
  const dx = b[0] - a[0];
  const dz = b[1] - a[1];
  const length = Math.hypot(dx, dz);
  if (length < 8) return;

  const texture = createDashTexture();
  texture.repeat.set(Math.max(1, Math.round(length / 11)), 1);
  const material = new THREE.MeshBasicMaterial({
    map: texture,
    transparent: true,
    opacity,
    depthWrite: false,
    polygonOffset: true,
    polygonOffsetFactor: -3,
    polygonOffsetUnits: -3
  });

  const geometry = new THREE.PlaneGeometry(length, 0.5);
  geometry.rotateX(-Math.PI / 2);
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.set((a[0] + b[0]) / 2, y, (a[1] + b[1]) / 2);
  mesh.rotation.y = -Math.atan2(dz, dx);
  group.add(mesh);
}

/** 标准田径场轮廓：两条直道 + 两个半圆，长轴沿 z。 */
function stadiumOutline(width, depth, segments = 28) {
  const radius = width / 2;
  const half = Math.max(0, depth - width) / 2;
  const points = [];
  for (let i = 0; i <= segments; i += 1) {
    const angle = (i / segments) * Math.PI;
    points.push([Math.cos(angle) * radius, -half - Math.sin(angle) * radius]);
  }
  for (let i = 0; i <= segments; i += 1) {
    const angle = Math.PI + (i / segments) * Math.PI;
    points.push([Math.cos(angle) * radius, half - Math.sin(angle) * radius]);
  }
  return points;
}

function stadiumGeometry(width, depth) {
  const outline = stadiumOutline(width, depth);
  const shape = new THREE.Shape(outline.map(([x, z]) => new THREE.Vector2(x, -z)));
  const geometry = new THREE.ShapeGeometry(shape);
  geometry.rotateX(-Math.PI / 2);
  return geometry;
}

function stadiumRingGeometry(width, depth, inset) {
  const outer = stadiumOutline(width, depth);
  const inner = stadiumOutline(width - inset * 2, depth - inset * 2);
  const shape = new THREE.Shape(outer.map(([x, z]) => new THREE.Vector2(x, -z)));
  shape.holes.push(new THREE.Path(inner.map(([x, z]) => new THREE.Vector2(x, -z)).reverse()));
  const geometry = new THREE.ShapeGeometry(shape);
  geometry.rotateX(-Math.PI / 2);
  return geometry;
}

function whiteLines(material) {
  const group = new THREE.Group();

  const rectangle = (cx, cz, hw, hd) => {
    const points = [
      new THREE.Vector3(cx - hw, 0, cz - hd),
      new THREE.Vector3(cx + hw, 0, cz - hd),
      new THREE.Vector3(cx + hw, 0, cz + hd),
      new THREE.Vector3(cx - hw, 0, cz + hd)
    ];
    const geometry = new THREE.BufferGeometry().setFromPoints(points);
    group.add(new THREE.LineLoop(geometry, material));
  };

  const segment = (x1, z1, x2, z2) => {
    const geometry = new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(x1, 0, z1),
      new THREE.Vector3(x2, 0, z2)
    ]);
    group.add(new THREE.Line(geometry, material));
  };

  const circle = (cx, cz, radius, segments = 40) => {
    const points = [];
    for (let i = 0; i < segments; i += 1) {
      const a = (i / segments) * Math.PI * 2;
      points.push(new THREE.Vector3(cx + Math.cos(a) * radius, 0, cz + Math.sin(a) * radius));
    }
    const geometry = new THREE.BufferGeometry().setFromPoints(points);
    group.add(new THREE.LineLoop(geometry, material));
  };

  const loop = (points) => {
    const geometry = new THREE.BufferGeometry().setFromPoints(
      points.map(([x, z]) => new THREE.Vector3(x, 0, z))
    );
    group.add(new THREE.LineLoop(geometry, material));
  };

  return { group, rectangle, segment, circle, loop };
}

const LANE_WIDTH = 1.22;
const LANE_COUNT = 8;
const TRACK_INNER_RADIUS = 36.5;

function buildTracks(campus) {
  const group = new THREE.Group();
  group.name = "tracks";

  const trackMat = new THREE.MeshStandardMaterial({
    color: 0xb0553f,
    roughness: 0.95,
    polygonOffset: true,
    polygonOffsetFactor: -2,
    polygonOffsetUnits: -2
  });
  const fieldMat = new THREE.MeshStandardMaterial({
    color: 0x5d8553,
    roughness: 1,
    polygonOffset: true,
    polygonOffsetFactor: -1,
    polygonOffsetUnits: -1
  });
  const courtMat = new THREE.MeshStandardMaterial({
    color: 0xa75f3d,
    roughness: 0.95,
    polygonOffset: true,
    polygonOffsetFactor: -2,
    polygonOffsetUnits: -2
  });
  const lineMat = new THREE.LineBasicMaterial({
    color: 0xf3f1e7,
    transparent: true,
    opacity: 0.85,
    depthWrite: false
  });

  for (const track of campus.tracks) {
    const node = new THREE.Group();
    node.position.set(track.x, 0, track.z);
    node.rotation.y = -THREE.MathUtils.degToRad(track.rot ?? 0);

    if (track.kind === "track") {
      const laneWidth = (track.w / 2 - TRACK_INNER_RADIUS) / LANE_COUNT;
      const ringInset = laneWidth * LANE_COUNT;
      const straight = Math.max(0, track.d - track.w);

      const ring = new THREE.Mesh(stadiumRingGeometry(track.w, track.d, ringInset), trackMat);
      ring.position.y = 0.075;
      ring.receiveShadow = true;
      node.add(ring);

      const infield = new THREE.Mesh(
        stadiumGeometry(track.w - ringInset * 2, track.d - ringInset * 2),
        fieldMat
      );
      infield.position.y = 0.06;
      infield.receiveShadow = true;
      node.add(infield);

      const lines = whiteLines(lineMat);
      for (let lane = 0; lane <= LANE_COUNT; lane += 1) {
        const radius = TRACK_INNER_RADIUS + lane * laneWidth;
        lines.loop(stadiumOutline(radius * 2, straight + radius * 2));
      }
      lines.segment(-track.w / 2, 0, -TRACK_INNER_RADIUS, 0);

      // 内场 68 m × 105 m 足球场
      lines.rectangle(0, 0, 34, 52.5);
      lines.segment(-34, 0, 34, 0);
      lines.circle(0, 0, 9.15);
      lines.rectangle(0, -44.25, 20.16, 8.25);
      lines.rectangle(0, 44.25, 20.16, 8.25);
      lines.rectangle(0, -49.75, 9.16, 2.75);
      lines.rectangle(0, 49.75, 9.16, 2.75);
      lines.circle(0, -41.5, 0.35, 10);
      lines.circle(0, 41.5, 0.35, 10);
      lines.group.position.y = 0.13;
      node.add(lines.group);
    } else if (track.kind === "basketball") {
      const court = new THREE.Mesh(new THREE.PlaneGeometry(track.w, track.d), courtMat);
      court.rotation.x = -Math.PI / 2;
      court.position.y = 0.065;
      court.receiveShadow = true;
      node.add(court);

      const lines = whiteLines(lineMat);
      lines.rectangle(0, 0, track.w / 2 - 1.5, track.d / 2 - 1.5);
      lines.segment(0, -track.d / 2 + 1.5, 0, track.d / 2 - 1.5);
      lines.circle(0, 0, 6);
      lines.group.position.y = 0.115;
      node.add(lines.group);
    } else {
      const field = new THREE.Mesh(new THREE.PlaneGeometry(track.w, track.d), fieldMat);
      field.rotation.x = -Math.PI / 2;
      field.position.y = 0.06;
      field.receiveShadow = true;
      node.add(field);

      const lines = whiteLines(lineMat);
      lines.rectangle(0, 0, track.w / 2 - 2, track.d / 2 - 2);
      lines.segment(0, -track.d / 2 + 2, 0, track.d / 2 - 2);
      lines.circle(0, 0, 6);
      lines.group.position.y = 0.115;
      node.add(lines.group);
    }

    group.add(node);
  }

  return group;
}

function buildCorridors(campus, quality) {
  const group = new THREE.Group();
  group.name = "corridors";

  const stoneMat = new THREE.MeshStandardMaterial({ color: 0xc2bbad, roughness: 0.9 });
  const pavingMat = new THREE.MeshStandardMaterial({
    color: 0xb6ada0,
    roughness: 0.96,
    polygonOffset: true,
    polygonOffsetFactor: -1,
    polygonOffsetUnits: -1
  });
  const woodMat = new THREE.MeshStandardMaterial({ color: 0x5b3b2e, roughness: 0.82 });
  const roofMat = new THREE.MeshStandardMaterial({ color: 0x46525a, roughness: 0.86 });
  const plaqueMat = new THREE.MeshStandardMaterial({ color: 0x5a2a22, roughness: 0.7 });

  const addBox = (parent, w, h, d, x, y, z, material, castShadow = true) => {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
    mesh.position.set(x, y, z);
    mesh.castShadow = castShadow;
    mesh.receiveShadow = true;
    parent.add(mesh);
  };

  const bayFactor = quality?.mobile ? 0.55 : 1;

  /** axis = "z" 时沿南北展开，axis = "x" 时沿东西展开。 */
  const addGallery = (x, z, w, d, side, bays, axis = "z") => {
    const node = new THREE.Group();
    addBox(node, w, 0.18, d, x, 0.09, z, stoneMat, false);
    addBox(node, w - 1.6, 0.12, d - 1.2, x, 0.22, z, stoneMat, false);

    const length = axis === "z" ? d : w;
    const count = Math.max(2, Math.round((bays ?? length / 3.5) * bayFactor));
    const step = (length - 4) / (count - 1);

    if (axis === "z") {
      const wallX = x + side * (w / 2 - 0.25);
      addBox(node, 0.4, 1.5, d - 1, wallX, 0.93, z, woodMat);
      for (const offset of [-w / 2 + 1.15, w / 2 - 1.15]) {
        for (let i = 0; i < count; i += 1) {
          addBox(node, 0.34, 4.3, 0.34, x + offset, 2.33, z - (d - 4) / 2 + step * i, woodMat);
        }
        addBox(node, 0.32, 0.34, d - 2, x + offset, 4.48, z, woodMat);
      }
      for (let i = 0; i < count; i += 1) {
        addBox(node, w - 1.4, 0.16, 0.2, x, 4.3, z - (d - 4) / 2 + step * i, woodMat, false);
      }
      addBox(node, w + 1.6, 0.32, d + 1.2, x, 4.78, z, roofMat);
      addBox(node, w * 0.42, 0.36, d + 1.4, x, 5.06, z, roofMat);
      addBox(node, 0.14, 1.25, 5.4, wallX - side * 0.24, 2.2, z, plaqueMat, false);
    } else {
      const wallZ = z + side * (d / 2 - 0.25);
      if (side) addBox(node, w - 1, 1.5, 0.4, x, 0.93, wallZ, woodMat);
      for (const offset of [-d / 2 + 1.15, d / 2 - 1.15]) {
        for (let i = 0; i < count; i += 1) {
          addBox(node, 0.34, 4.3, 0.34, x - (w - 4) / 2 + step * i, 2.33, z + offset, woodMat);
        }
        addBox(node, w - 2, 0.34, 0.32, x, 4.48, z + offset, woodMat);
      }
      for (let i = 0; i < count; i += 1) {
        addBox(node, 0.2, 0.16, d - 1.4, x - (w - 4) / 2 + step * i, 4.3, z, woodMat, false);
      }
      addBox(node, w + 1.2, 0.32, d + 1.6, x, 4.78, z, roofMat);
      addBox(node, w + 1.4, 0.36, d * 0.42, x, 5.06, z, roofMat);
    }

    group.add(node);
  };

  const addPavilion = (x, z, size, height, twoTier = false) => {
    const node = new THREE.Group();
    addBox(node, size + 1.4, 0.5, size + 1.4, x, 0.25, z, stoneMat);

    const offset = size / 2 - 0.65;
    const columnHeight = height * 0.58;
    const offsets = size >= 12 ? [-offset, 0, offset] : [-offset, offset];
    for (const dx of offsets) {
      for (const dz of offsets) {
        if (dx === 0 && dz === 0) continue;
        addBox(node, 0.48, columnHeight, 0.48, x + dx, 0.5 + columnHeight / 2, z + dz, woodMat);
      }
    }

    addBox(node, size, 0.3, size, x, 0.5 + columnHeight + 0.15, z, woodMat, false);
    const eave = 0.5 + columnHeight + 0.5;
    addBox(node, size + 2.6, 0.34, size + 2.6, x, eave, z, roofMat);

    let peakBase = eave + 0.17;
    let peakRadius = size * 0.72;
    let peakHeight = height * 0.42;
    if (twoTier) {
      addBox(node, size * 0.56, height * 0.2, size * 0.56, x, eave + height * 0.1 + 0.2, z, woodMat, false);
      addBox(node, size * 0.92, 0.3, size * 0.92, x, eave + height * 0.2 + 0.35, z, roofMat);
      peakBase = eave + height * 0.2 + 0.5;
      peakRadius = size * 0.54;
      peakHeight = height * 0.34;
    }

    const peak = new THREE.Mesh(new THREE.ConeGeometry(peakRadius, peakHeight, 4), roofMat);
    peak.rotation.y = Math.PI / 4;
    peak.position.set(x, peakBase + peakHeight / 2, z);
    peak.castShadow = true;
    peak.receiveShadow = true;
    node.add(peak);

    group.add(node);
  };

  const wings = [];
  for (const corridor of campus.corridors ?? []) {
    addGallery(corridor.x, corridor.z, corridor.w, corridor.d, corridor.side ?? 1, corridor.bays, "z");
    if (corridor.courtyard) wings.push(corridor);
  }

  if (wings.length >= 2) {
    const minX = Math.min(...wings.map((c) => c.x - c.w / 2));
    const maxX = Math.max(...wings.map((c) => c.x + c.w / 2));
    const minZ = Math.min(...wings.map((c) => c.z - c.d / 2));
    const maxZ = Math.max(...wings.map((c) => c.z + c.d / 2));
    const innerMinX = Math.min(...wings.map((c) => Math.abs(c.x) - c.w / 2));
    const crossW = innerMinX * 2;
    const crossZ = [minZ + 4.5, maxZ - 4.5];
    const middleZ = (minZ + maxZ) / 2;

    group.add(
      planarMesh(
        [
          [-innerMinX, crossZ[0] + 4.5],
          [innerMinX, crossZ[0] + 4.5],
          [innerMinX, crossZ[1] - 4.5],
          [-innerMinX, crossZ[1] - 4.5]
        ],
        pavingMat,
        0.045
      )
    );

    for (const z of crossZ) {
      addGallery(0, z, crossW, 9, z < middleZ ? -1 : 1, Math.round(crossW / 3.5), "x");
      for (const x of [minX + 4.5, maxX - 4.5]) addPavilion(x, z, 8, 6.5);
    }

    addPavilion(0, maxZ - 22, 13, 11, true);
  }

  return group;
}

function buildLamps(campus) {
  const positions = [];
  for (let z = 56; z <= 344; z += 48) {
    // 文化长廊院落范围内不再放中轴路灯，避免灯具穿入廊庑。
    if (z > 64 && z < 200) continue;
    positions.push([-13, z], [13, z]);
  }
  for (let x = -170; x <= 170; x += 68) {
    positions.push([x, 212], [x, 240]);
  }

  const poleGeometry = new THREE.CylinderGeometry(0.12, 0.18, 4.6, 6);
  poleGeometry.translate(0, 2.3, 0);
  const poleMaterial = new THREE.MeshStandardMaterial({ color: 0x3a3f42, roughness: 0.7, metalness: 0.4 });
  const poles = new THREE.InstancedMesh(poleGeometry, poleMaterial, positions.length);

  const headGeometry = new THREE.BoxGeometry(0.95, 0.22, 0.46);
  const headMaterial = new THREE.MeshStandardMaterial({
    color: 0xfff2cf,
    emissive: 0xffca7a,
    emissiveIntensity: 0,
    roughness: 0.4
  });
  const heads = new THREE.InstancedMesh(headGeometry, headMaterial, positions.length);

  const matrix = new THREE.Matrix4();
  positions.forEach(([x, z], index) => {
    matrix.makeTranslation(x, 0, z);
    poles.setMatrixAt(index, matrix);
    matrix.makeTranslation(x, 4.62, z);
    heads.setMatrixAt(index, matrix);
  });
  poles.castShadow = true;
  headMaterial.emissiveIntensity = 0;

  const group = new THREE.Group();
  group.name = "lamps";
  group.add(poles, heads);

  return { group, headMaterial };
}

function buildWater(campus) {
  const group = new THREE.Group();
  group.name = "water";

  // 单层水面：叠两层透明面在远距离会互相争深度，出现闪烁。
  const waterMat = new THREE.MeshStandardMaterial({
    color: 0x2f7189,
    roughness: 0.12,
    metalness: 0.08,
    transparent: true,
    opacity: 0.92,
    depthWrite: false,
    polygonOffset: true,
    polygonOffsetFactor: -2,
    polygonOffsetUnits: -2
  });
  const islandMat = new THREE.MeshStandardMaterial({
    color: 0x6f8a5c,
    roughness: 1,
    polygonOffset: true,
    polygonOffsetFactor: -3,
    polygonOffsetUnits: -3
  });
  const edgeMat = new THREE.LineBasicMaterial({
    color: 0xd8e6e2,
    transparent: true,
    opacity: 0.55,
    depthWrite: false
  });

  for (const polygon of campus.water ?? []) {
    group.add(planarMesh(polygon, waterMat, 0.09));

    const points = polygon.map(([x, z]) => new THREE.Vector3(x, 0.1, z));
    group.add(new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints(points), edgeMat));
  }

  for (const polygon of campus.waterIslands ?? []) {
    group.add(planarMesh(polygon, islandMat, 0.12));
  }

  return group;
}

export function buildGround(campus, quality) {
  const group = new THREE.Group();
  group.name = "ground";

  const grassTexture = createGrassTexture();
  const groundGeometry = new THREE.PlaneGeometry(1300, 1100);
  groundGeometry.rotateX(-Math.PI / 2);
  const ground = new THREE.Mesh(
    groundGeometry,
    new THREE.MeshStandardMaterial({
      map: grassTexture,
      roughness: 1,
      metalness: 0,
      polygonOffset: true,
      polygonOffsetFactor: 1,
      polygonOffsetUnits: 1
    })
  );
  ground.position.set(0, 0, 355);
  ground.receiveShadow = true;
  group.add(ground);

  // 所有路面站在同一条基准线上，靠 polygonOffset 分层；
  // 若每条路各自抬几毫米，鸟瞰时交叉口会与草地争深度而闪烁。
  const asphaltMat = new THREE.MeshStandardMaterial({
    color: 0x3f4950,
    roughness: 0.96,
    polygonOffset: true,
    polygonOffsetFactor: -2,
    polygonOffsetUnits: -2
  });
  const sidewalkMat = new THREE.MeshStandardMaterial({
    color: 0x9aa1a0,
    roughness: 0.95,
    polygonOffset: true,
    polygonOffsetFactor: -1,
    polygonOffsetUnits: -1
  });
  const plazaMat = new THREE.MeshStandardMaterial({
    color: 0xa79c8b,
    roughness: 0.93,
    polygonOffset: true,
    polygonOffsetFactor: -1,
    polygonOffsetUnits: -1
  });

  const roadsGroup = new THREE.Group();
  roadsGroup.name = "roads";
  campus.roads.forEach((road) => {
    for (let i = 0; i < road.points.length - 1; i += 1) {
      const a = road.points[i];
      const b = road.points[i + 1];
      addStrip(roadsGroup, a, b, road.width + 7, sidewalkMat, 0.03);
      addStrip(roadsGroup, a, b, road.width, asphaltMat, 0.08);
      addDashes(roadsGroup, a, b, 0.1);
    }
  });
  group.add(roadsGroup);

  for (const plaza of campus.plazas ?? []) {
    group.add(planarMesh(plaza.polygon, plazaMat, 0.055));
    const points = plaza.polygon.map(([x, z]) => new THREE.Vector3(x, 0.065, z));
    group.add(
      new THREE.LineLoop(
        new THREE.BufferGeometry().setFromPoints(points),
        new THREE.LineBasicMaterial({ color: 0xd9d2c3, transparent: true, opacity: 0.4, depthWrite: false })
      )
    );
  }

  group.add(buildTracks(campus));
  group.add(buildCorridors(campus, quality));
  group.add(buildWater(campus));

  const lamps = buildLamps(campus);
  group.add(lamps.group);

  return { group, lampMaterial: lamps.headMaterial };
}