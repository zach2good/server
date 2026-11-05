/*
===========================================================================

  Copyright (c) 2026 LandSandBoat Dev Teams

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see http://www.gnu.org/licenses/

===========================================================================
*/

#include "roam_region.h"

#include "navmesh/navmesh.h"

#include <common/tracy.h>
#include <common/xirand.h>

// Detour for the vector math only
#include <DetourCommon.h>

#include <mapbox/earcut.hpp>

#include <algorithm>
#include <cmath>
#include <limits>
#include <numbers>
#include <ranges>

// earcut wants 2D points
namespace mapbox::util
{

template <>
struct nth<0, Vector3>
{
    static auto get(const Vector3& vertex) -> float
    {
        return vertex.x;
    }
};

template <>
struct nth<1, Vector3>
{
    static auto get(const Vector3& vertex) -> float
    {
        return vertex.z;
    }
};

} // namespace mapbox::util

namespace
{

// samples a roam query takes before giving up on finding a walkable point
constexpr uint8 kSampleAttempts = 8;

// the load-time check runs once, so it can try much harder before writing a region off
constexpr uint8 kValidationSamples = 64;

// how far a snap may move a point before it counts as a different point
constexpr float kSnapTolerance = 2.5f;

// retail's 10th percentile leg
constexpr float kMinStep = 2.0f;

// rest a little inside the edge so the next leg still sees it; from the edge itself an outward leg crosses at t = 0 and is missed
constexpr float kEdgeMargin = 0.05f;

// retail legs are log-normal about RoamDistance and end near twice it; the same spread and cap fit every captured family
constexpr double kStepSigma = 0.40;
constexpr float  kStepCap   = 2.0f;

auto sampleStepDistance(const float median) -> float
{
    const auto drawn = static_cast<float>(median * std::exp(xirand::GetNormalNumber(0.0, kStepSigma)));
    return std::min(drawn, median * kStepCap);
}

// the only place the triangulator is named. it returns a flat triangle list indexing the rings concatenated in order
auto triangulate(const std::vector<RoamRegion::Ring>& rings) -> std::vector<uint32>
{
    return mapbox::earcut<uint32>(rings);
}

auto signedArea(const Vector3& a, const Vector3& b, const Vector3& c) -> float
{
    return (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z);
}

} // namespace

RoamRegion::RoamRegion(const Ring& outer, const std::vector<Ring>& holes)
{
    // earcut takes the outer ring first, then the holes
    std::vector<Ring> rings;
    rings.reserve(holes.size() + 1);
    rings.push_back(outer);
    rings.insert(rings.end(), holes.begin(), holes.end());

    const auto indices = triangulate(rings);

    // indices address the rings as one flat vertex run, in ring order
    const auto vertices = rings | std::views::join | std::ranges::to<Ring>();
    if (vertices.empty())
    {
        return;
    }

    // keep a running area total so sampling can pick a triangle by its share of the region
    float areaSum = 0.0f;

    triangles_.reserve(indices.size() / 3);
    for (size_t i = 0; i + 2 < indices.size(); i += 3)
    {
        const auto& a = vertices[indices[i]];
        const auto& b = vertices[indices[i + 1]];
        const auto& c = vertices[indices[i + 2]];

        areaSum += std::abs(signedArea(a, b, c)) * 0.5f;
        triangles_.push_back({ .a = a, .b = b, .c = c, .areaSum = areaSum });
    }

    for (const auto& ring : rings)
    {
        for (size_t i = 0; i < ring.size(); ++i)
        {
            edges_.push_back({ .a = ring[i], .b = ring[(i + 1) % ring.size()] });
        }
    }

    // the box every query checks before touching the triangles
    boundsX_ = std::ranges::minmax(vertices | std::views::transform(&Vector3::x));
    boundsZ_ = std::ranges::minmax(vertices | std::views::transform(&Vector3::z));

    buildGrid();
}

