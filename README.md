# 齐鲁师范学院（章丘校区）3D 校园 · v0.2

一个“网页参观 + Godot 游戏”双端校园项目，两端共用 `web/src/data/*.json` 这一套 41 栋建筑的坐标数据。

- **网页版 v0.1**：浏览器里的完整校园漫游，步行 / 飞行 / 鸟瞰三种视角。
- **游戏版 v0.2**：Godot 4 第三人称校园探索原型，开始界面男女选择、可跑跳、可飞行与缓降；右上角圆形小地图；北门内文化长廊、操场跑道与草坪球场。

## Godot v0.2 快速开始

Godot 工程根目录就是本仓库根目录，需要 Godot 4.7.1 stable。

```bat
:: 首次先下载 Web 版需要的中文字体（桌面端会自动回退系统字体）
download_font.bat

:: 无界面自检：检查数据、建筑、碰撞体、窗户、树木与穿模
smoke_test.bat

:: 无界面 UI 自检：验证开始界面、HUD、小地图与飞行状态
ui_smoke_test.bat

:: 迁移实拍参考图到 齐鲁师范3D建模素材/实拍/
tools\copy_photos.bat

:: 运行游戏
run_game.bat

:: 打开编辑器
open_editor.bat
```

Web 导出与预览：

```bat
export_web.bat
serve_web.bat
```

详细说明（操作键位、导出模板、字体、排错、目录结构）见 [game/README.md](game/README.md)。

## 网页版 v0.1

一个可在浏览器里完整游览章丘校区的 3D 校园演示：半写实低多边形风格，包含 41 栋建筑体块、道路、水系、运动场地、216 棵树，以及步行 / 飞行 / 鸟瞰三种视角。

v0.1 的重点是“把校园走通”：

- 第一人称步行（含碰撞、头部起伏、边界夹紧）
- 飞行模式（Space 升 / Q 降 / Shift 加速）
- 鸟瞰轨道视角，点击建筑弹出信息卡
- 小地图：点击传送、选中高亮、玩家朝向与视锥
- 建筑信息卡：编号、别名、层数、高度、描述、传送到门口
- 昼夜切换：白天 / 黄昏 / 夜晚，夜间窗户与路灯发光、星空出现
- 桌面优先，手机自动进入鸟瞰简化模式

## 快速开始

需要 Node.js 20.11+（或任意静态服务器）。

```bash
cd web
node scripts/serve.js
```

打开 <http://localhost:5173/>。

也可以使用 Python：

```bash
python -m http.server 8080 --directory web
```

> Three.js 通过 CDN import map 加载，首次打开需要网络；不需要 `npm install`，也没有构建步骤。

## 操作

| 操作 | 说明 |
| --- | --- |
| 点击画面 | 进入鼠标控制（Pointer Lock） |
| `W A S D` | 步行 / 飞行移动 |
| 鼠标 | 转动视角 |
| `Shift` | 加速 |
| `Space` / `Q` | 飞行升高 / 降低 |
| `E` 或单击 | 查看准星处建筑 |
| `1` `2` `3` | 步行 / 飞行 / 鸟瞰 |
| `T` | 切换白天 / 黄昏 / 夜晚 |
| `Esc` | 释放鼠标 |

点击右下角小地图可传送；点击建筑可打开信息卡，再点“传送到建筑门口”。

## 验证

```bash
cd web
node scripts/validate-data.js   # 数据契约与统计
node --test                     # 28 项单元测试
```

打开 <http://localhost:5173/test.html> 可运行浏览器自检（数据、几何、碰撞、投影、WebGL、模块加载）。

调试性能可加查询参数：<http://localhost:5173/?stats=1>，右上角显示 FPS、绘制调用与三角面数。

## 部署到 GitHub Pages

网页版由 `.github/workflows/deploy-pages.yml` 自动发布：推送到 `main` 后，工作流只把 `web/` 上传到 GitHub Pages。链接固定为：

```text
https://<你的用户名>.github.io/qlnu-campus/
```

首次发布只需配置一次：

1. 安装并登录 GitHub CLI：`winget install --id GitHub.cli`，然后运行 `gh auth login`。
2. 在仓库根目录创建公开仓库并推送：
   ```bash
   gh repo create qlnu-campus --public --source=. --remote=origin --push
   ```
