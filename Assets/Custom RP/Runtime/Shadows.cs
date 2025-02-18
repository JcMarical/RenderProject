using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class Shadows
{
    #region 基本设置

    const string bufferName = "Shadows";

    CommandBuffer buffer = new CommandBuffer() { 
        name = bufferName    
    };

    ScriptableRenderContext context;

    CullingResults cullingResults;

    #endregion

    


    #region 阴影
    ShadowSettings settings;

        const int maxShadowedDirLightCount = 4, maxCascades = 4;  //允许产生阴影的光源数量以及级联阴影数

        struct ShadowedDirectionalLight
        {
            public int visibleLightIndex;   //跟踪产生阴影的光源
            public float slopeScaleBias;
            public float nearPlaneOffset;
    }

        ShadowedDirectionalLight[] ShadowedDirectionalLights = 
            new ShadowedDirectionalLight[maxShadowedDirLightCount];


        int ShadowedDirectionalLightCount = 0;

    //定向阴影图集和级联球体
    static int
        dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas"),
        dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices"),
        cascadeDataId = Shader.PropertyToID("_CascadeData"),                    //级联数据
        shadowAtlasSizeId = Shader.PropertyToID("_ShadowAtlasSize"),            //shader图集大小
        cascadeCountId = Shader.PropertyToID("_CascadeCount"),
        cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres"),
                shadowDistanceFadeId = Shader.PropertyToID("_ShadowDistanceFade");



    static Vector4[] 
        cascadeCullingSpheres = new Vector4[maxCascades],       //级联maxCascades;
        cascadeData = new Vector4[maxCascades];                 //级联向量数组




    //阴影变换矩阵集
    static Matrix4x4[]
        dirShadowMatrices = new Matrix4x4[maxShadowedDirLightCount * maxCascades];


    //PCF设置
    static string[] directionalFilterKeywords = {
        "_DIRECTIONAL_PCF3",
        "_DIRECTIONAL_PCF5",
        "_DIRECTIONAL_PCF7",
    };

    //级联混合
    static string[] cascadeBlendKeywords =
    {
        "_CASCADE_BLEND_SOFT",
        "_CASCADE_BLEND_DITHER"
    };

    #endregion


    #region ShadowMask
    static string[] shadowMaskKeywords = {
        "_SHADOW_MASK_ALWAYS",
        "_SHADOW_MASK_DISTANCE"
    };

    bool useShadowMask;



    #endregion

    #region API
    public void Setup(
        ScriptableRenderContext context, CullingResults cullingResults,
        ShadowSettings settings
    )
    {
        this.context = context;
        this.cullingResults = cullingResults;
        this.settings = settings;
        ShadowedDirectionalLightCount = 0;

        useShadowMask = false;
    }

    //保存光源阴影信息
    public Vector3 ReserveDirectionalShadows(Light light, int visibleLightIndex)
    {
        if (ShadowedDirectionalLightCount < maxShadowedDirLightCount &&
            light.shadows != LightShadows.None && light.shadowStrength > 0f )                        //不可见或没有阴影值
                               
        {
            float maskChannel = -1;

            //阴影遮罩设置
            LightBakingOutput lightBaking = light.bakingOutput;
            if (
                lightBaking.lightmapBakeType == LightmapBakeType.Mixed &&
                lightBaking.mixedLightingMode == MixedLightingMode.Shadowmask
            )
            {
                useShadowMask = true;
                maskChannel = lightBaking.occlusionMaskChannel;
            }
            //本来是出边界，剔除跳过阴影
            if (!cullingResults.GetShadowCasterBounds(
                visibleLightIndex, out Bounds b
            ))
            {
                //后面需要确定是否使用阴影遮罩，再确定是否没有阴影投射物
                return new Vector4(-light.shadowStrength, 0f, 0f, maskChannel);      //但是阴影强度大于0，着色器将对阴影贴图采样，所以使用负阴影强度
            }



            ShadowedDirectionalLights[ShadowedDirectionalLightCount] =
                new ShadowedDirectionalLight
                {
                    visibleLightIndex = visibleLightIndex,
                    slopeScaleBias = light.shadowBias,   //运用灯光配置
                    nearPlaneOffset = light.shadowNearPlane
                };
            return new Vector4(
                light.shadowStrength, 
                settings.directional.cascadeCount * ShadowedDirectionalLightCount++,
                light.shadowNormalBias, maskChannel
            );
        }
        return new Vector4(0f, 0f, 0f, -1f);
    }

    public void Render()
    {
        if(ShadowedDirectionalLightCount > 0)
        {
            RenderDirecionalShadows();
        }
        //不声明的话WebGL2.0会有问题
        else
        {
            buffer.GetTemporaryRT(
                dirShadowAtlasId, 1, 1,
                32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap
            );
        }

        //ShadowMasks设置关键字
        buffer.BeginSample(bufferName);
        SetKeywords(shadowMaskKeywords, useShadowMask?
            QualitySettings.shadowmaskMode == ShadowmaskMode.Shadowmask ? 0 : 1: -1);
        buffer.EndSample(bufferName);
        ExecuteBuffer();

    }

    void RenderDirecionalShadows()
    {
        //设置图集
        int atlasSize = (int)settings.directional.atlasSize;                    //图集大小
        buffer.GetTemporaryRT(dirShadowAtlasId, atlasSize, atlasSize,
            32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);            //32位ARGB的Bilinear渲染纹理

        //设置渲染目标：指示GPU渲染到此纹理
        buffer.SetRenderTarget(
            dirShadowAtlasId,
            RenderBufferLoadAction.DontCare,        //加载:不关心初始初始状态，立刻清除
            RenderBufferStoreAction.Store           //存储:包含阴影数据
        );

        buffer.ClearRenderTarget(true, false, Color.clear); //清除摄像机目标
        buffer.BeginSample(bufferName);
        ExecuteBuffer();

        //级联阴影以及多光源图集拆分
        int tiles = ShadowedDirectionalLightCount * settings.directional.cascadeCount;
        int split = tiles <= 1 ? 1 : tiles <= 4 ? 2 : 4;
        int tileSize = atlasSize / split;

        for (int i = 0; i < ShadowedDirectionalLightCount; i++)
        {
            RenderDirectionalShadows(i, split,tileSize);
        }

        buffer.SetGlobalInt(cascadeCountId, settings.directional.cascadeCount);
        buffer.SetGlobalVectorArray(
            cascadeCullingSpheresId, cascadeCullingSpheres
        );

        buffer.SetGlobalVectorArray(cascadeDataId, cascadeData);            //发送级联数据
        buffer.SetGlobalMatrixArray(dirShadowMatricesId, dirShadowMatrices);
        //发送阴影淡化信息
        float f = 1f - settings.directional.cascadeFade;
        buffer.SetGlobalVector(
            shadowDistanceFadeId,
            new Vector4(1f / settings.maxDistance, 1f / settings.distanceFade, 
                1f / (1f - f * f)
            )
        );



        SetKeywords(directionalFilterKeywords, (int)settings.directional.filter - 1);   //PCF
        SetKeywords(cascadeBlendKeywords, (int)settings.directional.cascadeBlend - 1);  //级联混合模式
        //图集大小
        buffer.SetGlobalVector(
            shadowAtlasSizeId, new Vector4(atlasSize, 1f / atlasSize)
        );



        buffer.EndSample(bufferName);
        ExecuteBuffer();
    }

    void SetKeywords(string[] keywords, int enabledIndex)
    {
        for (int i = 0; i < keywords.Length; i++)
        {
            if (i == enabledIndex)
            {
                buffer.EnableShaderKeyword(keywords[i]);
            }
            else
            {
                buffer.DisableShaderKeyword(keywords[i]);
            }
        }
    }


    Vector2 SetTileViewport(int index, int split, float tileSize)
    {
        Vector2 offset = new Vector2(index % split, index / split);
        buffer.SetViewport(new Rect(
            offset.x * tileSize, offset.y * tileSize, tileSize, tileSize
        ));
        return offset;
    }


    //世界空间转换为阴影图块空间的矩阵
    Matrix4x4 ConvertToAtlasMatrix(Matrix4x4 m, Vector2 offset, int split)
    {
        //反转深度图（OpenGL）
        if (SystemInfo.usesReversedZBuffer)
        {
            m.m20 = -m.m20;
            m.m21 = -m.m21;
            m.m22 = -m.m22;
            m.m23 = -m.m23;
        }
        //裁剪空间[-1,1] To 纹理、坐标、深度[0,1]
        //以及图块偏移和缩放
        float scale = 1f / split;
        m.m00 = (0.5f * (m.m00 + m.m30) + offset.x * m.m30) * scale;
        m.m01 = (0.5f * (m.m01 + m.m31) + offset.x * m.m31) * scale;
        m.m02 = (0.5f * (m.m02 + m.m32) + offset.x * m.m32) * scale;
        m.m03 = (0.5f * (m.m03 + m.m33) + offset.x * m.m33) * scale;
        m.m10 = (0.5f * (m.m10 + m.m30) + offset.y * m.m30) * scale;
        m.m11 = (0.5f * (m.m11 + m.m31) + offset.y * m.m31) * scale;
        m.m12 = (0.5f * (m.m12 + m.m32) + offset.y * m.m32) * scale;
        m.m13 = (0.5f * (m.m13 + m.m33) + offset.y * m.m33) * scale;
        m.m20 = 0.5f * (m.m20 + m.m30);
        m.m21 = 0.5f * (m.m21 + m.m31);
        m.m22 = 0.5f * (m.m22 + m.m32);
        m.m23 = 0.5f * (m.m23 + m.m33);
        return m;
    }

    //渲染平行阴影
    void RenderDirectionalShadows(int index,int split, int tileSize) 
    {
        ShadowedDirectionalLight light = ShadowedDirectionalLights[index];
        var shadowSettings = new ShadowDrawingSettings(cullingResults, light.visibleLightIndex,
            BatchCullingProjectionType.Orthographic);   //Unity2022需要指定正交投影

        //级联阴影设置
        int cascadeCount = settings.directional.cascadeCount;
        int tileOffset = index * cascadeCount;
        Vector3 ratios = settings.directional.CascadeRatios;

        //剔除级联中重复的物体（但要确保阴影投射物永远不会被剔除，不然还得调）
        float cullingFactor =
    Mathf.Max(0f, 0.8f - settings.directional.cascadeFade);

        for (int i = 0; i < cascadeCount; i++)
        {

            cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex, i, cascadeCount, ratios, tileSize, light.nearPlaneOffset,  //可见光下标,级联阴影参数,纹理大小和shadow near plane
                out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix,   //视图矩阵，投影矩阵
                out ShadowSplitData splitData   //阴影分割数据（如何剔除）
            );

            //剔除设置
            splitData.shadowCascadeBlendCullingFactor = cullingFactor;

            shadowSettings.splitData = splitData;//复制到阴影设置

            //级联剔除球体设置（基于摄像机，所以多个光源都一样，只用设置第一盏灯）
            if (index == 0)
            {
                SetCascadeData(i, splitData.cullingSphere, tileSize);
            }

            int tileIndex = tileOffset + i;
            dirShadowMatrices[tileIndex] = ConvertToAtlasMatrix(
                projectionMatrix * viewMatrix,
                SetTileViewport(tileIndex, split, tileSize), split//设置阴影图集视口
            );
            buffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);


            buffer.SetGlobalDepthBias(0, light.slopeScaleBias);  //设置Depth Bias
            ExecuteBuffer();
            context.DrawShadows(ref shadowSettings);//绘制阴影
            buffer.SetGlobalDepthBias(0f, 0f);//回调
        }



    }


    //设置级联阴影数据
    void SetCascadeData(int index, Vector4 cullingSphere, float tileSize)
    {
        float texelSize = 2f * cullingSphere.w / tileSize;  //根据深度计算纹素大小
        float filterSize = texelSize * ((float)settings.directional.filter + 1f);//设置下pcf的滤镜（增加bias匹配滤波器大小）
        cascadeData[index].x = 1f / cullingSphere.w;
        cullingSphere.w -= filterSize;
        cullingSphere.w *= cullingSphere.w;
        cascadeCullingSpheres[index] = cullingSphere;    //用于检查片元是否在球体内部（直接存储平方，不必在着色器计算）

        cascadeData[index] = new Vector4(
            1f / cullingSphere.w,
            filterSize * 1.4142136f  //最坏情况:对角线缩放根号2
        );
    }

    //释放阴影纹理
    public void Cleanup()
    {
        buffer.ReleaseTemporaryRT(dirShadowAtlasId);
        ExecuteBuffer();
    }

    void ExecuteBuffer()
    {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    #endregion

}
