"""Bake the walkable cap of the Moon GLB into a Godot heightmap resource."""

import array
import json
import math
from pathlib import Path
import struct


PROJECT = Path(__file__).resolve().parents[1]
LUNAR = PROJECT / "world" / "lunar"
MOON = LUNAR / "assets" / "Moon_NASA_LRO_8k_Topo_Small.glb"
OUTPUT = LUNAR / "surface_collision.tres"

# Match the Moon instance, the collider's position relative to Ground, and
# the SurfaceBoundary in planet_surface.tscn. Godot spaces heightmap samples
# one unit apart, so divide heights by the collider's uniform scale.
MOON_SCALE = 102
CELL_SIZE = 0.5
CAP_HALF_SIZE = 50
CAP_CENTER_Z = 7


def load_mesh():
    with MOON.open("rb") as source:
        magic, version, _ = struct.unpack("<4sII", source.read(12))
        if (magic, version) != (b"glTF", 2):
            raise ValueError("Expected a glTF 2.0 binary")
        size, kind = struct.unpack("<I4s", source.read(8))
        if kind != b"JSON":
            raise ValueError("Missing glTF JSON chunk")
        manifest = json.loads(source.read(size))
        size, kind = struct.unpack("<I4s", source.read(8))
        if kind != b"BIN\0":
            raise ValueError("Missing glTF binary chunk")
        binary_start = source.tell()

        def read_accessor(index, typecode, component_type):
            accessor = manifest["accessors"][index]
            view = manifest["bufferViews"][accessor["bufferView"]]
            if accessor["componentType"] != component_type or view.get("byteStride"):
                raise ValueError("Expected tightly packed float positions and uint indices")
            source.seek(binary_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0))
            values = array.array(typecode)
            count = accessor["count"] * (3 if accessor["type"] == "VEC3" else 1)
            values.fromfile(source, count)
            if struct.pack("=I", 1) != struct.pack("<I", 1):
                values.byteswap()
            return values

        mesh = manifest["meshes"][0]["primitives"][0]
        positions = read_accessor(mesh["attributes"]["POSITION"], "f", 5126)
        indices = read_accessor(mesh["indices"], "I", 5125)
    return positions, indices


def bake_heightmap(positions, indices):
    width = round(2 * CAP_HALF_SIZE / CELL_SIZE) + 1
    min_z = CAP_CENTER_Z - CAP_HALF_SIZE
    max_z = CAP_CENTER_Z + CAP_HALF_SIZE
    # Cache only vertices near the cap. The margin exceeds the source mesh's
    # triangle size so triangles crossing the heightmap boundary are sampled.
    vertices = {}
    for index, (x, y, z) in enumerate(zip(positions[::3], positions[1::3], positions[2::3])):
        x, y, z = x * MOON_SCALE, y * MOON_SCALE, z * MOON_SCALE
        if y > 0 and abs(x) <= CAP_HALF_SIZE + 2 and min_z - 2 <= z <= max_z + 2:
            vertices[index] = ((x + CAP_HALF_SIZE) / CELL_SIZE, y / CELL_SIZE,
                               (z - min_z) / CELL_SIZE)

    heights = [-math.inf] * (width * width)
    for first, second, third in zip(indices[::3], indices[1::3], indices[2::3]):
        if first not in vertices or second not in vertices or third not in vertices:
            continue
        ax, ay, az = vertices[first]
        bx, by, bz = vertices[second]
        cx, cy, cz = vertices[third]
        area = (bx - ax) * (cz - az) - (cx - ax) * (bz - az)
        if abs(area) < 1e-9:
            continue
        for z in range(max(0, math.ceil(min(az, bz, cz))), min(width - 1, math.floor(max(az, bz, cz))) + 1):
            for x in range(max(0, math.ceil(min(ax, bx, cx))), min(width - 1, math.floor(max(ax, bx, cx))) + 1):
                b = ((x - ax) * (cz - az) - (cx - ax) * (z - az)) / area
                c = ((bx - ax) * (z - az) - (x - ax) * (bz - az)) / area
                a = 1 - b - c
                if min(a, b, c) >= -1e-7:
                    index = z * width + x
                    heights[index] = max(heights[index], a * ay + b * by + c * cy)
    if not all(map(math.isfinite, heights)):
        raise ValueError("The Moon mesh does not cover every sample in the walkable cap")
    return width, heights


def main():
    width, heights = bake_heightmap(*load_mesh())
    samples = ", ".join(f"{height:.4f}" for height in heights)
    OUTPUT.write_text(
        '[gd_resource type="HeightMapShape3D" format=3]\n\n[resource]\n'
        f"map_width = {width}\nmap_depth = {width}\n"
        f"map_data = PackedFloat32Array({samples})\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"Baked {width} x {width} Moon collision samples to {OUTPUT.name}")


if __name__ == "__main__":
    main()
