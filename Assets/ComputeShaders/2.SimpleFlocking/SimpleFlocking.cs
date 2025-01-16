using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SimpleFlocking : MonoBehaviour
{
    //集群结构
    public struct Boid
    {
        public Vector3 position;
        public Vector3 direction;

        //初始构造
        public Boid(Vector3 pos)
        {
            position.x = pos.x;
            position.y = pos.y;
            position.z = pos.z;
            direction.x = 0;
            direction.y = 0;
            direction.z = 0;
        }
    }

    //computeShader
    public ComputeShader shader;


    //集群参数
    public float rotationSpeed = 1f; //旋转速度
    public float boidSpeed = 1f;    //Boid速度
    public float neighbourDistance = 1f;//邻近距离
    public float boidSpeedVariation = 1f;//速度变化
    public GameObject boidPrefab;//Boid对象的预制体
    public int boidsCount;// Boid的数量
    public float spawnRadius;// boid生成半径
    public Transform target;// 群体移动目标


    //ComputeBuffer相关
    int kernelHandle;           
    ComputeBuffer boidsBuffer;   //集群缓冲
    Boid[] boidsArray;  //集群数组
    GameObject[] boids; 
    int groupSizeX;
    int numOfBoids;

    void Start()
    {
        kernelHandle = shader.FindKernel("CSMain");

        uint x;

        shader.GetKernelThreadGroupSizes(kernelHandle, out x, out _, out _);
        
        //线程组数 = 集群数/x的数量
        groupSizeX = Mathf.CeilToInt((float)boidsCount / (float)x);
        numOfBoids = groupSizeX * (int)x; //实际数量（数组对齐）

        InitBoids();
        InitShader();
    }

    /// <summary>
    /// 生成集群
    /// </summary>
    private void InitBoids()
    {
        boids = new GameObject[numOfBoids]; //gameobject数组（用于生成物体）
        boidsArray = new Boid[numOfBoids];  //集群数据数组初始化

        for (int i = 0; i < numOfBoids; i++)
        {
            //在圆内随机生成以一个位置
            Vector3 pos = transform.position + Random.insideUnitSphere * spawnRadius;
            //new一个我不是很懂...
            boidsArray[i] = new Boid(pos);
            //生成实体，方向都向前
            boids[i] = Instantiate(boidPrefab, pos, Quaternion.identity) as GameObject;
            boidsArray[i].direction = boids[i].transform.forward;
        }
    }

    void InitShader()
    {
        
        boidsBuffer = new ComputeBuffer(numOfBoids, 6 * sizeof(float));
        boidsBuffer.SetData(boidsArray);

        shader.SetBuffer(kernelHandle, "boidsBuffer", boidsBuffer);
        shader.SetFloat("rotationSpeed", rotationSpeed);
        shader.SetFloat("boidSpeed", boidSpeed);
        shader.SetFloat("boidSpeedVariation", boidSpeedVariation);
        shader.SetVector("flockPosition", target.transform.position);
        shader.SetFloat("neighbourDistance", neighbourDistance);
        shader.SetInt("boidsCount", boidsCount);
    }

    void Update()
    {
        //时间设置
        shader.SetFloat("time", Time.time);
        shader.SetFloat("deltaTime", Time.deltaTime);
        shader.SetVector("flockPosition", target.transform.position);
        //执行一次computeShader
        shader.Dispatch(kernelHandle, groupSizeX, 1, 1);

        //拿到计算得到的数据
        boidsBuffer.GetData(boidsArray);

        //再将位置、旋转都赋值过来。
        for (int i = 0; i < boidsArray.Length; i++)
        {
            boids[i].transform.localPosition = boidsArray[i].position;

            if (!boidsArray[i].direction.Equals(Vector3.zero))
            {
                boids[i].transform.rotation = Quaternion.LookRotation(boidsArray[i].direction);
            }

        }
    }

    void OnDestroy()
    {
        if (boidsBuffer != null)
        {
            boidsBuffer.Dispose();
        }
    }
}