"""齐鲁师范学院（章丘校区）低多边形校园生成器。

用法（需要 Blender 4.2+）：
    blender --background --python blender/build_campus.py

产物：
    blender/qlnu-campus.blend
    web/models/campus.glb

坐标约定：
    数据坐标 +X 东、+Z 南、+Y 上，1 单位 = 1 米，原点 = 北门。
    Blender / glTF 为 Z 向上，因此映射为 (x, -z, height)。
"""

from __future__ import annotations

import json
import math
import random
from pathlib import Path

import bpy
import bmesh

ROOT = Path(__file__).resolve().parent.parent
BUILDINGS_PATH = ROOT / "web" / "src" / "data" / "buildings.json"
CAMPUS_PATH = ROOT / "web" / "src" / "data" / "campus.json"
BLEND_PATH = ROOT / "blender" / "qlnu-campus.blend"
GLB_PATH = ROOT / "web" / "models" / "campus.glb"

# 与 web/src/lib/palette.js 保持一致（sRGB 十六进制）。
CATEGORY_COLORS = {
    "gate": 0x9AA0A8,
    "teaching": 0xD8C7AF,
    "lab": 0xB9C9D0,
    "library": 0xE2D0A8,
    "public": 0xD4C0AE,
    "canteen": 0xDDB78E,
    "dorm": 0xE5D3B9,
    "gym": 0xA9C3C7,
    "logistics": 0xC5BAA9,
}

ROOF_COLORS = {
    "gate": 0x6D7278,
    "teaching": 0x8F7F6C,
    "lab": 0x74858C,
    "library": 0x9C8B68,
    "public": 0x8B7C6B,
    "canteen": 0x997257,
    "dorm": 0x9D8A72,
    "gym": 0x6F878B,
    "logistics": 0x847A6C,
}

COLLECTIONS = ["00_ground", "10_core", "20_dorms", "30_sports", "40_landscape"]


# ---------------------------------------------------------------------------
# 基础工具
# ---------------------------------------------------------------------------


def srgb_to_linear(value: int) -> float:
    channel = value / 255.0
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def hex_to_rgba(value: int, alpha: float = 1.0) -> tuple[float, float, float, float]:
    return (
        srgb_to_linear((value >> 16) & 0xFF),
        srgb_to_linear((value >> 8) & 0xFF),
        srgb_to_linear(value & 0xFF),
        alpha,
    )


def make_material(name: str, color: int, roughness: float = 0.9, metallic: float = 0.0):
    material = bpy.data.materials.get(name)
    if material:
        return material
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = hex_to_rgba(color)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return material


def make_collection(name: str):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def link_object(name: str, mesh, collection) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return obj


def mesh_from_faces(name: str, vertices, faces, material_indices=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.validate()

    # 统一重算法线，避免 glTF 中部分面因朝向相反而不可见。
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    if material_indices:
        for index, face in enumerate(mesh.polygons):
            face.material_index = material_indices[index]
    mesh.update()
    return mesh


def apply_single_material(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    for face in obj.data.polygons:
        face.material_index = 0


def box_mesh(name: str, width: float, depth: float, height: float):
    hw = width / 2.0
    hd = depth / 2.0
    vertices = [
        (-hw, -hd, 0.0),
        (hw, -hd, 0.0),
        (hw, hd, 0.0),
        (-hw, hd, 0.0),
        (-hw, -hd, height),
        (hw, -hd, height),
        (hw, hd, height),
        (-hw, hd, height),
    ]
    faces = [
        (0, 3, 2, 1),
        (4, 5, 6, 7),
        (0, 1, 5, 4),
        (1, 2, 6, 5),
        (2, 3, 7, 6),
        (3, 0, 4, 7),
    ]
    return mesh_from_faces(name, vertices, faces, [0, 1, 0, 0, 0, 0])


def add_prism(name: str, points, height: float, collection, location=(0.0, 0.0, 0.0), rotation_z: float = 0.0):
    """由二维轮廓（局部坐标，沿 Z 拉伸）生成体块。"""
    count = len(points)
    vertices = [(x, y, 0.0) for x, y in points] + [(x, y, height) for x, y in points]
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count + nxt, count + index))
    material_indices = [0, 1] + [0] * count
    mesh = mesh_from_faces(name, vertices, faces, material_indices)
    obj = link_object(name, mesh, collection)
    obj.location = location
    obj.rotation_euler = (0.0, 0.0, rotation_z)
    return obj


