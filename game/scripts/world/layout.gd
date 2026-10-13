class_name Layout
## Garden blockout in Godot meters (X east, Y up, Z south; north is -Z).
## Started from pack/map/layout.json, then tuned so the entry bridge sits where
## the loop path crosses the pond's inlet stream.

const POND_RADII := Vector2(12.5, 9.5)
const WATER_Y := -0.3
const STREAM_WATER_Y := -0.36

const LOOP_CENTER := Vector2(0.0, 0.5)
const LOOP_RADII := Vector2(19.5, 15.5)
const PATH_HALF_WIDTH := 1.25
const SPUR_HALF_WIDTH := 1.05

## Inlet stream, from inside the pond out past the southwest boundary.
const STREAM := [
	Vector2(-7.0, 6.1), Vector2(-11.5, 8.8), Vector2(-15.0, 10.6), Vector2(-19.5, 14.5),
	Vector2(-25.0, 20.0), Vector2(-31.0, 26.0), Vector2(-44.0, 36.0),
]
const STREAM_HALF_WIDTH := 2.0  # water's edge; the banks slope gently down to it
## Where the loop path crosses the stream. The stream pinches in here so the
## bridge's ends rest on solid banks, with the water passing underneath.
const BRIDGE := Vector2(-14.9, 10.5)
const BRIDGE_PINCH := 0.38
## The bridge's span direction (its local X axis, yaw 2.39 rad).
const BRIDGE_AXIS := Vector2(-0.7307, -0.6827)

## Short spurs off the loop (polylines).
const SPURS := [
	[Vector2(-19.4, 0.0), Vector2(-21.9, 0.0)],                         # tea stall
	[Vector2(13.6, -10.3), Vector2(15.6, -12.4)],                        # moonleaf grove
	[Vector2(15.9, 9.4), Vector2(10.6, 7.3)],                           # dock
	[Vector2(0.0, 15.9), Vector2(0.0, 17.4)],                           # bench
	[Vector2(-6.6, 15.2), Vector2(-8.6, 22.0), Vector2(-10.0, 36.0), Vector2(-10.6, 46.0), Vector2(-12.5, 60.0)],   # entry lane, on into the woods
]

## Small plazas (center, radius) that read as path.
const PLAZAS := [
	[Vector2(15.9, -12.8), 2.6],
	[Vector2(-21.4, 0.0), 1.9],
	[Vector2(0.0, 17.2), 1.6],
]

const BOUNDS := Rect2(-33.0, -27.0, 66.0, 54.0)
const ENTRY_GAP_X := Vector2(-13.0, -7.0)
const ENTRY_DEPTH := 36.0
## The entry lane carries on out of the garden as a shallow wooded valley.
const LANE := [Vector2(-10.0, 24.0), Vector2(-10.0, 36.0), Vector2(-10.6, 46.0), Vector2(-12.5, 62.0)]
const LANE_HALF := 3.2

const SPAWN := Vector3(-10.0, 0.0, 33.0)

## Ground is kept perfectly flat here so buildings and characters sit flush.
const FLAT_ZONES := [
	[Vector2(-23.6, 0.0), 4.5],    # tea stall + fox
	[Vector2(-31.0, -6.0), 8.0],   # giant tree roots
	[Vector2(8.2, 5.7), 4.5],      # dock
	[Vector2(0.0, 17.6), 2.6],     # bench
	[Vector2(-14.9, 10.5), 4.0],   # bridge ends
	[Vector2(16.0, -13.4), 6.5],   # grove: moss spirit and moonleaves
]

static var _detail: FastNoiseLite


## The exact walkable surface: base shape plus the small grass undulation the
## terrain mesh uses. Everything placed on the ground must use this.
static func surface_height(p: Vector2) -> float:
	return ground_height(p) + detail_offset(p)


static func detail_offset(p: Vector2) -> float:
	if _detail == null:
		_detail = FastNoiseLite.new()
		_detail.seed = 3
		_detail.frequency = 0.07
	var k := pond_k(p)
	var sd := stream_distance(p)
	var calm := clampf((k - 1.08) * 5.0, 0.0, 1.0) * clampf((sd - 2.2) * 0.8, 0.0, 1.0)
	if calm <= 0.0:
		return 0.0
	var pf := path_factor(p) if rim_distance(p) < 4.0 else 0.0
	calm *= (1.0 - pf) * (1.0 - flat_factor(p))
	return _detail.get_noise_2dv(p) * 0.22 * calm


