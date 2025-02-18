using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class MeshBall : MonoBehaviour
{
    // Start is called before the first frame update
    static int 
        baseColorId = Shader.PropertyToID("_BaseColor"),
        metallicId = Shader.PropertyToID("_Metallic"),
        smoothnessId = Shader.PropertyToID("_Smoothness");

    [SerializeField]
    Mesh mesh = default;

    [SerializeField]
    Material material = default;

    [SerializeField]
    LightProbeProxyVolume lightProbeVolume = null;

    //一次可以提供多达1023个实例
    Matrix4x4[] matrices = new Matrix4x4[1023];
    Vector4[] baseColors = new Vector4[1023];
    float[]
        metallic = new float[1023],
        smoothness = new float[1023];

    

    MaterialPropertyBlock block;

    void Awake()
    {
        for (int i = 0; i < matrices.Length; i++)
        {
            matrices[i] = Matrix4x4.TRS(
                transform.position + Random.insideUnitSphere * 50f,
                Quaternion.Euler(
                Random.value * 360f, Random.value * 360f, Random.value * 360f
                ),
                Vector3.one * Random.Range(4.5f, 5.5f)
            );
            baseColors[i] =
                new Vector4(Random.value, Random.value, Random.value, 
                Random.Range(0.5f, 1f)
                );
            metallic[i] = Random.value < 0.25f ? 1f : 0f;//%25的金属
            smoothness[i] = Random.Range(0.05f, 0.95f);
        }
    }

    void Update()
    {
        if (block == null)
        {
            block = new MaterialPropertyBlock();
            block.SetVectorArray(baseColorId, baseColors);
            block.SetFloatArray(metallicId, metallic);
            block.SetFloatArray(smoothnessId, smoothness);

            //手动插值光照探针

            if (!lightProbeVolume)
            {
                    var positions = new Vector3[1023];
                for (int i = 0; i < matrices.Length; i++)
                {
                    positions[i] = matrices[i].GetColumn(3);//将第四列提出来
                }
                var lightProbes = new SphericalHarmonicsL2[1023];
                var occlusionProbes = new Vector4[1023];    //遮挡探针数据
                LightProbes.CalculateInterpolatedLightAndOcclusionProbes(
                    positions, lightProbes, occlusionProbes
                );//光照、遮挡探针计算
                block.CopySHCoefficientArraysFrom(lightProbes);//将光照探针复制到块中
                block.CopyProbeOcclusionArrayFrom(occlusionProbes); //遮挡探针
            }

        }


        //批绘制
        Graphics.DrawMeshInstanced(mesh, 0, material, matrices, 1023, block,
            ShadowCastingMode.On, true, 0, null, 
            lightProbeVolume ?
                LightProbeUsage.UseProxyVolume : LightProbeUsage.CustomProvided,    //使用光照探针还是LPPV
            lightProbeVolume);//MeshRenderer的相关设置
        
        //光照转换到线性空间
        GraphicsSettings.lightsUseLinearIntensity = true;
    }
}
