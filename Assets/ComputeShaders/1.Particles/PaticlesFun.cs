using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PaticlesFun : MonoBehaviour
{
    private Vector2 cursorPos; //存储光标位置

    struct Particle
    {
        public Vector3 position; //粒子位置
        public Vector3 velocity; //粒子速度
        public float life; //粒子生命周期
    }

    const int SIZE_PARTICLE = 7 * sizeof(float);//单个粒子大小


    public int particleCount = 1000000; //粒子数量
    public Material materail; //渲染粒子使用的材料
    public ComputeShader cShader;
    [Range(1, 10)]
    public int pointSize = 2;

    int kernelID;
    ComputeBuffer particleBuffer;

    int groupSizeX;

    /// <summary>
    /// 初始化粒子
    /// </summary>
    private void Init()
    {
        Particle[] particleArray = new Particle[particleCount];

        for(int i =0;i < particleCount; i++)
        {
            //生成随机位置和归一化
            float x = Random.value * 2 -1.0f;
            float y = Random.value * 2 -1.0f;
            float z = Random.value * 2 -1.0f;
            Vector3 xyz = new Vector3(x, y, z);
            xyz.Normalize();
            xyz *= Random.value;
            xyz *= 0.5f;
            

                   // 设置粒子的初始位置和速度
            particleArray[i].position.x = xyz.x;
            particleArray[i].position.y = xyz.y;
            particleArray[i].position.z = xyz.z + 3; // 偏移量为3

            particleArray[i].velocity.x = 0;
            particleArray[i].velocity.y = 0;
            particleArray[i].velocity.z = 0;

            // 设置粒子的生命周期
            particleArray[i].life = Random.value * 5.0f + 1.0f;
        }

        //创建并设置ComputeBuffer
        particleBuffer = new ComputeBuffer(particleCount, SIZE_PARTICLE);
        particleBuffer.SetData(particleArray);

        //查找KernelID
        kernelID = cShader.FindKernel("CSParticle");

        uint threadsX;
        cShader.GetKernelThreadGroupSizes(kernelID, out threadsX,out _,out _);

        groupSizeX = Mathf.CeilToInt((float)particleCount / (float)threadsX);


        //绑定ComputeBuffer到Shader
        cShader.SetBuffer(kernelID, "particleBuffer", particleBuffer);
        materail.SetBuffer("particleBuffer", particleBuffer);
        materail.SetInt("_PointSize", pointSize);

    }

    private void Start()
    {
        Init();
    }

    private void OnRenderObject()
    {
        materail.SetPass(0);
        Graphics.DrawProceduralNow(MeshTopology.Points, 1, particleCount);
    }

    private void OnDestroy()
    {
        //释放buffer资源
        if(particleBuffer != null)
            particleBuffer.Release();
    }

    private void Update()
    {
        float[] mousePosition2D = { cursorPos.x, cursorPos.y };

        //向compute Sahder 发送数据
        cShader.SetFloat("deltaTime", Time.deltaTime);
        cShader.SetFloats("mousePosition", mousePosition2D);

        // 更新粒子状态
        cShader.Dispatch(kernelID, groupSizeX, 1, 1);
    }

    private void OnGUI()
    {
        Vector3 p = new Vector3();
        Camera c = Camera.main;
        Event e = Event.current;
        Vector2 mousePos = new Vector2();

        // 获取鼠标位置，并处理Y坐标反转
        mousePos.x = e.mousePosition.x;
        mousePos.y = c.pixelHeight - e.mousePosition.y;

        p = c.ScreenToWorldPoint(new Vector3(mousePos.x, mousePos.y, c.nearClipPlane + 14));

        cursorPos.x = p.x;
        cursorPos.y = p.y;
    }



}
