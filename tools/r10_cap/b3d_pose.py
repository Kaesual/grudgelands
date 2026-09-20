#!/usr/bin/env python3
"""Bounded B3D pose evaluator for authored display clearance and native renders.

Mirrors pinned irr/src/CB3DMeshFileLoader.cpp:133-195, 377-386, 515-614:
node-global bind positions, BONE weights, and B3D key frame minus one.
Transform rotation uses irr/include/Transform.h:27 and quaternion.h:441
(transposed quaternion matrix). Skinning uses SkinnedMesh.cpp:156-194.
This is offline geometry evidence, not a substitute for the engine visual gate.
"""
import json
import struct
from pathlib import Path
import numpy as np


def trs(position, scale, quaternion):
    w, x, y, z = np.array(quaternion) / np.linalg.norm(quaternion)
    rotation = np.array([
        [1-2*y*y-2*z*z, 2*x*y+2*z*w, 2*x*z-2*y*w],
        [2*x*y-2*z*w, 1-2*x*x-2*z*z, 2*z*y+2*x*w],
        [2*x*z+2*y*w, 2*z*y-2*x*w, 1-2*x*x-2*y*y]])
    matrix = np.eye(4)
    matrix[:3, :3] = rotation @ np.diag(scale)
    matrix[:3, 3] = position
    return matrix


def sample(keys, frame, default, quaternion=False):
    if not keys:
        return default
    keys = sorted(keys)
    if frame <= keys[0][0]:
        return keys[0][1]
    for (first, a), (last, b) in zip(keys, keys[1:]):
        if frame <= last:
            t = (frame-first)/(last-first)
            a, b = np.array(a), np.array(b)
            if quaternion:
                dot = np.dot(a, b)
                if dot < 0:
                    a, dot = -a, -dot
                if dot < 0.95:
                    angle = np.arccos(np.clip(dot, -1, 1))
                    return (a*np.sin((1-t)*angle)+b*np.sin(t*angle))/np.sin(angle)
            return (1-t)*a+t*b
    return keys[-1][1]


def evaluate(path, frame=1):
    data = Path(path).read_bytes()
    nodes, meshes = [], []
    textures, brushes = [], []
    current_mesh = None
    counts = {'ANIM': 0, 'BONE': 0, 'KEYS': 0}

    def unpack(fmt, offset):
        return struct.unpack_from('<'+fmt, data, offset)

    def chunks(start, end, parent=None):
        nonlocal current_mesh
        while start < end:
            kind = data[start:start+4].decode('ascii')
            length, = unpack('i', start+4)
            offset, stop = start+8, start+8+length
            assert stop <= end
            if kind in counts:
                counts[kind] += 1
            if kind == 'BB3D':
                chunks(offset+4, stop)
            elif kind == 'TEXS':
                at=offset
                while at<stop:
                    end_name=data.index(b'\0',at)
                    values=unpack('2i5f',end_name+1)
                    textures.append(values[-2:]);at=end_name+29
            elif kind == 'BRUS':
                count,=unpack('i',offset);at=offset+4
                while at<stop:
                    end_name=data.index(b'\0',at)
                    ids=unpack(str(count)+'i',end_name+29)
                    brushes.append(ids);at=end_name+29+4*count
            elif kind == 'NODE':
                terminator = data.index(b'\0', offset)
                values = unpack('10f', terminator+1)
                node = {'name': data[offset:terminator].decode(), 'parent': parent,
                        'p': values[:3], 's': values[3:6], 'q': values[6:],
                        'keys': {1: [], 2: [], 4: []}, 'weights': []}
                node['bind'] = (parent['bind'] if parent else np.eye(4)) @ trs(node['p'], node['s'], node['q'])
                nodes.append(node)
                chunks(terminator+41, stop, node)
            elif kind == 'MESH':
                current_mesh = {'node': parent, 'groups': [], 'weights': {},
                                'brush': unpack('i',offset)[0]}
                meshes.append(current_mesh)
                chunks(offset+4, stop, parent)
            elif kind == 'VRTS':
                flags, sets, size = unpack('3i', offset)
                width = 3 + (3 if flags & 1 else 0) + (4 if flags & 2 else 0) + sets*size
                values = np.frombuffer(data[offset+12:stop], dtype='<f4').reshape((-1, width))
                positions = np.column_stack((values[:, :3], np.ones(len(values))))
                current_mesh['bind'] = (parent['bind'] @ positions.T).T
                uv_start = 3 + (3 if flags & 1 else 0) + (4 if flags & 2 else 0)
                current_mesh['uv'] = values[:, uv_start:uv_start+2].tolist()
            elif kind == 'TRIS':
                brush, = unpack('i', offset)
                triangles = np.frombuffer(data[offset+4:stop], dtype='<i4').reshape((-1, 3))
                if brush<0:brush=current_mesh['brush']
                tex=brushes[brush][0] if brush>=0 and brushes[brush] else -1
                uv_scale=textures[tex] if tex>=0 else (1,1)
                current_mesh['groups'].append({'brush': brush, 'uv_scale': uv_scale,
                                               'triangles': triangles.tolist()})
            elif kind == 'BONE':
                for at in range(offset, stop, 8):
                    vertex, weight = unpack('if', at)
                    if weight > 0:
                        current_mesh['weights'].setdefault(vertex, []).append((parent, weight))
            elif kind == 'KEYS':
                flags, = unpack('i', offset)
                at = offset+4
                while at < stop:
                    number, = unpack('i', at)
                    at += 4
                    for flag, width in ((1, 3), (2, 3), (4, 4)):
                        if flags & flag:
                            values = unpack(str(width)+'f', at)
                            at += width*4
                            parent['keys'][flag].append((max(1, number)-1, values))
            start = stop
        assert start == end

    chunks(0, len(data))
    for node in nodes:
        p = sample(node['keys'][1], frame, node['p'])
        s = sample(node['keys'][2], frame, node['s'])
        q = sample(node['keys'][4], frame, node['q'], True)
        node['pose'] = (node['parent']['pose'] if node['parent'] else np.eye(4)) @ trs(p, s, q)
        node['skin'] = node['pose'] @ np.linalg.inv(node['bind'])
    result = []
    for mesh in meshes:
        points = mesh['bind'].copy()
        for vertex, weights in mesh['weights'].items():
            total = sum(weight for _, weight in weights)
            points[vertex] = sum((node['skin'] @ mesh['bind'][vertex])*weight/total for node, weight in weights)
        result.append({'node': mesh['node']['name'], 'vertices': points[:, :3].tolist(), 'uv': mesh['uv'], 'groups': mesh['groups']})
    return {'frame': frame, 'chunks': counts, 'meshes': result}


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('model')
    parser.add_argument('--frame', type=float, default=1)
    parser.add_argument('--output')
    args = parser.parse_args()
    result = evaluate(args.model, args.frame)
    if args.output:
        Path(args.output).write_text(json.dumps(result))
    points = np.array([point for mesh in result['meshes'] for point in mesh['vertices']])
    print(json.dumps({'model': args.model, 'frame': args.frame, 'chunks': result['chunks'],
                      'min': points.min(axis=0).tolist(), 'max': points.max(axis=0).tolist()}))
