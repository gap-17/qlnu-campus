import { rectToPolygon } from "../lib/geo.js";
import { CATEGORY_CSS, HIGHLIGHT_CSS } from "../lib/palette.js";
import { minimapScale, minimapToWorld, worldToMinimap } from "../lib/projection.js";

const WIDTH = 240;
const HEIGHT = 210;

export class Minimap {
  constructor({ canvas, campus, buildings, onTeleport }) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.campus = campus;
    this.buildings = buildings;
    this.onTeleport = onTeleport;

    this.dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = WIDTH * this.dpr;
    canvas.height = HEIGHT * this.dpr;
    canvas.style.width = `${WIDTH}px`;
    canvas.style.height = `${HEIGHT}px`;

    this.bounds = {
      minX: campus.bounds.minX - 12,
      maxX: campus.bounds.maxX + 12,
      minZ: campus.bounds.minZ - 12,
      maxZ: campus.bounds.maxZ + 12
    };
    this.scale = minimapScale(this.bounds, { width: WIDTH, height: HEIGHT });

    this.staticCanvas = document.createElement("canvas");
    this.staticCanvas.width = WIDTH * this.dpr;
    this.staticCanvas.height = HEIGHT * this.dpr;
    this.drawStatic();

    this.state = null;
    this.selectedId = null;
    this.lastDraw = 0;

