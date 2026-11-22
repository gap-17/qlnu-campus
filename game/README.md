# 齐鲁师范学院 · 3D 校园（Godot v0.2）

v0.2 把 v0.1 的网页漫游扩展为一个可玩的 Godot 第三人称校园探索原型：

- 开始界面选择女生 / 男生，进入校园后可步行、奔跑、跳跃；
- 按 `F` 切换飞行，飞行中按 `Space` 上升、`Q` / `Ctrl` 下降，右上角圆形小地图显示位置与朝向；
- 北门内两侧设有文化长廊，操场包含塑胶跑道、草坪足球场与球场标线；
- 41 栋建筑、道路、水系、广场、操场、树木、路灯全部由 `web/src/data/*.json` 程序化生成；
- 与网页参观版共用同一份坐标数据，后续替换为 Blender 精细模型时不需要改数据；
- 支持 `--smoke` 无界面自检，以及 Web 导出（单线程，免 COOP/COEP）。

> Godot 工程根目录是仓库根目录 `D:\B2 qlnu-campus`，不是 `game/`。
> `game/project.godot` 只是一条说明，请勿单独打开。

## 1. 环境

| 项 | 要求 |
| --- | --- |
| Godot | 4.7.1 stable（GL Compatibility 渲染器） |
| 系统 | Windows 10/11 x64 |
| Node.js | 18+，仅用于本地 Web 预览（可选） |
| 字体 | Web 导出前必须放置一份中文字体 |

Godot 路径解析顺序：

1. 环境变量 `GODOT_BIN`；
2. `tools/Godot/Godot_v4.7.1-stable_win64.exe`；
3. 自动扫描 `D:\14app`、`D:\11AI`、`D:\03*`、`C:\Program Files`、桌面与下载目录。

## 2. 运行

```bat
:: 直接运行游戏
run_game.bat

:: 打开 Godot 编辑器
open_editor.bat

:: 无界面冒烟测试（会打印建筑 / 碰撞体 / 窗户 / 树木数量，并检查穿模）
smoke_test.bat

:: 无界面 UI 冒烟测试（开始界面、HUD、小地图、飞行/缓降状态）
ui_smoke_test.bat
```

首次打开编辑器会导入资源，需要几十秒。冒烟测试通过时最后一行是：

```
[smoke] PASS
```

UI 冒烟测试通过时最后一行是：

```
[ui-smoke] PASS
```

失败会打印 `[smoke] FAIL ...` / `[ui-smoke] FAIL ...` 并以非 0 退出。

## 3. 操作

| 按键 | 功能 |
| --- | --- |
| `W A S D` / 方向键 | 移动 |
| 鼠标 | 环绕视角 |
| `Shift` | 奔跑 |
| `Space` | 跳跃；飞行时上升 |
| `F` | 开关飞行 |
| `Q` / `Ctrl` | 飞行时下降（松开 F 后缓降落地） |
| 滚轮 | 拉近 / 拉远镜头 |
| `R` | 回到北门起点 |
| `Esc` / `P` | 暂停菜单 |
| `F11` | 全屏 |

飞行速度 12 m/s，按住 `Shift` 提升到 24 m/s。镜头遇到建筑会自动拉近，避免穿墙。

## 4. 中文字体

Web 平台没有系统字体，中文会显示成方块。先运行：

```bat
download_font.bat
```

脚本会把 `NotoSansCJKsc-Regular.otf` 下载到 `game/assets/fonts/`。也可以手动放任意 `.otf` / `.ttf` 中文字体，程序会自动扫描。桌面端找不到字体时会回退到微软雅黑。

## 5. 导出 Web

1. 安装 Godot Web 导出模板：
   - 编辑器菜单 `Editor > Manage Export Templates > Download and Install`，或
   - 手动下载 `Godot_v4.7.1-stable_export_templates.tpz`，解压到
     `%APPDATA%\Godot\export_templates\4.7.1.stable\`
2. 确认字体已放入 `game/assets/fonts/`。
3. 双击 `export_web.bat`。
4. 双击 `serve_web.bat`，浏览器打开 `http://127.0.0.1:5174/`。

