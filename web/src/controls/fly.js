import * as THREE from "three";

/**
 * 飞行模式：相机方向决定前进方向，Space/Q 升降，无碰撞。
 */
export class FlyController {
  constructor({ camera, dom, bounds, onLockChange }) {
    this.camera = camera;
    this.dom = dom;
    this.bounds = bounds;
    this.onLockChange = onLockChange;

    this.yaw = Math.PI;
    this.pitch = 0;
    this.speed = 28;
    this.enabled = false;
    this.keys = new Set();

    this._forward = new THREE.Vector3();
    this._right = new THREE.Vector3();
    this._up = new THREE.Vector3(0, 1, 0);

    this._onKeyDown = (event) => {
      if (!this.enabled) return;
      if (["Space", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(event.code)) {
        event.preventDefault();
      }
      this.keys.add(event.code);
    };
    this._onKeyUp = (event) => this.keys.delete(event.code);
    this._onMouseMove = (event) => {
      if (!this.enabled || document.pointerLockElement !== this.dom) return;
      this.yaw -= event.movementX * 0.0022;
      this.pitch = THREE.MathUtils.clamp(this.pitch - event.movementY * 0.0022, -1.45, 1.45);
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
    this.applyRotation();
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
      /* ignore */
    }
  }

  setPose(position, yaw, pitch = 0) {
    this.camera.position.copy(position);
    this.yaw = yaw;
    this.pitch = THREE.MathUtils.clamp(pitch, -1.45, 1.45);
    this.applyRotation();
  }

  teleport(x, z, faceX, faceZ) {
    this.camera.position.x = x;
    this.camera.position.z = z;
    this.camera.position.y = Math.max(this.camera.position.y, 45);
    if (typeof faceX === "number" && typeof faceZ === "number") {
      this.yaw = Math.atan2(-(faceX - x), -(faceZ - z));
      this.pitch = -0.12;
    }
    this.applyRotation();
  }

  applyRotation() {
    this.camera.rotation.set(this.pitch, this.yaw, 0, "YXZ");
  }

  update(dt) {
    if (!this.enabled) return;

    const forward = (this.keys.has("KeyW") ? 1 : 0) - (this.keys.has("KeyS") ? 1 : 0);
    const strafe = (this.keys.has("KeyD") ? 1 : 0) - (this.keys.has("KeyA") ? 1 : 0);
    const vertical = (this.keys.has("Space") ? 1 : 0) - (this.keys.has("KeyQ") ? 1 : 0);

    if (forward === 0 && strafe === 0 && vertical === 0) {
      this.applyRotation();
      return;
    }

    const boosting = this.keys.has("ShiftLeft") || this.keys.has("ShiftRight");
    const speed = this.speed * (boosting ? 3.2 : 1) * dt;

    this.camera.getWorldDirection(this._forward);
    this._right.crossVectors(this._forward, this._up).normalize();

    const position = this.camera.position;
    position.addScaledVector(this._forward, forward * speed);
    position.addScaledVector(this._right, strafe * speed);
    position.y += vertical * speed;

    const bounds = this.bounds;
    position.x = THREE.MathUtils.clamp(position.x, bounds.minX - 60, bounds.maxX + 60);
    position.z = THREE.MathUtils.clamp(position.z, bounds.minZ - 60, bounds.maxZ + 60);
    position.y = THREE.MathUtils.clamp(position.y, 1.4, 520);

    this.applyRotation();
  }
}