void RoamRegion::buildGrid()
{
    // small regions are as fast to scan as to look up
    constexpr std::size_t kMinTrianglesForGrid = 8;
    constexpr int         kMaxCellsPerSide     = 64;

    if (triangles_.size() <= kMinTrianglesForGrid)
    {
        return;
    }

    const auto side = std::clamp(static_cast<int>(std::ceil(std::sqrt(static_cast<float>(triangles_.size())))), 1, kMaxCellsPerSide);
    gridWidth_      = side;
    gridHeight_     = side;

    // guard degenerate (zero-width) bounds; the scale only has to be finite and positive
    const auto spanX = std::max(boundsX_.max - boundsX_.min, 1e-3f);
    const auto spanZ = std::max(boundsZ_.max - boundsZ_.min, 1e-3f);
    cellScaleX_      = static_cast<float>(gridWidth_) / spanX;
    cellScaleZ_      = static_cast<float>(gridHeight_) / spanZ;

    const auto cellX = [&](const float x)
    {
        return std::clamp(static_cast<int>((x - boundsX_.min) * cellScaleX_), 0, gridWidth_ - 1);
    };
    const auto cellZ = [&](const float z)
    {
        return std::clamp(static_cast<int>((z - boundsZ_.min) * cellScaleZ_), 0, gridHeight_ - 1);
    };

    // Each triangle goes in every cell its box overlaps. Points map to cells with the same functions,
    // so a triangle holding a point is always listed in that point's cell.
    const auto forEachCell = [&](const Triangle& triangle, auto&& fn)
    {
        const auto x0 = cellX(std::min({ triangle.a.x, triangle.b.x, triangle.c.x }));
        const auto x1 = cellX(std::max({ triangle.a.x, triangle.b.x, triangle.c.x }));
        const auto z0 = cellZ(std::min({ triangle.a.z, triangle.b.z, triangle.c.z }));
        const auto z1 = cellZ(std::max({ triangle.a.z, triangle.b.z, triangle.c.z }));
        for (int z = z0; z <= z1; ++z)
        {
            for (int x = x0; x <= x1; ++x)
            {
                fn(static_cast<std::size_t>(z * gridWidth_ + x));
            }
        }
    };

    const auto cells = static_cast<std::size_t>(gridWidth_) * static_cast<std::size_t>(gridHeight_);
    gridStart_.assign(cells + 1, 0);
    for (const auto& triangle : triangles_)
    {
        forEachCell(triangle,
                    [&](const std::size_t cell)
                    {
                        ++gridStart_[cell + 1];
                    });
    }
    for (std::size_t cell = 0; cell < cells; ++cell)
    {
        gridStart_[cell + 1] += gridStart_[cell];
    }

    gridTriangles_.resize(gridStart_[cells]);
    auto fill = std::vector<uint32_t>(gridStart_.begin(), gridStart_.end() - 1);
    for (uint32_t index = 0; index < triangles_.size(); ++index)
    {
        forEachCell(triangles_[index],
                    [&](const std::size_t cell)
                    {
                        gridTriangles_[fill[cell]++] = index;
                    });
    }

    // the ring edges, filed the same way (by the box of each edge)
    const auto forEachEdgeCell = [&](const Edge& edge, auto&& fn)
    {
        const auto x0 = cellX(std::min(edge.a.x, edge.b.x));
        const auto x1 = cellX(std::max(edge.a.x, edge.b.x));
        const auto z0 = cellZ(std::min(edge.a.z, edge.b.z));
        const auto z1 = cellZ(std::max(edge.a.z, edge.b.z));
        for (int z = z0; z <= z1; ++z)
        {
            for (int x = x0; x <= x1; ++x)
            {
                fn(static_cast<std::size_t>(z * gridWidth_ + x));
            }
        }
    };

    gridEdgeStart_.assign(cells + 1, 0);
    for (const auto& edge : edges_)
    {
        forEachEdgeCell(edge,
                        [&](const std::size_t cell)
                        {
                            ++gridEdgeStart_[cell + 1];
                        });
    }
    for (std::size_t cell = 0; cell < cells; ++cell)
    {
        gridEdgeStart_[cell + 1] += gridEdgeStart_[cell];
    }

    gridEdges_.resize(gridEdgeStart_[cells]);
    fill.assign(gridEdgeStart_.begin(), gridEdgeStart_.end() - 1);
    for (uint32_t index = 0; index < edges_.size(); ++index)
    {
        forEachEdgeCell(edges_[index],
                        [&](const std::size_t cell)
                        {
                            gridEdges_[fill[cell]++] = index;
                        });
    }
}

auto RoamRegion::inTriangle(const Triangle& triangle, const float x, const float z) const -> bool
{
    const Vector3 point{ .x = x, .y = 0.0f, .z = z };

    const auto ab = signedArea(triangle.a, triangle.b, point);
    const auto bc = signedArea(triangle.b, triangle.c, point);
    const auto ca = signedArea(triangle.c, triangle.a, point);

    // winding is whatever the ring was authored with, so accept either sign as long as it agrees
    return (ab >= 0.0f && bc >= 0.0f && ca >= 0.0f) || (ab <= 0.0f && bc <= 0.0f && ca <= 0.0f);
}

