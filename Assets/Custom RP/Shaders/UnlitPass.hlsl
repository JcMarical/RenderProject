#ifndef CUSTOM_UNLIT_PASS_INCLUDED
#define CUSTOM_UNLIT_PASS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"

//纹理上传和采样
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);//Wrap和Filter

//这种方法有些平台是无法兼容的
//cbuffer UnityPerMaterial {
//   float4 _BaseColor;
//}

//使用宏来设置常量缓冲区
/*
CBUFFER_START(UnityPerMaterial)
	float4 _BaseColor;
CBUFFER_END
*/

// GPUInstancing的常量缓冲区
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
	//	float4 _BaseColor;
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)//平铺和偏移
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)    //透明裁切
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)



struct Attributes {
    float3 positionOS : POSITION;
    float2 baseUV : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID//获得对象索引
};


struct Varyings {
	float4 positionCS : SV_POSITION;
    float2 baseUV : VAR_BASE_UV;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings UnlitPassVertex(Attributes input)
{
    Varyings output;
    //Instancing
    UNITY_SETUP_INSTANCE_ID(input);//提取索引并存储在一个全局静态变量中
    UNITY_TRANSFER_INSTANCE_ID(input, output);//复制索引

    //MVP
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(positionWS);
    
    //纹理平铺偏移处理
    float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
    output.baseUV = input.baseUV * baseST.xy + baseST.zw;

    return output;
}

float4 UnlitPassFragment(Varyings input) : SV_TARGET
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


	return base;

}


#endif