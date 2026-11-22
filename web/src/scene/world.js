import * as THREE from "three";
import { buildGround } from "./ground.js";
import { buildBuildings } from "./buildings.js";
import { buildVegetation } from "./vegetation.js";
import { buildLabels } from "./labels.js";
import { createLighting } from "./lighting.js";
import { collidersFromBuildings, waterColliders } from "../lib/colliders.js";
import { ModeManager } from "../controls/mode-manager.js";

// 用宏任务让出主线程：隐藏标签页里 requestAnimationFrame 不触发，会让分步构建卡死。
const tick = () => new Promise((resolve) => setTimeout(resolve, 16));

export class CampusWorld {
  constructor({ canvas, buildings, campus, quality, callbacks = {} }) {
    this.canvas = canvas;
    this.buildings = buildings;
    this.campus = campus;
    this.quality = quality;
    this.callbacks = callbacks;

    this.byId = new Map(buildings.map((building) => [building.id, building]));
    this.spawn = campus.spawn ?? { x: 0, z: 10, yawDeg: 180, eyeHeight: 1.7 };
    this.navBounds = { ...campus.bounds };
    this.colliders = [...collidersFromBuildings(buildings), ...waterColliders(campus.water ?? [])];

    this.scene = new THREE.Scene();
    const viewWidth = window.innerWidth || 1280;
    const viewHeight = window.innerHeight || 720;
    this.camera = new THREE.PerspectiveCamera(
      65,
      viewWidth / viewHeight,
      0.5,
      3600
    );
    this.camera.rotation.order = "YXZ";
    this.camera.position.set(this.spawn.x, this.spawn.eyeHeight ?? 1.7, this.spawn.z);
    this.camera.rotation.set(0, THREE.MathUtils.degToRad(this.spawn.yawDeg ?? 180), 0);

    this.frameHandlers = new Set();
    this.raycaster = new THREE.Raycaster();
    this._direction = new THREE.Vector3();
    this.clock = new THREE.Clock();
    this.hintTimer = 0;
    this.lastHint = null;
    this.raf = 0;

    this._onResize = () => this.resize();
    window.addEventListener("resize", this._onResize);
  }

  async build(onProgress = () => {}) {
    onProgress("创建渲染器", 6);
    this.initRenderer();

    onProgress("铺设地面与道路", 15);
    this.ground = buildGround(this.campus, this.quality);
    this.scene.add(this.ground.group);
    await tick();

    onProgress("生成校园建筑", 34);
    this.buildingsGroup = buildBuildings(this.buildings);
    this.scene.add(this.buildingsGroup);
    await tick();

    onProgress("种植树木与标识", 55);
    this.vegetation = buildVegetation(
      this.campus,
      collidersFromBuildings(this.buildings),
      this.quality
    );
    this.scene.add(this.vegetation);
    this.labels = buildLabels(this.buildings);
    this.scene.add(this.labels);
    await tick();

    onProgress("设置光照与天空", 72);
    this.lighting = createLighting(this.scene, this.quality);
    await tick();

    onProgress("准备漫游控制", 88);
    this.initModes();
    this.initPicking();
    this.resize();
    this.start();

    onProgress("完成", 100);
  }

