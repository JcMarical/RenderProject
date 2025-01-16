using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class CustomRenderPipeline : RenderPipeline 
{
    //设置渲染相机渲染器
	CameraRenderer renderer = new CameraRenderer();

    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    { }

    /// <summary>
    /// 渲染函数，SRP入口点
    /// </summary>
    /// <param name="context">渲染上下文</param>
    /// <param name="cameras">相机</param>
    protected override void Render(ScriptableRenderContext context, List<Camera> cameras)
    {
        for (int i = 0; i < cameras.Count; i++)
        {
            renderer.Render(context, cameras[i]);
        }
    }
}