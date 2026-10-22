// The node renderer of the building template tools: three.js geometry for a
// set of Luanti node cells (shapes, rotations, textures, node boxes, meshes),
// the orbit / walk / noclip cameras with a touch fallback, and block picking.
// The town viewer (town.html), the template gallery (gallery.html) and the
// template editor share it.
//
// It is a plain ES module. A page served as files imports it
// (`import { createNodeView } from "./renderer.js"`, with the importmap below
// for "three"); the self-contained pages get it inlined by build_viewer.py
// (`inline_renderer`), which drops the import lines and the `export` keywords.
//
// Coordinates are Luanti's (x east, y up, z north, one unit per node, node
// centres on integers). The scene root mirrors z, which turns Luanti's
// left-handed frame into three.js's right-handed one; three.js flips the
// front face for a mirrored object, so faces stay front facing.
//
// Inputs (from the build): `types`, one entry per node name a page uses
// (build_viewer.build_types: drawtype, tiles as texture indices, boxes,
// meshes, connects); `textures`, data URIs; `meshes`, triangle buffers.
// Cells are typed arrays X, Y, Z (int16), T (type index), P2 (param2), made
// into a lookup by `cellData` or decoded from the build's packing by
// `decodeCells`.

import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";

export const SKY = 0x9ec3ea;
export const EYE = 1.625, STEP = 0.6, RADIUS = 0.3, HEIGHT = 1.75;

// Luanti face shading (applyFacesShading) and tile order +Y -Y +X -X +Z -Z.
const FACE_SHADE = [1.0, 0.447213, 0.670820, 0.670820, 0.836660, 0.836660];
const NORMALS = [[0,1,0],[0,-1,0],[1,0,0],[-1,0,0],[0,0,1],[0,0,-1]];
const toLinear = s => Math.pow(s, 2.2);
const UNIT = [-.5, -.5, -.5, .5, .5, .5];
const FACE_AXIS = [1, 1, 0, 0, 2, 2];  // coordinate index of each face's normal
// drawPlantlike styles by meshoptions: [rotation, quad offset, offset top only].
const PLANT_STYLES = [
  [[46, 0], [-44, 0]],
  [[91, 0], [1, 0]],
  [[121, 0], [241, 0], [1, 0]],
  [[1, .25], [91, .25], [181, .25], [271, .25]],
  [[1, -.5, true], [91, -.5, true], [181, -.5, true], [271, -.5, true]],
];
function faceOf(n) {
  const ax = Math.abs(n[0]), ay = Math.abs(n[1]), az = Math.abs(n[2]);
  if (ay >= ax && ay >= az) return n[1] >= 0 ? 0 : 1;
  if (ax >= az) return n[0] >= 0 ? 2 : 3;
  return n[2] >= 0 ? 4 : 5;
}
function shadeOf(n) {
  const len = Math.hypot(n[0], n[1], n[2]);
  if (len < 1e-6) return 1;
  const y = n[1] / len, x = n[0] / len, z = n[2] / len;
  if (y < -0.5) return FACE_SHADE[1];
  if (x > 0.5 || x < -0.5) return FACE_SHADE[2];
  if (z > 0.5 || z < -0.5) return FACE_SHADE[4];
  return 1;
}

// Box face corners (in box-selector form) and the texture mapping Luanti uses
// for node boxes, converted to three.js's bottom-up v.
const FACE_CORNERS = [
  b => [[b[0],b[4],b[2]],[b[3],b[4],b[2]],[b[3],b[4],b[5]],[b[0],b[4],b[5]]],
  b => [[b[0],b[1],b[2]],[b[3],b[1],b[2]],[b[3],b[1],b[5]],[b[0],b[1],b[5]]],
  b => [[b[3],b[1],b[2]],[b[3],b[4],b[2]],[b[3],b[4],b[5]],[b[3],b[1],b[5]]],
  b => [[b[0],b[1],b[2]],[b[0],b[4],b[2]],[b[0],b[4],b[5]],[b[0],b[1],b[5]]],
  b => [[b[0],b[1],b[5]],[b[3],b[1],b[5]],[b[3],b[4],b[5]],[b[0],b[4],b[5]]],
  b => [[b[0],b[1],b[2]],[b[3],b[1],b[2]],[b[3],b[4],b[2]],[b[0],b[4],b[2]]],
];
const FACE_UV = [
  p => [p[0] + .5, p[2] + .5],
  p => [p[0] + .5, .5 - p[2]],
  p => [p[2] + .5, p[1] + .5],
  p => [.5 - p[2], p[1] + .5],
  p => [.5 - p[0], p[1] + .5],
  p => [p[0] + .5, p[1] + .5],
];
const sub = (a, b) => [a[0]-b[0], a[1]-b[1], a[2]-b[2]];
const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
const dot = (a, b) => a[0]*b[0] + a[1]*b[1] + a[2]*b[2];
// Corner order per face so that the quad is counter-clockwise from outside.
const FACE_REVERSE = FACE_CORNERS.map((f, i) => {
  const c = f([-.5,-.5,-.5,.5,.5,.5]);
  return dot(cross(sub(c[1], c[0]), sub(c[2], c[0])), NORMALS[i]) < 0;
});

