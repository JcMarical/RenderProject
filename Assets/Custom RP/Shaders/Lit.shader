Shader "Custom RP/Lit"
{
    Properties
    {
        _BaseMap("Texture", 2D) = "white" {}
		_BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1.0)
        //是枚举类型，但没有int
        //举个例子：src为1，完全添加该颜色，dst为0，完全忽略。
        //透明混合
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend ("Src Blend", Float) = 1//当前绘制的内容
        [Enum(UnityEngine.Rendering.BlendMode)]_DstBlend ("Dst Blend", Float) = 0//之前绘制的内容及结果最终位置
        
        //透明裁切
        _Cutoff("Alpha Cutoff", Range(0.0,1.0)) = 0.5
		[Toggle(_CLIPPING)] _Clipping ("Alpha Clipping", Float) = 0//开关

        //接收阴影
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows ("Receive Shadows", Float) = 1

        //阴影设置
        [KeywordEnum(On, Clip, Dither, Off)] _Shadows ("Shadows", Float) = 0

        //深度写入
        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1 //深度写入开关
    
        //表面特性
        _Metallic ("Metallic",Range(0,1)) = 0
        _Smoothness ("Smoothness",Range(0,1)) = 0.5

        //漫反射预乘Alpha
        [Toggle(_PREMULTIPLY_ALPHA)] _PremulAlpha ("Premultiply Alpha", Float) = 0


        //自发光
        [NoScaleOffset] _EmissionMap("Emission", 2D) = "white" {}
        [HDR] _EmissionColor("Emission", Color) = (0.0, 0.0, 0.0 ,0.0)

        //烘焙透明度，Unity这两个属性是硬编码的需求，所以隐藏了
        [HideInInspector] _MainTex("Texture for Lightmap", 2D) = "white" {}
		[HideInInspector] _Color("Color for Lightmap", Color) = (0.5, 0.5, 0.5, 1.0)
    
    }

    SubShader
    {
        //所有shader都要使用的库
		HLSLINCLUDE
		#include "../ShaderLibrary/Common.hlsl"
		#include "LitInput.hlsl"
		ENDHLSL
		


        Pass
        {
            Tags {
                "LightMode" = "CustomLit"
            }


            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            HLSLPROGRAM

            //避免编译OPENGL ES 2.0及以下的着色器变体
            #pragma target 3.5

            //Shader Feature
            //裁切开关（生成不同的Shader变体）
            #pragma shader_feature _CLIPPING    
            //开启阴影
            #pragma shader_feature _RECEIVE_SHADOWS
            //透明漫反射是否乘以alpha
            #pragma shader_feature _PREMULTIPLY_ALPHA 
            //开启PCF
			#pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
            //级联混合模式
            #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
            //阴影遮罩ShadowMask_distance
            #pragma multi_compile _ _SHADOW_MASK_ALWAYS _SHADOW_MASK_DISTANCE
            //光照贴图
            #pragma multi_compile _ LIGHTMAP_ON
            //GPUInstance
            #pragma multi_compile_instancing
            //名称识别着色器程序
            #pragma vertex LitPassVertex      
            #pragma fragment LitPassFragment
            
            //同一文件夹下的 着色器内核Shader Kernels
            #include "LitPass.hlsl"

            ENDHLSL
        }


        Pass
        {
            Tags{
                "LightMode" = "ShadowCaster"
            }

            ColorMask 0

            HLSLPROGRAM
            #pragma target 3.5
            #pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER
			#pragma multi_compile_instancing
			#pragma vertex ShadowCasterPassVertex
			#pragma fragment ShadowCasterPassFragment
			#include "ShadowCasterPass.hlsl"
            ENDHLSL
        }


                Pass {
			Tags {
				"LightMode" = "Meta"
			}

			Cull Off

			HLSLPROGRAM
			#pragma target 3.5
			#pragma vertex MetaPassVertex
			#pragma fragment MetaPassFragment
			#include "MetaPass.hlsl"
			ENDHLSL
		}
    }

    //编辑器绘制对应类的检查器
    CustomEditor "CustomShaderGUI"
}