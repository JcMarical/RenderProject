Shader "Custom RP/Unlit"
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

        //深度写入
        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1 //深度写入开关
    }

    SubShader
    {


    

        Pass
        {
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            HLSLPROGRAM

            //Shader Feature
            //裁切开关（生成不同的Shader变体）
            #pragma shader_feature _CLIPPING 

            #pragma multi_compile_instancing
            //名称识别着色器程序
            #pragma vertex UnlitPassVertex      
            #pragma fragment UnlitPassFragment
            
            //同一文件夹下的 着色器内核Shader Kernels
            #include "UnlitPass.hlsl"

            ENDHLSL
        }
    }
}