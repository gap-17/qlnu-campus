import * as THREE from "three";
import {
  createSignTexture,
  getDetailMaterial,
  getGlassMaterial,
  getRoofMaterial,
  getWallMaterial
} from "./materials.js";

const TILE_W = 4;
const TILE_H = 3.4;

const signTexture = { texture: null };

function getSignTexture() {
  if (!signTexture.texture) signTexture.texture = createSignTexture("齐鲁师范学院");
  return signTexture.texture;
}

/**
 * 让立面窗户按米数平铺：每 4m 一跨、3.4m 一层。
 * BoxGeometry 的 6 个面各有 4 个 UV 顶点，顺序 px nx py ny pz nz。
 */
function scaleFacadeUv(geometry, w, h, d, floors) {
  const uv = geometry.attributes.uv;
  const repeatsU = [d, d, w, w, w, w].map((side) => Math.max(1, Math.round(side / TILE_W)));
  const repeatsV = Math.max(1, Math.round(floors ?? h / TILE_H));

  for (let face = 0; face < 6; face += 1) {
    if (face === 2 || face === 3) continue;
    const su = repeatsU[face];
    for (let vertex = 0; vertex < 4; vertex += 1) {
      const index = face * 4 + vertex;
      uv.setXY(index, uv.getX(index) * su, uv.getY(index) * repeatsV);
    }
  }
  uv.needsUpdate = true;
}

function addEntrance(node, building, w, d) {
  if (!building.entrance || !building.rect) return;

  const dx = building.entrance.x - building.rect.x;
  const dz = building.entrance.z - building.rect.z;
  const horizontal = Math.abs(dx) > Math.abs(dz);
  const opening = Math.min(7.2, Math.max(3.6, Math.min(w, d) * 0.34));
  const doorMaterial = getDetailMaterial(0x33424a);
  const stepMaterial = getDetailMaterial(0xbdb7aa);

  if (horizontal) {
    const side = Math.sign(dx) || 1;
    const door = new THREE.Mesh(new THREE.BoxGeometry(0.7, 3.7, opening), doorMaterial);
    door.position.set(side * (w / 2 + 0.25), 1.85, 0);
    const step = new THREE.Mesh(new THREE.BoxGeometry(2.8, 0.3, opening + 4), stepMaterial);
    step.position.set(side * (w / 2 + 1.5), 0.15, 0);
    node.add(door, step);
  } else {
    const side = Math.sign(dz) || 1;
    const door = new THREE.Mesh(new THREE.BoxGeometry(opening, 3.7, 0.7), doorMaterial);
    door.position.set(0, 1.85, side * (d / 2 + 0.25));
    const step = new THREE.Mesh(new THREE.BoxGeometry(opening + 4, 0.3, 2.8), stepMaterial);
    step.position.set(0, 0.15, side * (d / 2 + 1.5));
    node.add(door, step);
  }
}

function addFacadeHighlights(node, building, w, h, d) {
  const glass = getGlassMaterial();
  const rail = getDetailMaterial(0xc9c3b6);

  if (building.id === "library") {
    const curtain = new THREE.Mesh(new THREE.BoxGeometry(w * 0.78, h * 0.82, 0.9), glass);
    curtain.position.set(0, h * 0.44, -d / 2 - 0.8);
    node.add(curtain);

    for (let i = 0; i < 6; i += 1) {
      const column = new THREE.Mesh(new THREE.BoxGeometry(1.8, h * 0.96, 1.8), rail);
      column.position.set(-w * 0.42 + i * (w * 0.84 / 5), h * 0.48, -d / 2 - 2.4);
      column.castShadow = true;
      node.add(column);
    }

    for (let i = 0; i < 3; i += 1) {
      const step = new THREE.Mesh(new THREE.BoxGeometry(w * 0.52 + i * 5, 0.32, 2.4), getDetailMaterial(0xc6c0b3));
      step.position.set(0, 0.16, -d / 2 - 4 - i * 2.3);
      step.receiveShadow = true;
      node.add(step);
    }

    const skylight = new THREE.Mesh(new THREE.BoxGeometry(w * 0.44, 1.6, d * 0.34), glass);
    skylight.position.set(0, h + 0.8, 0);
    node.add(skylight);

    const cap = new THREE.Mesh(new THREE.BoxGeometry(w * 0.5, 0.5, d * 0.4), getRoofMaterial("library"));
    cap.position.set(0, h + 1.85, 0);
    node.add(cap);
  }

  if (building.id === "gym") {
    const domeMaterial = new THREE.MeshStandardMaterial({
      color: 0x93b7bd,
      roughness: 0.46,
      metalness: 0.28,
      flatShading: true
    });
    const dome = new THREE.Mesh(
      new THREE.SphereGeometry(1, 30, 14, 0, Math.PI * 2, 0, Math.PI / 2),
      domeMaterial
    );
    dome.scale.set(w * 0.54, 9.5, d * 0.64);
    dome.position.y = h - 1.6;
    dome.castShadow = true;
    node.add(dome);
  }

  if (building.id === "admin") {
    const canopy = new THREE.Mesh(new THREE.BoxGeometry(26, 0.8, 10), getDetailMaterial(0xd3cec2));
    canopy.position.set(0, 6.1, -d / 2 - 3.4);
    canopy.castShadow = true;
    node.add(canopy);

    for (const x of [-9.5, 9.5]) {
      const column = new THREE.Mesh(new THREE.BoxGeometry(1.1, 6.1, 1.1), getDetailMaterial(0xcfc9bc));
      column.position.set(x, 3.05, -d / 2 - 7.6);
      column.castShadow = true;
      node.add(column);
    }
  }

  if (building.id === "activity-center") {
    const strip = new THREE.Mesh(new THREE.BoxGeometry(w * 0.64, 5.4, 0.5), glass);
    strip.position.set(0, 6.2, -d / 2 - 0.4);
    node.add(strip);
  }

  if (building.category === "canteen") {
    const awning = new THREE.Mesh(
      new THREE.BoxGeometry(w * 0.7, 0.5, 3.2),
      getDetailMaterial(building.id === "canteen-2" ? 0xc9a07a : 0xd0b590)
    );
    awning.position.set(0, 4.3, -d / 2 - 1.6);
    awning.castShadow = true;
    node.add(awning);
  }
}

