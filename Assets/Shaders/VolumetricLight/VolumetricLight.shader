Shader "PostEffect / VolumeLighting "
{
    Properties
    {
        _MainTex ("", 2D) = "black" {}  //在RenderFeature里面获取相机渲染图来传入
        _MaxStep ("",float) = 200      //设置最大步数
        _MaxDistance ("",float) = 1000   //最大步进距离
        _LightIntensity ("",float) = 0.01 //每次步进叠加的光照强度
        _StepSize ("" , float) = 0.1	 //每次步进距离
    }
     SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        ZWrite Off
		ZTest Always
		Cull Off

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)

        CBUFFER_END
        ENDHLSL

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            // 设置关键字
            #pragma shader_feature _AdditionalLights

            // 接收阴影所需关键字
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _SHADOWS_SOFT

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            struct Attributes
            {
                float4 positionOS: POSITION;
                float3 normalOS: NORMAL;
                float4 tangentOS: TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS: SV_POSITION;
                float3 positionWS: TEXCOORD0;
                float3 normalWS: TEXCOORD1;
                float3 viewDirWS: TEXCOORD2;
                float3 positionOS : TEXCOORD3;
                float2 uv : TEXCOORD4;
            };

            TEXTURE2D_X_FLOAT(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            float _MaxDistance;
            float _MaxStep;
            float _StepSize;
            float _LightIntensity;
            half4 _LightColor0;

            float4 GetTheWorldPos(float2 ScreenUV , float Depth)
			{
				//获取像素的屏幕空间位置
				float3 ScreenPos = float3(ScreenUV , Depth);
				float4 normalScreenPos = float4(ScreenPos * 2.0 - 1.0 , 1.0);
				//得到ndc空间下像素位置
				float4 ndcPos = mul( unity_CameraInvProjection , normalScreenPos );
				ndcPos = float4(ndcPos.xyz / ndcPos.w , 1.0);
				//获取世界空间下像素位置
				float4 sencePos = mul( unity_CameraToWorld , ndcPos * float4(1,1,-1,1));
				sencePos = float4(sencePos.xyz , 1.0);
				return sencePos;
			}

            float GetShadow(float3 posWorld)
            {
                float4 shadowCoord = TransformWorldToShadowCoord(posWorld);
                float shadow = MainLightRealtimeShadow(shadowCoord);
                return shadow;
            }


            Varyings vert(Attributes v)
            {
                Varyings o;
                // 获取不同空间下坐标信息
                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = positionInputs.positionCS;
                o.uv = v.uv;
                return o;
            }


          half4 frag(Varyings i): SV_Target
            {
                float2 uv = i.uv;
                //采用深度图
                float depth =  SAMPLE_TEXTURE2D_X(_CameraDepthTexture,sampler_CameraDepthTexture, uv).r;
                depth = 1-depth;//得到深度值，主要我们需要越远深度越大
 //定义光线步进起始点这里直接给摄像机，有些文章会用近裁面，其实大可不必那么麻烦
                float3 ro = _WorldSpaceCameraPos.xyz;
                //用一用我们刚才写的函数，现在就得到了屏幕上所有像素的世界空间位置
                float3 worldPos = GetTheWorldPos(uv , depth).xyz;
                //这里我们需要计算步进方向，高中就学过吧，终点位置-起点位置就能得到步进方向了
                //不过我们需要的只是方向还需要把向量化为单位向量
                float3 rd = normalize(worldPos - ro);
                //这里我们需要拿一个值来记录一下当前位置，初始值用起始点
                float3 currentPos = ro;
                //这里按照之前说的，我们在被遮挡或达到最大距离就停止，这里我们取一个最小值就                 //okkk了
                float m_length = min(length(worldPos - ro) , _MaxDistance);
                //每次步进的长度
                float delta = _StepSize;
                //叠加后总的光照强度，初始值给0
                float totalInt = 0;
                //记录一下步进距离
                float d = 0;
                //开始光线步进计算
                for(int j = 0; j < _MaxStep; j++)
                {
                    d += delta;
                    if(d > m_length) break; //距离大于设定的距离跳出循环
                    currentPos += delta * rd;
                    totalInt += _LightIntensity * GetShadow(currentPos);
                }
                half3 lightCol = totalInt * _LightColor0.rgb;
                half3 oCol = SAMPLE_TEXTURE2D(_MainTex , sampler_MainTex , uv).rgb;
                half3 dCol = lightCol + oCol;//和我们摄像机的颜色叠加一下
                return real4(dCol , 1);

            }

            ENDHLSL

        }
        //下面计算阴影的Pass可以直接通过使用URP内置的Pass计算
        //UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        // or
        // 计算阴影的Pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            Cull Off
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM

            // 设置关键字
            #pragma shader_feature _ALPHATEST_ON

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;

            struct Attributes
            {
                float4 positionOS: POSITION;
                float3 normalOS: NORMAL;
            };

            struct Varyings
            {
                float4 positionCS: SV_POSITION;
            };

            // 获取裁剪空间下的阴影坐标
            float4 GetShadowPositionHClips(Attributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                // 获取阴影专用裁剪空间下的坐标
                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

                // 判断是否是在DirectX平台翻转过坐标
                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif

                return positionCS;
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = GetShadowPositionHClips(input);
                return output;
            }


            half4 frag(Varyings input): SV_TARGET
            {
                return half4(0,0,0,1);
            }

            ENDHLSL

        }
    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}
