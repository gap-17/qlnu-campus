export class Hud {
  constructor({ onMode, onTime }) {
    this.modeBar = document.getElementById("mode-bar");
    this.timeBar = document.getElementById("time-bar");
    this.crosshair = document.getElementById("crosshair");
    this.hintEl = document.getElementById("hint");
    this.toastEl = document.getElementById("toast");
    this.helpToggle = document.getElementById("help-toggle");
    this.helpBody = document.querySelector(".help-body");
    this.toastTimer = 0;

    this.modeBar?.addEventListener("click", (event) => {
      const button = event.target.closest("button[data-mode]");
      if (button) onMode?.(button.dataset.mode);
    });

    this.timeBar?.addEventListener("click", (event) => {
      const button = event.target.closest("button[data-time]");
      if (button) onTime?.(button.dataset.time);
    });

    this.helpToggle?.addEventListener("click", () => this.toggleHelp());

    if (window.matchMedia("(pointer: coarse)").matches) {
      this.helpBody?.classList.add("collapsed");
      if (this.helpToggle) {
        this.helpToggle.textContent = "展开";
        this.helpToggle.setAttribute("aria-expanded", "false");
      }
    }
  }

  toggleHelp(force) {
    if (!this.helpBody) return;
    const collapsed =
      typeof force === "boolean" ? force : !this.helpBody.classList.contains("collapsed");
    this.helpBody.classList.toggle("collapsed", collapsed);
    if (this.helpToggle) {
      this.helpToggle.textContent = collapsed ? "展开" : "收起";
      this.helpToggle.setAttribute("aria-expanded", String(!collapsed));
    }
  }

  setMode(mode) {
    for (const button of this.modeBar?.querySelectorAll("button[data-mode]") ?? []) {
      button.classList.toggle("active", button.dataset.mode === mode);
    }
    document.body.dataset.mode = mode;
    const firstPerson = mode === "walk" || mode === "fly";
    this.crosshair?.classList.toggle("hidden", !firstPerson);
    if (!firstPerson) this.setHint("");
  }

  restrictModes(allowed) {
    for (const button of this.modeBar?.querySelectorAll("button[data-mode]") ?? []) {
      button.hidden = !allowed.includes(button.dataset.mode);
    }
  }

  setTime(name) {
    for (const button of this.timeBar?.querySelectorAll("button[data-time]") ?? []) {
      button.classList.toggle("active", button.dataset.time === name);
    }
  }

  setHint(text) {
    if (!this.hintEl) return;
    this.hintEl.textContent = text;
    this.hintEl.classList.toggle("visible", Boolean(text));
  }

  toast(message, duration = 2400) {
    if (!this.toastEl) return;
    this.toastEl.textContent = message;
    this.toastEl.classList.add("visible");
    window.clearTimeout(this.toastTimer);
    this.toastTimer = window.setTimeout(() => {
      this.toastEl.classList.remove("visible");
    }, duration);
  }
}