function makeBlock(building) {
  const { x, z, w, d, rot = 0 } = building.rect;
  const h = building.height_m;
  const node = new THREE.Group();
  node.name = building.id;
  node.position.set(x, 0, z);
  node.rotation.y = -THREE.MathUtils.degToRad(rot);

  const geometry = new THREE.BoxGeometry(w, h, d);
  geometry.translate(0, h / 2, 0);
  scaleFacadeUv(geometry, w, h, d, building.floors);

  const wall = getWallMaterial(building.category);
  const roof = getRoofMaterial(building.category);
  const body = new THREE.Mesh(geometry, [wall, wall, roof, roof, wall, wall]);
  body.castShadow = true;
  body.receiveShadow = true;
  node.add(body);

  const roofSlab = new THREE.Mesh(new THREE.BoxGeometry(w + 0.9, 0.7, d + 0.9), roof);
  roofSlab.position.y = h + 0.35;
  roofSlab.castShadow = true;
  node.add(roofSlab);

  const plinth = new THREE.Mesh(
    new THREE.BoxGeometry(w + 1.6, 0.5, d + 1.6),
    getDetailMaterial(0x9d998d)
  );
  plinth.position.y = 0.25;
  plinth.receiveShadow = true;
  node.add(plinth);

  addEntrance(node, building, w, d);
  addFacadeHighlights(node, building, w, h, d);

  return node;
}

function makeGate(building) {
  const { x, z, w, d } = building.rect;
  const horizontal = w >= d;
  const span = horizontal ? w : d;
  const thickness = horizontal ? d : w;
  const height = building.height_m;

  const node = new THREE.Group();
  node.name = building.id;
  node.position.set(x, 0, z);
  node.rotation.y = horizontal ? 0 : -Math.PI / 2;

  const stone = getDetailMaterial(0xb8b2a4);
  const pillarWidth = 6.4;
  const pillarDepth = thickness + 1.6;

  for (const side of [-1, 1]) {
    const pillar = new THREE.Mesh(new THREE.BoxGeometry(pillarWidth, height, pillarDepth), stone);
    pillar.position.set(side * (span / 2 - pillarWidth / 2), height / 2, 0);
    pillar.castShadow = true;
    pillar.receiveShadow = true;
    node.add(pillar);
  }

  const beam = new THREE.Mesh(
    new THREE.BoxGeometry(span - pillarWidth * 0.2, 2.5, thickness * 0.72),
    stone
  );
  beam.position.set(0, height - 1.6, 0);
  beam.castShadow = true;
  node.add(beam);

  const signMaterial = new THREE.MeshStandardMaterial({
    map: getSignTexture(),
    emissiveMap: getSignTexture(),
    emissive: 0xffffff,
    emissiveIntensity: 0.22,
    roughness: 0.6,
    metalness: 0.1
  });
  const sign = new THREE.Mesh(new THREE.BoxGeometry(24, 4.2, 0.4), signMaterial);
  sign.position.set(0, height - 1.6, thickness * 0.36 + 0.3);
  node.add(sign);

  const booth = new THREE.Mesh(
    new THREE.BoxGeometry(8, 3.4, 6),
    getDetailMaterial(0xcac4b6)
  );
  booth.position.set(-(span / 2 + 3.5), 1.7, 3);
  booth.castShadow = true;
  booth.receiveShadow = true;
  node.add(booth);

  const boothRoof = new THREE.Mesh(
    new THREE.BoxGeometry(9.2, 0.4, 7.2),
    getDetailMaterial(0x6f7276)
  );
  boothRoof.position.set(-(span / 2 + 3.5), 3.5, 3);
  node.add(boothRoof);

  return node;
}

export function buildBuildings(buildings) {
  const group = new THREE.Group();
  group.name = "buildings";

  for (const building of buildings) {
    const node = building.category === "gate" ? makeGate(building) : makeBlock(building);
    node.userData.buildingId = building.id;
    node.traverse((child) => {
      if (child.isMesh) child.userData.buildingId = building.id;
    });
    group.add(node);
  }

  return group;
}