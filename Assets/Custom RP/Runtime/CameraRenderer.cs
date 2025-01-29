using UnityEngine;
using UnityEngine.Rendering;

public partial class CameraRenderer
{
    //渲染上下文
    ScriptableRenderContext context;
    //相机
    Camera camera;

    //---------------CommandBuffer-------------------
    const string bufferName = "Render Camera";
    CommandBuffer buffer = new CommandBuffer
    {
        name = bufferName
    };

    //剔除结果
    CullingResults cullingResults;

    //着色器标签ID（目前只提供无光照着色器）
    static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");

    //渲染设置
    public void Render(ScriptableRenderContext context, Camera camera,bool useDynamicBatching, bool useGPUInstancing)
    {
        this.context = context;
        this.camera = camera;

        PrepareBuffer();//多摄像机缓冲准备

        //UI会向场景添加几何体，因此需要在剔除前完成
        PrepareForSceneWindow();    //UI绘制
        if (!Cull())
        {
            return;
        }

        Setup();    //设置
        DrawVisibleGeometry(useDynamicBatching,useGPUInstancing);   //绘制几何
        DrawUnsupportedShaders(); //绘制旧版着色器与几何
        DrawGizmos();
        Submit();   //提交 
    }

    //初始设置
    void Setup()
    {
        context.SetupCameraProperties(camera);//设置View-Peojection矩阵
        CameraClearFlags flags = camera.clearFlags;
        buffer.ClearRenderTarget(
            flags <= CameraClearFlags.Depth, //Skybox,Color,Depth,Nothing
            flags <= CameraClearFlags.Color,
            flags == CameraClearFlags.Color ?
                camera.backgroundColor.linear : Color.clear
        ); //清除渲染目标（帧缓冲）
        buffer.BeginSample(SampleName);     //分析器样本注入profiler便于分析
        ExecuteBuffer(); 
    }


    /// 绘制可视化几何
    void DrawVisibleGeometry(bool useDynamicBatching, bool useGPUInstancing)
    {
        //-------------不透明物体--------------
        var sortingSettings = new SortingSettings(camera)
        {
            criteria = SortingCriteria.CommonOpaque
        };
        var drawingSettings = new DrawingSettings(unlitShaderTagId, sortingSettings)
        {
            enableDynamicBatching = useDynamicBatching,
            enableInstancing = useGPUInstancing
        };
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

        context.DrawRenderers(
            cullingResults, ref drawingSettings, ref filteringSettings
        );
        //-----------------------------------
        context.DrawSkybox(camera);        //绘制天空盒

        //-----------透明物体-----------------
        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        drawingSettings.sortingSettings = sortingSettings;
        filteringSettings.renderQueueRange = RenderQueueRange.transparent;

        context.DrawRenderers(
            cullingResults, ref drawingSettings, ref filteringSettings
        );
        //------------------------------------
    }

  
    //渲染提交
    void Submit()
    {
        buffer.EndSample(SampleName);//关闭profiler样本
        ExecuteBuffer(); //处理Buffer
        context.Submit();
    }

    //执行CommandBuffer
    void ExecuteBuffer()
    {
        context.ExecuteCommandBuffer(buffer);//处理CommandBuffer
        buffer.Clear();
    }

    //剔除
    bool Cull()
    {

        //ScriptableCullingParameters p;
        if (camera.TryGetCullingParameters(out ScriptableCullingParameters p))
        {
            cullingResults = context.Cull(ref p);
            return true;
        }
        return false;
    }
}