## Terrain mesh grid (World builds the mesh from these).
const TERRAIN_MIN := Vector2(-58.0, -54.0)
const TERRAIN_MAX := Vector2(58.0, 60.0)
const TERRAIN_STEP := 0.55


static var _grid: PackedFloat32Array
static var _grid_nx := 0
static var _grid_nz := 0


static func grid_size() -> Vector2i:
	return Vector2i(int((TERRAIN_MAX.x - TERRAIN_MIN.x) / TERRAIN_STEP) + 1, int((TERRAIN_MAX.y - TERRAIN_MIN.y) / TERRAIN_STEP) + 1)


## surface_height at terrain grid vertex (ix, iz). Computed once for the whole
## grid and kept for the session (it never changes), so restarts are quick.
static func grid_height(ix: int, iz: int) -> float:
	if _grid.is_empty():
		var n := grid_size()
		_grid_nx = n.x
		_grid_nz = n.y
		_grid.resize(n.x * n.y)
		for z in n.y:
			for x in n.x:
				_grid[z * n.x + x] = surface_height(TERRAIN_MIN + Vector2(x, z) * TERRAIN_STEP)
	if ix < 0 or iz < 0 or ix >= _grid_nx or iz >= _grid_nz:
		return surface_height(TERRAIN_MIN + Vector2(ix, iz) * TERRAIN_STEP)
	return _grid[iz * _grid_nx + ix]


## Height of the actual terrain triangles at `p` (matches what you see, even on
## steep slopes where a triangle cuts below the smooth curve).
static func mesh_height(p: Vector2) -> float:
	var g := (p - TERRAIN_MIN) / TERRAIN_STEP
	var ix := floori(g.x)
	var iz := floori(g.y)
	var u := g.x - ix
	var v := g.y - iz
	var h00 := grid_height(ix, iz)
	var h10 := grid_height(ix + 1, iz)
	var h01 := grid_height(ix, iz + 1)
	# Cells are split along the (1,0)-(0,1) diagonal, like the mesh indices.
	if u + v <= 1.0:
		return h00 + u * (h10 - h00) + v * (h01 - h00)
	var h11 := grid_height(ix + 1, iz + 1)
	return h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)


static func flat_factor(p: Vector2) -> float:
	var f := 0.0
	for z in FLAT_ZONES:
		var r: float = z[1]
		f = maxf(f, 1.0 - smoothstep(r, r + 1.5, p.distance_to(z[0])))
	return f


static func pond_k(p: Vector2) -> float:
	return sqrt((p.x / POND_RADII.x) ** 2 + (p.y / POND_RADII.y) ** 2)


## Approximate distance to the loop path's center line.
static func loop_distance(p: Vector2) -> float:
	var q := p - LOOP_CENTER
	var a := LOOP_RADII.x
	var b := LOOP_RADII.y
	var f := (q.x / a) ** 2 + (q.y / b) ** 2 - 1.0
	var g := Vector2(2.0 * q.x / (a * a), 2.0 * q.y / (b * b)).length()
	return absf(f) / maxf(g, 0.0001)


static func loop_point(angle: float) -> Vector2:
	return LOOP_CENTER + Vector2(cos(angle) * LOOP_RADII.x, sin(angle) * LOOP_RADII.y)


static func polyline_distance(p: Vector2, pts: Array) -> float:
	var best := INF
	for i in pts.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		best = minf(best, p.distance_to(c))
	return best


## Distance from the stream's centerline, scaled up where the stream narrows
## (at the bridge), so every bank, channel and wall follows the narrowing.
static func stream_distance(p: Vector2) -> float:
	return polyline_distance(p, STREAM) * stream_widen(p)


## > 1 where the stream is narrower than usual.
static func stream_widen(p: Vector2) -> float:
	return 1.0 + BRIDGE_PINCH * (1.0 - smoothstep(2.5, 7.0, p.distance_to(BRIDGE)))


