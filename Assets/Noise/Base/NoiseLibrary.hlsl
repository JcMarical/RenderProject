#ifndef NoiseLibrary
#define NoiseLibrary
    /// <summary>
    /// blockmin单格纹理最小坐标:每个格子的坐标乘以每格的大小
    /// </summary>
    int3 GetBlockMin(int blockSize, int3 blockCoord) {
        int3 blockMin;
        blockMin.x = blockCoord.x * blockSize;
        blockMin.y = blockCoord.y * blockSize;
        blockMin.z = blockCoord.z * blockSize;
        return blockMin;
    }

    /// <summary>
    /// blockmax单格纹理最大坐标
    /// </summary>
    int3 GetBlockMax(int blockSize, int3 blockCoord) {
        int3 blockMax;
        blockMax.x = blockCoord.x * blockSize + blockSize;
        blockMax.y = blockCoord.y * blockSize + blockSize;
        blockMax.z = blockCoord.z * blockSize + blockSize;
        return blockMax;
    }
    /// <summary>
    /// 纹理坐标转换到网格坐标
    /// </summary>
    int3 PixelCoordToBlockCoord(int blockSize, int3 pixelCoord) {
        int3 blockCoord;
        blockCoord.x = floor(pixelCoord.x / (float)blockSize);
        blockCoord.y = floor(pixelCoord.y / (float)blockSize);
        blockCoord.z = floor(pixelCoord.z / (float)blockSize);
        return blockCoord;
    }

    /// <summary>
    /// float3映射到[-1,1]随机数采样器
    /// </summary>
    float3 GetRandom3To3_Raw(float3 param, float randomSeed) {
        float3 value;
        value.x = length(param) + 58.12 + 79.52 * randomSeed;
        value.y = length(param) + 96.53 + 36.95 * randomSeed;
        value.z = length(param) + 71.65 + 24.58 * randomSeed;
        value.x = sin(value.x) % 1;
        value.y = sin(value.y) % 1;
        value.z = sin(value.z) % 1;
        return value;
    }
    /// <summary>
    /// float3映射到[0,1]的随机数采样器
    /// </summary>
    float3 GetRandom3To3_Remapped(float3 param, float randomSeed) {
        float3 value = GetRandom3To3_Raw(param, randomSeed);
        value.x = (value.x + 1) / 2;
        value.y = (value.y + 1) / 2;
        value.z = (value.z + 1) / 2;
        return value;
    }

#endif