// ------------------------------------------------------------ rotation ---
// Irrlicht's rotateXZBy / rotateYZBy / rotateXYBy, and Luanti's
// rotateMeshBy6dFacedir, applied to the basis to get one integer matrix per
// facedir value.
function rot(p, plane, deg) {
  const r = deg * Math.PI / 180, c = Math.round(Math.cos(r)), s = Math.round(Math.sin(r));
  const [x, y, z] = p;
  if (plane === "xz") return [x*c - z*s, y, x*s + z*c];
  if (plane === "yz") return [x, y*c - z*s, y*s + z*c];
  return [x*c - y*s, x*s + y*c, z];
}
function facedirPoint(p, fd) {
  const axis = fd >> 2, r = fd & 3;
  if (r === 1) p = rot(p, "xz", -90);
  else if (r === 2) p = rot(p, "xz", 180);
  else if (r === 3) p = rot(p, "xz", 90);
  if (axis === 1) p = rot(p, "yz", 90);
  else if (axis === 2) p = rot(p, "yz", -90);
  else if (axis === 3) p = rot(p, "xy", -90);
  else if (axis === 4) p = rot(p, "xy", 90);
  else if (axis === 5) { p = rot(p, "xy", -90); p = rot(p, "xy", -90); }
  return p;
}
const FACEDIR_M = [];
for (let fd = 0; fd < 24; fd++) {
  const ex = facedirPoint([1,0,0], fd), ey = facedirPoint([0,1,0], fd), ez = facedirPoint([0,0,1], fd);
  FACEDIR_M.push([ex, ey, ez]);
}
const WALLMOUNTED_TO_FACEDIR = [20, 0, 17, 15, 8, 6];
function rotationFor(t, p2) {
  const kind = t.p2;
  let fd = -1;
  if (kind === "facedir" || kind === "colorfacedir") fd = p2 & 31;
  else if (kind === "4dir" || kind === "color4dir") fd = p2 & 3;
  else if ((kind === "wallmounted" || kind === "colorwallmounted") && !t.wall) {
    const w = p2 & 7; fd = w < 6 ? WALLMOUNTED_TO_FACEDIR[w] : -1;
  }
  if (fd <= 0 || fd > 23) return null;
  return FACEDIR_M[fd];
}
function apply(m, p) {
  if (!m) return p;
  return [p[0]*m[0][0] + p[1]*m[1][0] + p[2]*m[2][0],
          p[0]*m[0][1] + p[1]*m[1][1] + p[2]*m[2][1],
          p[0]*m[0][2] + p[1]*m[1][2] + p[2]*m[2][2]];
}
function applyInverse(m, p) {
  if (!m) return p;
  return [dot(p, m[0]), dot(p, m[1]), dot(p, m[2])];
}
// wallmounted node boxes: wall_side is authored against the -X wall.
function wallBoxes(t, p2) {
  const w = p2 & 7;
  if (w === 0) return { boxes: t.wall.wall_top, m: null };
  if (w === 1) return { boxes: t.wall.wall_bottom, m: null };
  const deg = { 2: 180, 3: 0, 4: -90, 5: 90 }[w] ?? 0;
  if (!deg) return { boxes: t.wall.wall_side, m: null };
  const m = [rot([1,0,0], "xz", deg), rot([0,1,0], "xz", deg), rot([0,0,1], "xz", deg)];
  return { boxes: t.wall.wall_side, m };
}

// ---------------------------------------------------------- node types ---
// Derived flags, once per type list.
export function prepareTypes(types) {
  for (const t of types) {
    if (!t || t.prepared) continue;
    t.prepared = true;
    t.cube = t.dt === "normal";
    t.leaves = t.dt === "allfaces" || t.dt === "allfaces_optional";
    t.glass = t.dt.startsWith("glasslike");
    t.liquid = t.dt === "liquid";
    t.occl = t.cube || t.leaves;
    t.walk = !["plantlike", "torchlike", "signlike", "liquid"].includes(t.dt) &&
      !/^doors:/.test(t.name) && !/torch/.test(t.name);
    if (t.ct) t.ctSet = new Set(t.ct);
  }
  return types;
}

// ---------------------------------------------------------------- cells ---
// A cell set from typed arrays: the lookup every function below takes.
export function cellData(X, Y, Z, T, P2) {
  const n = X.length;
  let x0 = 1e9, y0 = 1e9, z0 = 1e9, x1 = -1e9, y1 = -1e9, z1 = -1e9;
  for (let i = 0; i < n; i++) {
    x0 = Math.min(x0, X[i]); y0 = Math.min(y0, Y[i]); z0 = Math.min(z0, Z[i]);
    x1 = Math.max(x1, X[i]); y1 = Math.max(y1, Y[i]); z1 = Math.max(z1, Z[i]);
  }
  if (!n) { x0 = y0 = z0 = 0; x1 = y1 = z1 = 0; }
  const sx = x1 - x0 + 1, sy = y1 - y0 + 1, sz = z1 - z0 + 1;
  const grid = new Int32Array(sx * sy * sz).fill(-1);
  for (let i = 0; i < n; i++) grid[((Y[i]-y0) * sz + (Z[i]-z0)) * sx + (X[i]-x0)] = i;
  const at = (x, y, z) => {
    if (x < x0 || x > x1 || y < y0 || y > y1 || z < z0 || z > z1) return -1;
    return grid[((y-y0) * sz + (z-z0)) * sx + (x-x0)];
  };
  return { n, X, Y, Z, T, P2, at, min: [x0, y0, z0], max: [x1, y1, z1] };
}

// The build's packing: base64 of (int16 x, y, z, uint16 type, uint8 param2).
export function decodeCells(b64, count) {
  const bin = atob(b64);
  const u8 = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
  const dv = new DataView(u8.buffer), n = count;
  const X = new Int16Array(n), Y = new Int16Array(n), Z = new Int16Array(n);
  const T = new Uint16Array(n), P2 = new Uint8Array(n);
  for (let i = 0; i < n; i++) {
    const o = i * 9;
    X[i] = dv.getInt16(o, true); Y[i] = dv.getInt16(o + 2, true); Z[i] = dv.getInt16(o + 4, true);
    T[i] = dv.getUint16(o + 6, true); P2[i] = dv.getUint8(o + 8);
  }
  return cellData(X, Y, Z, T, P2);
}