导出配置位于仓库根目录 `export_presets.cfg`：

- 单线程（`variant/thread_support=false`），因此不需要 COOP/COEP 响应头；
- GL Compatibility，适合集显与移动端；
- 产物目录 `game/build/web/`；
- 自动包含 `web/src/data/*.json` 与字体文件。

> 不要直接双击 `index.html`（`file://` 下 wasm 会被浏览器拦截），必须通过 HTTP 访问。

## 6. 目录结构

```
project.godot                 Godot 工程（根目录）
export_presets.cfg            Web 导出预设
run_game.bat                  运行
open_editor.bat               打开编辑器
smoke_test.bat                无界面自检
ui_smoke_test.bat             无界面 UI 自检
export_web.bat                Web 导出
serve_web.bat                 本地静态服务器
download_font.bat             下载中文字体
tools/                        Godot 定位与任务脚本
game/
  scenes/Main.tscn            唯一入口场景
  scripts/
    game_state.gd             autoload：性别、输入、字体、主题、设置
    campus_data.gd            autoload：读取并查询校园 JSON
    campus_builder.gd         程序化生成整个校园
    student_visual.gd         男女学生低模与走路 / 飞行动画
    player.gd                 第三人称 CharacterBody3D 与镜头
    start_screen.gd           开始界面
    hud.gd                    游戏内 HUD
    minimap.gd                右上角圆形校园小地图（SubViewport + 圆形遮罩）
    pause_menu.gd             暂停菜单
    main.gd                   流程编排与冒烟测试
    serve_web.js              Web 预览服务器
  assets/                     字体、未来的 Blender GLB
  build/web/                  Web 导出产物（不提交）
web/                          网页参观版与共享校园数据
```

## 7. 数据与坐标

- 1 单位 = 1 米；`+X` 东、`+Z` 南、`+Y` 上；原点在北门。
- 建筑节点位置 `(rect.x, 0, rect.z)`，旋转 `-deg_to_rad(rect.rot)`。
- 建筑碰撞体使用旋转盒，避免 trimesh 开销。
- 树木、路灯、窗户、道路虚线使用 `MultiMesh`，控制 draw call。
- 想调整校园：直接改 `web/src/data/buildings.json` / `campus.json`，网页版与游戏同时生效。
- 北门两侧文化长廊的数据在 `campus.json` 的 `corridors` 中，改 `x/z/w/d/side/motto` 即可同步到 3D 场景与小地图。

## 8. 已知限制（v0.2）

- 建筑仍是体块 + 程序化立面，尚未替换为航拍比例的 Blender 精细模型；
- 小地图为平面示意，北向上；文化长廊、跑道与看台细节为程序化近似；
- 建筑内部、NPC、剧情、创造模式破坏尚未实现；
- 无音效与背景音乐；
- 角色是程序化低模，没有骨骼动画与布料；
- Web 端首次加载需要下载约 20–40 MB 资源，之后由浏览器缓存；
- 移动端触屏操作未适配。

## 9. 下一阶段

1. 用航拍截图 + Blender 重建图书馆、北门、体育馆等标志性建筑，导出 GLB 替换体块；
2. 室内场景与进入 / 离开建筑的过渡；
3. 故事模式垂直切片：一条主线、3–5 个 NPC、对话与开放结局；
4. 创造模式：第一视角、道具放置、限定范围拆除；
5. 音效、昼夜、天气与校园广播。

## 10. 排错

| 现象 | 处理 |
| --- | --- |
| `没有找到 Godot 4 可执行文件` | 设置 `GODOT_BIN`，或把 Godot 放到 `tools/Godot/` |
| 中文显示为方块 | 运行 `download_font.bat`，确认字体在 `game/assets/fonts/` |
| 导出提示缺少模板 | 安装对应 4.7.1 的导出模板 |
| Web 页面黑屏 | 用 `serve_web.bat` 通过 HTTP 打开，查看 F12 控制台 |
| 角色掉出地图 | 按 `R` 回起点；检查 `campus.json` 的 `bounds` |
| 画面卡顿 | 降低窗口分辨率；v0.2 的阴影距离为 170 m |