auto RoamRegion::contains(const float x, const float z) const -> bool
{
    TracyZoneScoped;

    // cheap reject before walking the triangle list
    if (x < boundsX_.min || x > boundsX_.max || z < boundsZ_.min || z > boundsZ_.max)
    {
        return false;
    }

    // inside the region means inside any one of its triangles
    if (gridWidth_ == 0)
    {
        return std::ranges::any_of(triangles_,
                                   [&](const Triangle& triangle)
                                   {
                                       return inTriangle(triangle, x, z);
                                   });
    }

    // only the triangles listed in this point's cell can hold it
    const auto cellX = std::clamp(static_cast<int>((x - boundsX_.min) * cellScaleX_), 0, gridWidth_ - 1);
    const auto cellZ = std::clamp(static_cast<int>((z - boundsZ_.min) * cellScaleZ_), 0, gridHeight_ - 1);
    const auto cell  = static_cast<std::size_t>(cellZ * gridWidth_ + cellX);
    for (auto i = gridStart_[cell]; i < gridStart_[cell + 1]; ++i)
    {
        if (inTriangle(triangles_[gridTriangles_[i]], x, z))
        {
            return true;
        }
    }
    return false;
}

auto RoamRegion::hasWalkableSurface(const NavMesh& navMesh) const -> bool
{
    return randomPoint(&navMesh, kValidationSamples).has_value();
}

auto RoamRegion::closestPoint(const position_t& position) const -> position_t
{
    TracyZoneScoped;

    // already inside, so the position is its own answer
    if (triangles_.empty() || contains(position.x, position.z))
    {
        return position;
    }

    // this scans the edges the triangulation added too, which is harmless: from outside, a boundary edge is always hit before any of them
    auto closest         = position;
    auto closestDistance = std::numeric_limits<float>::max();
    auto consider        = [&](const Vector3& a, const Vector3& b)
    {
        float      t        = 0.0f;
        const auto distance = dtDistancePtSegSqr2D(&position.x, &a.x, &b.x, t);
        if (distance < closestDistance)
        {
            closestDistance = distance;
            dtVlerp(&closest.x, &a.x, &b.x, t);
        }
    };

    // three edges per triangle, nearest one wins
    for (const auto& triangle : triangles_)
    {
        consider(triangle.a, triangle.b);
        consider(triangle.b, triangle.c);
        consider(triangle.c, triangle.a);
    }

    return closest;
}

auto RoamRegion::distanceOutside(const position_t& position) const -> float
{
    const auto closest = closestPoint(position);

    return std::hypot(closest.x - position.x, closest.z - position.z);
}

auto RoamRegion::clampToRegion(const position_t& from, const Vector3& direction, const float distance) const -> float
{
    TracyZoneScoped;

    // a start outside the region gets no leg
    if (!contains(from.x, from.z))
    {
        return 0.0f;
    }

    // heading out from the boundary crosses at t = 0, which the scan below skips
    if (!contains(from.x + direction.x * kEdgeMargin, from.z + direction.z * kEdgeMargin))
    {
        return 0.0f;
    }

    // first crossing of a ring edge; the ray may leave and come back
    float      nearest  = distance;
    const auto consider = [&](const Edge& edge)
    {
        const float ex    = edge.b.x - edge.a.x;
        const float ez    = edge.b.z - edge.a.z;
        const float denom = direction.x * ez - direction.z * ex;
        if (std::abs(denom) < 1e-6f)
        {
            return;
        }

        const float dx = edge.a.x - from.x;
        const float dz = edge.a.z - from.z;
        const float t  = (dx * ez - dz * ex) / denom;
        const float u  = (dx * direction.z - dz * direction.x) / denom;
        if (t > 1e-4f && t < nearest && u >= 0.0f && u <= 1.0f)
        {
            nearest = t;
        }
    };

    // Only edges in the cells the step's box covers can be crossed by it. An edge listed in several
    // of those cells is just tested again, which can't change the nearest crossing.
    bool usedGrid = false;
    if (gridWidth_ > 0)
    {
        const float toX = from.x + direction.x * distance;
        const float toZ = from.z + direction.z * distance;
        const auto  x0  = std::clamp(static_cast<int>((std::min(from.x, toX) - boundsX_.min) * cellScaleX_), 0, gridWidth_ - 1);
        const auto  x1  = std::clamp(static_cast<int>((std::max(from.x, toX) - boundsX_.min) * cellScaleX_), 0, gridWidth_ - 1);
        const auto  z0  = std::clamp(static_cast<int>((std::min(from.z, toZ) - boundsZ_.min) * cellScaleZ_), 0, gridHeight_ - 1);
        const auto  z1  = std::clamp(static_cast<int>((std::max(from.z, toZ) - boundsZ_.min) * cellScaleZ_), 0, gridHeight_ - 1);

        // a step spanning much of the region is cheaper to check against every edge once
        const auto cellsCovered = static_cast<std::size_t>(x1 - x0 + 1) * static_cast<std::size_t>(z1 - z0 + 1);
        if (cellsCovered * 4 <= edges_.size())
        {
            usedGrid = true;
            for (int z = z0; z <= z1; ++z)
            {
                for (int x = x0; x <= x1; ++x)
                {
                    const auto cell = static_cast<std::size_t>(z * gridWidth_ + x);
                    for (auto i = gridEdgeStart_[cell]; i < gridEdgeStart_[cell + 1]; ++i)
                    {
                        consider(edges_[gridEdges_[i]]);
                    }
                }
            }
        }
    }

    if (!usedGrid)
    {
        for (const auto& edge : edges_)
        {
            consider(edge);
        }
    }

    if (nearest >= distance)
    {
        return distance;
    }

    return std::max(nearest - kEdgeMargin, 0.0f);
}

