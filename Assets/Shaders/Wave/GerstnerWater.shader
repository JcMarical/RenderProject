Shader "Maric/GerstnerWater"
{
    Properties 
    {
        _ShallowColor("Shallow Color",Color) = (1,1,1,1)
        _DeepColor("Deep Color", Color) = (1,1,1,1)
        _SpecColor("Spec Color", Color) = (1,1,1,1)
        _Shininess("Shininess", Float) = 10
        
        _BumpMap("Bump Map", 2D) = "black" {}
        _BumpScale("Bump Scale", Float) = 1
        _BumpWeight("Bump Weight", Range(0, 1)) = 1
        
        _FlowMap("Flow Map", 2D) = "black" {}
        _FlowStrength("Flow Strength", Float) = 1
        _FlowSpeed("Flow Speed",Float) = 1
        
        
        _SpecIntensity("Spec Intensity", Float) = 1
        _WaveParamA("xy(direction),zw(amplitude, wave length)", Vector) = (0,0,0,0)
        _WaveParamB("xy(direction),zw(amplitude, wave length)", Vector) = (0,0,0,0)
        _WaveParamC("xy(direction),zw(amplitude, wave length)", Vector) = (0,0,0,0)
        _Speed("Speed", Float) = 1
        
        
        _DeepScale("Deep Scale", Float) = 1000
        _DeepCurve("Deep Curve", Float) = 1
        _DeepPower("Deep Power", Float) = 1
        
        _Refraction("Refraction", Range(0, 1)) = 0
        
        _FoamColor("Foam Color", Color) = (1,1,1,1)
        _FoamBias("Foam Bias", Float) = 0
        
        _ReflectBias("Reflect Bias", Vector) = (0,0,0,0)
        _ReflectIntensity("Reflect Intensity", Float) = 1
        
        _FrenelIntensity("Frenel Intensity", Float) = 1
        _FrenelPower("Frenel Power", Float) = 1
        _FrenelThreshold("Frenel Threshold",Range(0, 1)) = 0.5
        
        _CausticMap("Caustic Map", 2D) = "black" {}
        _CausticIntensity("Caustic Intensity", Float) = 1
        _CausticPower("Caustic Power", Float) = 1
        
        [Enum(Off, 0, Front, 1, Back, 2)]_Cull ("Cull", float) = 2
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
        }
        LOD 100

        HLSLINCLUDE
        #include "./Gerstner.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


        struct appdata
        {
            float4 positionOS : POSITION;
            float3 normalOS   : NORMAL;
            float4 tangentOS  : TANGENT;
            float2 uv         : TEXCOORD0;
        };

        struct v2f
        {
            float2 uv : TEXCOORD0;
            float3 normalWS : TEXCOORD1;
            float4 positionCS : SV_POSITION;
            float3 positionWS : TEXCOORD2;
            float4 vertexCS: TEXCOORD3;
            float4 tangentWS: TEXCOORD5;
            float3 normalWSOrigin: TEXCOORD4;
        };

        TEXTURE2D(_BumpMap);               SAMPLER(sampler_BumpMap);
        TEXTURE2D(_FlowMap);               SAMPLER(sampler_FlowMap);
        TEXTURE2D(_CameraOpaqueTexture);   SAMPLER(sampler_CameraOpaqueTexture);
        TEXTURE2D(_CausticMap);            SAMPLER(sampler_CausticMap);

        
        CBUFFER_START(UnityPerMaterial)

        half4 _CausticMap_ST;
        
        half4 _FlowMap_ST;
        float _FlowStrength;
        float _FlowSpeed;
        
        half4 _BumpMap_ST;
        float _BumpScale;
        float _BumpWeight;

        
        half4 _ShallowColor;
        half4 _DeepColor;
        half4 _SpecColor;
        
        float _Shininess;
        float _SpecIntensity;
        
        float4 _WaveParamA;
        float4 _WaveParamB;
        float4 _WaveParamC;
        
        float _Speed;
        float _DeepScale;
        float _DeepCurve;
        float _DeepPower;

        float _Refraction;

         // foam
        half4 _FoamColor;
        float _FoamBias;

        // reflect
        float3 _ReflectBias;
        float _ReflectIntensity;

        float _FrenelIntensity;
        float _FrenelPower;
        float _FrenelThreshold;

        float _CausticPower;
        float _CausticIntensity;

        CBUFFER_END
        
        float SineWave(float4 waveParam, float speed, float x, float z, inout float3 tangent, inout float3 bitangent)
        {
            float amplitude = waveParam.z;
            float waveLength = waveParam.w;
            
            float k = 2 * PI / max(1, waveLength);
            float fx = k * (x - speed);
            float fz = k * (z - speed + 0.5);
            float waveOffset = amplitude * sin(fx) + amplitude * sin(fz);

            tangent = normalize(float3(1, amplitude * k * cos(fx),0));
            bitangent = normalize(float3(0, amplitude * k * cos(fz),1));
            
            return waveOffset;
        }
        
        v2f vert(appdata i)
        {
            v2f o = (v2f)0;

            
            float3 bitangent = 0;
            float3 tangent = 0;
            
            //i.positionOS.y += SineWave(_WaveParam, _Time.y * _Speed, i.positionOS.x, i.positionOS.z, tangent, bitangent);
            float3 wavePos = GerstnerWave(_WaveParamA, _Time.y * _Speed, i.positionOS.xyz, tangent, bitangent);
            wavePos += GerstnerWave(_WaveParamB, _Time.y * _Speed, i.positionOS.xyz, tangent, bitangent);
            wavePos += GerstnerWave(_WaveParamC, _Time.y * _Speed, i.positionOS.xyz, tangent, bitangent);
            i.positionOS.y = wavePos.y;
            i.positionOS.x += wavePos.x;
            i.positionOS.z += wavePos.z;

            o.normalWSOrigin = TransformObjectToWorldNormal(i.normalOS.xyz);
            
            i.tangentOS.xyz = normalize(tangent);
            i.normalOS = normalize(cross(bitangent, tangent));
            
            o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
            o.vertexCS = o.positionCS;
            o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
            o.normalWS = TransformObjectToWorldNormal(i.normalOS.xyz);

            o.tangentWS = float4(TransformObjectToWorldDir(i.tangentOS.xyz), i.tangentOS.w);

            o.uv = i.uv;
            return o;
        }

          float3 FlowUV(float2 uv, float2 flowVector, float time, float phaseOffset = 0)
        {
            float progress = frac(time + phaseOffset);
            float2 resUV;
            float weight = 1 - abs(2 * progress - 1);
            resUV.xy = uv - flowVector * progress;
            return float3(resUV, weight);
        }
        
        half4 frag(v2f i) : SV_TARGET
        {
            half3 baseColor = _ShallowColor.rgb;
            float alpha = _ShallowColor.a;
            
            half3 normalWS = normalize(i.normalWS);


            float2 bumpUV = i.uv.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;
             // flow map
            float2 flowUV = i.uv.xy;
            half4 flowMap = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, flowUV) * 2 - 1;
            flowMap.xy *= _FlowStrength;
            float flowTime = _Time.y * _FlowSpeed + flowMap.a;
            float3 uv0 = FlowUV(bumpUV, flowMap.xy, flowTime);
            float3 uv1 = FlowUV(bumpUV, flowMap.xy, flowTime, 0.5);

            // bump map
            half3 unpackNormalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv0.xy), _BumpScale) * uv0.z
                
               + UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv1.xy), _BumpScale) * uv1.z;
            
            
            
            real3x3 tbn = CreateTangentToWorld(normalWS.xyz, normalize(i.tangentWS).xyz,
                                               i.tangentWS.w > 0.0 ? 1.0 : -1.0);
            half3 normalWSFromBumpMap = normalize(TransformTangentToWorld(unpackNormalTS, tbn));
            
            Light mainLight = GetMainLight();
            half3 lightDir = normalize(mainLight.direction);
            half NdotL = dot(normalWS, lightDir);
            
            normalWS.xy = lerp(normalWS.xy, normalWSFromBumpMap.xy, _BumpWeight);
            normalWS = normalize(normalWS);
            
            // return half4(normalWS, 1.0);
            float3 positionWS = i.positionWS;
            half3 viewDir = normalize(GetWorldSpaceViewDir(positionWS));
            
           
            half3 halfVec = normalize(viewDir + lightDir);
            
           
            half NdotH = dot(normalWS, halfVec);
            half halfLambert = NdotL * 0.5 + 0.5;
            //return half4(halfLambert.xxx, 1.0);

             // 计算屏幕坐标
            float4 screenPos = ComputeScreenPos(i.vertexCS);
            float2 screenUV = screenPos.xy / i.vertexCS.w;
            float2 refractedScreenUV = screenUV + normalWS.xz * _Refraction * 0.05;

          
            // return half4(screenUV.xy, 0, 1.0);
            float3 objectPositionWS = ComputeWorldSpacePosition(
                refractedScreenUV, SampleSceneDepth(refractedScreenUV), UNITY_MATRIX_I_VP);

            // frenel
            half NdotV = dot(normalize(i.normalWSOrigin), viewDir);
            float frenel = 1 - NdotV;
            frenel = saturate(pow(saturate(frenel), _FrenelPower) * _FrenelIntensity);
            
            // refraction
            refractedScreenUV = lerp(screenUV, refractedScreenUV, step(objectPositionWS.y, positionWS.y));

           
            objectPositionWS = ComputeWorldSpacePosition(
                refractedScreenUV, SampleSceneDepth(refractedScreenUV), UNITY_MATRIX_I_VP);
            
            float waterDeep =  abs(positionWS.y - objectPositionWS.y) / max(_DeepScale * 10, 1);
            waterDeep = pow(waterDeep, _DeepPower);
            //return half4(waterDeep.xxx, 1.0);
            float deepFactor = 1 - exp2(-_DeepCurve * waterDeep);

            
             //return half4(deepFactor.xxx, 1.0);
            
            baseColor.rgb = lerp(_ShallowColor.rgb, _DeepColor.rgb, deepFactor);
           
            
            alpha = saturate(lerp(_ShallowColor.a, _DeepColor.a, max(frenel, deepFactor)));

            
            half3 diffuse = max(0.3, halfLambert) * baseColor.rgb;

            float specTerm = _SpecIntensity * pow(saturate(NdotH), _Shininess);
            //return half4(specTerm.xxx, 1.0);
            half3 specular = specTerm * mainLight.color * _SpecColor.rgb;

            
            half3 finalColor = specular + diffuse;

            
            half3 opaqueColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, refractedScreenUV.xy);

            float2 reflectionUV = refractedScreenUV ;
            objectPositionWS = ComputeWorldSpacePosition(
                reflectionUV, SampleSceneDepth(reflectionUV), UNITY_MATRIX_I_VP);


            float3 positionVS = TransformWorldToView(positionWS);
            positionVS.xyz += _ReflectBias.xyz;
            float3 positionWSBias = mul(UNITY_MATRIX_I_V, float4(positionVS, 1.0)).xyz;
            float3 objectPositionAbove = float3(positionWSBias.x , 2 * positionWSBias.y - objectPositionWS.y, positionWSBias.z);
            
            
            float4 screenPosReflect = ComputeScreenPos(TransformWorldToHClip(objectPositionAbove));
            float2 reflectUV = screenPosReflect.xy / screenPosReflect.w + normalWS.xz * _Refraction * 0.05;
            
            half3 indirectSpecular = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, reflectUV);
            indirectSpecular *= _ReflectIntensity;
          //  return half4(indirectSpecular*0.7, 1.0);

           
            indirectSpecular *= saturate(frenel);
            
            flowUV = i.uv.xy * _FlowMap_ST.xy + _FlowMap_ST.zw;
            float foamNoise = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, flowUV + flowTime).a;
            //return half4(foamNoise.xxx, 1.0);

            
            alpha = saturate(max(frenel, alpha));
          // return  half4(frenel.xxx, 1.0);

            // caustic
            float2 causticUV = i.uv.xy * _CausticMap_ST.xy + _CausticMap_ST.zw;


            float causticMask = 1-deepFactor;
            causticMask *= (1-pow(frenel, _CausticPower)) * saturate(NdotL);
            
            half3 causticColor0 = SAMPLE_TEXTURE2D(_CausticMap, sampler_CausticMap, causticUV + flowTime).rgb;
            half3 causticColor1 = SAMPLE_TEXTURE2D(_CausticMap, sampler_CausticMap, causticUV - flowTime).rgb;
            
            causticColor0 *= causticMask ;
            
            causticColor0 *= _CausticIntensity;

            causticColor1 *= causticMask ;
            
            causticColor1 *= _CausticIntensity;
            
            opaqueColor += min(causticColor0, causticColor1);
           
            finalColor = finalColor * alpha + opaqueColor * (1 - alpha) + _FoamColor.rgb * step(deepFactor, _FoamBias * 0.1) * step(0.3,foamNoise);
            finalColor += indirectSpecular;
            alpha = 1.0;
            
            
            //return half4(deepFactor.xxx, 1.0);
            return half4(finalColor, alpha);
        }
        
        ENDHLSL
        Pass
        {

            Tags 
            {
                "LightMode" = "SRPDefaultUnlit"
                "Queue" = "Transparent"
            }
            
            Cull[_Cull]
            BlendOp Add
            Blend SrcAlpha OneMinusSrcAlpha 
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
    }
}