# CPRedux anatomical model assets

`body.mesh.json.gz` and `structures.json` are adapted from **Z-Anatomy — The libre
3D atlas of anatomy**, by Gauthier Kervyn and contributors, CC BY-SA 4.0.

Source: https://github.com/Z-Anatomy/Models-of-human-anatomy
Source revision: a1b2704b00e65050a5af6af8194758a11c26d0f9
Source file: Z-Anatomy.zip / Z-Anatomy/Startup.blend
License: https://creativecommons.org/licenses/by-sa/4.0/

Underlying source attribution:

- **BodyParts3D — The Database Center for Life Science — CC BY-SA 2.1 Japan**.
  Kousaku Okubo. https://dbarchive.biosciencedbc.jp/en/bodyparts3d/download.html
  https://creativecommons.org/licenses/by-sa/2.1/jp/
- **Z-Anatomy — The libre 3D atlas of anatomy — CC BY-SA 4.0**.
  Gauthier Kervyn (design, 3D, anatomy) and contributors.
- Source project's anatomical references include Brainder / University of
  Washington and **Cranial Nerves and Foramina — University of Dundee, CAHID —
  CC BY 4.0**. https://creativecommons.org/licenses/by/4.0/

CPRedux adaptations: selected surface regions, skeleton, superficial muscles,
arteries, veins, cerebral cortex and peripheral nerves; detached demonstration
pieces removed; vertices welded, polygon counts reduced, coordinates normalized,
normals quantized, and left/right cyberware zones assigned. Adapted geometry is
licensed under **CC BY-SA 4.0**. No endorsement by the original authors is implied.
The separately licensed inner-ear and kidney models and textual definitions are
not included. The exact exported structure names are listed in `structures.json`.

Reproduce with Blender (the original source archive is not needed at runtime):

```
Blender --background Startup.blend --disable-autoexec \
  --python tool/export_anatomy.py -- assets/anatomy
```

This asset license applies to the adapted anatomy files. The renderer, application
code and other project assets retain their respective project licenses.
