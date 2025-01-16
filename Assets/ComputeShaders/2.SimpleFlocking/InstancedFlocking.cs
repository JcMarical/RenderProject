using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class InstancedFlocking : MonoBehaviour
{
    //集群结构
    public struct Boid
    {
        public Vector3 position;
        public Vector3 direction;
        public float noise_offset;//新增一个噪声偏移

        //初始构造

        public Boid(Vector3 pos, Vector3 dir, float offset)
        {
            position.x = pos.x;
            position.y = pos.y;
            position.z = pos.z;
            direction.x = dir.x;
            direction.y = dir.y;
            direction.z = dir.z;
            noise_offset = offset;
        }
    }

    //computeShader
    public ComputeShader shader;


    //集群参数
    public float rotationSpeed = 1f; //旋转速度
    public float boidSpeed = 1f;    //Boid速度
    public float neighbourDistance = 1f;//邻近距离
    public float boidSpeedVariation = 1f;//速度变化
    public Mesh boidMesh;//新增：Mesh
    public Material boidMaterial;//新增：材质
    //public GameObject boidPrefab;//Boid对象的预制体
    public int boidsCount;// Boid的数量
    public float spawnRadius;// boid生成半径
    public Transform target;// 群体移动目标


    //ComputeBuffer相关
    int kernelHandle;           
    ComputeBuffer boidsBuffer;   //集群缓冲
    ComputeBuffer argsBuffer; //新增：argsBuffer传给GPUInsStancing用
    uint[] args = new uint[5] { 0, 0, 0, 0, 0 }; //新增：参数
    Boid[] boidsArray;  //集群数组
    GameObject[] boids; 
    int groupSizeX;
    int numOfBoids;

    Bounds bounds;//新增：AABB盒

    void Start()
    {
        kernelHandle = shader.FindKernel("CSMain");

        uint x;

        shader.GetKernelThreadGroupSizes(kernelHandle, out x, out _, out _);
        
        //线程组数 = 集群数/x的数量
        groupSizeX = Mathf.CeilToInt((float)boidsCount / (float)x);
        numOfBoids = groupSizeX * (int)x; //实际数量（数组对齐）


        bounds = new Bounds(Vector3.zero, Vector3.one * 1000);//1000大小的AABB盒

        InitBoids();
        InitShader();
    }

    /// <summary>
    /// 生成集群
    /// </summary>
    private void InitBoids()
    {
        boidsArray = new Boid[numOfBoids];  //集群数据数组初始化

        for (int i = 0; i < numOfBoids; i++)
        {
            //在圆内随机生成以一个位置
            Vector3 pos = transform.position + Random.insideUnitSphere * spawnRadius;
            //再随机生成一个方向
            Quaternion rot = Quaternion.Slerp(transform.rotation, Random.rotation, 0.3f);
            //随机偏移
            float offset = Random.value * 1000.0f;
            //new一个我不是很懂...
            boidsArray[i] = new Boid(pos, rot.eulerAngles, offset);//随机的位置、方向、偏移
        }
    }

    void InitShader()
    {
        
        boidsBuffer = new ComputeBuffer(numOfBoids, 7 * sizeof(float));
        boidsBuffer.SetData(boidsArray);

        //argsBuffer设置
        argsBuffer = new ComputeBuffer(1, 5 * sizeof(uint), ComputeBufferType.IndirectArguments);
        if (boidMesh != null)
        {
            args[0] = (uint)boidMesh.GetIndexCount(0);
            args[1] = (uint)numOfBoids;
        }
        argsBuffer.SetData(args);



        shader.SetBuffer(kernelHandle, "boidsBuffer", boidsBuffer);
        shader.SetFloat("rotationSpeed", rotationSpeed);
        shader.SetFloat("boidSpeed", boidSpeed);
        shader.SetFloat("boidSpeedVariation", boidSpeedVariation);
        shader.SetVector("flockPosition", target.transform.position);
        shader.SetFloat("neighbourDistance", neighbourDistance);
        shader.SetInt("boidsCount", boidsCount);


        boidMaterial.SetBuffer("boidsBuffer", boidsBuffer);//材质也设置一下boid的buffer
    }

    void Update()
    {
        //时间设置
        shader.SetFloat("time", Time.time);
        shader.SetFloat("deltaTime", Time.deltaTime);
        shader.SetVector("flockPosition", target.transform.position);
        //执行一次computeShader
        shader.Dispatch(kernelHandle, groupSizeX, 1, 1);

        //GPUInstacning优化
        Graphics.DrawMeshInstancedIndirect(boidMesh, 0, boidMaterial, bounds, argsBuffer);
    
    }

    void OnDestroy()
    {
        if (boidsBuffer != null)
        {
            boidsBuffer.Dispose();
        }

        if (argsBuffer != null)
        {
            argsBuffer.Dispose();
        }
    }
}