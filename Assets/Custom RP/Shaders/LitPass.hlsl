#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

//GI相关的宏
#if defined(LIGHTMAP_ON)
	#define GI_ATTRIBUTE_DATA float2 lightMapUV : TEXCOORD1;
	#define GI_VARYINGS_DATA float2 lightMapUV : VAR_LIGHT_MAP_UV;
	#define TRANSFER_GI_DATA(input, output) \
		output.lightMapUV = input.lightMapUV * \
		unity_LightmapST.xy + unity_LightmapST.zw;
	#define GI_FRAGMENT_DATA(input) input.lightMapUV
#else
	#define GI_ATTRIBUTE_DATA
	#define GI_VARYINGS_DATA
	#define TRANSFER_GI_DATA(input, output)
	#define GI_FRAGMENT_DATA(input) 0.0
#endif


#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/GI.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"





struct Attributes {
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;     //新增法线，用于计算光照
    float2 baseUV : TEXCOORD0;
    GI_ATTRIBUTE_DATA               //GI光照贴图数据
    UNITY_VERTEX_INPUT_INSTANCE_ID//获得对象索引
};


struct Varyings {
	float4 positionCS : SV_POSITION;
    float3 positionWS : VAR_POSITION;
    float3 normalWS : VAR_NORMAL;       //新增法线
    float2 baseUV : VAR_BASE_UV;
    GI_VARYINGS_DATA
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings LitPassVertex(Attributes input)
{
    Varyings output;
    //Instancing
    UNITY_SETUP_INSTANCE_ID(input);//提取索引并存储在一个全局静态变量中
    UNITY_TRANSFER_INSTANCE_ID(input, output);//复制索引

    //GI
    TRANSFER_GI_DATA(input, output);

    //MVP
    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(output.positionWS);

    //Normal
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    
    //纹理平铺偏移处理
    output.baseUV = TransformBaseUV(input.baseUV);;

    return output;
}

float4 LitPassFragment(Varyings input) : SV_TARGET
{
    

    //Instancing
    UNITY_SETUP_INSTANCE_ID(input);


    float4 base = GetBase(input.baseUV);

    //透明裁切（变体）
	#if defined(_CLIPPING)
		clip(base.a - GetCutoff(input.baseUV));
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

    surface.metallic = GetMetallic(input.baseUV);
	surface.smoothness = GetSmoothness(input.baseUV);

	surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);  //生成抖动值


    //Light光照处理
    #if defined(_PREMULTIPLY_ALPHA)
		BRDF brdf = GetBRDF(surface, true);
	#else
		BRDF brdf = GetBRDF(surface);
	#endif
    
    //GI
    GI gi = GetGI(GI_FRAGMENT_DATA(input),surface);

    //光照
    float3 color = GetLighting(surface, brdf,gi);

    //emission自发光
	color += GetEmission(input.baseUV);

    return float4(color, surface.alpha);


}   


#endif