"""导出 v0.1 校园 blockout，供 Godot 项目做第三人称空跑验证。

用法：
    blender --background --python blender/export_blockout.py

产物：
    blender/qlnu-campus-blockout.blend
    game/assets/campus_blockout.glb
"""

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_campus  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
build_campus.BLEND_PATH = ROOT / "blender" / "qlnu-campus-blockout.blend"
build_campus.GLB_PATH = ROOT / "game" / "assets" / "campus_blockout.glb"

build_campus.main()