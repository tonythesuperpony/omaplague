#!/usr/bin/env python3
"""
Builds complete world data for Omaplague:
- 177 real countries from Natural Earth / TopoJSON world-110m.json
- Equirectangular projection coordinates (1920 x 960)
- World Bank populations, accurate climates, wealth, density
- Shared-arc land borders, coastal seaport detection, and air/sea transit networks
"""

import urllib.request
import json
import csv
import io
import math
import os

MAP_WIDTH = 1920.0
MAP_HEIGHT = 960.0

print("1. Fetching TopoJSON world-110m.json...")
topo_url = "https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json"
topo_req = urllib.request.Request(topo_url, headers={"User-Agent": "Mozilla/5.0"})
topo = json.loads(urllib.request.urlopen(topo_req).read().decode("utf-8"))

print("2. Fetching ISO-3166 table...")
iso_url = "https://raw.githubusercontent.com/lukes/ISO-3166-Countries-with-Regional-Codes/master/all/all.json"
iso_req = urllib.request.Request(iso_url, headers={"User-Agent": "Mozilla/5.0"})
iso_list = json.loads(urllib.request.urlopen(iso_req).read().decode("utf-8"))

print("3. Fetching World Bank population dataset...")
pop_url = "https://raw.githubusercontent.com/datasets/population/master/data/population.csv"
pop_req = urllib.request.Request(pop_url, headers={"User-Agent": "Mozilla/5.0"})
pop_csv = urllib.request.urlopen(pop_req).read().decode("utf-8")
pop_reader = csv.reader(io.StringIO(pop_csv))
next(pop_reader)
pop_by_code = {}
for name, code, year, val in pop_reader:
    pop_by_code[code] = int(val)

# Build ISO lookup
num_to_iso = {}
for item in iso_list:
    num_to_iso[item["country-code"]] = item
    num_to_iso[item["country-code"].lstrip("0")] = item

# Special custom mapping for entities without standard numeric ISO
custom_entities = {
    "N. Cyprus": {"alpha-3": "CYN", "name": "Northern Cyprus", "region": "Asia", "pop": 380000},
    "Somaliland": {"alpha-3": "SOL", "name": "Somaliland", "region": "Africa", "pop": 5700000},
    "Kosovo": {"alpha-3": "XKX", "name": "Kosovo", "region": "Europe", "pop": 1780000},
    "-99": {"alpha-3": "ESH", "name": "Western Sahara", "region": "Africa", "pop": 580000},
    "Fr. S. Antarctic Lands": {"alpha-3": "ATF", "name": "French Southern Lands", "region": "Antarctica", "pop": 400},
}

# Decode TopoJSON Arcs
transform = topo["transform"]
scale = transform["scale"]
translate = transform["translate"]
raw_arcs = topo["arcs"]

def decode_arc(arc):
    coords = []
    x, y = 0, 0
    for pt in arc:
        x += pt[0]
        y += pt[1]
        coords.append((x * scale[0] + translate[0], y * scale[1] + translate[1]))
    return coords

decoded_arcs = [decode_arc(a) for a in raw_arcs]

# Track which arcs belong to which countries to determine land neighbors and coastlines
arc_users = {} # arc_idx -> set of country_keys

def get_ring_coords(arc_indices, country_key):
    ring = []
    for idx in arc_indices:
        raw_idx = idx if idx >= 0 else ~idx
        if raw_idx not in arc_users:
            arc_users[raw_idx] = set()
        arc_users[raw_idx].add(country_key)
        
        arc_pts = decoded_arcs[idx] if idx >= 0 else decoded_arcs[~idx][::-1]
        if not ring:
            ring.extend(arc_pts)
        else:
            ring.extend(arc_pts[1:])
    return ring

def project_pt(lon, lat):
    # Equirectangular projection
    x = (lon + 180.0) / 360.0 * MAP_WIDTH
    y = (90.0 - lat) / 180.0 * MAP_HEIGHT
    return round(x, 1), round(y, 1)

