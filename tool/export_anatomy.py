"""Run with Blender --background Startup.blend --disable-autoexec --python
this_file -- OUTPUT_DIR. Adapted Z-Anatomy geometry remains CC BY-SA 4.0.
No scripts embedded in the source .blend are needed or executed.
"""
import bpy, bmesh, gzip, json, math, os, sys
from collections import defaultdict

out = sys.argv[sys.argv.index('--') + 1]
os.makedirs(out, exist_ok=True)
# Work only with anatomical meshes, never annotations, definitions, inner ear,
# kidneys or other separately licensed visceral models.
def layer_for(o):
    groups = {c.name for c in o.users_collection}
    if o.type not in {'MESH', 'CURVE'} or o.name.endswith(('.i', '.j')):
        return None
    if '9: Regions of human body' in groups and o.type == 'MESH':
        return 'surface'
    if '1: Skeletal system' in groups and o.type == 'MESH':
        return 'skeleton'
    if 'Superficial muscles' in groups and o.type == 'MESH':
        return 'muscles'
    if '5: Cardiovascular system' in groups:
        if 'Systemic veins' in groups or 'venous' in o.name.lower():
            return 'veins'
        if 'Systemic arteries' in groups or 'Heart' in groups:
            return 'arteries'
    if '7: Nervous system & Sense organs' in groups:
        if 'Nerves' in groups or 'Neo-cortex' in groups or o.name.startswith('Spinal cord'):
            return 'nervous'
    return None

layers = defaultdict(lambda: [[], [], []])
# Atlas skin regions have individual Solidify shells for exploded educational
# views. Remove these before welding, otherwise overlapping inner walls cause
# false facets and holes in the continuous external body.
for o in list(bpy.data.objects):
    if layer_for(o) == 'surface':
        for modifier in list(o.modifiers):
            o.modifiers.remove(modifier)
deps = bpy.context.evaluated_depsgraph_get()
for o in list(bpy.data.objects):
    layer = layer_for(o)
    if not layer:
        continue
    if o.type == 'CURVE':
        o.data.resolution_u = 3
        o.data.bevel_resolution = 1
        o.data.resolution_v = 1
    ev = o.evaluated_get(deps)
    mesh = ev.to_mesh()
    if len(mesh.polygons) == 0:
        ev.to_mesh_clear()
        continue
    # The atlas also contains detached demonstration pieces to the side.
    world = [o.matrix_world @ v.co for v in mesh.vertices]
    if world and max(abs(v.x) for v in world) > .50:
        ev.to_mesh_clear()
        continue
    vs, fs, names = layers[layer]
    offset = len(vs)
    vs.extend(tuple(v) for v in world)
    fs.extend(tuple(offset + i for i in p.vertices) for p in mesh.polygons)
    names.append(o.name)
    ev.to_mesh_clear()

budgets = dict(surface=22000, skeleton=30000, muscles=18000,
               arteries=18000, veins=14000, nervous=22000)
result = []
for layer, (vertices, faces, names) in layers.items():
    mesh = bpy.data.meshes.new('CPRedux_' + layer)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.00004)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new('CPRedux_' + layer, mesh)
    bpy.context.scene.collection.objects.link(obj)
    # Render assets, not model source; cap complexity for native desktop drawing.
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    if layer == 'surface':
        smooth = obj.modifiers.new('Continuous skin', 'SUBSURF')
        smooth.levels = 1
        tris *= 4
    if tris > budgets[layer]:
        dec = obj.modifiers.new('Desktop LOD', 'DECIMATE')
        dec.ratio = budgets[layer] / tris
    ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    cooked = ev.to_mesh()
    cooked.calc_loop_triangles()
    cooked.calc_normals()
    # Blender coordinates: X left, Y posterior, Z superior.
    # Renderer coordinates: X right on screen, Y superior, Z anterior.
    positions, normals = [], []
    for v in cooked.vertices:
        x, y, z = v.co
        positions.extend([round(x / .86 * 10000),
                          round((z - .86) / .86 * 10000),
                          round(-y / .86 * 10000)])
        nx, ny, nz = v.normal
        normals.extend([round(nx * 127), round(nz * 127), round(-ny * 127)])
    indices, zones = [], []
    for t in cooked.loop_triangles:
        indices.extend(t.vertices)
        xyz = [sum(cooked.vertices[i].co[k] for i in t.vertices) / 3 for k in range(3)]
        x, y, z = xyz
        ax = abs(x)
        if z > 1.47:
            zone = 0  # head
            if 1.53 < z < 1.585 and y < -.075 and .015 < ax < .055:
                zone = 1  # eyes
            elif 1.50 < z < 1.59 and ax > .065:
                zone = 2  # ears
        elif ax > .205 and z > .74:
            zone = (11 if x > 0 else 12) if z < .94 else (9 if x > 0 else 10)  # anatomical left/right hands/arms
        elif z < .86:
            zone = 13 if x > 0 else 14  # anatomical left/right legs
        elif z < 1.055 and ax < .205:
            zone = 6  # pelvis
        else:
            zone = 3  # torso
        zones.append(zone)
    result.append(dict(layer=layer, p=positions, n=normals, t=indices, z=zones))
    print('EXPORTED', layer, len(names), 'structures', len(zones), 'triangles', flush=True)
    ev.to_mesh_clear()

payload = dict(format=1, source='Z-Anatomy / BodyParts3D', meshes=result)
with open(os.path.join(out,'body.mesh.json.gz'),'wb') as f:
    f.write(gzip.compress(json.dumps(payload,separators=(',',':')).encode(),mtime=0))
with open(os.path.join(out,'structures.json'),'w') as f:
    json.dump({k:v[2] for k,v in layers.items()},f,indent=2)
print('DONE',flush=True)