auto RoamRegion::samplePoint() const -> position_t
{
    // area-weighted, so every square yalm is equally likely however the triangles were cut
    const auto  pick     = xirand::GetRandomNumber(0.0f, triangles_.back().areaSum);
    const auto& triangle = *std::ranges::lower_bound(triangles_, pick, {}, &Triangle::areaSum);

    // two barycentric weights, folded back over the diagonal when they overshoot the triangle
    auto u = xirand::GetRandomNumber(0.0f, 1.0f);
    auto v = xirand::GetRandomNumber(0.0f, 1.0f);
    if (u + v > 1.0f)
    {
        u = 1.0f - u;
        v = 1.0f - v;
    }

    // mix the corners by those weights, y included
    const auto& a = triangle.a;
    const auto& b = triangle.b;
    const auto& c = triangle.c;

    position_t point;
    point.x = a.x + u * (b.x - a.x) + v * (c.x - a.x);
    point.y = a.y + u * (b.y - a.y) + v * (c.y - a.y);
    point.z = a.z + u * (b.z - a.z) + v * (c.z - a.z);

    return point;
}

auto RoamRegion::acceptPoint(const position_t& point, const NavMesh* navMesh) const -> Maybe<position_t>
{
    // no mesh to check against, so the geometry has the final say
    if (!navMesh)
    {
        return point;
    }

    // take the mesh height over the authored one. if the snap has to travel to get there, the point was never walkable
    const auto snapped = navMesh->findClosestValidPoint(point);
    if (!snapped)
    {
        return std::nullopt;
    }

    // it landed too far from where we asked, or the snap carried it out of the region
    if (std::abs(snapped->x - point.x) > kSnapTolerance || std::abs(snapped->z - point.z) > kSnapTolerance || !contains(snapped->x, snapped->z))
    {
        return std::nullopt;
    }

    return snapped;
}

auto RoamRegion::randomPoint(const NavMesh* navMesh, const uint8 attempts) const -> Maybe<position_t>
{
    TracyZoneScoped;

    if (triangles_.empty())
    {
        return std::nullopt;
    }

    // sample until one of them survives the mesh check
    for (uint8 attempt = 0; attempt < attempts; ++attempt)
    {
        if (const auto point = acceptPoint(samplePoint(), navMesh))
        {
            return point;
        }
    }

    return std::nullopt;
}

auto RoamRegion::randomPointAt(const position_t& from, float distance, const NavMesh* navMesh) const -> Maybe<position_t>
{
    TracyZoneScoped;

    if (triangles_.empty())
    {
        return std::nullopt;
    }

    for (uint8 attempt = 0; attempt < kSampleAttempts; ++attempt)
    {
        const auto angle     = xirand::GetRandomNumber(0.0f, 2.0f * std::numbers::pi_v<float>);
        const auto direction = Vector3{ .x = std::cos(angle), .y = 0.0f, .z = std::sin(angle) };

        // shorten the step to the edge rather than discard the draw
        const auto step = clampToRegion(from, direction, sampleStepDistance(distance));

        if (step < kMinStep)
        {
            continue;
        }

        const position_t target{ from.x + direction.x * step, from.y, from.z + direction.z * step, 0, 0 };

        if (!navMesh)
        {
            return target;
        }

        // walk the surface rather than teleport: it stops at the first wall in the way, so nothing lands across geometry
        position_t reached;
        if (!navMesh->moveAlongSurface(from, target, reached))
        {
            continue;
        }

        // sliding along the surface can end outside even when the target was inside
        if (!contains(reached.x, reached.z))
        {
            continue;
        }

        // a wall shortens the walk; only one that got nowhere is retried
        if (std::hypot(reached.x - from.x, reached.z - from.z) < kMinStep)
        {
            continue;
        }

        return reached;
    }

    return std::nullopt;
}
