using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class VolumeLighting : VolumeComponent,IPostProcessComponent
{
    [Range(0, 3)]
    public FloatParameter lightIntensity = new FloatParameter(0); //光强
    public FloatParameter stepSize = new FloatParameter(0); // 步长
    public FloatParameter maxDistance = new FloatParameter(1000); //最远距离
    public IntParameter maxStep = new IntParameter(0); //最大步数
    public bool IsActive() => lightIntensity.value > 0f;
    public bool IsTileCompatible() => false;
}
