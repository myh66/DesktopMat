#include <metal_stdlib>
using namespace metal;

struct RugVertex {
    float3 position;
    float3 normal;
    float2 uv;
    float occlusion;
    float pileDirection;
};

struct RugUniforms {
    float2 viewport;
    float2 rugSize;
    float backingScale;
    uint material;
    float2 shadowOffset;
};

struct RasterVertex {
    float4 position [[position]];
    float2 uv;
    float3 normal;
    float height;
    float occlusion;
    float pileDirection;
};

vertex RasterVertex rug_vertex(
    uint vertexID [[vertex_id]],
    const device RugVertex *vertices [[buffer(0)]],
    constant RugUniforms &u [[buffer(1)]]
) {
    RugVertex v = vertices[vertexID];
    // The same oblique 3D projection is used in RugProjection.screenPoint and
    // CPU triangle hit testing. Moving cloth geometry really reveals the desk.
    float2 point = v.position.xy + float2(0.12, 0.42) * v.position.z;
    float depth = clamp(0.86 - v.position.z / 1800.0, 0.03, 0.95);
    if (u.material == 0) {
        float spread = 4.5 + max(v.position.z, 0.0) * 0.080;
        point = v.position.xy + float2(0.26, -0.28) * v.position.z;
        point += u.shadowOffset * spread;
        point += (v.uv - 0.5) * (9.0 + max(v.position.z, 0.0) * 0.035);
        depth = 0.98;
    }
    RasterVertex out;
    out.position = float4(point * u.backingScale / (u.viewport * 0.5) - 1.0, depth, 1);
    out.uv = v.uv;
    out.normal = v.normal;
    out.height = v.position.z;
    out.occlusion = v.occlusion;
    out.pileDirection = v.pileDirection;
    return out;
}

float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 smooth = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + float2(1, 0)), smooth.x),
               mix(hash21(i + float2(0, 1)), hash21(i + float2(1, 1)), smooth.x), smooth.y);
}

fragment float4 rug_fragment(
    RasterVertex in [[stage_in]],
    bool frontFacing [[front_facing]],
    constant RugUniforms &u [[buffer(1)]],
    texture2d<float> pattern [[texture(0)]]
) {
    constexpr sampler wovenSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 point = (in.uv - 0.5) * u.rugSize;
    float2 edgeDistances = min(in.uv, 1.0 - in.uv) * u.rugSize;
    float edgeDistance = min(edgeDistances.x, edgeDistances.y);

    if (u.material == 0) {
        float feather = smoothstep(0.0, 4.2 + max(in.height, 0.0) * 0.018, edgeDistance);
        float alpha = 0.068 * exp(-max(in.height, 0.0) / 340.0) * feather;
        return float4(float3(0.029, 0.034, 0.036) * alpha, alpha);
    }

    float3 normal = normalize(in.normal);
    normal = frontFacing ? normal : -normal;
    float3 lightDirection = normalize(float3(-0.38, 0.46, 0.82));
    float diffuse = max(0.0, dot(normal, lightDirection));
    float lighting = (0.60 + diffuse * 0.42) * in.occlusion;
    if (u.material == 1) {
        float3 yarn = float3(0.75, 0.69, 0.55) * (0.87 + in.pileDirection * 0.16);
        float3 color = min(yarn * lighting, float3(1.0));
        return float4(color, 1.0);
    }

    // Fine irregularity belongs to the textile edge in UV/material space and
    // follows the cloth; there is no rectangle clipping or transform animation.
    float roughEdge = (noise(point * 3.1) - 0.5) * 0.42;
    float alpha = smoothstep(0.03, 0.68, edgeDistance + roughEdge);
    if (alpha < 0.005) { discard_fragment(); }
    float2 yarnUV = in.uv + (float2(noise(point * 0.23), noise(point * 0.19 + 70)) - 0.5) * 0.00065;
    // CoreGraphics bitmap rows run from the image's top; cloth UVs increase
    // upward from the desktop. Match the gallery's upright composition.
    yarnUV.y = 1.0 - yarnUV.y;
    float3 base = pattern.sample(wovenSampler, yarnUV).rgb;
    float pile = noise(point * 4.8);
    float tufts = noise(point * float2(1.8, 3.5));
    float warp = sin(point.y * 7.5 + noise(point * 0.15) * 2.0);
    float weft = sin(point.x * 10.2 + point.y * 0.7);
    float wear = noise(point * 0.017) * 0.055 + noise(point * 0.080) * 0.020;
    float wool = 0.91 + pile * 0.12 + tufts * 0.055 + warp * 0.016 + weft * 0.014;
    float rim = 1.0 - smoothstep(0.0, 5.3, edgeDistance);
    float binding = (0.5 + 0.5 * sin((point.x + point.y) * 6.0));

    if (!frontFacing) {
        // A subdued woven backing becomes visible when a corner actually folds
        // over. Herringbone fibers are separate from the face's Ningxia pile.
        float chevron = sin(point.x * 2.7 + abs(fract(point.y * 0.075) - 0.5) * 17.0);
        float threadVariation = sin(point.y * 5.2) * 0.017 + chevron * 0.028;
        base = float3(0.61, 0.57, 0.48) * (0.90 + pile * 0.11 + threadVariation);
        wool = 1.0;
    }
    float3 color = base * wool * lighting;
    color = mix(color, float3(0.65, 0.60, 0.48) * lighting, wear);
    color *= 1.0 - rim * (0.18 + binding * 0.12);
    // The directional pile changes softly with local tilt while the geometric
    // folds get their depth and light from actual deformed normals.
    float pileSheen = 0.020 * pow(max(0.0, dot(normal, normalize(float3(0.1, 0.6, 0.8)))), 5.0);
    float fiber = smoothstep(0.86, 0.98, noise(point * float2(10.0, 2.6)));
    color += float3(0.040, 0.037, 0.030) * fiber * lighting + pileSheen;
    return float4(clamp(color, 0.0, 1.0) * alpha, alpha);
}