def poly_area_and_centroid(pts):
    if len(pts) < 3:
        return 0, (0, 0)
    area = 0.0
    cx = 0.0
    cy = 0.0
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        cross = pts[i][0] * pts[j][1] - pts[j][0] * pts[i][1]
        area += cross
        cx += (pts[i][0] + pts[j][0]) * cross
        cy += (pts[i][1] + pts[j][1]) * cross
    area *= 0.5
    if abs(area) < 1e-5:
        mx = sum(p[0] for p in pts) / len(pts)
        my = sum(p[1] for p in pts) / len(pts)
        return 0, (mx, my)
    cx /= (6.0 * area)
    cy /= (6.0 * area)
    return abs(area), (cx, cy)

def clean_poly_pts(pts):
    if len(pts) < 3:
        return []
    # Drop closing point if identical to first
    if math.isclose(pts[0][0], pts[-1][0], abs_tol=1e-3) and math.isclose(pts[0][1], pts[-1][1], abs_tol=1e-3):
        pts = pts[:-1]
    res = []
    for p in pts:
        if not res:
            res.append(p)
        else:
            dx = p[0] - res[-1][0]
            dy = p[1] - res[-1][1]
            if dx*dx + dy*dy > 0.16: # at least 0.4px away
                res.append(p)
    if len(res) < 3:
        return []
    # Check last vs first
    dx = res[0][0] - res[-1][0]
    dy = res[0][1] - res[-1][1]
    if dx*dx + dy*dy <= 0.16:
        res.pop()
    if len(res) < 3:
        return []
    # Area filter
    area = 0.0
    for i in range(len(res)):
        j = (i + 1) % len(res)
        area += res[i][0] * res[j][1] - res[j][0] * res[i][1]
    if abs(area) * 0.5 < 1.0: # smaller than 1 square pixel
        return []
    return res

def clean_and_split_ring(ring):
    # Splits any ring that jumps across the antimeridian (|dx| > 180)
    has_jump = any(abs(ring[i+1][0] - ring[i][0]) > 180.0 for i in range(len(ring) - 1))
    if not has_jump:
        return [ring]
        
    chunks = []
    curr = [ring[0]]
    for i in range(len(ring) - 1):
        p1 = ring[i]
        p2 = ring[i+1]
        if abs(p2[0] - p1[0]) > 180.0:
            b1 = 180.0 if p1[0] > 0 else -180.0
            b2 = -180.0 if p1[0] > 0 else 180.0
            y_mid = (p1[1] + p2[1]) * 0.5
            curr.append((b1, y_mid))
            chunks.append(curr)
            curr = [(b2, y_mid), p2]
        else:
            curr.append(p2)
    chunks.append(curr)
    
    east_chunks = [c for c in chunks if sum(p[0] for p in c)/len(c) > 0]
    west_chunks = [c for c in chunks if sum(p[0] for p in c)/len(c) <= 0]
    
    res = []
    for group in [east_chunks, west_chunks]:
        flat = []
        for c in group:
            flat.extend(c)
        if len(flat) >= 3:
            res.append(flat)
    return res

# Process all geometries
geometries = topo["objects"]["countries"]["geometries"]
print("Total country geometries:", len(geometries))

countries_meta = []
country_polygons = {}
country_arcs = {} # cid -> set of raw arc indices

# High-wealth countries
RICH_COUNTRIES = {
    "USA", "CAN", "GBR", "FRA", "DEU", "ITA", "ESP", "CHE", "SWE", "NOR", 
    "FIN", "DNK", "NLD", "BEL", "LUX", "IRL", "AUT", "AUS", "NZL", "JPN", 
    "KOR", "SGP", "ISR", "SAU", "ARE", "QAT", "KWT", "OMN", "BHR", "PRT",
    "GRC", "CYP", "ISL", "CZE", "SVN", "EST", "POL"
}