def rect_local_points(rect):
    hw = rect["w"] / 2.0
    hd = rect["d"] / 2.0
    return [(-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)]


def polygon_centroid(points):
    x = sum(point[0] for point in points) / len(points)
    y = sum(point[1] for point in points) / len(points)
    return x, y


# ---------------------------------------------------------------------------
# 数据读取
# ---------------------------------------------------------------------------


def load_data():
    with BUILDINGS_PATH.open("r", encoding="utf-8") as handle:
        buildings = json.load(handle)["buildings"]
    with CAMPUS_PATH.open("r", encoding="utf-8") as handle:
        campus = json.load(handle)
    return buildings, campus


# ---------------------------------------------------------------------------
# 场景构建
# ---------------------------------------------------------------------------


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    world = bpy.data.worlds.new("CampusWorld")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = hex_to_rgba(0x9FB8C8)
    background.inputs["Strength"].default_value = 0.7
    scene.world = world


def build_material_library():
    materials = {}
    for category, color in CATEGORY_COLORS.items():
        materials[f"wall_{category}"] = make_material(f"wall_{category}", color, 0.85)
        materials[f"roof_{category}"] = make_material(
            f"roof_{category}", ROOF_COLORS.get(category, 0x8C8272), 0.75
        )
    materials["grass"] = make_material("grass", 0x80996B, 1.0)
    materials["asphalt"] = make_material("asphalt", 0x3F4950, 0.96)
    materials["sidewalk"] = make_material("sidewalk", 0x9AA1A0, 0.95)
    materials["plaza"] = make_material("plaza", 0xA79C8B, 0.93)
    materials["water"] = make_material("water", 0x2F7189, 0.22, 0.15)
    materials["track"] = make_material("track", 0xB0553F, 0.95)
    materials["field"] = make_material("field", 0x5D8553, 1.0)
    materials["court"] = make_material("court", 0xA75F3D, 0.95)
    materials["tree_trunk"] = make_material("tree_trunk", 0x6D5540, 0.95)
    materials["tree_canopy"] = make_material("tree_canopy", 0x4E7B46, 0.9)
    return materials


def build_ground(campus, materials, collections):
    ground = collections["00_ground"]
    landscape = collections["40_landscape"]

    ground_obj = add_prism("ground", [(-650, -550), (650, -550), (650, 550), (-650, 550)], 0.2, ground)
    ground_obj.location = (0.0, -355.0, -0.2)
    apply_single_material(ground_obj, materials["grass"])

    for road in campus["roads"]:
        points = road["points"]
        for index in range(len(points) - 1):
            ax, az = points[index]
            bx, bz = points[index + 1]
            dx = bx - ax
            dz = bz - az
            length = math.hypot(dx, dz)
            if length < 1e-6:
                continue
            angle = -math.atan2(dz, dx)
            center = ((ax + bx) / 2.0, -(az + bz) / 2.0)

            sidewalk = add_prism(
                f"sidewalk_{road['id']}_{index}",
                [(-length / 2, -(road["width"] + 7) / 2), (length / 2, -(road["width"] + 7) / 2),
                 (length / 2, (road["width"] + 7) / 2), (-length / 2, (road["width"] + 7) / 2)],
                0.06,
                ground,
                location=(center[0], center[1], 0.0),
                rotation_z=angle,
            )
            apply_single_material(sidewalk, materials["sidewalk"])

            asphalt = add_prism(
                f"road_{road['id']}_{index}",
                [(-length / 2, -road["width"] / 2), (length / 2, -road["width"] / 2),
                 (length / 2, road["width"] / 2), (-length / 2, road["width"] / 2)],
                0.05,
                ground,
                location=(center[0], center[1], 0.04),
                rotation_z=angle,
            )
            apply_single_material(asphalt, materials["asphalt"])

    for index, plaza in enumerate(campus.get("plazas", [])):
        points = [(x, -z) for x, z in plaza["polygon"]]
        plaza_obj = add_prism(f"plaza_{plaza['id']}", points, 0.04, ground, location=(0.0, 0.0, 0.02))
        apply_single_material(plaza_obj, materials["plaza"])

    for index, polygon in enumerate(campus.get("water", [])):
        points = [(x, -z) for x, z in polygon]
        water = add_prism(f"water_{index}", points, 0.05, landscape, location=(0.0, 0.0, 0.05))
        apply_single_material(water, materials["water"])

    for track in campus.get("tracks", []):
        build_track(track, landscape, materials)


