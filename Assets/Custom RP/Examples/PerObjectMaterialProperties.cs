using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[DisallowMultipleComponent]
public class PerObjectMaterialProperties : MonoBehaviour
{
    static int baseColorID = Shader.PropertyToID("_BaseColor");
    static int cutoffId = Shader.PropertyToID("_Cutoff");

    [SerializeField]
    Color baseColor = Color.white;


    [SerializeField, Range(0f, 1f)]
    float cutoff = 0.5f;


    static MaterialPropertyBlock block;

    //加载和被编辑时调用
    private void OnValidate()
    {
        if (block == null)
        {
            block = new MaterialPropertyBlock();

        }
        block.SetColor(baseColorID, baseColor);
        block.SetFloat(cutoffId, cutoff);
        GetComponent<Renderer>().SetPropertyBlock(block);
    }

    private void Awake()
    {
        //由于不会在被构建时调用，所以单独设置一下
        OnValidate();
    }

}
