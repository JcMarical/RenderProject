#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

//设置PCF关键字
#if defined(_DIRECTIONAL_PCF3)
	#define DIRECTIONAL_FILTER_SAMPLES 4
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_DIRECTIONAL_PCF5)
	#define DIRECTIONAL_FILTER_SAMPLES 9
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_DIRECTIONAL_PCF7)
	#define DIRECTIONAL_FILTER_SAMPLES 16
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif


#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_CASCADE_COUNT 4

TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);

CBUFFER_START(_CustomShadows)
    int _CascadeCount;
    float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT];
    float4 _CascadeData[MAX_CASCADE_COUNT];
	float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT* MAX_CASCADE_COUNT];
    float4 _ShadowAtlasSize;
    float4 _ShadowDistanceFade;
CBUFFER_END

struct ShadowMask {
	bool always;
	bool distance;
	float4 shadows;
};

struct ShadowData {
	int cascadeIndex;
    float cascadeBlend;
    float strength;
	ShadowMask shadowMask;
};

struct DirectionalShadowData {
	float strength;
	int tileIndex;
    float normalBias;
	int shadowMaskChannel;
};
//阴影淡化
float FadedShadowStrength (float distance, float scale, float fade)
{
    return saturate((1.0 - distance * scale) * fade);
}


ShadowData GetShadowData (Surface surfaceWS) {
	ShadowData data;
	//ShadowMask
	data.shadowMask.always = false;
	//ShadowMaskDistance处理
	data.shadowMask.distance = false;
	data.shadowMask.shadows = 1.0;
    //不仅需要球体去剔除，也需要深度去剔除(后改为根据深度淡化)
    data.cascadeBlend = 1.0;
    data.strength = FadedShadowStrength(surfaceWS.depth, _ShadowDistanceFade.x, _ShadowDistanceFade.y);
    //遍历所有级联剔除球体，直到找到包含表面位置的球体。
    //然后就使用当前循环迭代器作为级联索引。
    //如果有片段在球体之外，会得到无效索引
    int i;
	for (i = 0; i < _CascadeCount; i++) {
		float4 sphere = _CascadeCullingSpheres[i];
		float distanceSqr = DistanceSquared(surfaceWS.position, sphere.xyz);
		if (distanceSqr < sphere.w) {
			//级联淡入淡出
            float fade = FadedShadowStrength(
				distanceSqr, _CascadeData[i].x, _ShadowDistanceFade.z
			);

            if (i == _CascadeCount - 1) {
				data.strength *= fade;
            }
            else {
				data.cascadeBlend = fade;   //适合PCF宝宝体质的淡入淡出
			}
            break;
		}
	}

    //如果在级联范围内，strength则为0
    if (i == _CascadeCount) {
		data.strength = 0.0;
	}
	#if defined(_CASCADE_BLEND_DITHER)
		else if (data.cascadeBlend < surfaceWS.dither) {
			i += 1;
		}
	#endif
	#if !defined(_CASCADE_BLEND_SOFT)
		data.cascadeBlend = 1.0;
	#endif
	data.cascadeIndex = i;
	return data;
}

//阴影图集采样
float SampleDirectionalShadowAtlas (float3 positionSTS) {
	return SAMPLE_TEXTURE2D_SHADOW(
		_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS
	);
}


//PCF
float FilterDirectionalShadow (float3 positionSTS) {
	#if defined(DIRECTIONAL_FILTER_SETUP)
		float weights[DIRECTIONAL_FILTER_SAMPLES];
		float2 positions[DIRECTIONAL_FILTER_SAMPLES];
		float4 size = _ShadowAtlasSize.yyxx;
		DIRECTIONAL_FILTER_SETUP(size, positionSTS.xy, weights, positions);
		float shadow = 0;
		for (int i = 0; i < DIRECTIONAL_FILTER_SAMPLES; i++) {
			shadow += weights[i] * SampleDirectionalShadowAtlas(
				float3(positions[i].xy, positionSTS.z)
			);
		}
        return shadow;
	#else
		return SampleDirectionalShadowAtlas(positionSTS);
	#endif
}


//获取级联阴影
float GetCascadedShadow (
	DirectionalShadowData directional, ShadowData global, Surface surfaceWS
) {
    //bias设置
    float3 normalBias = surfaceWS.normal * (directional.normalBias * _CascadeData[global.cascadeIndex].y);
    //阴影矩阵X表面位置
    float3 positionSTS = mul(
        _DirectionalShadowMatrices[directional.tileIndex],
        float4(surfaceWS.position + normalBias,1.0)
    ).xyz;
    //通过位置进行阴影采样
    float shadow = FilterDirectionalShadow(positionSTS);
    //如果级联混合小于1，说明在过渡区需要插值
    if (global.cascadeBlend < 1.0) {
		normalBias = surfaceWS.normal *
			(directional.normalBias * _CascadeData[global.cascadeIndex + 1].y);
		positionSTS = mul(
			_DirectionalShadowMatrices[directional.tileIndex + 1],
			float4(surfaceWS.position + normalBias, 1.0)
		).xyz;
		shadow = lerp(
			FilterDirectionalShadow(positionSTS), shadow, global.cascadeBlend
		);
	}
		return shadow;
}

//获取烘焙阴影
float GetBakedShadow (ShadowMask mask, int channel) {
	float shadow = 1.0;
	if (mask.always || mask.distance) {
		if (channel >= 0) {
			shadow = mask.shadows[channel];
		}
	}
	return shadow;
}

//混合烘焙和实时阴影
float MixBakedAndRealtimeShadows (
	ShadowData global, float shadow, int shadowMaskChannel,float strength
) {
	float baked = GetBakedShadow(global.shadowMask, shadowMaskChannel);
	//shadowMask ：取最小值来组合烘焙阴影和实时阴影。
	if (global.shadowMask.always) {
		shadow = lerp(1.0, shadow, global.strength);
		shadow = min(baked, shadow);
		return lerp(1.0, shadow, strength);
	}
	//ShadowMaskDistance
	if (global.shadowMask.distance) {
		shadow = lerp(baked, shadow, global.strength);
		return lerp(1.0, shadow, strength);
	}
	return lerp(1.0, shadow, strength * global.strength);	 //强度为0，光照完全不受阴影影响，应该为1。
}

//仅烘焙阴影遮罩
float GetBakedShadow (ShadowMask mask, int channel, float strength) {
	//没有开启阴影遮罩则直接无阴影
	if (mask.always || mask.distance) {
		return lerp(1.0, GetBakedShadow(mask, channel), strength);
	}
	return 1.0;
}


//阴影衰减
float GetDirecitonalShadowAttenuation (DirectionalShadowData directional,ShadowData global, Surface surfaceWS){
    //接受阴影
    #if !defined(_RECEIVE_SHADOWS)
		return 1.0;
	#endif
    
    //阴影强度为0时，完全不需要采样，我们有一个无阴影的光源
	float shadow;
	if (directional.strength * global.strength <= 0.0) {
		//现在改为：仅使用烘焙阴影或无阴影
		shadow =  GetBakedShadow(global.shadowMask, directional.shadowMaskChannel,abs(directional.strength));
	}   
	else
	{
		shadow = GetCascadedShadow(directional, global, surfaceWS);				//级联阴影
		shadow = MixBakedAndRealtimeShadows(global, shadow, directional.shadowMaskChannel,directional.strength);	//混合阴影
	}

	return shadow;
    
}



#endif