// --------------------------------------------------------------- view ----
// One renderer on one stage element. `opts`: stage (element), types,
// textures, meshes, onPick(hit, event) for a click that did not drag,
// onFrame(dt) after each camera update.
export function createNodeView(opts) {
  const TYPES = prepareTypes(opts.types);
  const TEXTURES = opts.textures, MESHES = opts.meshes || {};
  const stage = opts.stage;
  const filter = { cut: Infinity, veg: true };
  let data = null, group = null, mode = "orbit";

  // ---------------------------------------------------- textures ------
  const texCache = new Map();
  function texture(i) {
    if (texCache.has(i)) return texCache.get(i);
    const img = new Image();
    const t = new THREE.Texture(img);
    img.onload = () => { t.needsUpdate = true; };
    img.src = TEXTURES[i];
    t.magFilter = THREE.NearestFilter;
    t.minFilter = THREE.NearestMipmapLinearFilter;
    t.colorSpace = THREE.SRGBColorSpace;
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.anisotropy = 4;
    texCache.set(i, t);
    return t;
  }
  const matCache = new Map();
  function material(tex, mode) {
    const key = tex + "|" + mode;
    if (matCache.has(key)) return matCache.get(key);
    const o = { vertexColors: true, fog: true };
    if (tex >= 0) o.map = texture(tex); else o.color = 0xff00ff;
    if (mode === "clip" || mode === "clip2" || mode === "ovl") o.alphaTest = 0.5;
    if (mode === "blend") { o.transparent = true; o.depthWrite = false; o.opacity = 0.85; }
    if (mode === "clip2" || mode === "blend") o.side = THREE.DoubleSide;
    if (mode === "ovl") { o.polygonOffset = true; o.polygonOffsetFactor = -1; o.polygonOffsetUnits = -1; }
    const m = new THREE.MeshBasicMaterial(o);
    matCache.set(key, m);
    return m;
  }

  class Bucket {
    constructor(tex, mode) { this.tex = tex; this.mode = mode; this.pos = []; this.uv = []; this.col = []; this.idx = []; this.n = 0; }
    quad(pts, uvs, cols) {
      const n = this.n;
      for (let i = 0; i < 4; i++) {
        this.pos.push(pts[i][0], pts[i][1], pts[i][2]);
        this.uv.push(uvs[i][0], uvs[i][1]);
        const c = cols[i]; this.col.push(c, c, c);
      }
      // Split along the brighter diagonal so ambient occlusion stays smooth.
      if (cols[0] + cols[2] < cols[1] + cols[3]) this.idx.push(n+1, n+2, n+3, n+1, n+3, n);
      else this.idx.push(n, n+1, n+2, n, n+2, n+3);
      this.n += 4;
    }
    tri(pts, uvs, c) {
      const n = this.n;
      for (let i = 0; i < 3; i++) {
        this.pos.push(pts[i][0], pts[i][1], pts[i][2]);
        this.uv.push(uvs[i][0], uvs[i][1]);
        this.col.push(c, c, c);
      }
      this.idx.push(n, n+1, n+2);
      this.n += 3;
    }
    mesh() {
      const g = new THREE.BufferGeometry();
      g.setAttribute("position", new THREE.Float32BufferAttribute(this.pos, 3));
      g.setAttribute("uv", new THREE.Float32BufferAttribute(this.uv, 2));
      g.setAttribute("color", new THREE.Float32BufferAttribute(this.col, 3));
      g.setIndex(this.n > 65535 ? new THREE.Uint32BufferAttribute(this.idx, 1) : new THREE.Uint16BufferAttribute(this.idx, 1));
      g.computeBoundingSphere();
      const m = new THREE.Mesh(g, material(this.tex, this.mode));
      if (this.mode === "blend") m.renderOrder = 2;
      return m;
    }
  }

  // The type a cell is drawn as under the current filter, or null.
  function visibleType(i, d) {
    if (i < 0) return null;
    const t = TYPES[d.T[i]];
    if (!t) return null;
    if (!filter.veg && t.veg) return null;
    if (d.Y[i] > filter.cut) return null;
    return t;
  }

  // Node boxes and their rotation, for drawing and collision.
  function nodeBoxes(t, p2, d, x, y, z) {
    if (t.conn) return connectedBoxes(t, d, x, y, z);
    let boxes, m;
    if (t.wall) ({ boxes, m } = wallBoxes(t, p2));
    else { boxes = t.boxes || [[-.5,-.5,-.5,.5,.5,.5]]; m = rotationFor(t, p2); }
    return { boxes, m };
  }
  const SIDES = [
    ["top", [0,1,0], "bottom"], ["bottom", [0,-1,0], "top"],
    ["right", [1,0,0], "left"], ["left", [-1,0,0], "right"],
    ["back", [0,0,1], "front"], ["front", [0,0,-1], "back"],
  ];
  function connectedBoxes(t, d, x, y, z) {
    const out = [...(t.boxes || [])];
    let any = false, anySide = false;
    const conn = t.conn;
    for (const [side, o, opposite] of SIDES) {
      const j = d.at(x + o[0], y + o[1], z + o[2]);
      const nt = visibleType(j, d);
      let linked = false;
      if (nt && t.ctSet && t.ctSet.has(d.T[j])) {
        linked = !nt.connect_sides || nt.connect_sides.includes(opposite);
      }
      if (linked) {
        any = true; if (o[1] === 0) anySide = true;
        if (conn["connect_" + side]) out.push(...conn["connect_" + side]);
      } else if (conn["disconnected_" + side]) out.push(...conn["disconnected_" + side]);
    }
    if (!any && conn.disconnected) out.push(...conn.disconnected);
    if (!anySide && conn.disconnected_sides) out.push(...conn.disconnected_sides);
    return { boxes: out, m: null };
  }

  // ---------------------------------------------------- geometry ------
  function buildGroup(d) {
    const buckets = new Map();
    const bucket = (tex, mode) => {
      const k = tex + "|" + mode;
      let b = buckets.get(k);
      if (!b) { b = new Bucket(tex, mode); buckets.set(k, b); }
      return b;
    };
    const modeOf = t => t.alpha === "blend" ? "blend" : (t.alpha === "opaque" && t.cube ? "opaque" : "clip");
    const occl = (x, y, z) => { const t = visibleType(d.at(x, y, z), d); return t && t.occl ? 1 : 0; };
    const AO = [1.0, 0.8, 0.66, 0.54];

    for (let i = 0; i < d.n; i++) {
      const t = visibleType(i, d);
      if (!t) continue;
      const x = d.X[i], y = d.Y[i], z = d.Z[i], p2 = d.P2[i];

      if (t.cube || t.leaves || t.glass || t.liquid) {
        // A facedir cube (shelf, barrel) turns its tiles with param2.
        const m = rotationFor(t, p2);
        for (let f = 0; f < 6; f++) {
          const local = FACE_CORNERS[f](UNIT);
          if (FACE_REVERSE[f]) local.reverse();
          const uvs = local.map(FACE_UV[f]);
          const corners = local.map(p => apply(m, p));
          const wf = faceOf(apply(m, NORMALS[f]));
          const nrm = NORMALS[wf];
          const nt = visibleType(d.at(x + nrm[0], y + nrm[1], z + nrm[2]), d);
          if (nt) {
            if (nt.cube) continue;
            if ((t.glass || t.liquid || t.cube) && nt === t) continue;
          }
          const shade = FACE_SHADE[wf];
          // Per-vertex ambient occlusion from the three nodes around each
          // corner in the layer in front of the face.
          const cols = corners.map(c => {
            let a = 1;
            if (t.cube || t.leaves) {
              const s = [0, 0, 0], u = [0, 0, 0];
              const axes = [0, 1, 2].filter(k => nrm[k] === 0);
              s[axes[0]] = c[axes[0]] > 0 ? 1 : -1;
              u[axes[1]] = c[axes[1]] > 0 ? 1 : -1;
              const bx = x + nrm[0], by = y + nrm[1], bz = z + nrm[2];
              const s1 = occl(bx + s[0], by + s[1], bz + s[2]);
              const s2 = occl(bx + u[0], by + u[1], bz + u[2]);
              const cc = occl(bx + s[0] + u[0], by + s[1] + u[1], bz + s[2] + u[2]);
              a = AO[s1 && s2 ? 3 : s1 + s2 + cc];
            }
            return toLinear(shade * a);
          });
          const pts = corners.map(c => [c[0] + x, c[1] + y, c[2] + z]);
          bucket(t.tex[f], modeOf(t)).quad(pts, uvs, cols);
          if (t.ovl && t.ovl[f] >= 0) bucket(t.ovl[f], "ovl").quad(pts, uvs, cols);
        }
        continue;
      }

      if (t.dt === "nodebox") {
        const { boxes, m } = nodeBoxes(t, p2, d, x, y, z);
        // Connected boxes never rotate, but their tiles still follow facedir
        // (a horizontal branch keeps its bark grain along the branch).
        const tm = t.conn ? rotationFor(t, p2) : null;
        for (const b of boxes) {
          for (let g = 0; g < 6; g++) {
            const local = FACE_CORNERS[g](b);
            if (FACE_REVERSE[g]) local.reverse();
            const rotated = local.map(p => apply(m, p));
            const wf = faceOf(apply(m, NORMALS[g]));
            let f = g, texPts = local;
            if (tm) {
              texPts = rotated.map(p => applyInverse(tm, p));
              f = faceOf(applyInverse(tm, NORMALS[wf]));
            }
            const uvs = t.world[f] ? rotated.map(FACE_UV[wf]) : texPts.map(FACE_UV[f]);
            // Cull a face flush with the node boundary against a full cube.
            const axis = FACE_AXIS[wf], edge = (wf & 1) ? -0.5 : 0.5;
            if (rotated.every(p => Math.abs(p[axis] - edge) < 1e-4)) {
              const nt = visibleType(d.at(x + NORMALS[wf][0], y + NORMALS[wf][1], z + NORMALS[wf][2]), d);
              if (nt && nt.cube) continue;
            }
            const c = toLinear(FACE_SHADE[wf]);
            const pts = rotated.map(p => [p[0] + x, p[1] + y, p[2] + z]);
            bucket(t.tex[f], modeOf(t)).quad(pts, uvs, [c, c, c, c]);
          }
        }
        continue;
      }

      if (t.dt === "mesh") {
        const bufs = MESHES[t.mesh] || [];
        const m = rotationFor(t, p2);
        bufs.forEach((buf, bi) => {
          const b = bucket(t.tex[Math.min(bi, t.tex.length - 1)], "clip");
          for (let k = 0; k + 15 <= buf.length; k += 15) {
            const pts = [], uvs = [];
            for (let v = 0; v < 3; v++) {
              const o = k + v * 5;
              const p = apply(m, [buf[o], buf[o+1], buf[o+2]]);
              pts.push([p[0] + x, p[1] + y, p[2] + z]);
              uvs.push([buf[o+3], buf[o+4]]);
            }
            const nrm = cross(sub(pts[1], pts[0]), sub(pts[2], pts[0]));
            b.tri(pts, uvs, toLinear(shadeOf(nrm)));
          }
        });
        continue;
      }

      const one = toLinear(1), ones = [one, one, one, one];
      const place = q => q.map(p => [p[0] + x, p[1] + y, p[2] + z]);
      const QUAD_UV = [[0,1],[1,1],[1,0],[0,0]];

      if (t.dt === "plantlike") {
        // drawPlantlike: meshoptions bits 0-2 pick the style, bit 4 scales by 1.41.
        const style = t.p2 === "meshoptions" ? (p2 & 7) : 0;
        let s = 0.5 * t.vs;
        if (t.p2 === "meshoptions" && (p2 & 16)) s *= 1.41421;
        const h = 2 * s;
        const quads = PLANT_STYLES[style] || PLANT_STYLES[0];
        const b = bucket(t.tex[0], "clip2");
        for (const [deg, off, topOnly] of quads) {
          const q = [[-s, -.5 + h, 0], [s, -.5 + h, 0], [s, -.5, 0], [-s, -.5, 0]];
          q.forEach((p, k) => { if (!topOnly || k < 2) p[2] += off; });
          b.quad(place(q.map(p => rot(p, "xz", deg))), QUAD_UV, ones);
        }
        continue;
      }

      if (t.dt === "torchlike") {
        // drawTorchlikeNode: one quad; tile 0 floor, 1 ceiling, 2 wall.
        const w = t.p2 === "wallmounted" || t.p2 === "colorwallmounted" ? (p2 & 7) : 1;
        const tile = (w === 0 || w === 6) ? 1 : (w === 1 || w === 7) ? 0 : 2;
        const s = 0.5 * t.vs;
        const q = [[-s, s, 0], [s, s, 0], [s, -s, 0], [-s, -s, 0]].map(p => {
          switch (w) {
            case 0: case 6: p[1] += -s + .5; return rot(p, "xz", -45);
            case 2: p[0] += s - .5; return p;
            case 3: p[0] += -s + .5; return rot(p, "xz", 180);
            case 4: p[2] += s - .5; return rot(p, "xz", 90);
            case 5: p[2] += -s + .5; return rot(p, "xz", -90);
            default: p[1] += s - .5; return rot(p, "xz", 45);
          }
        });
        bucket(t.tex[Math.min(tile, t.tex.length - 1)], "clip2").quad(place(q), QUAD_UV, ones);
        continue;
      }

      if (t.dt === "signlike") {
        const w = p2 & 7, dir = NORMALS[[0, 1, 2, 3, 4, 5][w] ?? 1] || NORMALS[1];
        const f = faceOf(dir);
        const box = UNIT.slice();
        const k = FACE_AXIS[f]; box[k] = box[k + 3] = dir[k] * (0.5 - 1/16);
        const corners = FACE_CORNERS[f ^ 1](box);
        const uvs = corners.map(FACE_UV[f ^ 1]);
        bucket(t.tex[0], "clip2").quad(place(corners), uvs, ones);
      }
    }

    const out = new THREE.Group();
    for (const b of buckets.values()) if (b.n) out.add(b.mesh());
    return out;
  }

  // ------------------------------------------------------- scene ------
  const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  stage.appendChild(renderer.domElement);
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(SKY);
  scene.fog = new THREE.Fog(SKY, 140, 340);
  const camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.05, 1000);
  const root = new THREE.Group();
  root.scale.set(1, 1, -1);
  scene.add(root);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.12;
  controls.maxPolarAngle = Math.PI * 0.495;
  controls.screenSpacePanning = false;
  controls.minDistance = 2;
  controls.maxDistance = 600;

  const selection = new THREE.LineSegments(
    new THREE.EdgesGeometry(new THREE.BoxGeometry(1.04, 1.04, 1.04)),
    new THREE.LineBasicMaterial({ color: 0xffd23f, depthTest: false, transparent: true }));
  selection.renderOrder = 10;
  selection.visible = false;
  root.add(selection);

  // Luanti <-> three.js points.
  const toThree = p => new THREE.Vector3(p[0], p[1], -p[2]);
  const toLuanti = v => [v.x, v.y, -v.z];

  function rebuild() {
    if (group) {
      root.remove(group);
      group.traverse(o => { if (o.geometry) o.geometry.dispose(); });
      group = null;
    }
    if (data) { group = buildGroup(data); root.add(group); }
  }
  function setData(d) { data = d; selection.visible = false; rebuild(); }

  // ------------------------------------------------------ cameras -----
  // Walk mode: the player's body (feet, radius, height, step height) against
  // the node boxes. Noclip: free flight through everything, the camera where
  // the eye is.
  const walker = { x: 0, z: 0, feet: 1, vy: 0, yaw: 0, pitch: 0, keys: new Set(), grounded: false };
  const modeListeners = [];
  function setMode(m) {
    if (m === mode) return;
    const prev = mode;
    mode = m;
    if (m === "orbit") {
      const dir = new THREE.Vector3(); camera.getWorldDirection(dir);
      controls.target.copy(camera.position).addScaledVector(dir, 12);
      controls.enabled = true;
    } else {
      controls.enabled = false;
      const dir = new THREE.Vector3(); camera.getWorldDirection(dir);
      if (m === "noclip") {
        // Fly on from exactly where the camera is.
        const p = toLuanti(camera.position);
        walker.x = p[0]; walker.z = p[2]; walker.feet = p[1] - EYE;
        walker.yaw = Math.atan2(-dir.x, -dir.z);
        walker.pitch = Math.asin(Math.max(-1, Math.min(1, dir.y)));
      } else if (prev === "orbit") {
        const t = toLuanti(controls.target);
        walker.x = t[0]; walker.z = t[2];
        walker.yaw = Math.atan2(-dir.x, -dir.z);
        walker.pitch = 0;
        walker.feet = groundAt(walker.x, walker.z, 40) ?? 1;
      } else {
        // Noclip to walk: land on the ground below the eye.
        walker.feet = groundAt(walker.x, walker.z, walker.feet + 0.5) ?? walker.feet;
      }
      walker.vy = 0;
    }
    walker.keys.clear();
    touch.update();
    for (const f of modeListeners) f(m);
  }
  function lookAt(pos, target) {
    setMode("orbit");
    camera.position.copy(toThree(pos));
    controls.target.copy(toThree(target));
    controls.update();
  }
  function walkFrom(pos, yaw, m = "walk") {
    setMode(m);
    walker.x = pos[0]; walker.z = pos[2]; walker.yaw = yaw; walker.pitch = -0.05;
    walker.feet = m === "walk" ? (groundAt(pos[0], pos[2], pos[1] + 2) ?? pos[1]) : pos[1];
    walker.vy = 0;
    applyWalkerCamera();
  }
  // Camera position and a look-at point 10 nodes ahead, Luanti frame.
  function pose() {
    const pos = toLuanti(camera.position);
    if (mode === "orbit") return { pos, target: toLuanti(controls.target) };
    const dir = new THREE.Vector3(); camera.getWorldDirection(dir);
    return { pos, target: toLuanti(camera.position.clone().addScaledVector(dir, 10)) };
  }

  // ------------------------------------------------ walking physics ---
  function cellBoxes(i, d) {
    const t = visibleType(i, d);
    if (!t || !t.walk) return null;
    if (t.cube || t.leaves || t.glass) return [[-.5,-.5,-.5,.5,.5,.5]];
    if (t.dt === "nodebox") {
      const { boxes, m } = nodeBoxes(t, d.P2[i], d, d.X[i], d.Y[i], d.Z[i]);
      return boxes.map(b => {
        const a = apply(m, [b[0], b[1], b[2]]), c = apply(m, [b[3], b[4], b[5]]);
        return [Math.min(a[0], c[0]), Math.min(a[1], c[1]), Math.min(a[2], c[2]),
                Math.max(a[0], c[0]), Math.max(a[1], c[1]), Math.max(a[2], c[2])];
      });
    }
    return [[-.5,-.5,-.5,.5,.5,.5]];
  }
  // Highest walkable surface under (x, z) at or below `limit`, or null.
  function groundAt(px, pz, limit) {
    const d = data;
    if (!d) return null;
    let best = null;
    for (const [ox, oz] of [[-RADIUS, -RADIUS], [RADIUS, -RADIUS], [RADIUS, RADIUS], [-RADIUS, RADIUS]]) {
      const qx = px + ox, qz = pz + oz;
      const cx = Math.round(qx), cz = Math.round(qz);
      for (let y = Math.min(Math.floor(limit + 0.5), d.max[1]); y >= d.min[1]; y--) {
        const i = d.at(cx, y, cz);
        const boxes = i >= 0 ? cellBoxes(i, d) : null;
        if (!boxes) continue;
        let top = null;
        for (const b of boxes) {
          if (qx - cx < b[0] || qx - cx > b[3] || qz - cz < b[2] || qz - cz > b[5]) continue;
          const ty = y + b[4];
          if (ty <= limit + 1e-3 && (top === null || ty > top)) top = ty;
        }
        if (top !== null) { if (best === null || top > best) best = top; break; }
      }
    }
    return best;
  }
  // Does a body standing with its feet at `feet` overlap any walkable box?
  function blocked(px, pz, feet) {
    const d = data;
    if (!d) return false;
    const lo = feet + 0.01, hi = feet + HEIGHT;
    for (let cx = Math.round(px - RADIUS); cx <= Math.round(px + RADIUS); cx++)
      for (let cz = Math.round(pz - RADIUS); cz <= Math.round(pz + RADIUS); cz++)
        for (let y = Math.round(lo); y <= Math.round(hi); y++) {
          const i = d.at(cx, y, cz);
          const boxes = i >= 0 ? cellBoxes(i, d) : null;
          if (!boxes) continue;
          for (const b of boxes) {
            if (px + RADIUS <= cx + b[0] || px - RADIUS >= cx + b[3]) continue;
            if (pz + RADIUS <= cz + b[2] || pz - RADIUS >= cz + b[5]) continue;
            if (hi <= y + b[1] || lo >= y + b[4]) continue;
            return true;
          }
        }
    return false;
  }
  function stepWalker(dt) {
    const k = walker.keys;
    let fx = 0, fz = 0;
    if (k.has("KeyW") || k.has("ArrowUp")) fz += 1;
    if (k.has("KeyS") || k.has("ArrowDown")) fz -= 1;
    if (k.has("KeyA") || k.has("ArrowLeft")) fx -= 1;
    if (k.has("KeyD") || k.has("ArrowRight")) fx += 1;
    const len = Math.hypot(fx, fz) || 1;
    // Luanti frame: yaw 0 looks north (+z); positive yaw turns west.
    const sy = Math.sin(walker.yaw), cy = Math.cos(walker.yaw);
    const fwd = [-sy, cy], right = [cy, sy];
    if (mode === "noclip") {
      // The game's fly keys: Space up, Shift down, E faster (aux1).
      const v = (k.has("KeyE") ? 18 : 6) * dt;
      const speed = v / len;
      const cp = Math.cos(walker.pitch), sp = Math.sin(walker.pitch);
      walker.x += (fwd[0] * fz * cp + right[0] * fx) * speed;
      walker.z += (fwd[1] * fz * cp + right[1] * fx) * speed;
      walker.feet += fz * sp * speed;
      if (k.has("Space")) walker.feet += v;
      if (k.has("ShiftLeft") || k.has("ShiftRight") || k.has("KeyC")) walker.feet -= v;
      return;
    }
    const fast = k.has("ShiftLeft") || k.has("ShiftRight");
    const speed = (fast ? 5.6 : 4.0) * dt / len;
    const dx = (fwd[0] * fz + right[0] * fx) * speed, dz = (fwd[1] * fz + right[1] * fx) * speed;
    const tryMove = (nx, nz) => {
      if (!blocked(nx, nz, walker.feet)) { walker.x = nx; walker.z = nz; return; }
      // Step up onto a slab, stair or (while jumping) a full block.
      const g = groundAt(nx, nz, walker.feet + STEP);
      if (g !== null && g > walker.feet && !blocked(nx, nz, g)) { walker.x = nx; walker.z = nz; walker.feet = g; }
    };
    if (dx) tryMove(walker.x + dx, walker.z);
    if (dz) tryMove(walker.x, walker.z + dz);
    const ground = groundAt(walker.x, walker.z, walker.feet + 0.05);
    const floor = ground ?? view.groundLevel ?? (data ? data.min[1] - 0.5 : 0);
    if (k.has("Space") && walker.grounded) { walker.vy = 6.5; walker.grounded = false; }
    walker.vy -= 22 * dt;
    walker.feet += walker.vy * dt;
    if (walker.vy > 0 && blocked(walker.x, walker.z, walker.feet)) { walker.feet -= walker.vy * dt; walker.vy = 0; }
    if (walker.feet <= floor) { walker.feet = floor; walker.vy = 0; walker.grounded = true; }
    else walker.grounded = walker.feet - floor < 0.02;
  }
  function applyWalkerCamera() {
    camera.position.copy(toThree([walker.x, walker.feet + EYE, walker.z]));
    camera.rotation.order = "YXZ";
    // three.js yaw: looking down -z (Luanti north) at 0.
    camera.rotation.set(walker.pitch, walker.yaw, 0);
  }

  // ------------------------------------------------------- picking ----
  // The first drawn cell along the ray under a screen point (or a cell the
  // page's `extraHit(x, y, z)` claims), as {i, x, y, z}, or null.
  function pick(clientX, clientY, extraHit) {
    if (!data) return null;
    const r = renderer.domElement.getBoundingClientRect();
    const ndc = new THREE.Vector2((clientX - r.left) / r.width * 2 - 1, -((clientY - r.top) / r.height) * 2 + 1);
    const ray = new THREE.Raycaster();
    camera.updateMatrixWorld();
    ray.setFromCamera(ndc, camera);
    const o = toLuanti(ray.ray.origin), dir = toLuanti(ray.ray.direction);
    const d = data;
    // Amanatides-Woo walk over the node grid (cells are [i-0.5, i+0.5]).
    let c = o.map(v => Math.round(v));
    const step = dir.map(v => v > 0 ? 1 : -1);
    const tMax = [0, 1, 2].map(k => dir[k] === 0 ? Infinity : ((c[k] + step[k] * 0.5) - o[k]) / dir[k]);
    const tDelta = dir.map(v => v === 0 ? Infinity : Math.abs(1 / v));
    for (let n = 0; n < 1500; n++) {
      const i = d.at(c[0], c[1], c[2]);
      if (visibleType(i, d)) return { i, x: c[0], y: c[1], z: c[2] };
      if (extraHit && c[1] <= filter.cut && extraHit(c[0], c[1], c[2]))
        return { i: -1, x: c[0], y: c[1], z: c[2] };
      const k = tMax[0] < tMax[1] ? (tMax[0] < tMax[2] ? 0 : 2) : (tMax[1] < tMax[2] ? 1 : 2);
      c[k] += step[k]; tMax[k] += tDelta[k];
      if (tMax[k] > 900) break;
    }
    return null;
  }
  function select(hit) {
    if (!hit) { selection.visible = false; return; }
    selection.position.set(hit.x, hit.y, hit.z);
    selection.visible = true;
  }

  // -------------------------------------------------------- input -----
  const MOVE_KEYS = ["KeyW", "KeyA", "KeyS", "KeyD", "KeyC", "KeyE", "Space", "ArrowUp", "ArrowDown",
    "ArrowLeft", "ArrowRight", "ShiftLeft", "ShiftRight"];
  const isTyping = () => ["INPUT", "SELECT", "TEXTAREA"].includes(document.activeElement?.tagName) &&
    document.activeElement.type !== "checkbox" && document.activeElement.type !== "range";
  window.addEventListener("keydown", e => {
    if (isTyping()) return;
    if (mode !== "orbit" && MOVE_KEYS.includes(e.code)) { walker.keys.add(e.code); e.preventDefault(); }
  });
  window.addEventListener("keyup", e => walker.keys.delete(e.code));
  window.addEventListener("blur", () => walker.keys.clear());

  // Click (not drag) picks a block; dragging looks around in walk and noclip
  // mode. Pointers are tracked by id, so a finger on a touch button does not
  // turn the camera while another one drags.
  const downs = new Map();
  renderer.domElement.addEventListener("pointerdown", e => {
    downs.set(e.pointerId, { x: e.clientX, y: e.clientY, lx: e.clientX, ly: e.clientY, moved: false });
    renderer.domElement.focus?.();
  });
  window.addEventListener("pointermove", e => {
    const down = downs.get(e.pointerId);
    if (!down) return;
    if (Math.hypot(e.clientX - down.x, e.clientY - down.y) > 5) down.moved = true;
    if (mode !== "orbit") {
      const gain = e.pointerType === "touch" ? 0.008 : 0.005;
      walker.yaw -= (e.clientX - down.lx) * gain;
      walker.pitch = Math.max(-1.5, Math.min(1.5, walker.pitch - (e.clientY - down.ly) * gain));
    }
    down.lx = e.clientX; down.ly = e.clientY;
  });
  const endPointer = e => {
    const down = downs.get(e.pointerId);
    downs.delete(e.pointerId);
    if (e.type === "pointerup" && down && !down.moved && e.target === renderer.domElement && opts.onPick)
      opts.onPick(e);
  };
  window.addEventListener("pointerup", endPointer);
  window.addEventListener("pointercancel", endPointer);

  // The touch fallback: a move pad and up/down (noclip) or jump (walk)
  // buttons, shown in walk and noclip mode on a touch screen. Each button
  // holds its key while pressed.
  const touch = (() => {
    if (!document.getElementById("touchpad-css")) {
      const style = document.createElement("style");
      style.id = "touchpad-css";
      style.textContent = TOUCH_CSS;
      document.head.appendChild(style);
    }
    const pad = document.createElement("div");
    pad.className = "touchpad";
    pad.hidden = true;
    pad.innerHTML =
      '<div class="tp-move"><button data-k="KeyW" aria-label="Forward">▲</button>' +
      '<button data-k="KeyA" aria-label="Left">◀</button>' +
      '<button data-k="KeyD" aria-label="Right">▶</button>' +
      '<button data-k="KeyS" aria-label="Back">▼</button></div>' +
      '<div class="tp-lift"><button data-k="Space" class="tp-up" aria-label="Up">Up</button>' +
      '<button data-k="ShiftLeft" class="tp-down" aria-label="Down">Down</button>' +
      '<button data-k="KeyE" class="tp-fast" aria-label="Faster">Fast</button></div>';
    document.body.appendChild(pad);
    let coarse = window.matchMedia?.("(pointer: coarse)").matches || false;
    window.addEventListener("touchstart", () => { if (!coarse) { coarse = true; update(); } }, { passive: true });
    for (const b of pad.querySelectorAll("button")) {
      const k = b.dataset.k;
      b.addEventListener("pointerdown", e => { e.preventDefault(); b.setPointerCapture?.(e.pointerId); walker.keys.add(k); b.classList.add("on"); });
      const up = () => { walker.keys.delete(k); b.classList.remove("on"); };
      b.addEventListener("pointerup", up);
      b.addEventListener("pointercancel", up);
      b.addEventListener("lostpointercapture", up);
      b.addEventListener("contextmenu", e => e.preventDefault());
    }
    function update() {
      pad.hidden = !(coarse && mode !== "orbit");
      pad.querySelector(".tp-up").textContent = mode === "walk" ? "Jump" : "Up";
      pad.querySelector(".tp-down").hidden = mode === "walk";
      pad.querySelector(".tp-fast").hidden = mode === "walk";
    }
    return { update, el: pad };
  })();

  window.addEventListener("resize", () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
  });

  let last = performance.now(), running = false;
  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    if (mode === "orbit") controls.update();
    else { stepWalker(dt); applyWalkerCamera(); }
    if (opts.onFrame) opts.onFrame(dt);
    renderer.render(scene, camera);
    requestAnimationFrame(frame);
  }
  function start() {
    if (running) return;
    running = true;
    last = performance.now();
    requestAnimationFrame(frame);
  }
  // One synchronous step and render (headless screenshots, hooks).
  function step(dt = 0.016) {
    if (mode === "orbit") controls.update();
    else { stepWalker(dt); applyWalkerCamera(); }
    if (opts.onFrame) opts.onFrame(dt);
    renderer.render(scene, camera);
  }

  const view = {
    // Where walking stops when no cell is below (null: half a node under
    // the lowest cell); a page that shows a building alone sets its ground.
    groundLevel: null,
    THREE, renderer, scene, camera, controls, root, filter, walker,
    get data() { return data; }, get mode() { return mode; },
    setData, rebuild, setMode, lookAt, walkFrom, pose, pick, select, start, step,
    groundAt, toThree, toLuanti, types: TYPES,
    onMode(f) { modeListeners.push(f); },
  };
  return view;
}

