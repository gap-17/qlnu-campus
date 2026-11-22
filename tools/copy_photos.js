const fs = require("fs");
const os = require("os");
const path = require("path");

const source = path.join(
  os.homedir(),
  ".qoder-cn",
  "tmp",
  "D--B2-qwen",
  "images",
  "f7262e76-32a7-416d-be15-eae4f725d722"
);
const target = path.resolve(__dirname, "..", "齐鲁师范3D建模素材", "实拍");

if (!fs.existsSync(source)) {
  console.error("[qlnu] source directory not found:");
  console.error("       " + source);
  process.exit(1);
}

fs.mkdirSync(target, { recursive: true });
const files = fs
  .readdirSync(source)
  .filter((name) => /\.(jpe?g|png)$/i.test(name))
  .sort();

let copied = 0;
for (const name of files) {
  copied += 1;
  const extension = path.extname(name).toLowerCase();
  const destination = path.join(target, `实拍_${String(copied).padStart(2, "0")}${extension}`);
  fs.copyFileSync(path.join(source, name), destination);
}

console.log(`[qlnu] copied ${copied} photos -> ${target}`);