def ellipse_points(rx: float, rz: float, center, segments: int = 48):
    cx, cz = center
    return [
        (cx + math.cos(index / segments * math.tau) * rx,
         cz + math.sin(index / segments * math.tau) * rz)
        for index in range(segments)
    ]


def build_track(track, collection, materials):
    center = (track["x"], -track["z"])
    shape = track.get("kind", "field")

    if shape == "track":
        outer = ellipse_points(track["w"] / 2, track["d"] / 2, center)
        inner = ellipse_points(max(track["w"] / 2 - 8, 1), max(track["d"] / 2 - 8, 1), center)
        vertices = [(x, y, 0.0) for x, y in outer] + [(x, y, 0.0) for x, y in inner]
        count = len(outer)
        faces = []
        for index in range(count):
            nxt = (index + 1) % count
            faces.append((index, nxt, count + nxt, count + index))
        mesh = mesh_from_faces(f"track_{track['id']}", vertices, faces)
        obj = link_object(f"track_{track['id']}", mesh, collection)
        obj.location.z = 0.06
        obj.data.materials.append(materials["track"])
        for face in obj.data.polygons:
            face.material_index = 0

        infield = add_prism(
            f"field_{track['id']}",
            ellipse_points(track["w"] / 2 - 8, track["d"] / 2 - 8, (0, 0)),
            0.04,
            collection,
            location=(center[0], center[1], 0.04),
        )
        apply_single_material(infield, materials["field"])
        return

    width = track["w"]
    depth = track["d"]
    material = materials["court"] if shape == "basketball" else materials["field"]
    obj = add_prism(
        f"field_{track['id']}",
        [(-width / 2, -depth / 2), (width / 2, -depth / 2), (width / 2, depth / 2), (-width / 2, depth / 2)],
        0.04,
        collection,
        location=(center[0], center[1], 0.03),
    )
    apply_single_material(obj, material)


def building_collection_name(category: str) -> str:
    if category == "dorm":
        return "20_dorms"
    if category == "gym":
        return "30_sports"
    return "10_core"


def build_buildings(buildings, materials, collections):
    for building in buildings:
        category = building["category"]
        collection = collections[building_collection_name(category)]
        name = building["name"]
        height = building.get("height_m", 12.0)

        if "rect" in building:
            rect = building["rect"]
            points = rect_local_points(rect)
            rotation = -math.radians(rect.get("rot", 0.0))
            location = (rect["x"], -rect["z"], 0.0)
        else:
            polygon = [(x, -z) for x, z in building.get("polygon", [])]
            if not polygon:
                continue
            cx, cy = polygon_centroid(polygon)
            points = [(x - cx, y - cy) for x, y in polygon]
            rotation = 0.0
            location = (cx, cy, 0.0)

        obj = add_prism(
            f"bld_{building['id']}",
            points,
            height,
            collection,
            location=location,
            rotation_z=rotation,
        )
        obj.data.materials.append(materials.get(f"wall_{category}", materials["wall_public"]))
        obj.data.materials.append(materials.get(f"roof_{category}", materials["roof_public"]))

        obj["building_id"] = building["id"]
        obj["name_zh"] = name
        obj["alias_zh"] = building.get("alias", "")
        obj["category"] = category
        obj["status"] = building.get("status", "built")
        obj["floors"] = building.get("floors", 1)
        obj["height_m"] = height


