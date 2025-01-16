#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

float3 GerstnerWave(float4 waveParam, float time, float3 positionOS, inout float3 tangent, inout float3 bitangent)
{
    float3 position = 0;

    float2 direction = normalize(waveParam.xy);
            
    float waveLength = waveParam.w;
            
    float k = 2 * PI / max(1, waveLength);

    // 这里限制一下z让z永远不超过1
   // waveParam.z = abs(waveParam.z) / (abs(waveParam.z) + 1);
    float amplitude = waveParam.z;

    float speed = sqrt(9.8 / k);
            
    float f = k * (dot(direction, positionOS.xz) - speed * time);
            
    position.y = amplitude * sin(f);
    position.x = amplitude * cos(f) * direction.x;
    position.z = amplitude * cos(f) * direction.y;

    // 2022.4.27  更正偏导计算
    float yy = amplitude * k * cos(f);
    tangent += float3(-amplitude * k * sin(f) * direction.x * direction.x, yy * direction.x, -amplitude * sin(f) * direction.y * k * direction.x);
    
    bitangent += float3(-amplitude * k * sin(f) * direction.x * direction.y, yy * direction.y, -amplitude * k * sin(f) * direction.y * direction.y);
            
    return position;
}