import { CATEGORY_LABELS, STATUS_LABELS } from "../lib/data.js";

export class InfoCard {
  constructor({ onClose, onTeleport }) {
    this.root = document.getElementById("info-card");
    this.categoryEl = document.getElementById("info-category");
    this.nameEl = document.getElementById("info-name");
    this.aliasEl = document.getElementById("info-alias");
    this.idEl = document.getElementById("info-id");
    this.floorsEl = document.getElementById("info-floors");
    this.heightEl = document.getElementById("info-height");
    this.descEl = document.getElementById("info-desc");
    this.teleportBtn = document.getElementById("info-teleport");
    this.closeBtn = document.getElementById("info-close");

    this.building = null;
    this.onTeleport = onTeleport;

    this.closeBtn?.addEventListener("click", () => {
      this.hide();
      onClose?.();
    });

    this.teleportBtn?.addEventListener("click", () => {
      if (this.building) this.onTeleport?.(this.building);
    });
  }

  get isOpen() {
    return Boolean(this.root && !this.root.hidden);
  }

  show(building) {
    if (!this.root) return;
    this.building = building;

    this.categoryEl.textContent = CATEGORY_LABELS[building.category] ?? building.category;
    this.categoryEl.dataset.category = building.category;
    this.nameEl.textContent = building.name;

    if (building.alias) {
      this.aliasEl.textContent = building.alias;
      this.aliasEl.hidden = false;
    } else {
      this.aliasEl.textContent = "";
      this.aliasEl.hidden = true;
    }

    this.idEl.textContent = building.id;
    this.floorsEl.textContent = `${building.floors} 层`;
    this.heightEl.textContent = `${building.height_m} m`;
    this.descEl.textContent = `${building.description} 状态：${
      STATUS_LABELS[building.status] ?? building.status
    }。`;

    this.root.hidden = false;
    this.root.classList.add("visible");
  }

  hide() {
    if (!this.root) return;
    this.root.classList.remove("visible");
    this.root.hidden = true;
    this.building = null;
  }
}