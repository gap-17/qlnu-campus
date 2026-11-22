import * as THREE from "three";
import { CATEGORY_COLORS, ROOF_COLORS } from "../lib/palette.js";

const facadeCache = new Map();
const wallCache = new Map();
const roofCache = new Map();
const detailCache = new Map();
const windowMaterials = new Set();

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

function makeCanvas(size) {
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  return canvas;
}

function windowLayout(kind) {
  if (kind === "dorm") {
    return [
      { x: 16, y: 62, w: 62, h: 132 },
      { x: 97, y: 62, w: 62, h: 132 },
      { x: 178, y: 62, w: 62, h: 132 }
    ];
  }
  if (kind === "lab") {
    return [
      { x: 16, y: 58, w: 50, h: 132 },
      { x: 72, y: 58, w: 50, h: 132 },
      { x: 128, y: 58, w: 50, h: 132 },
      { x: 184, y: 58, w: 50, h: 132 }
    ];
  }
  return [
    { x: 24, y: 62, w: 78, h: 130 },
    { x: 134, y: 62, w: 78, h: 130 }
  ];
}

/**
 * 一张贴图代表 4m × 3.4m（约一层、两跨窗）。
 * 通过 UV 重复在立面上平铺，所有建筑共享材质。
 */
function createFacadeSet(kind, seed) {
  const size = 256;
  const mapCanvas = makeCanvas(size);
  const emitCanvas = makeCanvas(size);
  const ctx = mapCanvas.getContext("2d");
  const ectx = emitCanvas.getContext("2d");
  const rng = mulberry32(seed);

  ctx.fillStyle = "#ece8df";
  ctx.fillRect(0, 0, size, size);

  for (let i = 0; i < 160; i += 1) {
    ctx.fillStyle = `rgba(118,112,101,${0.025 + rng() * 0.05})`;
    ctx.fillRect(rng() * size, rng() * size, 2, 2);
  }

  ctx.fillStyle = "#c8c2b6";
  ctx.fillRect(0, size - 12, size, 12);
  ctx.fillStyle = "rgba(255,255,255,0.35)";
  ctx.fillRect(0, size - 12, size, 2);

  ectx.fillStyle = "#000000";
  ectx.fillRect(0, 0, size, size);

  const windows = windowLayout(kind);

  // 先决定哪些窗亮灯，并保证每套立面至少有一扇亮窗，避免整栋楼夜间全黑。
  const litFlags = windows.map(() => rng() < 0.48);
  if (!litFlags.some(Boolean)) {
    litFlags[Math.floor(rng() * windows.length)] = true;
  }

  windows.forEach((win, index) => {
    ctx.fillStyle = "#c1bbaf";
    ctx.fillRect(win.x - 5, win.y - 5, win.w + 10, win.h + 10);

    const gradient = ctx.createLinearGradient(0, win.y, 0, win.y + win.h);
    gradient.addColorStop(0, "#9db4c2");
    gradient.addColorStop(0.55, "#728b9c");
    gradient.addColorStop(1, "#516a7b");
    ctx.fillStyle = gradient;
    ctx.fillRect(win.x, win.y, win.w, win.h);

    ctx.fillStyle = "rgba(255,255,255,0.16)";
    ctx.beginPath();
    ctx.moveTo(win.x, win.y + win.h * 0.32);
    ctx.lineTo(win.x + win.w * 0.62, win.y);
    ctx.lineTo(win.x + win.w * 0.92, win.y);
    ctx.lineTo(win.x, win.y + win.h * 0.55);
    ctx.closePath();
    ctx.fill();

    ctx.fillStyle = "#d8d2c7";
    ctx.fillRect(win.x + win.w / 2 - 2, win.y, 4, win.h);
    ctx.fillRect(win.x, win.y + win.h / 2 - 2, win.w, 4);
    ctx.fillStyle = "rgba(20,26,30,0.5)";
    ctx.fillRect(win.x, win.y + win.h - 3, win.w, 3);

    if (litFlags[index]) {
      const warm = 205 + Math.floor(rng() * 40);
      const eg = ectx.createLinearGradient(0, win.y, 0, win.y + win.h);
      eg.addColorStop(0, `rgb(255,${warm + 25},${warm - 35})`);
      eg.addColorStop(1, `rgb(255,${warm - 15},${Math.max(120, warm - 80)})`);
      ectx.fillStyle = eg;
      ectx.fillRect(win.x + 1, win.y + 1, win.w - 2, win.h - 2);
      ectx.fillStyle = "#000000";
      ectx.fillRect(win.x + win.w / 2 - 2, win.y, 4, win.h);
      ectx.fillRect(win.x, win.y + win.h / 2 - 2, win.w, 4);
    }
  });

  if (kind === "dorm") {
    ctx.fillStyle = "rgba(92,88,80,0.7)";
    for (let x = 12; x < size; x += 14) {
      ctx.fillRect(x, 176, 2, 46);
    }
    ctx.fillRect(8, 172, size - 16, 4);
    ctx.fillRect(8, 218, size - 16, 5);
  }

  const map = new THREE.CanvasTexture(mapCanvas);
  map.colorSpace = THREE.SRGBColorSpace;
  map.wrapS = THREE.RepeatWrapping;
  map.wrapT = THREE.RepeatWrapping;
  map.anisotropy = 4;

  const emissiveMap = new THREE.CanvasTexture(emitCanvas);
  emissiveMap.colorSpace = THREE.SRGBColorSpace;
  emissiveMap.wrapS = THREE.RepeatWrapping;
  emissiveMap.wrapT = THREE.RepeatWrapping;
  emissiveMap.anisotropy = 4;

  return { map, emissiveMap };
}