POOR_COUNTRIES = {
    "AFG", "YEM", "HTI", "SOM", "SSD", "TCD", "NER", "MLI", "BFA", "CAF",
    "COD", "BDI", "MDG", "MOZ", "MWI", "LBR", "SLE", "GIN", "GNB", "ERI",
    "GMB", "TGO", "BEN", "ZWE", "SOL"
}

# Arid / Desert countries
ARID_COUNTRIES = {
    "SAU", "ARE", "OMN", "YEM", "QAT", "KWT", "EGY", "LBY", "DZA", "TUN",
    "MAR", "MRT", "SDN", "TCD", "NER", "MLI", "ESH", "JOR", "IRQ", "IRN",
    "SYR", "AFG", "PAK", "TKM", "UZB", "KAZ", "MNG", "NAM", "BWA"
}

# Cold countries
COLD_COUNTRIES = {
    "CAN", "RUS", "GRL", "ISL", "NOR", "SWE", "FIN", "EST", "LVA", "LTU",
    "BLR", "KAZ", "MNG", "ATF"
}

for i, geom in enumerate(geometries):
    raw_id = str(geom.get("id", ""))
    cname = geom["properties"]["name"]
    
    # Exclude Antarctica from playable countries (it's uninhabited ice)
    if cname == "Antarctica":
        continue
        
    iso_info = (
        num_to_iso.get(raw_id) or 
        num_to_iso.get(raw_id.zfill(3)) or 
        custom_entities.get(cname) or 
        custom_entities.get(raw_id)
    )
    
    if iso_info:
        cid = iso_info["alpha-3"]
        disp_name = iso_info.get("name", cname)
    else:
        cid = ("C%03d" % i)
        disp_name = cname

    # Clean up long formal names for player-friendly UI
    NAME_MAP = {
        "United States of America": "United States",
        "United Kingdom of Great Britain and Northern Ireland": "United Kingdom",
        "Russian Federation": "Russia",
        "Iran (Islamic Republic of)": "Iran",
        "Korea, Republic of": "South Korea",
        "Korea (Republic of)": "South Korea",
        "Korea, Democratic People's Republic of": "North Korea",
        "Korea (Democratic People's Republic of)": "North Korea",
        "Syrian Arab Republic": "Syria",
        "Venezuela, Bolivarian Republic of": "Venezuela",
        "Venezuela (Bolivarian Republic of)": "Venezuela",
        "Bolivia, Plurinational State of": "Bolivia",
        "Bolivia (Plurinational State of)": "Bolivia",
        "Tanzania, United Republic of": "Tanzania",
        "Viet Nam": "Vietnam",
        "Lao People's Democratic Republic": "Laos",
        "Congo, Democratic Republic of the": "DR Congo",
        "Democratic Republic of the Congo": "DR Congo",
        "Dem. Rep. Congo": "DR Congo",
        "Czechia": "Czech Republic",
        "Moldova, Republic of": "Moldova",
        "Brunei Darussalam": "Brunei",
        "Central African Republic": "Central African Rep.",
        "Dominican Republic": "Dominican Rep.",
    }
    disp_name = NAME_MAP.get(disp_name, disp_name)
        
    # Unpack rings
    gtype = geom["type"]
    arc_groups = [geom["arcs"]] if gtype == "Polygon" else geom["arcs"]
    
    country_arcs[cid] = set()
    cleaned_polys = []
    best_area = -1.0
    best_centroid = (0.0, 0.0)
    
    for poly_arcs in arc_groups:
        outer_ring_arcs = poly_arcs[0]
        for a in outer_ring_arcs:
            country_arcs[cid].add(a if a >= 0 else ~a)
            
        ring_pts = get_ring_coords(outer_ring_arcs, cid)
        split_rings = clean_and_split_ring(ring_pts)
        
        for sring in split_rings:
            # Check for centroid on largest valid piece
            area, cent = poly_area_and_centroid(sring)
            if area > best_area:
                best_area = area
                best_centroid = cent
                
            # Project to screen coordinates
            proj_pts = [project_pt(p[0], p[1]) for p in sring]
            clean_proj = clean_poly_pts(proj_pts)
            if clean_proj:
                cleaned_polys.append(clean_proj)
                
    if not cleaned_polys:
        print("Warning: empty polygons for", cid, cname)
        continue
        
    country_polygons[cid] = cleaned_polys
    
    # Centroid
    cx, cy = project_pt(best_centroid[0], best_centroid[1])
    
    # Population
    pop = pop_by_code.get(cid, 0)
    if pop == 0 and iso_info and "pop" in iso_info:
        pop = iso_info["pop"]
    if pop == 0:
        # Fallback population estimate
        pop = 5000000
        
    # Climate & Attributes
    lat = best_centroid[1]
    if cid in COLD_COUNTRIES or abs(lat) > 55.0:
        climate = "cold"
    elif cid in ARID_COUNTRIES:
        climate = "arid"
    elif abs(lat) < 23.5:
        climate = "hot"
    else:
        climate = "balanced"
        
    if cid in ARID_COUNTRIES:
        humidity = "arid"
    elif climate == "hot" and abs(lat) < 18.0:
        humidity = "humid"
    else:
        humidity = "balanced"
        
    if cid in RICH_COUNTRIES:
        wealth = "rich"
    elif cid in POOR_COUNTRIES:
        wealth = "poor"
    else:
        wealth = "medium"
        
    if pop > 50000000 or cid in {"SGP", "HKG", "NLD", "BEL", "GBR", "JPN", "KOR"}:
        density = "urban"
    elif pop < 3000000 or climate in {"cold", "arid"}:
        density = "rural"
    else:
        density = "balanced"
        
    countries_meta.append({
        "id": cid,
        "name": disp_name,
        "region_index": len(countries_meta) + 1,
        "population": pop,
        "climate": climate,
        "humidity": humidity,
        "wealth": wealth,
        "density": density,
        "map_x": cx,
        "map_y": cy,
        "lat": round(best_centroid[1], 2),
        "lon": round(best_centroid[0], 2),
        "has_airport": True,
        "has_seaport": False, # calculated below
        "connections": {"land": [], "air": [], "sea": []}
    })

