###
### SPATIAL SETTING LAYERS
### `SpatialSettings` and `JoinNearby`: settings of people living near each other, placed by
### household coordinates displaced by a random distance.
###

###
### HOME COORDINATES
###

"""
    _HomeCoordinates(table)

Household homes in km, by household id, from a table with `id`, `lon` and `lat`: an
equirectangular projection around the households' mean latitude, NaN where unknown.
"""
struct _HomeCoordinates
    x::Vector{Float32}
    y::Vector{Float32}
end

# a table's columns can be abstractly typed, so the work happens behind this call
_HomeCoordinates(table) = _HomeCoordinates(table.id, table.lon, table.lat)

function _HomeCoordinates(ids::AbstractVector, lon::AbstractVector, lat::AbstractVector)
    known = [k for k in eachindex(ids) if _finite(ids[k]) && ids[k] >= 1 && _finite(lon[k]) && _finite(lat[k])]
    isempty(known) && throw(ArgumentError("`household_coordinates` has no household with a finite `lon` and `lat`"))
    km = 6371.0 * π / 180
    x_km = km * cosd(mean(lat[k] for k in known))
    n = Int(maximum(ids[k] for k in known))
    x, y = fill(NaN32, n), fill(NaN32, n)
    for k in known
        x[ids[k]] = Float32(x_km * lon[k])
        y[ids[k]] = Float32(km * lat[k])
    end
    return _HomeCoordinates(x, y)
end

_finite(v) = !ismissing(v) && isfinite(v)

# The individual's home in km, NaN if their household has no coordinates.
function _home(coords::_HomeCoordinates, ind::Individual, store::ActivityPlanStore)
    h = household_id(ind, store)
    1 <= h <= length(coords.x) || return NaN32, NaN32
    return @inbounds coords.x[h], coords.y[h]
end

# A displacement in km: Gaussian with standard deviation `spread`, or a drawn distance at a
# uniform angle. Both take a fixed number of draws.
_draw_displacement(rng::Xoshiro, spread::Float64) = (spread * gems_randn(rng), spread * gems_randn(rng))

function _draw_displacement(rng::Xoshiro, spread::Distribution)
    r = _rand_val(spread, rng)
    θ = 2π * gems_rand(rng)
    return r * cos(θ), r * sin(θ)
end

###
### NEW SETTINGS ALONG A CURVE
###

function _partition(a::SpatialSettings, members::Vector{Int32}, ctx::_LayerContext{_HomeCoordinates}, rng::Xoshiro)
    points, box = _displaced_homes(a.spread, members, ctx, rng)
    located = Int32[k for k in eachindex(points) if isfinite(points[k][1])]
    loose = Int32[k for k in eachindex(points) if !isfinite(points[k][1])]
    labels = Vector{Int32}(undef, length(members))
    last = _cut_labels!(labels, _hilbert_order(points, located, box), a.size, ctx.size_rng, Int32(0))
    # members without coordinates are packed among themselves
    _cut_labels!(labels, loose[_shuffled_positions(rng, length(loose))], a.size, ctx.size_rng, last)
    return labels
end

# Each member's home displaced by a fresh draw, NaN for members without coordinates, and the
# bounding box `(x0, x1, y0, y1)` of the homes themselves.
function _displaced_homes(spread, members::Vector{Int32}, ctx::_LayerContext{_HomeCoordinates}, rng::Xoshiro)
    points = Vector{NTuple{2, Float32}}(undef, length(members))
    x0, x1, y0, y1 = Inf32, -Inf32, Inf32, -Inf32
    for (k, i) in enumerate(members)
        hx, hy = _home(ctx.coords, ctx.inds[i], ctx.store)
        # drawn for everyone, so the draws do not depend on who has coordinates
        dx, dy = _draw_displacement(rng, spread)
        points[k] = (hx + Float32(dx), hy + Float32(dy))
        if isfinite(hx)
            x0, x1, y0, y1 = min(x0, hx), max(x1, hx), min(y0, hy), max(y1, hy)
        end
    end
    return points, (x0, x1, y0, y1)
end

