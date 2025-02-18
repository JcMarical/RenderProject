#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED






//计算光照，并限制到0-1之间
float3 IncomingLight (Surface surface,  Light light){
	return saturate(dot(surface.normal, light.direction)  * light.attenuation)* light.color;
}


float3 GetLighting (Surface surface, BRDF brdf, Light light) {
	return IncomingLight(surface, light) * DirectBRDF(surface, brdf, light);//处理漫反射
}


float3 GetLighting (Surface surfaceWS,BRDF brdf,GI gi) {
	ShadowData shadowData = GetShadowData(surfaceWS);
	//将gi的shadowMask赋值给shadowData
	shadowData.shadowMask = gi.shadowMask;
	//return gi.shadowMask.shadows.rgb;   //阴影遮罩调试

	float3 color = gi.diffuse * brdf.diffuse;
	for (int i = 0; i < GetDirectionalLightCount(); i++) {
		Light light = GetDirectionalLight(i, surfaceWS, shadowData);
		color += GetLighting(surfaceWS, brdf, light);
	}
	return color;
}


#endif