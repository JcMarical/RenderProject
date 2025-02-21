#ifndef CUSTOM_GI_INCLUDED
#define CUSTOM_GI_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"

TEXTURE2D(unity_Lightmap);
SAMPLER(samplerunity_Lightmap);

TEXTURE2D(unity_ShadowMask);
SAMPLER(samplerunity_ShadowMask);

TEXTURE3D_FLOAT(unity_ProbeVolumeSH);
SAMPLER(samplerunity_ProbeVolumeSH);

struct GI {
	float3 diffuse;
    ShadowMask shadowMask;
};


float3 SampleLightMap (float2 lightMapUV) {
	#if defined(LIGHTMAP_ON)
		return SampleSingleLightmap(
            TEXTURE2D_ARGS(unity_Lightmap, samplerunity_Lightmap), //采样光照贴图
            lightMapUV,                     //采样光照贴图UV
            float4(1.0, 1.0, 0.0, 0.0),    //scale and translation
        
			#if defined(UNITY_LIGHTMAP_FULL_HDR)    //光照贴图是否被压缩
				false,
			#else
				true,
			#endif
            
			float4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0, 0.0)

            );
	#else
		return 0.0;
	#endif
}


float4 SampleBakedShadows (float2 lightMapUV, Surface surfaceWS) {
	#if defined(LIGHTMAP_ON)        //如果开启光照贴图，则根据光照贴图UV采样，否则没有烘焙阴影
		return SAMPLE_TEXTURE2D(
			unity_ShadowMask, samplerunity_ShadowMask, lightMapUV   
		);
	#else
		if (unity_ProbeVolumeParams.x) {    //处理LPPVs阴影遮罩（不需要法线）
			return SampleProbeOcclusion(
				TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
				surfaceWS.position, unity_ProbeVolumeWorldToObject,
				unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
				unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz
			);
		}
		else {
			return unity_ProbesOcclusion;   //返回遮挡探针
		}
	#endif
}


float3 SampleLightProbe (Surface surfaceWS) {
	#if defined(LIGHTMAP_ON)
		return 0.0;
	#else
    if (unity_ProbeVolumeParams.x) {
    return SampleProbeVolumeSH4(
        TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
        surfaceWS.position, surfaceWS.normal,
        unity_ProbeVolumeWorldToObject,
        unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
        unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz
        );
    }
    else {
		float4 coefficients[7];
		coefficients[0] = unity_SHAr;
		coefficients[1] = unity_SHAg;
		coefficients[2] = unity_SHAb;
		coefficients[3] = unity_SHBr;
		coefficients[4] = unity_SHBg;
		coefficients[5] = unity_SHBb;
		coefficients[6] = unity_SHC;
		return max(0.0, SampleSH9(coefficients, surfaceWS.normal));

    }
    	#endif
}

GI GetGI (float2 lightMapUV,Surface surfaceWS) {
	GI gi;
	gi.diffuse = SampleLightMap(lightMapUV) + SampleLightProbe(surfaceWS);
    gi.shadowMask.always = false;
    gi.shadowMask.distance = false;
	gi.shadowMask.shadows = 1.0;
    
    //如果开启阴影遮罩，则采样烘焙遮罩
    #if defined(_SHADOW_MASK_ALWAYS)
		gi.shadowMask.always = true;
		gi.shadowMask.shadows = SampleBakedShadows(lightMapUV, surfaceWS);
	#elif defined(_SHADOW_MASK_DISTANCE)
		gi.shadowMask.distance = true;
		gi.shadowMask.shadows = SampleBakedShadows(lightMapUV,surfaceWS);
	#endif

	return gi;
}

#endif