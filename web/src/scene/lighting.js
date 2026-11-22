import * as THREE from "three";
import { setWindowGlow } from "./materials.js";

const DEG = Math.PI / 180;

const PRESETS = {
  day: {
    sun: 2.55,
    sunColor: 0xfff3df,
    hemi: 0.95,
    hemiSky: 0xcfe8ff,
    hemiGround: 0x50604a,
    sky: 0xbfe3ff,
    fog: 0xd4ebff,
    fogNear: 320,
    fogFar: 1650,
    elevation: 56,
    azimuth: 185,
    window: 0,
    star: 0
  },
  dusk: {
    sun: 1.25,
    sunColor: 0xffa05c,
    hemi: 0.55,
    hemiSky: 0xffc9a1,
    hemiGround: 0x3d3a34,
    sky: 0xf0ad7c,
    fog: 0xf0c09a,
    fogNear: 240,
    fogFar: 1300,
    elevation: 9,
    azimuth: 252,
    window: 0.55,
    star: 0.06
  },
  night: {
    sun: 0.24,
    sunColor: 0x9fb8ff,
    hemi: 0.3,
    hemiSky: 0x24355c,
    hemiGround: 0x0a0f18,
    sky: 0x070c1a,
    fog: 0x0c1426,
    fogNear: 180,
    fogFar: 1150,
    elevation: 46,
    azimuth: 158,
    window: 1,
    star: 1
  }
};

function resolvePreset(preset) {
  return {
    sun: preset.sun,
    hemi: preset.hemi,
    fogNear: preset.fogNear,
    fogFar: preset.fogFar,
    elevation: preset.elevation,
    azimuth: preset.azimuth,
    window: preset.window,
    star: preset.star,
    sunColor: new THREE.Color(preset.sunColor),
    hemiSky: new THREE.Color(preset.hemiSky),
    hemiGround: new THREE.Color(preset.hemiGround),
    sky: new THREE.Color(preset.sky),
    fog: new THREE.Color(preset.fog)
  };
}

function lerpState(target, from, to, t) {
  for (const key of ["sun", "hemi", "fogNear", "fogFar", "elevation", "azimuth", "window", "star"]) {
    target[key] = from[key] + (to[key] - from[key]) * t;
  }
  target.sunColor.lerpColors(from.sunColor, to.sunColor, t);
  target.hemiSky.lerpColors(from.hemiSky, to.hemiSky, t);
  target.hemiGround.lerpColors(from.hemiGround, to.hemiGround, t);
  target.sky.lerpColors(from.sky, to.sky, t);
  target.fog.lerpColors(from.fog, to.fog, t);
}

function cloneState(state) {
  const copy = { ...state };
  copy.sunColor = state.sunColor.clone();
  copy.hemiSky = state.hemiSky.clone();
  copy.hemiGround = state.hemiGround.clone();
  copy.sky = state.sky.clone();
  copy.fog = state.fog.clone();
  return copy;
}

function createStars() {
  const count = 1400;
  const positions = new Float32Array(count * 3);
  let seed = 20261122;
  const random = () => {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    return seed / 4294967296;
  };

  for (let i = 0; i < count; i += 1) {
    const azimuth = random() * Math.PI * 2;
    const elevation = (4 + random() * 84) * DEG;
    const radius = 1500;
    positions[i * 3] = Math.cos(elevation) * Math.sin(azimuth) * radius;
    positions[i * 3 + 1] = Math.sin(elevation) * radius;
    positions[i * 3 + 2] = 320 + Math.cos(elevation) * Math.cos(azimuth) * radius;
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute("position", new THREE.BufferAttribute(positions, 3));
  const material = new THREE.PointsMaterial({
    color: 0xe8efff,
    size: 2,
    sizeAttenuation: false,
    transparent: true,
    opacity: 0,
    depthWrite: false,
    fog: false
  });
  return { points: new THREE.Points(geometry, material), material };
}

export function createLighting(scene, quality) {
  scene.background = new THREE.Color(0xbfe3ff);
  scene.fog = new THREE.Fog(0xd4ebff, 320, 1650);

  const hemi = new THREE.HemisphereLight(0xcfe8ff, 0x50604a, 0.95);
  scene.add(hemi);

  const sun = new THREE.DirectionalLight(0xfff3df, 2.5);
  sun.castShadow = quality.shadows;
  sun.shadow.mapSize.set(quality.shadows ? 2048 : 1024, quality.shadows ? 2048 : 1024);
  sun.shadow.camera.left = -560;
  sun.shadow.camera.right = 560;
  sun.shadow.camera.top = 560;
  sun.shadow.camera.bottom = -560;
  sun.shadow.camera.near = 20;
  sun.shadow.camera.far = 2600;
  sun.shadow.bias = -0.0004;
  sun.shadow.normalBias = 0.8;
  sun.target.position.set(0, 0, 320);
  scene.add(sun);
  scene.add(sun.target);

  const stars = createStars();
  scene.add(stars.points);

  const current = resolvePreset(PRESETS.day);
  let from = cloneState(current);
  let to = cloneState(current);
  let mix = 1;
  let presetName = "day";

  function apply() {
    sun.intensity = current.sun;
    sun.color.copy(current.sunColor);
    hemi.intensity = current.hemi;
    hemi.color.copy(current.hemiSky);
    hemi.groundColor.copy(current.hemiGround);

    const azimuth = current.azimuth * DEG;
    const elevation = current.elevation * DEG;
    const radius = 1000;
    sun.position.set(
      Math.sin(azimuth) * Math.cos(elevation) * radius,
      Math.sin(elevation) * radius,
      320 - Math.cos(azimuth) * Math.cos(elevation) * radius
    );

    scene.background.copy(current.sky);
    scene.fog.color.copy(current.fog);
    scene.fog.near = current.fogNear;
    scene.fog.far = current.fogFar;

    setWindowGlow(current.window);
    stars.material.opacity = current.star * 0.92;
    stars.points.visible = current.star > 0.01;
  }

  apply();

  return {
    sun,
    hemi,
    get state() {
      return current;
    },
    get name() {
      return presetName;
    },
    setPreset(name) {
      if (!PRESETS[name]) return;
      from = cloneState(current);
      to = resolvePreset(PRESETS[name]);
      mix = 0;
      presetName = name;
    },
    update(dt) {
      if (mix < 1) {
        mix = Math.min(1, mix + dt / 1.6);
        const t = mix * mix * (3 - 2 * mix);
        lerpState(current, from, to, t);
        apply();
      }
    }
  };
}

export const TIME_PRESETS = Object.keys(PRESETS);