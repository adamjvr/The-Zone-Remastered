#include <metal_stdlib>
using namespace metal;
struct VIn { float2 position; float2 uv; };
struct VOut { float4 position [[position]]; float2 uv; };
vertex VOut zone_vertex(const device VIn *v [[buffer(0)]], uint id [[vertex_id]]) {
    VOut o; o.position=float4(v[id].position,0,1); o.uv=v[id].uv; return o;
}
fragment float4 zone_fragment(VOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              sampler s [[sampler(0)]],
                              constant float &flash [[buffer(0)]]) {
    float4 c = tex.sample(s,in.uv);
    if (c.a <= 0.0) return c;
    const float amount = clamp(flash, 0.0f, 1.0f) * 0.75f;
    c.rgb = mix(c.rgb, float3(1.0f), amount);
    return c;
}
