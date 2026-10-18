"""
Leafrune Akadémia – üvegház-váz építő Blenderhez.

Használat:
  1. Nyisd meg a Blendert, és fent válts a "Scripting" fülre.
  2. Nyomd meg az "Open" gombot, és nyisd meg ezt a fájlt
     (vagy másold be a tartalmát egy új szövegbe a "New" gombbal).
  3. Írd be lent az EXPORT_PATH-hoz a projekted mappáját (lásd a példát).
  4. Nyomd meg a ▶ (Run Script) gombot.

A szkript létrehoz egy "Greenhouse" gyűjteményt: padló mozaikkarikákkal,
kőlábazat, íves ablakkeretek kis díszkarikákkal, üvegfalak, nyeregtető bordákkal
és boltíves bejárat. Ha megadtad az EXPORT_PATH-t, .glb fájlba is kimenti,
amit a Godot automatikusan használ a helyőrző falak helyett.

Bátran futtasd újra: mindig törli és újraépíti a gyűjteményt.
A méreteket a lenti számokkal tudod állítani (méterben), de ha a falakat
elmozdítod, a Godot-ban a main.gd ugyanilyen nevű számait is igazítani kell.
"""

import math
import bpy
from mathutils import Matrix, Vector

# Példa: r"C:\Users\Anita\Documents\GitHub\leafrune\assets\models\greenhouse.glb"
EXPORT_PATH = r"C:\Users\nitta\Documents\leafrune\assets\models\greenhouse.glb"

ROOM_W = 16.0     # szélesség (Godot x)
ROOM_D = 12.0     # mélység (Godot z), a bejárat a Godot +z oldalán van
WALL_H = 4.2
RIDGE_H = 5.6
BAYS_X = 7        # ablakmezők száma az első és hátsó falon (páratlan, a középső az ajtó)
BAYS_Z = 5        # ablakmezők száma az oldalfalakon
KICK_H = 0.6      # kőlábazat magassága
SPRING_H = 2.95   # itt kezdődik az ablakív

COL_NAME = "Greenhouse"

# Blenderben Z mutat felfelé. Godotban Y. Az exportáló ezt magától átváltja:
# Godot (x, y, z)  ==  Blender (x, -z, y)


def g2b(x, y, z):
    return Vector((x, -z, y))


# ---------------------------------------------------------------- anyagok

