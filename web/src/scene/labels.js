import * as THREE from "three";

const LANDMARKS = [
  "gate-north",
  "library",
  "admin",
  "gym",
  "activity-center",
  "art-center",
  "canteen-1",
  "canteen-2",
  "canteen-south",
  "canteen-3",
  "training-center",
  "music-hall",
  "complex",
  "research-dorm",
  "gate-east"
];

function createLabelTexture(name, alias) {
  const width = 512;
  const height = alias ? 144 : 112;
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");

  ctx.fillStyle = "rgba(8, 18, 20, 0.66)";
  const radius = 26;
  ctx.beginPath();
  ctx.roundRect(6, 6, width - 12, height - 12, radius);
  ctx.fill();
  ctx.strokeStyle = "rgba(255, 255, 255, 0.22)";
  ctx.lineWidth = 3;
  ctx.stroke();

  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = "#f4f1e8";
  let fontSize = 50;
  ctx.font = `600 ${fontSize}px "PingFang SC", "Microsoft YaHei", sans-serif`;
  while (ctx.measureText(name).width > width - 56 && fontSize > 26) {
    fontSize -= 2;
    ctx.font = `600 ${fontSize}px "PingFang SC", "Microsoft YaHei", sans-serif`;
  }
  ctx.fillText(name, width / 2, alias ? height * 0.38 : height * 0.52);

  if (alias) {
    ctx.fillStyle = "rgba(242, 179, 92, 0.92)";
    ctx.font = "400 30px 'PingFang SC', 'Microsoft YaHei', sans-serif";
    ctx.fillText(alias, width / 2, height * 0.72);
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = 4;
  return texture;
}

export function buildLabels(buildings) {
  const group = new THREE.Group();
  group.name = "labels";
  const byId = new Map(buildings.map((building) => [building.id, building]));

  for (const id of LANDMARKS) {
    const building = byId.get(id);
    if (!building?.rect) continue;

    const texture = createLabelTexture(building.name, building.alias);
    const material = new THREE.SpriteMaterial({
      map: texture,
      transparent: true,
      depthWrite: false,
      opacity: 0.94
    });
    const sprite = new THREE.Sprite(material);
    const aspect = texture.image.height / texture.image.width;
    const width = building.id === "library" ? 46 : 40;
    sprite.scale.set(width, width * aspect, 1);
    sprite.position.set(building.rect.x, building.height_m + 9, building.rect.z);
    sprite.userData.buildingId = building.id;
    sprite.renderOrder = 3;
    group.add(sprite);
  }

  return group;
}