# The positions `located` in the order a Hilbert curve over the homes' bounding box `box` visits
# their points, ties by position. Points displaced past the box count as on its edge, so a few far
# draws don't coarsen the curve for everyone.
function _hilbert_order(points::Vector{NTuple{2, Float32}}, located::Vector{Int32}, box::NTuple{4, Float32})
    isempty(located) && return Int32[]
    x0, x1, y0, y1 = box
    # one scale for both axes, so the curve's cells are square
    side = max(x1 - x0, y1 - y0, eps(Float32))
    scale = (2^15 - 1) / side
    keys = Vector{UInt64}(undef, length(located))
    for (k, p) in enumerate(located)
        x, y = clamp(points[p][1], x0, x0 + side), clamp(points[p][2], y0, y0 + side)
        cell = _hilbert(round(Int, (x - x0) * scale), round(Int, (y - y0) * scale))
        # the position in `located` in the low bits, so plain sorting orders and breaks ties
        keys[k] = (UInt64(cell) << 32) | UInt64(k)
    end
    sort!(keys)
    return Int32[located[key & 0xffffffff] for key in keys]
end

"""
    _hilbert(x::Int, y::Int)

Returns the position of cell `(x, y)` along a Hilbert curve through a 2^15 × 2^15 grid.
"""
function _hilbert(x::Int, y::Int)
    n = 1 << 15
    d = 0
    s = n >> 1
    while s > 0
        rx, ry = (x & s) > 0, (y & s) > 0
        d += s * s * ((3 * rx) ⊻ ry)
        # rotate the quadrant so the curve stays continuous
        if !ry
            rx && ((x, y) = (n - 1 - x, n - 1 - y))
            x, y = y, x
        end
        s >>= 1
    end
    return d
end

###
### JOINING NEARBY SETTINGS
###

"""
    _CentroidGrid

The candidates of a layer's type that have located members, binned by the centroid of those
members' homes into square cells of about four each: cell `c`'s candidate positions are
`positions[starts[c]:(starts[c + 1] - 1)]`.
"""
struct _CentroidGrid
    x0::Float64
    y0::Float64
    cell::Float64
    nx::Int
    ny::Int
    starts::Vector{Int}
    positions::Vector{Int32}
end

"""
    _NearbyState

`JoinNearby`'s lookup for one layer: the centroid grid, every candidate for the fallback draw,
and buffers reused across draws.
"""
struct _NearbyState
    grid::_CentroidGrid
    candidates::_JoinCandidates
    ring::Vector{Int32}
    ring_weights::Vector{Int}
end

function _join_state(::JoinNearby, ctx::_LayerContext{_HomeCoordinates})
    c = _JoinCandidates(ctx.store, ctx.inds, ctx.tidx)
    return _NearbyState(_CentroidGrid(c, ctx), c, Int32[], Int[])
end

function _CentroidGrid(c::_JoinCandidates, ctx::_LayerContext{_HomeCoordinates})
    js, cx, cy = _centroids(c, ctx)
    isempty(js) && return _CentroidGrid(0.0, 0.0, 1.0, 0, 0, [1], Int32[])
    (x0, x1), (y0, y1) = extrema(cx), extrema(cy)
    w, h = max(x1 - x0, 1e-3), max(y1 - y0, 1e-3)
    # about four candidates a cell, and at most about 4n cells along a thin strip
    cell = max(sqrt(w * h * 4 / length(js)), max(w, h) / (4 * length(js)))
    nx, ny = floor(Int, w / cell) + 1, floor(Int, h / cell) + 1
    cells = map(eachindex(js)) do k
        ix, iy = _cell_coords(x0, y0, cell, cx[k], cy[k])
        # the largest centroids sit on the far edge
        1 + min(ix, nx - 1) + nx * min(iy, ny - 1)
    end
    # counting sort by cell
    starts = zeros(Int, nx * ny + 1)
    foreach(cl -> starts[cl + 1] += 1, cells)
    starts[1] = 1
    cumsum!(starts, starts)
    positions, next = Vector{Int32}(undef, length(js)), starts[1:(end - 1)] .- 1
    for (k, cl) in enumerate(cells)
        positions[next[cl] += 1] = js[k]
    end
    return _CentroidGrid(x0, y0, cell, nx, ny, starts, positions)
end