def build_tree_prototype(collection, materials):
    trunk = [
        (-0.22, -0.22, 0.0), (0.22, -0.22, 0.0), (0.22, 0.22, 0.0), (-0.22, 0.22, 0.0),
        (-0.22, -0.22, 2.6), (0.22, -0.22, 2.6), (0.22, 0.22, 2.6), (-0.22, 0.22, 2.6),
    ]
    trunk_faces = [
        (0, 3, 2, 1), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7),
    ]
    canopy_ring = [
        (math.cos(index / 6 * math.tau) * 2.15, math.sin(index / 6 * math.tau) * 2.15, 4.4)
        for index in range(6)
    ]
    apex = (0.0, 0.0, 7.1)
    vertices = trunk + canopy_ring + [apex]
    faces = list(trunk_faces)
    for index in range(6):
        nxt = (index + 1) % 6
        faces.append((8 + index, 8 + nxt, 14))
    faces.append(tuple(range(8, 14)))
    material_indices = [0] * len(trunk_faces) + [1] * (len(faces) - len(trunk_faces))

    mesh = mesh_from_faces("tree", vertices, faces, material_indices)
    mesh.materials.append(materials["tree_trunk"])
    mesh.materials.append(materials["tree_canopy"])
    return mesh


def mulberry32(seed: int):
    state = seed & 0xFFFFFFFF

    def rng():
        nonlocal state
        state = (state + 0x6D2B79F5) & 0xFFFFFFFF
        value = state
        value = ((value ^ (value >> 15)) * (value | 1)) & 0xFFFFFFFF
        value ^= (value + (((value ^ (value >> 7)) * (value | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
        return ((value ^ (value >> 14)) & 0xFFFFFFFF) / 4294967296

    return rng


def expand(bounds, margin):
    return {
        "minX": bounds["minX"] - margin,
        "maxX": bounds["maxX"] + margin,
        "minZ": bounds["minZ"] - margin,
        "maxZ": bounds["maxZ"] + margin,
    }


def inside(x, z, bounds):
    return bounds["minX"] <= x <= bounds["maxX"] and bounds["minZ"] <= z <= bounds["maxZ"]


def point_in_polygon(x, z, polygon):
    inside_flag = False
    count = len(polygon)
    for index in range(count):
        xi, zi = polygon[index]
        xj, zj = polygon[index - 1]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
            inside_flag = not inside_flag
    return inside_flag


def distance_to_segment(px, pz, ax, az, bx, bz):
    abx = bx - ax
    abz = bz - az
    length_sq = abx * abx + abz * abz
    if length_sq < 1e-9:
        return math.hypot(px - ax, pz - az)
    t = max(0.0, min(1.0, ((px - ax) * abx + (pz - az) * abz) / length_sq))
    return math.hypot(px - (ax + abx * t), pz - (az + abz * t))


def building_aabb(building):
    rect = building.get("rect")
    if rect:
        hw = rect["w"] / 2
        hd = rect["d"] / 2
        return {
            "minX": rect["x"] - hw,
            "maxX": rect["x"] + hw,
            "minZ": rect["z"] - hd,
            "maxZ": rect["z"] + hd,
        }
    polygon = building.get("polygon") or []
    if not polygon:
        return None
    xs = [point[0] for point in polygon]
    zs = [point[1] for point in polygon]
    return {"minX": min(xs), "maxX": max(xs), "minZ": min(zs), "maxZ": max(zs)}


def plan_trees(campus, buildings):
    blocked_buildings = [expand(aabb, 3) for aabb in (building_aabb(item) for item in buildings) if aabb]
    blocked_tracks = [
        expand(
            {
                "minX": track["x"] - track["w"] / 2,
                "maxX": track["x"] + track["w"] / 2,
                "minZ": track["z"] - track["d"] / 2,
                "maxZ": track["z"] + track["d"] / 2,
            },
            4,
        )
        for track in campus.get("tracks", [])
    ]
    water_bounds = []
    for polygon in campus.get("water", []):
        xs = [point[0] for point in polygon]
        zs = [point[1] for point in polygon]
        water_bounds.append(expand({"minX": min(xs), "maxX": max(xs), "minZ": min(zs), "maxZ": max(zs)}, 3))

    trees = []
    nav = expand(campus["bounds"], -6)
    for zone in campus.get("treeZones", []):
        rect = zone["rect"]
        rng = mulberry32(zone.get("seed", 1))
        target = zone["count"]
        placed = 0
        attempts = 0
        while placed < target and attempts < target * 90:
            attempts += 1
            x = rect["x"] - rect["w"] / 2 + rng() * rect["w"]
            z = rect["z"] - rect["d"] / 2 + rng() * rect["d"]
            if not inside(x, z, nav):
                continue
            if any(inside(x, z, box) for box in blocked_buildings):
                continue
            if any(inside(x, z, box) for box in blocked_tracks):
                continue
            if any(inside(x, z, box) for box in water_bounds):
                continue
            if any(point_in_polygon(x, z, plaza["polygon"]) for plaza in campus.get("plazas", [])):
                continue
            if any(
                distance_to_segment(x, z, road["points"][index][0], road["points"][index][1],
                                    road["points"][index + 1][0], road["points"][index + 1][1])
                < road["width"] / 2 + 5
                for road in campus["roads"]
                for index in range(len(road["points"]) - 1)
            ):
                continue
            if any(math.hypot(tree["x"] - x, tree["z"] - z) < 3.4 for tree in trees):
                continue
            trees.append({"x": x, "z": z, "scale": 0.78 + rng() * 0.62, "rotation": rng() * math.tau})
            placed += 1
    return trees


def build_trees(campus, buildings, collection, materials):
    trees = plan_trees(campus, buildings)
    if not trees:
        return
    prototype = build_tree_prototype(collection, materials)
    for index, tree in enumerate(trees):
        obj = bpy.data.objects.new(f"tree_{index:03d}", prototype)
        obj.location = (tree["x"], -tree["z"], 0.0)
        obj.rotation_euler = (0.0, 0.0, tree["rotation"])
        obj.scale = (tree["scale"], tree["scale"], tree["scale"] * (0.92 + (index % 7) * 0.02))
        collection.objects.link(obj)


def build_camera_and_light():
    scene = bpy.context.scene
    camera_data = bpy.data.cameras.new("CampusCamera")
    camera_data.lens = 24
    camera = bpy.data.objects.new("CampusCamera", camera_data)
    camera.location = (0.0, -8.0, 20.0)
    camera.rotation_euler = (math.radians(-86), 0.0, 0.0)
    scene.collection.objects.link(camera)
    scene.camera = camera

    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.2
    sun_data.angle = math.radians(1.2)
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.location = (180.0, -220.0, 260.0)
    sun.rotation_euler = (math.radians(48), 0.0, math.radians(28))
    scene.collection.objects.link(sun)


def main():
    buildings, campus = load_data()
    reset_scene()
    materials = build_material_library()
    collections = {name: make_collection(name) for name in COLLECTIONS}

    build_ground(campus, materials, collections)
    build_buildings(buildings, materials, collections)
    build_trees(campus, buildings, collections["40_landscape"], materials)
    build_camera_and_light()

    BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        export_yup=True,
        use_selection=False,
    )
    print(f"[qlnu] buildings={len(buildings)} blend={BLEND_PATH} glb={GLB_PATH}")


if __name__ == "__main__":
    main()