3. 在仓库 `Settings → Pages → Build and deployment` 中把 Source 设为 **GitHub Actions**；也可以用命令：
   ```bash
   gh api --method POST repos/{owner}/{repo}/pages -f build_type=workflow
   ```
   如果提示已存在，改用 `--method PUT`。
4. 打开仓库的 **Actions** 页，等待 `Deploy web to GitHub Pages` 完成。

之后每次 `git push` 到 `main` 都会重新部署，链接不变。页面右上角显示 `v0.1 · <commit>`；已打开的旧页面检测到新版本后会提示刷新。GitHub Pages 自带约 10 分钟缓存，必要时用 `Ctrl+F5` 强制刷新。

不要重命名仓库，否则 Pages 链接会变化。原始素材目录 `齐鲁师范3D建模素材/` 已在 `.gitignore` 中排除，不会进入公开仓库。

## 更新校园数据

所有几何都来自两份 JSON：

- `web/src/data/buildings.json`：建筑 `rect {x,z,w,d,rot}` 或 `polygon`、`height_m`、`floors`、`entrance`、别名与描述
- `web/src/data/campus.json`：边界、出生点、道路、水系、广场、文化长廊、运动场地、树木分区

修改后运行：

```bash
cd web
node scripts/validate-data.js
```

校验会检查 id 唯一、枚举合法、北门位于原点、出生点在边界内、道路/水系/场地结构完整等。数据通过后刷新页面即可看到变化。

## Blender 源文件

需要 Blender 4.2+：

```bash
blender --background --python blender/build_campus.py
```

输出 `blender/qlnu-campus.blend` 与 `web/models/campus.glb`。详见 [blender/README.md](blender/README.md)。

网页 v0.1 直接使用程序化体块渲染，GLB 供 Blender / 其他引擎继续加工；两者共用同一份 JSON 数据。

## 目录

```text
project.godot         Godot v0.2 工程入口（根目录）
export_presets.cfg    Web 导出预设
run_game.bat          运行游戏
open_editor.bat       打开 Godot 编辑器
smoke_test.bat        无界面自检
ui_smoke_test.bat     无界面 UI 自检（HUD / 小地图）
tools/copy_photos.bat 迁移实拍参考图
export_web.bat        Web 导出
serve_web.bat         本地预览服务器
download_font.bat     下载中文字体
game/
  scenes/             Godot 场景
  scripts/            GDScript 与预览服务器
  assets/             字体、未来的 GLB 模型
  README.md           Godot 版说明
web/
  index.html          入口
  styles.css          UI 样式
  test.html           浏览器自检
  src/
    main.js           启动与装配
    config.js         版本、模式、设备质量
    data/             建筑与校园 JSON
    lib/              几何、碰撞、投影、数据校验
    scene/            地面、建筑、植被、标签、光照、世界
    controls/         步行、飞行、鸟瞰、模式管理
    ui/               加载层、HUD、信息卡、小地图
  scripts/            静态服务器、数据校验
  tests/              Node 单元测试
blender/
  build_campus.py     校园生成器
  README.md
docs/
  specs/              设计规格
  superpowers/plans/  实施计划
```

## 已知近似与限制

- 建筑轮廓与高度依据校园平面图描图、航拍视频和公开资料近似还原，不是测绘成果；重点建筑的层数、立面细节仍待核对。
- 教学 1#/2# 与“博文楼 / 笃学楼”、第一/第二餐厅与“齐风坊 / 鲁味坊”等别名的对应关系尚未确认，数据中暂不臆造。
- 只做建筑外观，没有室内、没有多人联机。
- 树木、道路、水系为示意性布置，后续可用 CAD 或实测数据替换。
- 手机端简化为鸟瞰视角 + 小地图 + 信息卡，关闭阴影并降低树木密度。

## 数据来源与版权

校园平面图与航拍素材由项目发起人提供；建筑名称、位置与描述参考学校公开信息整理。本项目用于学习与演示，非学校官方产品。若用于公开发布，请先核对建筑信息并获得素材使用授权。