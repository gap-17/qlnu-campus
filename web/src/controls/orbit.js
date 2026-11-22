import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";

/**
 * 鸟瞰 / 轨道模式：围绕校园中心旋转、缩放、平移。
 */
export class OrbitController {
  constructor({ camera, dom }) {
    this.camera = camera;
    this.dom = dom;
    this.controls = new OrbitControls(camera, dom);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.075;
    this.controls.screenSpacePanning = false;
    this.controls.minDistance = 18;
    this.controls.maxDistance = 1200;
    this.controls.maxPolarAngle = Math.PI * 0.495;
    this.controls.target.set(0, 0, 320);
    this.controls.enabled = false;
  }

  enable() {
    this.controls.enabled = true;
    this.controls.update();
  }

  disable() {
    this.controls.enabled = false;
  }

  update() {
    if (this.controls.enabled) this.controls.update();
  }

  get target() {
    return this.controls.target;
  }

  setFromCamera(camera, direction) {
    const target = camera.position.clone().addScaledVector(direction, 130);
    target.y = Math.max(4, target.y);

    const horizontal = new THREE.Vector3(direction.x, 0, direction.z);
    if (horizontal.lengthSq() < 1e-6) horizontal.set(0, 0, 1);
    horizontal.normalize();

    camera.position.copy(target).add(new THREE.Vector3(-horizontal.x * 100, 120, -horizontal.z * 100));
    this.controls.target.copy(target);
    this.controls.update();
  }

  focusPoint(x, z, { distance = 170, height = 120 } = {}) {
    this.controls.target.set(x, 0, z);
    this.camera.position.set(x, height, z + distance);
    this.controls.update();
  }
}