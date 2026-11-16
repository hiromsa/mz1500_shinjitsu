#!/usr/bin/env python3
# SHINJITSU NO TOU - floor maps: 5 floors x 16x16
# Corridor-maze generator (recursive backtracker + a few loops).
# '#' wall '.' floor 'S' start 'U' stairs 'C' chest 'P' spirit 'B' boss 'D' door
# Design (user feedback 2026-11-15): the dungeon should be a maze of narrow
# corridors, not open halls - especially the start must be a corridor so the
# 3D view shows walls on both sides and the way ahead is readable.
import random
from collections import deque

W = H = 16
CODE = {'#': 1, '.': 0, 'S': 2, 'U': 3, 'C': 4, 'P': 5, 'B': 6, 'D': 7}


def gen_maze(rng):
    g = [['#'] * W for _ in range(H)]
    # lattice nodes: odd coords 1..13 plus the 14 edge row/column, so the
    # maze fills the whole 1..14 interior (nodes 13 and 14 are adjacent,
    # their connecting passage needs no wall cell carved)
    coords = [1, 3, 5, 7, 9, 11, 13, 14]
    cells = {(x, y) for y in coords for x in coords}
    start = (1, 1)
    g[start[1]][start[0]] = '.'
    stack = [start]
    seen = {start}
    while stack:
        x, y = stack[-1]
        nbs = []
        for ax, ay in cells:
            if (ax, ay) in seen:
                continue
            if ay == y and abs(ax - x) in (1, 2):
                nbs.append((ax, ay))
            elif ax == x and abs(ay - y) in (1, 2):
                nbs.append((ax, ay))
        if not nbs:
            stack.pop()
            continue
        nx, ny = rng.choice(nbs)
        if abs(nx - x) == 2:
            g[y][(x + nx) // 2] = '.'
        if abs(ny - y) == 2:
            g[(y + ny) // 2][x] = '.'
        g[ny][nx] = '.'
        seen.add((nx, ny))
        stack.append((nx, ny))
    # knock a few loops: open interior walls flanked by open cells
    opened = 0
    tries = 0
    while opened < 5 and tries < 200:
        tries += 1
        x = rng.randrange(1, 15)
        y = rng.randrange(1, 15)
        if g[y][x] != '#':
            continue
        horiz = g[y][x - 1] != '#' and g[y][x + 1] != '#'
        vert = g[y - 1][x] != '#' and g[y + 1][x] != '#'
        if horiz != vert:
            g[y][x] = '.'
            opened += 1
    return g


def open_nbs(g, x, y):
    return [(x + dx, y + dy) for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0))
            if g[y + dy][x + dx] != '#']


def bfs(g, sx, sy):
    dist = {(sx, sy): 0}
    parent = {}
    q = deque([(sx, sy)])
    while q:
        x, y = q.popleft()
        for nx, ny in open_nbs(g, x, y):
            if (nx, ny) not in dist:
                dist[(nx, ny)] = dist[(x, y)] + 1
                parent[(nx, ny)] = (x, y)
                q.append((nx, ny))
    return dist, parent


def build_floor(fi, rng, want):
    g = gen_maze(rng)
    opens = [(x, y) for y in range(H) for x in range(W) if g[y][x] == '.']
    # start: a corridor cell with a straight run north (2+ open cells) and
    # at least one wall beside the first step, so the first 3D view reads
    # as a corridor - prefer longer runs, then southern/central cells
    def north_run(c):
        x, y = c
        n = 0
        while y - n - 1 >= 0 and g[y - n - 1][x] != '#':
            n += 1
        return n

    def corridor_score(c):
        x, y = c
        run = north_run(c)
        if run < 2:
            return None
        side_wall = (g[y - 1][x - 1] == '#') + (g[y - 1][x + 1] == '#')
        if side_wall < 1:
            return None
        # southern first, then central, then longer run
        return (y, -abs(x - 7), run, side_wall)

    scored = [(corridor_score(c), c) for c in opens]
    scored = [(s, c) for s, c in scored if s is not None]
    scored.sort(reverse=True)
    sx, sy = scored[0][1]
    dist, parent = bfs(g, sx, sy)
    assert len(dist) == len(opens), f"floor {fi+1}: unreachable cells"
    dead = [c for c in opens if c != (sx, sy) and len(open_nbs(g, *c)) == 1]
    dead.sort(key=lambda c: -dist[c])
    far = sorted(opens, key=lambda c: -dist[c])
    used = {(sx, sy)}

    def take(pool):
        for c in pool:
            if c not in used:
                used.add(c)
                return c
        raise AssertionError("no cell left")

    marks = {}
    if want.get('boss'):
        marks[take(dead or far)] = 'B'
    for _ in range(want.get('chest', 0)):
        marks[take(dead + far)] = 'C'
    if want.get('spirit'):
        marks[take(dead + far)] = 'P'
    if want.get('stairs'):
        marks[take(far)] = 'U'
    g[sy][sx] = 'S'
    for (x, y), ch in marks.items():
        g[y][x] = ch
    if want.get('door'):
        # door on the S->stairs path, about halfway, plain corridor cell
        target = next((c for c, ch in marks.items() if ch == 'U'), None)
        if target is None:
            target = max(marks, key=lambda c: dist[c])
        path = []
        c = target
        while c != (sx, sy):
            path.append(c)
            c = parent[c]
        path.reverse()
        for c in path[len(path) // 2:]:
            if g[c[1]][c[0]] == '.':
                g[c[1]][c[0]] = 'D'
                break
    return [''.join(r) for r in g], (sx, sy), marks


WANTS = [
    {'stairs': 1, 'chest': 2, 'door': 1},
    {'stairs': 1, 'chest': 2, 'spirit': 1},
    {'stairs': 1, 'chest': 2, 'spirit': 1},
    {'stairs': 1, 'chest': 2, 'spirit': 1},
    {'chest': 2, 'boss': 1, 'door': 1},
]

out = ["; generated by gen_maps.py - do not edit", "maps_data:"]
for fi in range(5):
    rng = random.Random(1500 + fi * 77)
    rows, spos, marks = build_floor(fi, rng, WANTS[fi])
    print(f"--- floor {fi+1}: S={spos} " +
          " ".join(f"{ch}={c}" for c, ch in sorted(marks.items())))
    for r in rows:
        print(r)
    out.append(f"; floor {fi+1}")
    for row in rows:
        out.append("    DB " + ",".join(str(CODE[c]) for c in row))
with open("maps.inc", "w") as fh:
    fh.write("\n".join(out) + "\n")
print("maps.inc written", 5 * 256, "cells")
