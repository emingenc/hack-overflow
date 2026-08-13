#!/usr/bin/env python3
"""Generate proper HACK://OVERFLOW level maps (wide, multi-height, playable)."""
import os

W = 130  # map width in tiles
G = 13   # ground row

def blank():
    return [['.'] * W for _ in range(G + 2)]

def put(m, x, y, ch):
    if 0 <= x < W and 0 <= y < len(m):
        m[y][x] = ch

def ground(m):
    for x in range(W):
        m[G][x] = '#'
        m[G + 1][x] = '#'

def platform(m, x0, x1, y):
    for x in range(x0, x1 + 1):
        put(m, x, y, '=')

def spikes(m, x0, x1, y):
    for x in range(x0, x1 + 1):
        put(m, x, y, '^')

def chips(m, positions):
    for (x, y) in positions:
        put(m, x, y, 'C')

def drones(m, positions):
    for (x, y) in positions:
        put(m, x, y, 'D')

def turrets(m, positions):
    for (x, y) in positions:
        put(m, x, y, 'T')

def render(m):
    return "\n".join("".join(row) for row in m)

# ── LEVEL 1: THE TERMINAL (tutorial, easy) ──────────────────────────
m = blank(); ground(m)
# starter platform
platform(m, 8, 14, G - 3)
platform(m, 18, 24, G - 6)
platform(m, 20, 26, G - 9)
platform(m, 30, 36, G - 3)
platform(m, 40, 44, G - 6)
platform(m, 46, 52, G - 3)
platform(m, 56, 62, G - 6)
platform(m, 58, 64, G - 9)
platform(m, 68, 74, G - 3)
platform(m, 78, 82, G - 6)
platform(m, 86, 92, G - 3)
platform(m, 96, 102, G - 6)
platform(m, 100, 106, G - 9)
platform(m, 110, 118, G - 3)
# hazards (spikes on the ground between platforms)
spikes(m, 26, 28, G - 1)
spikes(m, 44, 45, G - 1)
spikes(m, 64, 66, G - 1)
spikes(m, 84, 85, G - 1)
spikes(m, 104, 105, G - 1)
# collectibles
chips(m, [(10, G - 4), (21, G - 7), (23, G - 10), (33, G - 4), (42, G - 7),
          (49, G - 4), (60, G - 7), (61, G - 10), (71, G - 4), (80, G - 7),
          (89, G - 4), (99, G - 7), (103, G - 10), (114, G - 4), (116, G - 4)])
# enemies
drones(m, [(12, G - 1), (34, G - 1), (50, G - 1), (70, G - 1), (90, G - 1), (112, G - 1)])
turrets(m, [(22, G - 4), (60, G - 4), (100, G - 4)])
# player, firewall, exit
put(m, 2, G - 1, 'P')
put(m, W - 8, G - 1, 'F')
put(m, W - 4, G - 1, 'E')
map1 = render(m)

# ── LEVEL 2: SERVER FARM (medium) ───────────────────────────────────
m = blank(); ground(m)
platform(m, 8, 14, G - 4)
platform(m, 12, 18, G - 8)
platform(m, 20, 26, G - 4)
platform(m, 24, 30, G - 8)
platform(m, 32, 38, G - 4)
platform(m, 36, 42, G - 8)
platform(m, 44, 50, G - 4)
platform(m, 48, 54, G - 8)
platform(m, 56, 62, G - 4)
platform(m, 60, 66, G - 8)
platform(m, 68, 74, G - 4)
platform(m, 72, 78, G - 8)
platform(m, 80, 86, G - 4)
platform(m, 84, 90, G - 8)
platform(m, 92, 98, G - 4)
platform(m, 96, 102, G - 8)
platform(m, 104, 110, G - 4)
platform(m, 108, 114, G - 8)
platform(m, 116, 122, G - 4)
# spike fields
spikes(m, 16, 18, G - 1)
spikes(m, 40, 42, G - 1)
spikes(m, 64, 66, G - 1)
spikes(m, 88, 90, G - 1)
spikes(m, 112, 114, G - 1)
# chips on high platforms
chips(m, [(15, G - 5), (26, G - 5), (38, G - 5), (50, G - 5), (62, G - 5),
          (74, G - 5), (86, G - 5), (98, G - 5), (110, G - 5), (119, G - 5)])