// The touch pad's look, added to the page once by createNodeView.
const TOUCH_CSS = `
.touchpad { position: fixed; inset: auto 0 calc(16px + env(safe-area-inset-bottom, 0px)) 0;
  display: flex; justify-content: space-between; align-items: flex-end; padding: 0 16px;
  pointer-events: none; z-index: 3; }
.touchpad button { pointer-events: auto; width: 56px; height: 56px; border-radius: 12px;
  border: 1px solid rgba(255,255,255,.5); background: rgba(22,28,34,.45); color: #fff;
  font: 600 15px/1 system-ui, sans-serif; touch-action: none; user-select: none; -webkit-user-select: none; }
.touchpad button.on { background: rgba(46,107,82,.8); }
.tp-move { display: grid; grid-template-columns: repeat(3, 56px); grid-template-rows: repeat(2, 56px);
  gap: 6px; grid-template-areas: ". w ." "a s d"; }
.tp-move [data-k=KeyW] { grid-area: w; } .tp-move [data-k=KeyA] { grid-area: a; }
.tp-move [data-k=KeyS] { grid-area: s; } .tp-move [data-k=KeyD] { grid-area: d; }
.tp-lift { display: flex; flex-direction: column; gap: 6px; }
.touchpad[hidden], .touchpad [hidden] { display: none; }
`;