print("Successfully processed %d countries and polygon sets!" % len(countries_meta))

# Determine Seaports and Land Neighbors
# 1. Coastal check: if any arc of a country is shared with NO other country, it's a coastline!
for c in countries_meta:
    cid = c["id"]
    arcs = country_arcs.get(cid, set())
    is_coastal = False
    for a in arcs:
        if len(arc_users.get(a, set())) == 1:
            is_coastal = True
            break
    c["has_seaport"] = is_coastal

# 2. Land neighbors: shared arcs between countries
for i, c1 in enumerate(countries_meta):
    cid1 = c1["id"]
    arcs1 = country_arcs.get(cid1, set())
    for j in range(i + 1, len(countries_meta)):
        c2 = countries_meta[j]
        cid2 = c2["id"]
        arcs2 = country_arcs.get(cid2, set())
        if arcs1 & arcs2:
            c1["connections"]["land"].append(cid2)
            c2["connections"]["land"].append(cid1)

# 3. Air & Sea transit networks
# Continental Hubs for international flights
GLOBAL_AIR_HUBS = ["USA", "GBR", "FRA", "DEU", "CHN", "JPN", "IND", "BRA", "AUS", "ZAF", "EGY", "ARE", "SGP"]
GLOBAL_SEA_HUBS = ["CHN", "USA", "SGP", "NLD", "DEU", "JPN", "KOR", "ARE", "GBR", "ESP", "BRA", "AUS", "EGY", "ZAF"]

# Filter hubs to those present in countries_meta
present_cids = {c["id"] for c in countries_meta}
meta_by_id = {c["id"]: c for c in countries_meta}
GLOBAL_AIR_HUBS = [h for h in GLOBAL_AIR_HUBS if h in present_cids]
GLOBAL_SEA_HUBS = [h for h in GLOBAL_SEA_HUBS if h in present_cids]

