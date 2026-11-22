export class Loading {
  constructor() {
    this.root = document.getElementById("loading");
    this.statusEl = document.getElementById("loading-status");
    this.barEl = document.getElementById("loading-bar");
  }

  status(text, percent) {
    if (this.statusEl) this.statusEl.textContent = text;
    if (this.barEl) this.barEl.style.width = `${Math.max(2, Math.min(100, percent))}%`;
  }

  done() {
    this.status("准备就绪", 100);
    this.root?.classList.add("is-hidden");
    window.setTimeout(() => {
      if (this.root) this.root.hidden = true;
    }, 650);
  }

  fail(message) {
    if (!this.root) return;
    this.root.classList.add("has-error");
    if (this.statusEl) {
      this.statusEl.textContent = `加载失败：${message}`;
    }
    if (this.barEl) this.barEl.style.width = "100%";
  }
}