function getFacade(kind) {
  if (!facadeCache.has(kind)) {
    const seeds = { standard: 7, dorm: 13, lab: 29 };
    facadeCache.set(kind, createFacadeSet(kind, seeds[kind] ?? 7));
  }
  return facadeCache.get(kind);
}

function kindForCategory(category) {
  if (category === "dorm") return "dorm";
  if (category === "lab") return "lab";
  return "standard";
}

export function getWallMaterial(category) {
  if (!wallCache.has(category)) {
    const facade = getFacade(kindForCategory(category));
    const material = new THREE.MeshStandardMaterial({
      map: facade.map,
      emissiveMap: facade.emissiveMap,
      emissive: new THREE.Color(0xffca8a),
      emissiveIntensity: 0,
      color: new THREE.Color(CATEGORY_COLORS[category] ?? 0xd8d2c4),
      roughness: 0.86,
      metalness: 0.04
    });
    wallCache.set(category, material);
    windowMaterials.add(material);
  }
  return wallCache.get(category);
}

export function getRoofMaterial(category) {
  if (!roofCache.has(category)) {
    roofCache.set(
      category,
      new THREE.MeshStandardMaterial({
        color: new THREE.Color(ROOF_COLORS[category] ?? 0x8c8272),
        roughness: 0.95,
        metalness: 0.06
      })
    );
  }
  return roofCache.get(category);
}

export function getDetailMaterial(color) {
  if (!detailCache.has(color)) {
    detailCache.set(
      color,
      new THREE.MeshStandardMaterial({
        color: new THREE.Color(color),
        roughness: 0.8,
        metalness: 0.08
      })
    );
  }
  return detailCache.get(color);
}

let glassMaterial = null;

export function getGlassMaterial() {
  if (!glassMaterial) {
    glassMaterial = new THREE.MeshStandardMaterial({
      color: 0x9cc2d4,
      roughness: 0.18,
      metalness: 0.35,
      transparent: true,
      opacity: 0.58,
      emissive: 0x2b4a58,
      emissiveIntensity: 0.22,
      side: THREE.DoubleSide
    });
  }
  return glassMaterial;
}

export function setWindowGlow(value) {
  for (const material of windowMaterials) {
    material.emissiveIntensity = value * 1.35;
  }
  if (glassMaterial) {
    // 图书馆等玻璃幕墙没有窗格贴图，夜间给一层暖色室内光，避免整面发黑。
    glassMaterial.emissive.set(value > 0.02 ? 0xffd9a0 : 0x2b4a58);
    glassMaterial.emissiveIntensity = 0.22 + value * 0.18;
    glassMaterial.opacity = 0.58 + value * 0.06;
  }
}

export function createSignTexture(text) {
  const canvas = document.createElement("canvas");
  canvas.width = 1024;
  canvas.height = 192;
  const ctx = canvas.getContext("2d");

  ctx.fillStyle = "#7c2f2c";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.strokeStyle = "rgba(240,205,150,0.65)";
  ctx.lineWidth = 6;
  ctx.strokeRect(10, 10, canvas.width - 20, canvas.height - 20);

  ctx.fillStyle = "#f3d9a4";
  ctx.font = "600 104px 'Noto Serif SC', 'Songti SC', serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(text, canvas.width / 2, canvas.height / 2 + 6);

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = 4;
  return texture;
}