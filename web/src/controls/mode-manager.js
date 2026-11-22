import * as THREE from "three";
import { WalkController } from "./walk.js";
import { FlyController } from "./fly.js";
import { OrbitController } from "./orbit.js";

const MODES = ["walk", "fly", "orbit"];

/**
 * 步行 / 飞行 / 鸟瞰三种模式的状态交接。
 * 切换时尽量保持相机位置和朝向，避免“跳视角”。
 */
export class ModeManager {
  constructor({ camera, dom, colliders, bounds, spawn, eyeHeight, onChange, onLockChange }) {
    this.camera = camera;
    this.onChange = onChange;
    this.mode = null;

    this.controllers = {
      walk: new WalkController({
        camera,
        dom,
        colliders,
        bounds,
        spawn,
        eyeHeight,
        onLockChange
      }),
      fly: new FlyController({ camera, dom, bounds, onLockChange }),
      orbit: new OrbitController({ camera, dom })
    };
  }

  set(mode, { requestLock = true } = {}) {
    if (!MODES.includes(mode)) return;
    if (this.mode === mode) {
      if (requestLock) this.controllers[mode].requestLock?.();
      return;
    }

    const previous = this.mode;
    if (previous) this.controllers[previous].disable();
    if (mode === "orbit" && document.pointerLockElement) document.exitPointerLock();

    const direction = new THREE.Vector3();
    this.camera.getWorldDirection(direction);
    const yaw = Math.atan2(-direction.x, -direction.z);
    const pitch = Math.asin(THREE.MathUtils.clamp(direction.y, -1, 1));

    if (mode === "walk") {
      let x = this.camera.position.x;
      let z = this.camera.position.z;
      if (previous === "orbit") {
        x = this.controllers.orbit.target.x;
        z = this.controllers.orbit.target.z;
      }
      this.controllers.walk.setPose(x, z, yaw, Math.min(Math.max(pitch, -0.35), 0.35));
      this.controllers.walk.enable({ requestLock });
    } else if (mode === "fly") {
      this.controllers.fly.setPose(this.camera.position.clone(), yaw, pitch);
      this.controllers.fly.enable({ requestLock });
    } else {
      if (previous) {
        this.controllers.orbit.setFromCamera(this.camera, direction);
      } else {
        this.controllers.orbit.focusPoint(0, 330, { distance: 520, height: 320 });
      }
      this.controllers.orbit.enable();
    }

    this.mode = mode;
    this.onChange?.(mode);
  }

  update(dt) {
    if (!this.mode) return;
    if (this.mode === "orbit") this.controllers.orbit.update();
    else this.controllers[this.mode].update(dt);
  }

  requestPointerLock() {
    this.controllers[this.mode]?.requestLock?.();
  }

  getYaw() {
    if (this.mode === "walk" || this.mode === "fly") return this.controllers[this.mode].yaw;
    const direction = new THREE.Vector3();
    this.camera.getWorldDirection(direction);
    return Math.atan2(-direction.x, -direction.z);
  }

  teleport(x, z, { faceX, faceZ } = {}) {
    if (this.mode === "orbit") {
      this.controllers.orbit.focusPoint(x, z, { distance: 150, height: 100 });
      return;
    }
    this.controllers[this.mode]?.teleport(x, z, faceX, faceZ);
  }

  focusOrbit(x, z, options) {
    if (this.mode !== "orbit") this.set("orbit");
    this.controllers.orbit.focusPoint(x, z, options);
  }

  setOrbitInitial(x, z) {
    this.controllers.orbit.focusPoint(x, z, { distance: 520, height: 330 });
  }
}