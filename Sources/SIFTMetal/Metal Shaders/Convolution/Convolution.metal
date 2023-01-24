//
//  Convolution.metal
//  SkyLight
//
//  Created by Luke Van In on 2023/01/07.
//

#include <metal_stdlib>

#include "Common.h"

using namespace metal;


kernel void convolutionX(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    texture2d<float, access::read> inputTexture [[texture(1)]],
    device float * weights [[buffer(0)]],
    device uint & numberOfWeights [[buffer(1)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    const int width = inputTexture.get_width();
    
    float sum = 0;
    const int n = (int)numberOfWeights;
    const int o = (int)gid.x - (n / 2);
    for (int i = 0; i < n; i++) {
        int x = symmetrizedCoordinates(o + i, width);
        sum += weights[i] * inputTexture.read(ushort2(x, gid.y)).r;
    }
    outputTexture.write(float4(sum, 0, 0, 1), gid);
}


kernel void convolutionY(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    texture2d<float, access::read> inputTexture [[texture(1)]],
    device float * weights [[buffer(0)]],
    device uint & numberOfWeights [[buffer(1)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    const int height = inputTexture.get_height();
    
    float sum = 0;
    const int n = (int)numberOfWeights;
    const int o = (int)gid.y - (n / 2);
    for (int i = 0; i < n; i++) {
        int y = symmetrizedCoordinates(o + i, height);
        sum += weights[i] * inputTexture.read(ushort2(gid.x, y)).r;
    }
    outputTexture.write(float4(sum, 0, 0, 1), gid);
}
