//
//  SIFTExtrema.metal
//  SkyLight
//
//  Created by Luke Van In on 2023/01/07.
//

#include <metal_stdlib>

#include "SIFTExtrema.h"

using namespace metal;


constant int3 neighborOffsets[] = {
    int3(-1, -1, -1),
    int3( 0, -1, -1),
    int3(+1, -1, -1),
    int3(-1,  0, -1),
    int3( 0,  0, -1),
    int3(+1,  0, -1),
    int3(-1, +1, -1),
    int3( 0, +1, -1),
    int3(+1, +1, -1),
    
    int3(-1, -1,  0),
    int3( 0, -1,  0),
    int3(+1, -1,  0),
    int3(-1,  0,  0),
    
    int3(+1,  0,  0),
    int3(-1, +1,  0),
    int3( 0, +1,  0),
    int3(+1, +1,  0),
    
    int3(-1, -1, +1),
    int3( 0, -1, +1),
    int3(+1, -1, +1),
    int3(-1,  0, +1),
    int3( 0,  0, +1),
    int3(+1,  0, +1),
    int3(-1, +1, +1),
    int3( 0, +1, +1),
    int3(+1, +1, +1),
};


static inline float fetch(
    texture2d_array<float, access::read> texture [[texture(0)]],
    const int2 g,
    const int s,
    const int i
) {
    const int3 neighborOffset = neighborOffsets[i];
    const int2 neighborDelta = g + neighborOffset.xy;
    const int textureIndex = s + neighborOffset.z;
    const float neighborValue = texture.read((ushort2)neighborDelta, (short)textureIndex).r;
    return neighborValue;
}


kernel void siftExtremaList(
    device SIFTExtremaResult * output [[buffer(0)]],
    device atomic_uint * outputCount [[buffer(1)]],
    texture2d_array<float, access::read> inputTexture [[texture(0)]],
    ushort3 gid [[thread_position_in_grid]],
    ushort3 lid [[thread_position_in_threadgroup]],
    ushort tid [[thread_index_in_threadgroup]]
) {
    // Thread group runs [0...output.width - 2][0...output.height - 2]
    const ushort threadsInThreadgroup = 1024;
    threadgroup SIFTExtremaResult localResults[threadsInThreadgroup];
    threadgroup atomic_int localCount;
    atomic_store_explicit(&localCount, 0, memory_order_relaxed);
    threadgroup_barrier(mem_flags::mem_none);
    
    const int2 g = (int2)gid.xy + 1;
    const int s = (int)gid.z + 1;
    const float value = inputTexture.read((ushort2)g, (ushort)s).r;
    
    float minimum = +1000;
    float maximum = -1000;

    for (int i = 1; i < 26; i++) {
        float neighborValue = fetch(inputTexture, g, s, i);
        minimum = min(minimum, neighborValue);
        maximum = max(maximum, neighborValue);
    }

    if ((value < minimum) || (value > maximum)) {
        const int i = atomic_fetch_add_explicit(&localCount, 1, memory_order_relaxed);
        SIFTExtremaResult result;
        result.x = g.x;
        result.y = g.y;
        result.scale = s;
        localResults[i] = result;
    }
    
    // Copy local results to output
    threadgroup_barrier(mem_flags::mem_none);
    if (tid == 0) {
        const int count = atomic_load_explicit(&localCount, memory_order_relaxed);
        if (count > 0) {
            const int b = atomic_fetch_add_explicit(outputCount, count, memory_order_relaxed);
            for (int i = 0; i < count; i++) {
                output[b + i] = localResults[i];
            }
        }
    }
}


kernel void siftExtrema(
    texture2d_array<float, access::write> outputTexture [[texture(0)]],
    texture2d_array<float, access::read> inputTexture [[texture(1)]],
    ushort3 gid [[thread_position_in_grid]],
    ushort3 threadPositionInThreadGroup [[thread_position_in_threadgroup]],
    ushort3 threadsPerThreadGroup [[threads_per_threadgroup]]
) {
    // Thread group runs [0...output.width - 2][0...output.height - 2]
    
    const float value = inputTexture.read(gid.xy + 1, gid.z + 1).r;
    const int2 center = int2(gid.xy);
    
    float minValue = +1000;
    float maxValue = -1000;

    for (int i = 0; i < 26; i++) {
        int3 neighborOffset = neighborOffsets[i];
        ushort textureIndex = gid.z + neighborOffset.x;
        int2 neighborDelta = int2(neighborOffset.yz);
        ushort2 coordinate = ushort2(center + neighborDelta);
        float neighborValue = inputTexture.read(coordinate + 1, textureIndex).r;

        minValue = min(minValue, neighborValue);
        maxValue = max(maxValue, neighborValue);
    }
    
    float result = 0;
    
    if ((value < minValue) || (value > maxValue)) {
        result = 1;
    }

    outputTexture.write(float4(result, 0, 0, 1), gid.xy + 1, gid.z);
}

