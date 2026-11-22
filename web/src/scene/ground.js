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
    polygonOffsetFactor: -2
  });

  const geometry = new THREE.PlaneGeometry(length, 0.5);
  geometry.rotateX(-Math.PI / 2);
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.set((a[0] + b[0]) / 2, y, (a[1] + b[1]) / 2);
  mesh.rotation.y = -Math.atan2(dz, dx);
  group.add(mesh);
}

function ellipseRingGeometry(outerW, outerD, inset) {
  const shape = new THREE.Shape();
  shape.absellipse(0, 0, outerW / 2, outerD / 2, 0, Math.PI * 2, false, 0);
  const hole = new THREE.Path();
  hole.absellipse(0, 0, outerW / 2 - inset, outerD / 2 - inset, 0, Math.PI * 2, true, 0);
  shape.holes.push(hole);
  const geometry = new THREE.ShapeGeometry(shape, 48);
  geometry.rotateX(-Math.PI / 2);
  return geometry;
}

function ellipseGeometry(w, d) {
  const shape = new THREE.Shape();
  shape.absellipse(0, 0, w / 2, d / 2, 0, Math.PI * 2, false, 0);
  const geometry = new THREE.ShapeGeometry(shape, 48);
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

  return { group, rectangle, segment, circle };
}

function buildTracks(campus) {
  const group = new THREE.Group();
  group.name = "tracks";

  const trackMat = new THREE.MeshStandardMaterial({ color: 0xb0553f, roughness: 0.95 });
  const fieldMat = new THREE.MeshStandardMaterial({ color: 0x5d8553, roughness: 1 });
  const courtMat = new THREE.MeshStandardMaterial({ color: 0xa75f3d, roughness: 0.95 });
  const lineMat = new THREE.LineBasicMaterial({ color: 0xf3f1e7, transparent: true, opacity: 0.85 });

  for (const track of campus.tracks) {
    const node = new THREE.Group();
    node.position.set(track.x, 0, track.z);
    node.rotation.y = -THREE.MathUtils.degToRad(track.rot ?? 0);

    if (track.kind === "track") {
      const ring = new THREE.Mesh(ellipseRingGeometry(track.w, track.d, 8), trackMat);
      ring.position.y = 0.04;
      ring.receiveShadow = true;
      node.add(ring);

      const infield = new THREE.Mesh(ellipseGeometry(track.w - 16, track.d - 16), fieldMat);
      infield.position.y = 0.032;
      infield.receiveShadow = true;
      node.add(infield);

      const lines = whiteLines(lineMat);
      lines.rectangle(0, 0, 30, 50);
      lines.segment(-30, 0, 30, 0);
      lines.circle(0, 0, 9);
      lines.rectangle(0, -39, 20, 8);
      lines.rectangle(0, 39, 20, 8);
      lines.group.position.y = 0.07;
      node.add(lines.group);
    } else if (track.kind === "basketball") {
      const court = new THREE.Mesh(new THREE.PlaneGeometry(track.w, track.d), courtMat);
      court.rotation.x = -Math.PI / 2;
      court.position.y = 0.03;
      court.receiveShadow = true;
      node.add(court);

      const lines = whiteLines(lineMat);
      lines.rectangle(0, 0, track.w / 2 - 1.5, track.d / 2 - 1.5);
      lines.segment(0, -track.d / 2 + 1.5, 0, track.d / 2 - 1.5);
      lines.circle(0, 0, 6);
      lines.group.position.y = 0.06;
      node.add(lines.group);
    } else {
      const field = new THREE.Mesh(new THREE.PlaneGeometry(track.w, track.d), fieldMat);
      field.rotation.x = -Math.PI / 2;
      field.position.y = 0.03;
      field.receiveShadow = true;
      node.add(field);

      const lines = whiteLines(lineMat);
      lines.rectangle(0, 0, track.w / 2 - 2, track.d / 2 - 2);
      lines.segment(0, -track.d / 2 + 2, 0, track.d / 2 - 2);
      lines.circle(0, 0, 6);
      lines.group.position.y = 0.06;
      node.add(lines.group);
    }

    group.add(node);
  }

  return group;
}

