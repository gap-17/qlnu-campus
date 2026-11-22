# Blender 源工程

用 Blender 4.2+ 从校园 JSON 数据生成低多边形体块场景，输出 `.blend` 源文件与 `.glb` 模型。

## 运行

在项目根目录执行：

```bash
blender --background --python blender/build_campus.py
```

生成：

- `blender/qlnu-campus.blend` —— 可继续编辑的源工程
- `web/models/campus.glb` —— 带材质、按 `export_yup=True` 导出的 glTF 二进制

若只想重新导出：打开 `.blend`，使用 File → Export → glTF 2.0，格式选 GLB。

## 场景结构

| 集合 | 内容 |
| --- | --- |
| `00_ground` | 草地、道路、人行道、广场 |
| `10_core` | 校门、教学、实验、图书馆、公共建筑、食堂、后勤 |
| `20_dorms` | 学生公寓 |
| `30_sports` | 体育馆 |
| `40_landscape` | 水系、运动场地、树木 |

每栋建筑对象带有自定义属性：

- `building_id`、`name_zh`、`alias_zh`
- `category`、`status`
- `floors`、`height_m`

材质名称与网页端 `web/src/lib/palette.js` 对应：`wall_<category>`、`roof_<category>`，另有 `grass`、`asphalt`、`sidewalk`、`plaza`、`water`、`track`、`field`、`court`、`tree_trunk`、`tree_canopy`。

## 坐标映射

数据使用 `+X 东、+Z 南、+Y 上`，Blender / glTF 使用 Z 向上，因此：

```text
Blender (x, y, z) = 数据 (x, -z, height)
```

建筑的 `rot` 以数据坐标绕 Y 轴的角度表示，写入 Blender 时转换为绕 Z 轴 `-rot`。

## 说明

- 树木使用同一份原型网格的链接副本，位置与剔除规则和网页端一致，共 216 棵。
- 体块与高度来自平面图描图和航拍近似，不是测绘成果。
- 开发机未安装 Blender，脚本已通过 Python 语法检查与数据逻辑冒烟测试（41 栋建筑、216 棵树）；首次运行时如遇 Blender API 版本差异，请按提示调整。