  initRenderer() {
    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      antialias: !this.quality.mobile,
      powerPreference: "high-performance",
      // 鸟瞰时相机距离可达 1 km，普通深度缓冲难以区分贴地的道路、水面与操场画线。
      logarithmicDepthBuffer: true
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, this.quality.maxPixelRatio));
    this.renderer.setSize(window.innerWidth, window.innerHeight);
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.04;
    this.renderer.shadowMap.enabled = this.quality.shadows;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;

    this.canvas.addEventListener("webglcontextlost", (event) => {
      event.preventDefault();
      this.callbacks.onToast?.("图形上下文丢失，请刷新页面");
    });
  }

  initModes() {
    this.modes = new ModeManager({
      camera: this.camera,
      dom: this.canvas,
      colliders: this.colliders,
      bounds: this.navBounds,
      spawn: this.spawn,
      eyeHeight: this.spawn.eyeHeight ?? 1.7,
      onChange: (mode) => {
        this.lastHint = null;
        this.callbacks.onModeChange?.(mode);
      },
      onLockChange: (locked) => this.callbacks.onLockChange?.(locked)
    });

    if (this.quality.mobile) {
      this.modes.set("orbit", { requestLock: false });
    } else {
      this.modes.set("walk", { requestLock: false });
    }
  }

  initPicking() {
    this._onClick = (event) => {
      if (this.modes.mode === "orbit") {
        const building = this.pickAt(event.clientX, event.clientY, 2600);
        if (building) this.select(building);
        return;
      }
      if (document.pointerLockElement === this.canvas) {
        const building = this.pickCenter(200);
        if (building) this.select(building);
      } else {
        this.modes.requestPointerLock();
      }
    };
    this.canvas.addEventListener("click", this._onClick);

    this._onKey = (event) => {
      if (event.code !== "KeyE") return;
      if (this.modes?.mode !== "walk" && this.modes?.mode !== "fly") return;
      const building = this.pickCenter(200);
      if (building) this.select(building);
    };
    window.addEventListener("keydown", this._onKey);
  }

  _firstBuilding(raycaster, maxDistance) {
    raycaster.far = maxDistance;
    const targets = [this.buildingsGroup];
    if (this.labels) targets.push(this.labels);
    const hits = raycaster.intersectObjects(targets, true);
    for (const hit of hits) {
      const id = hit.object.userData.buildingId;
      if (id) return this.byId.get(id) ?? null;
    }
    return null;
  }

  pickCenter(maxDistance = 180) {
    this.raycaster.setFromCamera({ x: 0, y: 0 }, this.camera);
    return this._firstBuilding(this.raycaster, maxDistance);
  }

  pickAt(clientX, clientY, maxDistance = 2600) {
    const rect = this.canvas.getBoundingClientRect();
    const ndc = {
      x: ((clientX - rect.left) / rect.width) * 2 - 1,
      y: -((clientY - rect.top) / rect.height) * 2 + 1
    };
    this.raycaster.setFromCamera(ndc, this.camera);
    return this._firstBuilding(this.raycaster, maxDistance);
  }

  select(building) {
    if (document.pointerLockElement) document.exitPointerLock();
    this.callbacks.onSelect?.(building);
  }

  setMode(mode) {
    this.modes?.set(mode);
  }

  getMode() {
    return this.modes?.mode ?? "walk";
  }

  setTime(name) {
    this.lighting?.setPreset(name);
    this.callbacks.onTimeChange?.(name);
  }

  getTime() {
    return this.lighting?.name ?? "day";
  }

  teleport(x, z) {
    if (this.quality.mobile) {
      this.modes?.focusOrbit(x, z, { distance: 170, height: 110 });
      this.callbacks.onToast?.("已定位到地图位置");
      return;
    }
    this.modes?.teleport(x, z);
    this.callbacks.onToast?.("已传送");
  }

  teleportToBuilding(building) {
    const entrance = building.entrance ?? (building.rect ? { x: building.rect.x, z: building.rect.z } : null);
    if (!entrance) return;

    if (this.quality.mobile) {
      this.modes?.focusOrbit(entrance.x, entrance.z, { distance: 120, height: 85 });
      this.callbacks.onToast?.(`已定位到 ${building.name}`);
      return;
    }

    if (this.modes.mode !== "walk") this.modes.set("walk");
    this.modes.teleport(entrance.x, entrance.z, {
      faceX: building.rect?.x ?? entrance.x,
      faceZ: building.rect?.z ?? entrance.z
    });
    this.callbacks.onToast?.(`已到达 ${building.name}`);
  }

  getPlayerState() {
    this.camera.getWorldDirection(this._direction);
    return {
      x: this.camera.position.x,
      y: this.camera.position.y,
      z: this.camera.position.z,
      dirX: this._direction.x,
      dirZ: this._direction.z,
      mode: this.modes?.mode ?? "walk"
    };
  }

  onFrame(handler) {
    this.frameHandlers.add(handler);
    return () => this.frameHandlers.delete(handler);
  }

  _emitHint(text) {
    if (this.lastHint === text) return;
    this.lastHint = text;
    this.callbacks.onHint?.(text);
  }

  _updateHint(dt) {
    if (!this.modes) return;
    if (this.modes.mode !== "walk" && this.modes.mode !== "fly") {
      this._emitHint("");
      return;
    }
    if (document.pointerLockElement !== this.canvas) {
      this._emitHint("");
      return;
    }
    this.hintTimer -= dt;
    if (this.hintTimer > 0) return;
    this.hintTimer = 0.24;
    const building = this.pickCenter(200);
    this._emitHint(building ? `E · 查看 ${building.name}` : "");
  }

  start() {
    this.clock.start();
    const loop = () => {
      const dt = Math.min(0.05, this.clock.getDelta());
      this.modes?.update(dt);
      this.lighting?.update(dt);
      if (this.ground?.lampMaterial && this.lighting) {
        this.ground.lampMaterial.emissiveIntensity = this.lighting.state.window * 1.8;
      }
      this._updateHint(dt);

      const state = this.getPlayerState();
      for (const handler of this.frameHandlers) handler(state, dt);

      this.renderer.render(this.scene, this.camera);
      this.raf = requestAnimationFrame(loop);
    };
    this.raf = requestAnimationFrame(loop);
  }

  resize() {
    if (!this.renderer) return;
    const width = window.innerWidth;
    const height = window.innerHeight;
    // 隐藏标签页或内嵌视口可能报 0×0，跳过以免相机投影矩阵变成 NaN。
    if (!width || !height) return;
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, this.quality.maxPixelRatio));
    this.renderer.setSize(width, height);
  }

  dispose() {
    cancelAnimationFrame(this.raf);
    window.removeEventListener("resize", this._onResize);
  }
}