# drones + turrets
drones(m, [(10, G - 1), (34, G - 1), (58, G - 1), (82, G - 1), (106, G - 1)])
turrets(m, [(22, G - 3), (46, G - 3), (70, G - 3), (94, G - 3), (118, G - 3)])
put(m, 2, G - 1, 'P')
put(m, W - 8, G - 1, 'F')
put(m, W - 4, G - 1, 'E')
map2 = render(m)

# ── LEVEL 3: THE CORE (hard) ────────────────────────────────────────
m = blank(); ground(m)
platform(m, 6, 12, G - 5)
platform(m, 10, 16, G - 9)
platform(m, 18, 24, G - 5)
platform(m, 22, 28, G - 9)
platform(m, 30, 36, G - 5)
platform(m, 34, 40, G - 9)
platform(m, 42, 48, G - 5)
platform(m, 46, 52, G - 9)
platform(m, 54, 60, G - 5)
platform(m, 58, 64, G - 9)
platform(m, 66, 72, G - 5)
platform(m, 70, 76, G - 9)
platform(m, 78, 84, G - 5)
platform(m, 82, 88, G - 9)
platform(m, 90, 96, G - 5)
platform(m, 94, 100, G - 9)
platform(m, 102, 108, G - 5)
platform(m, 106, 112, G - 9)
platform(m, 114, 120, G - 5)
platform(m, 118, 124, G - 9)
# spikes everywhere
spikes(m, 14, 16, G - 1)
spikes(m, 38, 40, G - 1)
spikes(m, 62, 64, G - 1)
spikes(m, 86, 88, G - 1)
spikes(m, 110, 112, G - 1)
spikes(m, 8, 9, G - 1)
spikes(m, 30, 31, G - 1)
# chips demanding risky routes
chips(m, [(13, G - 6), (24, G - 6), (36, G - 6), (48, G - 6), (60, G - 6),
          (72, G - 6), (84, G - 6), (96, G - 6), (108, G - 6), (121, G - 6),
          (20, G - 10), (44, G - 10), (68, G - 10), (92, G - 10), (116, G - 10)])
# dense enemies
drones(m, [(8, G - 1), (32, G - 1), (56, G - 1), (80, G - 1), (104, G - 1)])
turrets(m, [(14, G - 4), (38, G - 4), (62, G - 4), (86, G - 4), (110, G - 4)])
turrets(m, [(24, G - 8), (48, G - 8), (72, G - 8), (96, G - 8), (120, G - 8)])
put(m, 2, G - 1, 'P')
put(m, W - 8, G - 1, 'F')
put(m, W - 4, G - 1, 'E')
map3 = render(m)

def tscn(idx, name, mapstr):
    return f'''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/levels/level.gd" id="1"]

[node name="Level" type="Node2D"]
script = ExtResource("1")
level_index = {idx}
level_name = "{name}"
level_map = "{mapstr}"
'''

base = "/Users/eminmacprom1/Documents/Code/hacker-platformer/scenes/levels"
os.makedirs(base, exist_ok=True)
open(f"{base}/level_01_terminal.tscn", "w").write(tscn(0, "THE TERMINAL", map1))
open(f"{base}/level_02_servers.tscn", "w").write(tscn(1, "SERVER FARM", map2))
open(f"{base}/level_03_core.tscn", "w").write(tscn(2, "THE CORE", map3))
print("maps written:", W, "tiles wide x", G + 2, "rows")
print("map1 rows:", len(map1.split("\n")), "len:", len(map1.split("\n")[0]))