# The candidates with located members, by position, and the centroids of those members' homes.
function _centroids(c::_JoinCandidates, ctx::_LayerContext{_HomeCoordinates})
    sx, sy, n = zeros(length(c.ids)), zeros(length(c.ids)), zeros(Int, length(c.ids))
    # each id's position among the candidates, a lookup instead of a search per entry
    position = zeros(Int32, isempty(c.ids) ? 0 : Int(last(c.ids)))
    position[c.ids] .= Int32(1):Int32(length(c.ids))
    @inbounds for ind in ctx.inds
        hx, hy = _home(ctx.coords, ind, ctx.store)
        isfinite(hx) || continue
        for k in _type_slots(ctx.store, ind, ctx.tidx)
            sid = setting_id(ctx.store.entries[k])
            # as in `_JoinCandidates`, which counts ids from 1 only
            sid >= 1 || continue
            j = position[sid]
            sx[j] += hx
            sy[j] += hy
            n[j] += 1
        end
    end
    js = Int32.(findall(>(0), n))
    return js, sx[js] ./ n[js], sy[js] ./ n[js]
end

# The column and row of the cell holding point `(x, y)` in a grid from `(x0, y0)` with cells of
# side `cell`, from 0; outside the grid for a point outside it.
_cell_coords(x0, y0, cell, x, y) =
    (floor(Int, clamp((x - x0) / cell, -1e9, 1e9)), floor(Int, clamp((y - y0) / cell, -1e9, 1e9)))
_cell_coords(g::_CentroidGrid, x, y) = _cell_coords(g.x0, g.y0, g.cell, x, y)

function _choose(a::JoinNearby, i::Int, held::Vector{Int32}, s::_NearbyState, ctx::_LayerContext{_HomeCoordinates}, rng::Xoshiro)
    hx, hy = _home(ctx.coords, ctx.inds[i], ctx.store)
    # drawn for everyone, so the draws do not depend on who has coordinates
    dx, dy = _draw_displacement(rng, a.spread)
    if isfinite(hx)
        sid = _nearest_ring_draw(s, hx + dx, hy + dy, held, rng)
        sid == 0 || return sid
    end
    # no coordinates, or nothing within the ring cap
    return _choose(JoinExisting(), i, held, s.candidates, ctx, rng)
end

const _MAX_RINGS = 32

# A draw ∝ member count among the candidates not in `held` in the nearest ring of cells around
# `(x, y)` that has any, searching at most `_MAX_RINGS` rings out; 0 if none has.
function _nearest_ring_draw(s::_NearbyState, x, y, held::Vector{Int32}, rng::Xoshiro)
    s.grid.nx == 0 && return Int32(0)
    ix, iy = _cell_coords(s.grid, x, y)
    for k in 0:_MAX_RINGS
        _ring_candidates!(s, ix, iy, k, held)
        isempty(s.ring) || return _weighted_draw(s.ring, s.ring_weights, rng)
    end
    return Int32(0)
end

# Fills the state's buffers with the candidates not in `held` in the cells exactly `k` cells
# from cell `(ix, iy)`, and their member counts.
function _ring_candidates!(s::_NearbyState, ix::Int, iy::Int, k::Int, held::Vector{Int32})
    empty!(s.ring)
    empty!(s.ring_weights)
    if k == 0
        _add_cell_candidates!(s, ix, iy, held)
        return nothing
    end
    for cx in (ix - k):(ix + k)
        _add_cell_candidates!(s, cx, iy - k, held)
        _add_cell_candidates!(s, cx, iy + k, held)
    end
    for cy in (iy - k + 1):(iy + k - 1)
        _add_cell_candidates!(s, ix - k, cy, held)
        _add_cell_candidates!(s, ix + k, cy, held)
    end
    return nothing
end

function _add_cell_candidates!(s::_NearbyState, cx::Int, cy::Int, held::Vector{Int32})
    g, c = s.grid, s.candidates
    (0 <= cx < g.nx && 0 <= cy < g.ny) || return nothing
    cell = 1 + cx + g.nx * cy
    @inbounds for p in g.starts[cell]:(g.starts[cell + 1] - 1)
        j = Int(g.positions[p])
        c.ids[j] in held && continue
        push!(s.ring, c.ids[j])
        push!(s.ring_weights, _candidate_weight(c, j))
    end
    return nothing
end

# One of `ids`, drawn ∝ `weights`.
function _weighted_draw(ids::Vector{Int32}, weights::Vector{Int}, rng::Xoshiro)
    x = gems_rand(rng, 1:sum(weights))
    for (k, w) in enumerate(weights)
        x <= w && return ids[k]
        x -= w
    end
    return ids[end]
end
