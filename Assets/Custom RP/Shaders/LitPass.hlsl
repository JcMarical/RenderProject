#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"


//纹理上传和采样
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);//Wrap和Filter

// GPUInstancing的常量缓冲区
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
	//	float4 _BaseColor;
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)//平铺和偏移
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)    //透明裁切
    UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)   //金属度
	UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness) //粗糙度
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)



struct Attributes {
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;     //新增法线，用于计算光照
    float2 baseUV : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID//获得对象索引
};


struct Varyings {
	float4 positionCS : SV_POSITION;
    float3 positionWS : VAR_POSITION;
    float3 normalWS : VAR_NORMAL;       //新增法线
    float2 baseUV : VAR_BASE_UV;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings LitPassVertex(Attributes input)
{
    Varyings output;
    //Instancing
    UNITY_SETUP_INSTANCE_ID(input);//提取索引并存储在一个全局静态变量中
    UNITY_TRANSFER_INSTANCE_ID(input, output);//复制索引

    //MVP
    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(output.positionWS);

    //Normal
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    
    //纹理平铺偏移处理
    float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
    output.baseUV = input.baseUV * baseST.xy + baseST.zw;

    return output;
}

float4 LitPassFragment(Varyings input) : SV_TARGET
{
    

    //Instancing
    UNITY_SETUP_INSTANCE_ID(input);

    //纹理采样
    float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);//通过UV和sampler进行采样
    
    //Color
    float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
    float4 base = baseMap * baseColor;

    //透明裁切（变体）
	#if defined(_CLIPPING)
		clip(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));
	#endif

    /* Test
    base.rgb = input.normalWS;//测试法向量
    base.rgb = abs(length(input.normalWS) - 1.0) * 10.0; //插值法线
    base.rgb = normalize(input.normalWS);//归一化法向量来平滑插值失真
    */

    //Surface表面处理
    Surface surface;
    surface.position = input.positionWS;
    surface.normal = normalize(input.normalWS);
    surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
    surface.depth = -TransformWorldToView(input.positionWS).z;
    surface.color = base.rgb;
    surface.alpha = base.a;
    surface.metallic = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Metallic);
	surface.smoothness = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Smoothness);
	surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);  //生成抖动值


    //Light光照处理
    #if defined(_PREMULTIPLY_ALPHA)
		BRDF brdf = GetBRDF(surface, true);
	#else
		BRDF brdf = GetBRDF(surface);
	#endif


    float3 color = GetLighting(surface, brdf);


    return float4(color, surface.alpha);


}   


#endif