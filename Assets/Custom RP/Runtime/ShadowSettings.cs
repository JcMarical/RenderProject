using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public class ShadowSettings 
{
    [Min(0f)]
    public float maxDistance = 100f;                    //阴影最大距离

    [Range(0.001f, 1f)]
    public float distanceFade = 0.1f;                   //距离淡化滑块


    public enum MapSize                                 //阴影贴图精度枚举
    {
        _256 = 256, _512 = 512, _1024 = 1024,
        _2048 = 2048, _4096 = 4096, _8192 = 8192
    }

    public enum FilterMode
    {
        PCF2x2, PCF3x3, PCF5x5,PCF7x7
    }


    [System.Serializable]
    public struct Directional
    {
        public MapSize atlasSize;

        public FilterMode filter;

        [Range(1, 4)]
        public int cascadeCount;

        [Range(0f,1f)]
        public float cascadeRatio1, cascadeRatio2, cascadeRatio3;

        public Vector3 CascadeRatios => new Vector3(cascadeRatio1, cascadeRatio2, cascadeRatio3);

        [Range(0.001f, 1f)]
        public float cascadeFade;

        //级联过渡
        public enum CascadeBlendMode
        {
            Hard, Soft, Dither
        }

        public CascadeBlendMode cascadeBlend;

    }

    public Directional directional = new Directional    //默认精度为1024
    {
        atlasSize = MapSize._1024,
        filter = FilterMode.PCF2x2,
        cascadeCount = 4,
        cascadeRatio1 = 0.1f,
        cascadeRatio2 = 0.25f,
        cascadeRatio3 = 0.5f,
        cascadeFade = 0.1f,
        cascadeBlend = Directional.CascadeBlendMode.Hard
    };


}