## 0 when off-path, 1 in the middle of any path, spur or plaza.
static func path_factor(p: Vector2) -> float:
	var f := 1.0 - smoothstep(PATH_HALF_WIDTH - 0.3, PATH_HALF_WIDTH + 0.25, loop_distance(p))
	for spur in SPURS:
		var d := polyline_distance(p, spur)
		f = maxf(f, 1.0 - smoothstep(SPUR_HALF_WIDTH - 0.3, SPUR_HALF_WIDTH + 0.25, d))
	for plaza in PLAZAS:
		var d2 := p.distance_to(plaza[0])
		f = maxf(f, 1.0 - smoothstep(float(plaza[1]) - 0.4, float(plaza[1]) + 0.3, d2))
	return f


static func distance_to_any_path(p: Vector2) -> float:
	var d := loop_distance(p) - PATH_HALF_WIDTH
	for spur in SPURS:
		d = minf(d, polyline_distance(p, spur) - SPUR_HALF_WIDTH)
	for plaza in PLAZAS:
		d = minf(d, p.distance_to(plaza[0]) - float(plaza[1]))
	return d


## How far `p` lies outside the walkable garden rectangle (0 inside).
static func outside_distance(p: Vector2) -> float:
	var dx := maxf(BOUNDS.position.x - p.x, p.x - BOUNDS.end.x)
	var dz := maxf(BOUNDS.position.y - p.y, p.y - BOUNDS.end.y)
	var d := maxf(maxf(dx, dz), 0.0)
	# The entry lane south of the garden counts as inside.
	if p.y > BOUNDS.end.y and p.x > ENTRY_GAP_X.x - 1.0 and p.x < ENTRY_GAP_X.y + 1.0 and p.y < ENTRY_DEPTH:
		d = 0.0
	return d


static func ground_height(p: Vector2) -> float:
	var h := 0.0
	# Gentle hills rising beyond the boundary to enclose the garden; the entry
	# lane cuts a soft valley through them instead of ending at a wall.
	var out := rim_distance(p)
	h += smoothstep(0.0, 16.0, out) * 5.5
	# Pond bowl.
	var k := pond_k(p)
	if k < 1.0:
		h = minf(h, -1.7 * smoothstep(0.0, 0.42, 1.0 - k))
	# Stream channel.
	var sd := stream_distance(p)
	if sd < 3.4:
		h = minf(h, -0.95 * smoothstep(3.4, 0.5, sd))
	return maxf(h, bridge_abutment(p))


## The banks are built up under each end of the bridge, so the deck rests on
## earth instead of hanging over a slope. -INF away from the bridge ends.
static func bridge_abutment(p: Vector2) -> float:
	var d := p - BRIDGE
	if d.length_squared() > 16.0:
		return -INF
	var lx := d.dot(BRIDGE_AXIS)          # along the span
	var lz := d.dot(Vector2(-BRIDGE_AXIS.y, BRIDGE_AXIS.x))
	var ax := absf(lx)
	# Rises from the water's edge to the deck underside, fades out beyond the
	# ends and to either side of the deck.
	var w := smoothstep(1.4, 1.95, ax) * (1.0 - smoothstep(1.15, 1.85, absf(lz))) * (1.0 - smoothstep(3.0, 3.9, ax))
	if w <= 0.0:
		return -INF
	var f := clampf((lx + 2.8) / 0.4, 0.0, Prop.BRIDGE_MODEL_DECK.size() - 1.001)
	var i := int(f)
	var deck: float = lerpf(Prop.BRIDGE_MODEL_DECK[i], Prop.BRIDGE_MODEL_DECK[i + 1], f - i)
	return lerpf(-0.95, deck - 0.1, w)


## Distance outside the garden for shaping the hills: zero inside the garden
## and along the entry lane valley.
static func rim_distance(p: Vector2) -> float:
	var lane := maxf(polyline_distance(p, LANE) - LANE_HALF, 0.0)
	# The stream leaves through its own little valley, not a cut in the hill.
	var brook := maxf(stream_distance(p) - 4.0, 0.0)
	return minf(outside_distance(p), minf(lane, brook) * 1.3)
