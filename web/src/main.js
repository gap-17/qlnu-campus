import { validateCampusData } from "./lib/data.js";
import { TIME_ORDER, detectQuality } from "./config.js";
import { CampusWorld } from "./scene/world.js";
import { Loading } from "./ui/loading.js";
import { Hud } from "./ui/hud.js";
import { Minimap } from "./ui/minimap.js";
import { InfoCard } from "./ui/info-card.js";

const loading = new Loading();

let world = null;
let hud = null;
let minimap = null;
let infoCard = null;

const BUILD_POLL_MS = 60_000;
let activeBuild = null;

async function readBuildInfo() {
  const response = await fetch(`./version.json?t=${Date.now()}`, { cache: "no-store" });
  if (!response.ok) return null;
  return response.json();
}

function applyBuildInfo(info) {
  if (!info?.sha || info.sha === "dev") return;
  activeBuild = info.sha;
  document.documentElement.dataset.build = info.sha;
  const tag = document.getElementById("build-tag");
  if (tag) tag.textContent = `v0.1 · ${info.sha}`;
}

function watchBuild() {
  readBuildInfo().then(applyBuildInfo).catch(() => {});
  window.setInterval(async () => {
    try {
      const info = await readBuildInfo();
      if (!info?.sha || info.sha === "dev" || info.sha === activeBuild) return;
      activeBuild = info.sha;
      hud?.toast("校园已更新，按 Ctrl+F5 刷新以加载新版本", 8000);
    } catch {
      // 网络波动时跳过本轮检查。
    }
  }, BUILD_POLL_MS);
}

watchBuild();

async function fetchJson(url) {
  const response = await fetch(url, { cache: "no-cache" });
  if (!response.ok) throw new Error(`${url} 加载失败（HTTP ${response.status}）`);
  return response.json();
}

function mountStats(world) {
  if (!new URLSearchParams(window.location.search).has("stats")) return;

  const element = document.createElement("pre");
  element.id = "stats";
  element.setAttribute("aria-hidden", "true");
  document.getElementById("app").appendChild(element);

  let frames = 0;
  let since = performance.now();
  world.onFrame(() => {
    frames += 1;
  });

  setInterval(() => {
    const now = performance.now();
    const fps = Math.round((frames * 1000) / Math.max(1, now - since));
    frames = 0;
    since = now;
    const info = world.renderer.info.render;
    element.textContent = `${fps} fps · ${info.calls} calls · ${info.triangles.toLocaleString()} tris`;
  }, 1000);
}

function wireKeyboard() {
  window.addEventListener("keydown", (event) => {
    if (event.code === "Digit1") world?.setMode("walk");
    else if (event.code === "Digit2") world?.setMode("fly");
    else if (event.code === "Digit3") world?.setMode("orbit");
    else if (event.code === "KeyT") {
      const current = world?.getTime() ?? "day";
      const next = TIME_ORDER[(TIME_ORDER.indexOf(current) + 1) % TIME_ORDER.length];
      world?.setTime(next);
    }
  });
}

async function boot() {
  loading.status("读取校园数据", 4);

  const [buildingsDoc, campusDoc] = await Promise.all([
    fetchJson("./src/data/buildings.json"),
    fetchJson("./src/data/campus.json")
  ]);

  const check = validateCampusData(buildingsDoc, campusDoc);
  if (!check.ok) {
    throw new Error(`数据校验失败：${check.errors.slice(0, 3).join("；")}`);
  }

  for (const warning of check.warnings) console.warn(warning);

  const quality = detectQuality();
  document.body.classList.toggle("is-mobile", quality.mobile);

  hud = new Hud({
    onMode: (mode) => world?.setMode(mode),
    onTime: (name) => world?.setTime(name)
  });

  infoCard = new InfoCard({
    onTeleport: (building) => {
      world?.teleportToBuilding(building);
      infoCard.hide();
    }
  });

  world = new CampusWorld({
    canvas: document.getElementById("scene"),
    buildings: buildingsDoc.buildings,
    campus: campusDoc,
    quality,
    callbacks: {
      onModeChange: (mode) => hud.setMode(mode),
      onTimeChange: (name) => hud.setTime(name),
      onSelect: (building) => {
        infoCard.show(building);
        minimap?.setSelected(building.id);
      },
      onHint: (text) => hud.setHint(text),
      onLockChange: (locked) => {
        if (!locked && !infoCard.isOpen) {
          hud.toast("已释放鼠标，点击画面继续漫游", 2200);
        }
      },
      onToast: (message) => hud.toast(message)
    }
  });

  await world.build((text, percent) => loading.status(text, percent));

  minimap = new Minimap({
    canvas: document.getElementById("minimap"),
    campus: campusDoc,
    buildings: buildingsDoc.buildings,
    onTeleport: (x, z) => world.teleport(x, z)
  });

  world.onFrame((state) => minimap.setPlayer(state));

  if (quality.mobile) {
    hud.restrictModes(["orbit"]);
  }

  hud.setMode(world.getMode());
  hud.setTime(world.getTime());
  wireKeyboard();
  mountStats(world);
  loading.done();

  window.__CAMPUS__ = world;
}

boot().catch((error) => {
  console.error(error);
  loading.fail(error.message ?? String(error));
});