def dist(c1, c2):
    dx = c1["map_x"] - c2["map_x"]
    dy = c1["map_y"] - c2["map_y"]
    return math.hypot(dx, dy)

for c in countries_meta:
    cid = c["id"]
    
    # Connect air:
    # 1. Connect to 2 nearest neighbors
    sorted_by_dist = sorted([other for other in countries_meta if other["id"] != cid], key=lambda o: dist(c, o))
    for nearby in sorted_by_dist[:3]:
        if nearby["id"] not in c["connections"]["air"]:
            c["connections"]["air"].append(nearby["id"])
            if cid not in nearby["connections"]["air"]:
                nearby["connections"]["air"].append(cid)
                
    # 2. Connect to nearest global hub
    nearest_air_hub = min(GLOBAL_AIR_HUBS, key=lambda h: dist(c, meta_by_id[h]))
    if nearest_air_hub != cid and nearest_air_hub not in c["connections"]["air"]:
        c["connections"]["air"].append(nearest_air_hub)
        if cid not in meta_by_id[nearest_air_hub]["connections"]["air"]:
            meta_by_id[nearest_air_hub]["connections"]["air"].append(cid)
            
    # Connect sea if coastal:
    if c["has_seaport"]:
        coastal_others = [o for o in countries_meta if o["id"] != cid and o["has_seaport"]]
        if coastal_others:
            sorted_coastal = sorted(coastal_others, key=lambda o: dist(c, o))
            for nearby_coast in sorted_coastal[:2]:
                if nearby_coast["id"] not in c["connections"]["sea"]:
                    c["connections"]["sea"].append(nearby_coast["id"])
                    if cid not in nearby_coast["connections"]["sea"]:
                        nearby_coast["connections"]["sea"].append(cid)
                        
            nearest_sea_hub = min(GLOBAL_SEA_HUBS, key=lambda h: dist(c, meta_by_id[h]))
            if nearest_sea_hub != cid and nearest_sea_hub not in c["connections"]["sea"]:
                c["connections"]["sea"].append(nearest_sea_hub)
                if cid not in meta_by_id[nearest_sea_hub]["connections"]["sea"]:
                    meta_by_id[nearest_sea_hub]["connections"]["sea"].append(cid)

# Compute 25 stipple dot positions inside each country's primary landmass
import random
random.seed(42) # Deterministic stipple points

def pt_in_poly(x, y, poly):
    inside = False
    n = len(poly)
    for i in range(n):
        j = (i + 1) % n
        xi, yi = poly[i]
        xj, yj = poly[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi):
            inside = not inside
    return inside

print("Generating biological infection stipple points...")
for c in countries_meta:
    cid = c["id"]
    plist = country_polygons.get(cid, [])
    if not plist:
        c["stipple_points"] = []
        continue
    largest = max(plist, key=len)
    xs = [p[0] for p in largest]
    ys = [p[1] for p in largest]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    
    dots = []
    attempts = 0
    while len(dots) < 25 and attempts < 1500:
        attempts += 1
        rx = random.uniform(min_x, max_x)
        ry = random.uniform(min_y, max_y)
        if pt_in_poly(rx, ry, largest):
            dots.append([round(rx, 1), round(ry, 1)])
            
    # Fallback to centroid if polygon is too thin
    if not dots:
        dots.append([c["map_x"], c["map_y"]])
    c["stipple_points"] = dots

# Remove temporary fields before saving
for c in countries_meta:
    if "lat" in c: del c["lat"]
    if "lon" in c: del c["lon"]

# Save to data/countries.json and data/country_polygons.json
out_countries = "/home/sierra/Projects/omaplague/data/countries.json"
out_polygons = "/home/sierra/Projects/omaplague/data/country_polygons.json"

with open(out_countries, "w") as f:
    json.dump(countries_meta, f, indent=2)
print("Saved %d countries to %s" % (len(countries_meta), out_countries))

with open(out_polygons, "w") as f:
    json.dump(country_polygons, f)
print("Saved polygon data for %d countries to %s" % (len(country_polygons), out_polygons))
