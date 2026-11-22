export const APP = {
  name: "齐鲁师范学院",
  campus: "章丘校区",
  version: "v0.1"
};

export const TIME_ORDER = ["day", "dusk", "night"];

export const TIME_LABELS = {
  day: "白天",
  dusk: "黄昏",
  night: "夜晚"
};

export const MODE_LABELS = {
  walk: "步行",
  fly: "飞行",
  orbit: "鸟瞰"
};

/**
 * 移动端简化：关阴影、限制像素比、降低树木密度。
 * 触屏设备默认进入鸟瞰模式，靠小地图与信息卡游览。
 */
export function detectQuality() {
  const coarse = window.matchMedia("(pointer: coarse)").matches;
  const narrow = window.innerWidth < 860;
  const mobile = coarse || narrow;
  return {
    mobile,
    shadows: !mobile,
    maxPixelRatio: mobile ? 1.5 : 2,
    treeDensity: mobile ? 0.45 : 1
  };
}