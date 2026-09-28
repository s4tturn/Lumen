#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

constexpr sampler textureSampler(address::clamp_to_edge, filter::bicubic);

[[visible]]
void lumenSurfaceShader(realitykit::surface_parameters params)
{
    float2 uv = params.geometry().uv0();
    uv.y = 1.0 - uv.y;

    half3 baseColor = (half3)params.textures().base_color().sample(textureSampler, uv).rgb;

    float3 worldPos = params.geometry().world_position();
    float t = fract(worldPos.x * 2.0 + worldPos.z * 2.0);

    half3 tint = mix(baseColor * 0.5, baseColor, half(t));
    params.surface().set_base_color(tint);
}