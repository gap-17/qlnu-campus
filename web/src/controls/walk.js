import * as THREE from "three";
import { moveWithCollisions } from "../lib/collision.js";

/**
 * 第一人称步行：鼠标视角 + WASD + 圆/矩形碰撞 + 边界约束。
 */
export class WalkController {
  constructor({ camera, dom, colliders, bounds, eyeHeight = 1.7, spawn, onLockChange }) {
    this.camera = camera;
    this.dom = dom;
    this.colliders = colliders;
    this.bounds = bounds;
    this.eyeHeight = eyeHeight;
    this.onLockChange = onLockChange;

    this.x = spawn?.x ?? 0;
    this.z = spawn?.z ?? 0;
    this.yaw = Math.PI;
    this.pitch = 0;
    this.bob = 0;
    this.bobTime = 0;
    this.radius = 0.5;
    this.speed = 5.4;
    this.enabled = false;
    this.keys = new Set();

    this._onKeyDown = (event) => {
      if (!this.enabled) return;
      if (["Space", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(event.code)) {
        event.preventDefault();
      }
      this.keys.add(event.code);
    };
    this._onKeyUp = (event) => {
      this.keys.delete(event.code);
    };
    this._onMouseMove = (event) => {
      if (!this.enabled || document.pointerLockElement !== this.dom) return;
      this.yaw -= event.movementX * 0.0022;
      this.pitch = THREE.MathUtils.clamp(this.pitch - event.movementY * 0.0022, -1.4, 1.4);
    };
    this._onLockChange = () => {
      if (!this.enabled) return;
      this.onLockChange?.(document.pointerLockElement === this.dom);
    };
    this._onBlur = () => this.keys.clear();

    window.addEventListener("keydown", this._onKeyDown);
    window.addEventListener("keyup", this._onKeyUp);
    window.addEventListener("blur", this._onBlur);
    document.addEventListener("mousemove", this._onMouseMove);
    document.addEventListener("pointerlockchange", this._onLockChange);
  }

  enable({ requestLock = true } = {}) {
    this.enabled = true;
    this.keys.clear();
    this.applyCamera();
    if (requestLock) this.requestLock();
  }

  disable() {
    this.enabled = false;
    this.keys.clear();
  }

  requestLock() {
    if (document.pointerLockElement === this.dom) return;
    try {
      const result = this.dom.requestPointerLock?.();
      if (result && typeof result.catch === "function") result.catch(() => {});
    } catch {
      /* 浏览器可能拒绝，用户点击画面可重试 */
    }
  }

  setPose(x, z, yaw, pitch = 0) {
    this.x = x;
    this.z = z;
    this.yaw = yaw;
    this.pitch = THREE.MathUtils.clamp(pitch, -1.4, 1.4);
    this.applyCamera();
  }

  teleport(x, z, faceX, faceZ) {
    const resolved = moveWithCollisions({ x, z }, 0, 0, this.radius, this.colliders, this.bounds);
    this.x = resolved.x;
    this.z = resolved.z;
    if (typeof faceX === "number" && typeof faceZ === "number") {
      this.yaw = Math.atan2(-(faceX - this.x), -(faceZ - this.z));
      this.pitch = 0;
    }
    this.applyCamera();
  }

  applyCamera() {
    this.camera.position.set(this.x, this.eyeHeight + this.bob, this.z);
    this.camera.rotation.set(this.pitch, this.yaw, 0, "YXZ");
  }

  update(dt) {
    if (!this.enabled) return;

    const forward = (this.keys.has("KeyW") ? 1 : 0) - (this.keys.has("KeyS") ? 1 : 0);
    const strafe = (this.keys.has("KeyD") ? 1 : 0) - (this.keys.has("KeyA") ? 1 : 0);
    const moving = forward !== 0 || strafe !== 0;

    if (moving) {
      const length = Math.hypot(forward, strafe);
      const boosting = this.keys.has("ShiftLeft") || this.keys.has("ShiftRight");
      const speed = this.speed * (boosting ? 2.6 : 1);
      const sin = Math.sin(this.yaw);
      const cos = Math.cos(this.yaw);
      const dx = ((-sin * forward + cos * strafe) / length) * speed * dt;
      const dz = ((-cos * forward - sin * strafe) / length) * speed * dt;

      const result = moveWithCollisions(
        { x: this.x, z: this.z },
        dx,
        dz,
        this.radius,
        this.colliders,
        this.bounds
      );
      this.x = result.x;
      this.z = result.z;
      this.bobTime += dt * speed * 1.5;
    } else {
      this.bobTime += dt * 1.8;
    }

    const targetBob = moving ? Math.sin(this.bobTime) * 0.045 : Math.sin(this.bobTime) * 0.01;
    this.bob += (targetBob - this.bob) * Math.min(1, dt * 10);
    this.applyCamera();
  }
}