    canvas.addEventListener("click", (event) => this.handleClick(event));
    this.draw();
  }

  project(x, z) {
    return worldToMinimap(x, z, this.bounds, { width: WIDTH, height: HEIGHT });
  }

  pathPolygon(ctx, polygon) {
    polygon.forEach(([x, z], index) => {
      const { u, v } = this.project(x, z);
      if (index === 0) ctx.moveTo(u, v);
      else ctx.lineTo(u, v);
    });
    ctx.closePath();
  }

  drawStatic() {
    const ctx = this.staticCanvas.getContext("2d");
    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    ctx.clearRect(0, 0, WIDTH, HEIGHT);

    const background = ctx.createLinearGradient(0, 0, WIDTH, HEIGHT);
    background.addColorStop(0, "#0b1719");
    background.addColorStop(1, "#0a1214");
    ctx.fillStyle = background;
    ctx.fillRect(0, 0, WIDTH, HEIGHT);

    ctx.strokeStyle = "rgba(255,255,255,0.05)";
    ctx.lineWidth = 1;
    for (let x = -400; x <= 400; x += 100) {
      const { u } = this.project(x, 0);
      ctx.beginPath();
      ctx.moveTo(u, 4);
      ctx.lineTo(u, HEIGHT - 4);
      ctx.stroke();
    }
    for (let z = 0; z <= 700; z += 100) {
      const { v } = this.project(0, z);
      ctx.beginPath();
      ctx.moveTo(4, v);
      ctx.lineTo(WIDTH - 4, v);
      ctx.stroke();
    }

    for (const plaza of this.campus.plazas ?? []) {
      ctx.beginPath();
      this.pathPolygon(ctx, plaza.polygon);
      ctx.fillStyle = "#4a453c";
      ctx.fill();
    }

    for (const road of this.campus.roads) {
      ctx.beginPath();
      road.points.forEach(([x, z], index) => {
        const { u, v } = this.project(x, z);
        if (index === 0) ctx.moveTo(u, v);
        else ctx.lineTo(u, v);
      });
      ctx.lineCap = "round";
      ctx.lineJoin = "round";
      const width = road.width * this.scale.x;

      ctx.strokeStyle = "#1d282c";
      ctx.lineWidth = width + 5;
      ctx.stroke();

      ctx.strokeStyle = "#415057";
      ctx.lineWidth = width;
      ctx.stroke();
    }

    for (const corridor of this.campus.corridors ?? []) {
      ctx.beginPath();
      this.pathPolygon(ctx, rectToPolygon({ x: corridor.x, z: corridor.z, w: corridor.w, d: corridor.d, rot: 0 }));
      ctx.fillStyle = "#8a6a4c";
      ctx.fill();
    }

    for (const polygon of this.campus.water ?? []) {
      ctx.beginPath();
      this.pathPolygon(ctx, polygon);
      ctx.fillStyle = "#2f7189";
      ctx.fill();
      ctx.strokeStyle = "rgba(160,210,225,0.6)";
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    for (const track of this.campus.tracks ?? []) {
      const { u, v } = this.project(track.x, track.z);
      const rx = (track.w / 2) * this.scale.x;
      const rz = (track.d / 2) * this.scale.z;

      if (track.kind === "track") {
        ctx.beginPath();
        ctx.ellipse(u, v, rx, rz, 0, 0, Math.PI * 2);
        ctx.fillStyle = "#9c5138";
        ctx.fill();
        ctx.beginPath();
        ctx.ellipse(u, v, rx * 0.84, rz * 0.84, 0, 0, Math.PI * 2);
        ctx.fillStyle = "#4c6b45";
        ctx.fill();
      } else {
        ctx.beginPath();
        ctx.ellipse(u, v, rx, rz, 0, 0, Math.PI * 2);
        ctx.fillStyle = track.kind === "basketball" ? "#94603f" : "#4c6b45";
        ctx.fill();
      }
    }

    for (const building of this.buildings) {
      if (!building.rect) continue;
      const polygon = rectToPolygon(building.rect);
      ctx.beginPath();
      this.pathPolygon(ctx, polygon);
      ctx.fillStyle = CATEGORY_CSS[building.category] ?? "#c8c2b6";
      ctx.fill();
      ctx.strokeStyle = "rgba(0,0,0,0.55)";
      ctx.lineWidth = 0.8;
      ctx.stroke();
    }

    ctx.strokeStyle = "rgba(255,255,255,0.35)";
    ctx.fillStyle = "rgba(255,255,255,0.65)";
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(18, 32);
    ctx.lineTo(18, 15);
    ctx.moveTo(13, 21);
    ctx.lineTo(18, 15);
    ctx.lineTo(23, 21);
    ctx.stroke();
    ctx.font = "600 10px 'PingFang SC', 'Microsoft YaHei', sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("N", 27, 20);

    const scaleLength = 100 * this.scale.x;
    ctx.strokeStyle = "rgba(255,255,255,0.6)";
    ctx.beginPath();
    ctx.moveTo(WIDTH - 14 - scaleLength, HEIGHT - 16);
    ctx.lineTo(WIDTH - 14, HEIGHT - 16);
    ctx.moveTo(WIDTH - 14 - scaleLength, HEIGHT - 20);
    ctx.lineTo(WIDTH - 14 - scaleLength, HEIGHT - 12);
    ctx.moveTo(WIDTH - 14, HEIGHT - 20);
    ctx.lineTo(WIDTH - 14, HEIGHT - 12);
    ctx.stroke();
    ctx.fillStyle = "rgba(255,255,255,0.62)";
    ctx.font = "10px 'PingFang SC', 'Microsoft YaHei', sans-serif";
    ctx.textAlign = "right";
    ctx.fillText("100 m", WIDTH - 14, HEIGHT - 24);
  }

  draw() {
    const ctx = this.ctx;
    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    ctx.clearRect(0, 0, WIDTH, HEIGHT);
    ctx.drawImage(this.staticCanvas, 0, 0, WIDTH, HEIGHT);

    if (this.selectedId) {
      const building = this.buildings.find((item) => item.id === this.selectedId);
      if (building?.rect) {
        ctx.beginPath();
        this.pathPolygon(ctx, rectToPolygon(building.rect));
        ctx.fillStyle = "rgba(242,179,92,0.35)";
        ctx.fill();
        ctx.strokeStyle = HIGHLIGHT_CSS;
        ctx.lineWidth = 1.8;
        ctx.stroke();
      }
    }

    if (!this.state) return;
    const { u, v } = this.project(this.state.x, this.state.z);
    const horizontal = Math.hypot(this.state.dirX, this.state.dirZ);
    const angle = horizontal > 1e-4 ? Math.atan2(this.state.dirZ, this.state.dirX) : Math.PI / 2;

    ctx.beginPath();
    ctx.moveTo(u, v);
    ctx.arc(u, v, 24, angle - 0.48, angle + 0.48);
    ctx.closePath();
    ctx.fillStyle = "rgba(242,179,92,0.18)";
    ctx.fill();

    ctx.save();
    ctx.translate(u, v);
    ctx.rotate(angle);
    ctx.beginPath();
    ctx.moveTo(8, 0);
    ctx.lineTo(-5, 5);
    ctx.lineTo(-2.5, 0);
    ctx.lineTo(-5, -5);
    ctx.closePath();
    ctx.fillStyle = HIGHLIGHT_CSS;
    ctx.fill();
    ctx.strokeStyle = "rgba(10,18,20,0.85)";
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.restore();
  }

  setPlayer(state) {
    this.state = state;
    const now = performance.now();
    if (now - this.lastDraw < 90) return;
    this.lastDraw = now;
    this.draw();
  }

  setSelected(id) {
    this.selectedId = id;
    this.draw();
  }

  handleClick(event) {
    const rect = this.canvas.getBoundingClientRect();
    const u = ((event.clientX - rect.left) / rect.width) * WIDTH;
    const v = ((event.clientY - rect.top) / rect.height) * HEIGHT;
    if (u < 0 || v < 0 || u > WIDTH || v > HEIGHT) return;

    const point = minimapToWorld(u, v, this.bounds, { width: WIDTH, height: HEIGHT });
    const x = Math.min(this.campus.bounds.maxX, Math.max(this.campus.bounds.minX, point.x));
    const z = Math.min(this.campus.bounds.maxZ, Math.max(this.campus.bounds.minZ, point.z));
    this.onTeleport?.(x, z);
  }
}