function buildCorridors(campus) {
  const group = new THREE.Group();
  group.name = "corridors";

  const stoneMat = new THREE.MeshStandardMaterial({ color: 0xc2bbad, roughness: 0.9 });
  const woodMat = new THREE.MeshStandardMaterial({ color: 0x7a4a38, roughness: 0.82 });
  const roofMat = new THREE.MeshStandardMaterial({ color: 0x46525a, roughness: 0.86 });
  const plaqueMat = new THREE.MeshStandardMaterial({ color: 0x5a2a22, roughness: 0.7 });

  const addBox = (parent, w, h, d, x, y, z, material, castShadow = true) => {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
    mesh.position.set(x, y, z);
    mesh.castShadow = castShadow;
    mesh.receiveShadow = true;
    parent.add(mesh);
  };

  for (const corridor of campus.corridors ?? []) {
    const { x, z, w, d, side } = corridor;
    const node = new THREE.Group();
    node.name = corridor.id ?? "corridor";

    addBox(node, w, 0.18, d, x, 0.09, z, stoneMat, false);
    addBox(node, w - 1.6, 0.12, d - 1.2, x, 0.22, z, stoneMat, false);

    const wallX = x + side * (w / 2 - 0.25);
    addBox(node, 0.4, 1.5, d - 1, wallX, 0.93, z, woodMat);

    const columnOffsets = [-w / 2 + 1.15, w / 2 - 1.15];
    const columnCount = 11;
    const step = (d - 5) / (columnCount - 1);
    for (const offset of columnOffsets) {
      for (let i = 0; i < columnCount; i += 1) {
        const columnZ = z - (d - 5) / 2 + step * i;
        addBox(node, 0.34, 3.3, 0.34, x + offset, 1.83, columnZ, woodMat);
      }
      addBox(node, 0.32, 0.34, d - 2, x + offset, 3.48, z, woodMat);
    }

    for (let i = 0; i < columnCount; i += 1) {
      const rafterZ = z - (d - 5) / 2 + step * i;
      addBox(node, w - 1.4, 0.16, 0.2, x, 3.3, rafterZ, woodMat, false);
    }

    addBox(node, w + 1.6, 0.32, d + 1.2, x, 3.78, z, roofMat);
    addBox(node, w * 0.42, 0.36, d + 1.4, x, 4.06, z, roofMat);

    for (const zOffset of [-11, 11]) {
      addBox(node, 0.62, 0.44, 8, wallX - side * 0.55, 0.44, z + zOffset, woodMat);
    }

    addBox(node, 0.14, 1.25, 5.4, wallX - side * 0.24, 2.2, z, plaqueMat, false);
    group.add(node);
  }

  return group;
}

function buildLamps(campus) {
  const positions = [];
  for (let z = 56; z <= 344; z += 48) {
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

  const waterMat = new THREE.MeshStandardMaterial({
    color: 0x2f7189,
    roughness: 0.22,
    metalness: 0.15,
    transparent: true,
    opacity: 0.94
  });
  const innerMat = new THREE.MeshStandardMaterial({
    color: 0x3f8ba3,
    roughness: 0.18,
    metalness: 0.12,
    transparent: true,
    opacity: 0.9
  });
  const edgeMat = new THREE.LineBasicMaterial({ color: 0xd8e6e2, transparent: true, opacity: 0.55 });

  for (const polygon of campus.water ?? []) {
    const surface = planarMesh(polygon, waterMat, 0.05);
    group.add(surface);

    let cx = 0;
    let cz = 0;
    for (const [x, z] of polygon) {
      cx += x;
      cz += z;
    }
    cx /= polygon.length;
    cz /= polygon.length;

    const inner = polygon.map(([x, z]) => [cx + (x - cx) * 0.86, cz + (z - cz) * 0.86]);
    group.add(planarMesh(inner, innerMat, 0.058));

    const points = polygon.map(([x, z]) => new THREE.Vector3(x, 0.075, z));
    group.add(new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints(points), edgeMat));
  }

  return group;
}

export function buildGround(campus) {
  const group = new THREE.Group();
  group.name = "ground";

  const grassTexture = createGrassTexture();
  const groundGeometry = new THREE.PlaneGeometry(1300, 1100);
  groundGeometry.rotateX(-Math.PI / 2);
  const ground = new THREE.Mesh(
    groundGeometry,
    new THREE.MeshStandardMaterial({ map: grassTexture, roughness: 1, metalness: 0 })
  );
  ground.position.set(0, 0, 355);
  ground.receiveShadow = true;
  group.add(ground);

  const asphaltMat = new THREE.MeshStandardMaterial({ color: 0x3f4950, roughness: 0.96 });
  const sidewalkMat = new THREE.MeshStandardMaterial({ color: 0x9aa1a0, roughness: 0.95 });
  const plazaMat = new THREE.MeshStandardMaterial({ color: 0xa79c8b, roughness: 0.93 });
  const curbMat = new THREE.MeshStandardMaterial({ color: 0xb7b2a6, roughness: 0.9 });

  const roadsGroup = new THREE.Group();
  roadsGroup.name = "roads";
  campus.roads.forEach((road, index) => {
    const baseY = 0.018 + index * 0.0006;
    for (let i = 0; i < road.points.length - 1; i += 1) {
      const a = road.points[i];
      const b = road.points[i + 1];
      addStrip(roadsGroup, a, b, road.width + 7, sidewalkMat, baseY);
      addStrip(roadsGroup, a, b, road.width, asphaltMat, baseY + 0.006);
      addDashes(roadsGroup, a, b, baseY + 0.012);
    }
  });
  group.add(roadsGroup);

  for (const plaza of campus.plazas ?? []) {
    group.add(planarMesh(plaza.polygon, plazaMat, 0.024));
    const points = plaza.polygon.map(([x, z]) => new THREE.Vector3(x, 0.03, z));
    group.add(
      new THREE.LineLoop(
        new THREE.BufferGeometry().setFromPoints(points),
        new THREE.LineBasicMaterial({ color: 0xd9d2c3, transparent: true, opacity: 0.4 })
      )
    );
  }

  group.add(buildTracks(campus));
  group.add(buildCorridors(campus));
  group.add(buildWater(campus));

  const lamps = buildLamps(campus);
  group.add(lamps.group);

  return { group, lampMaterial: lamps.headMaterial };
}