def material(name, color, rough=0.6, metal=0.0, alpha=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Alpha"].default_value = alpha
    if alpha < 1.0:
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
        try:
            m.blend_method = "BLEND"
        except Exception:
            pass
    m.diffuse_color = (*color, alpha)
    return m


MAT = {
    "frame": material("LR_Keret", (0.82, 0.70, 0.42), rough=0.35, metal=0.6),
    "glass": material("LR_Uveg", (0.80, 0.90, 0.92), rough=0.05, alpha=0.18),
    "stone": material("LR_Ko", (0.80, 0.72, 0.56), rough=0.9),
    "floor": material("LR_Padlo", (0.78, 0.68, 0.52), rough=0.85),
    "mosaic": material("LR_Mozaik", (0.58, 0.50, 0.34), rough=0.85),
    "mosaic2": material("LR_Mozaik_zold", (0.42, 0.52, 0.34), rough=0.85),
}


# ---------------------------------------------------------------- geometria-gyűjtő

class Builder:
    """Sok kis elemet anyagonként egy-egy objektumba gyűjt, hogy a Godot gyors maradjon."""

    def __init__(self):
        self.parts = {}

    def _add(self, mat, verts, faces):
        vs, fs = self.parts.setdefault(mat, ([], []))
        o = len(vs)
        vs.extend(verts)
        fs.extend([tuple(i + o for i in f) for f in faces])

    def box(self, mat, center, size, M=Matrix()):
        """center és size Blender-koordinátában, M a fal helyzete."""
        x, y, z = size[0] / 2, size[1] / 2, size[2] / 2
        local = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z),
                 (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
        T = M @ Matrix.Translation(center)
        self._add(mat, [tuple(T @ Vector(v)) for v in local],
                  [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])

    def beam(self, mat, a, b, thick, M=Matrix()):
        """Rúd két pont között (a falsíkban, Blender x-z koordinátával)."""
        a, b = Vector(a), Vector(b)
        d = b - a
        length = d.length
        if length < 1e-5:
            return
        x_axis = d.normalized()
        y_axis = Vector((0, 1, 0))
        z_axis = x_axis.cross(y_axis).normalized()
        y_axis = z_axis.cross(x_axis).normalized()
        R = Matrix((x_axis, y_axis, z_axis)).transposed().to_4x4()
        T = M @ Matrix.Translation((a + b) / 2) @ R
        x, y, z = length / 2 + thick / 2, thick / 2, thick / 2
        local = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z),
                 (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
        self._add(mat, [tuple(T @ Vector(v)) for v in local],
                  [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])

    def arc(self, mat, center, r, a0, a1, thick, segs, M=Matrix()):
        pts = []
        for i in range(segs + 1):
            a = a0 + (a1 - a0) * i / segs
            pts.append((center[0] + r * math.cos(a), 0.0, center[2] + r * math.sin(a)))
        for p, q in zip(pts, pts[1:]):
            self.beam(mat, p, q, thick, M)

    def quad(self, mat, pts, M=Matrix()):
        self._add(mat, [tuple(M @ Vector(p)) for p in pts], [(0, 1, 2, 3)])

    def tri(self, mat, pts, M=Matrix()):
        self._add(mat, [tuple(M @ Vector(p)) for p in pts], [(0, 1, 2)])

    def ring(self, mat, center, r_in, r_out, z, segs=64):
        verts, faces = [], []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            verts.append((center[0] + r_in * math.cos(a), center[1] + r_in * math.sin(a), z))
            verts.append((center[0] + r_out * math.cos(a), center[1] + r_out * math.sin(a), z))
        for i in range(segs):
            j = (i + 1) % segs
            faces.append((2 * i, 2 * i + 1, 2 * j + 1, 2 * j))
        self._add(mat, verts, faces)

    def build(self, collection, prefix):
        for mat_key, (vs, fs) in self.parts.items():
            me = bpy.data.meshes.new(f"{prefix}_{mat_key}")
            me.from_pydata(vs, [], fs)
            me.update()
            me.materials.append(MAT[mat_key])
            ob = bpy.data.objects.new(f"{prefix}_{mat_key}", me)
            collection.objects.link(ob)
            if mat_key != "glass":
                for poly in me.polygons:
                    poly.use_smooth = False


# ---------------------------------------------------------------- részek

def wall(B, length, bays, M, door=False):
    """Egy fal a saját koordinátáiban: x a fal mentén, z felfelé, y a vastagság."""
    bw = length / bays
    door_i = bays // 2 if door else -1
    arch_r = bw / 2 - 0.12
    for i in range(bays + 1):
        x = -length / 2 + i * bw
        B.box("frame", (x, 0, WALL_H / 2), (0.14, 0.14, WALL_H), M)
    B.box("frame", (0, 0, WALL_H - 0.05), (length, 0.16, 0.1), M)
    for i in range(bays):
        xc = -length / 2 + (i + 0.5) * bw
        inner = bw - 0.14
        if i != door_i:
            # kőlábazat rombuszmintával
            B.box("stone", (xc, 0, KICK_H / 2), (inner, 0.22, KICK_H), M)
            B.box("frame", (xc, 0, KICK_H), (inner, 0.1, 0.06), M)
            B.beam("frame", (xc - inner / 2 + 0.1, -0.12, 0.1), (xc, -0.12, KICK_H - 0.08), 0.03, M)
            B.beam("frame", (xc, -0.12, KICK_H - 0.08), (xc + inner / 2 - 0.1, -0.12, 0.1), 0.03, M)
            B.beam("frame", (xc - inner / 2 + 0.1, 0.12, 0.1), (xc, 0.12, KICK_H - 0.08), 0.03, M)
            B.beam("frame", (xc, 0.12, KICK_H - 0.08), (xc + inner / 2 - 0.1, 0.12, 0.1), 0.03, M)
            # üveg
            B.box("glass", (xc, 0, (KICK_H + WALL_H) / 2), (inner, 0.02, WALL_H - KICK_H), M)
            # osztók: függőleges középen, vízszintesek
            B.box("frame", (xc, 0, (KICK_H + SPRING_H) / 2), (0.05, 0.06, SPRING_H - KICK_H), M)
            for h in (1.3, 2.1):
                B.box("frame", (xc, 0, h), (inner, 0.05, 0.04), M)
            # belső kis ív a két alsó mező tetején
            B.arc("frame", (xc - inner / 4, 0, SPRING_H - 0.02), inner / 4 - 0.02, 0, math.pi, 0.04, 10, M)
            B.arc("frame", (xc + inner / 4, 0, SPRING_H - 0.02), inner / 4 - 0.02, 0, math.pi, 0.04, 10, M)
        else:
            # ajtó: üveg csak az ív fölött
            B.box("glass", (xc, 0, (SPRING_H + WALL_H) / 2), (inner, 0.02, WALL_H - SPRING_H), M)
            B.box("frame", (xc, 0, SPRING_H), (inner, 0.12, 0.08), M)
        # nagy ív és díszkarika
        B.arc("frame", (xc, 0, SPRING_H), arch_r, 0, math.pi, 0.07, 16, M)
        B.box("frame", (xc, 0, SPRING_H), (inner, 0.06, 0.05), M)
        ring_z = SPRING_H + arch_r + (WALL_H - SPRING_H - arch_r) / 2
        ring_r = min(0.16, (WALL_H - SPRING_H - arch_r) / 2 - 0.03)
        if ring_r > 0.05:
            for k in (-1, 1):
                B.arc("frame", (xc + k * (arch_r * 0.75), 0, ring_z), ring_r, 0, 2 * math.pi, 0.03, 12, M)
        B.beam("frame", (xc, 0, SPRING_H + arch_r), (xc, 0, WALL_H - 0.1), 0.05, M)


def roof(B):
    hw, hd = ROOM_W / 2, ROOM_D / 2
    for s in (-1, 1):
        eave = g2b(0, WALL_H, s * hd)
        ridge = g2b(0, RIDGE_H, 0)
        B.quad("glass", [
            (-hw, eave.y, eave.z), (hw, eave.y, eave.z),
            (hw, ridge.y, ridge.z), (-hw, ridge.y, ridge.z)])
        for i in range(BAYS_X + 1):
            x = -hw + i * ROOM_W / BAYS_X
            B.beam("frame", (x, eave.y, eave.z + 0.06), (x, ridge.y, ridge.z + 0.06), 0.1)
        # közbenső merevítő
        mid = (eave + ridge) / 2
        B.beam("frame", (-hw, mid.y, mid.z + 0.06), (hw, mid.y, mid.z + 0.06), 0.07)
    B.beam("frame", (-hw, 0, RIDGE_H), (hw, 0, RIDGE_H), 0.16)
    # oromzat a két oldalon
    for sx in (-1, 1):
        x = sx * hw
        B.tri("glass", [(x, hd, WALL_H), (x, -hd, WALL_H), (x, 0, RIDGE_H)])
        B.beam("frame", (x, hd, WALL_H), (x, 0, RIDGE_H), 0.1)
        B.beam("frame", (x, -hd, WALL_H), (x, 0, RIDGE_H), 0.1)
        for k in (-1, 1):
            yb = k * hd / 2
            top = WALL_H + (RIDGE_H - WALL_H) * (1 - abs(yb) / hd)
            B.beam("frame", (x, yb, WALL_H), (x, yb, top), 0.06)


def floor(B):
    B.box("floor", (0, 0, -0.1), (ROOM_W, ROOM_D, 0.2))
    c = g2b(0, 0, 0.6)
    B.ring("mosaic", (c.x, c.y), 3.1, 3.4, 0.004)
    B.ring("mosaic2", (c.x, c.y), 3.55, 3.7, 0.004)
    B.ring("mosaic", (c.x, c.y), 1.65, 1.85, 0.004)
    # küszöbkő a bejáratnál
    s = g2b(0, 0, ROOM_D / 2 + 0.5)
    B.box("stone", (s.x, s.y, -0.08), (2.6, 1.0, 0.16))


# ---------------------------------------------------------------- futtatás

def main():
    if COL_NAME in bpy.data.collections:
        col = bpy.data.collections[COL_NAME]
        for ob in list(col.objects):
            bpy.data.objects.remove(ob, do_unlink=True)
    else:
        col = bpy.data.collections.new(COL_NAME)
        bpy.context.scene.collection.children.link(col)

    hw, hd = ROOM_W / 2, ROOM_D / 2
    B = Builder()
    floor(B)
    # hátsó fal (Godot z = -hd  ->  Blender y = +hd), első fal ajtóval, két oldalfal
    wall(B, ROOM_W, BAYS_X, Matrix.Translation((0, hd, 0)))
    wall(B, ROOM_W, BAYS_X, Matrix.Translation((0, -hd, 0)), door=True)
    wall(B, ROOM_D, BAYS_Z, Matrix.Translation((-hw, 0, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z"))
    wall(B, ROOM_D, BAYS_Z, Matrix.Translation((hw, 0, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z"))
    roof(B)
    B.build(col, "Uveghaz")
    print("Leafrune: az üvegház elkészült.")

    if EXPORT_PATH:
        bpy.ops.object.select_all(action="DESELECT")
        for ob in col.objects:
            ob.select_set(True)
        bpy.ops.export_scene.gltf(
            filepath=EXPORT_PATH,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
        )
        print("Leafrune: elmentve ide:", EXPORT_PATH)
    else:
        print("Leafrune: EXPORT_PATH üres, ezért csak Blenderben építettem fel.")


main()
