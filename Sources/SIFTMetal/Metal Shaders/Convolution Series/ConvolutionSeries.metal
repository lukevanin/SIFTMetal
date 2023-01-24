//
//  Convolution.metal
//  SkyLight
//
//  Created by Luke Van In on 2023/01/07.
//

#include <metal_stdlib>

#include "Common.h"
#include "ConvolutionSeries.h"

using namespace metal;


kernel void convolutionSeriesX(
    texture2d_array<float, access::write> outputTexture [[texture(0)]],
    texture2d_array<float, access::read> inputTexture [[texture(1)]],
    device ConvolutionParameters & parameters [[buffer(0)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    const int width = inputTexture.get_width();
    
    float sum = 0;
    const int n = (int)parameters.count;
    const int o = (int)gid.x - (n / 2);
    for (int i = 0; i < n; i++) {
        int x = symmetrizedCoordinates(o + i, width);
        float c = inputTexture.read(ushort2(x, gid.y), parameters.inputDepth).r;
        sum += parameters.weights[i] * c;
    }
    outputTexture.write(float4(sum, 0, 0, 1), gid, parameters.outputDepth);
}


kernel void convolutionSeriesY(
    texture2d_array<float, access::write> outputTexture [[texture(0)]],
    texture2d_array<float, access::read> inputTexture [[texture(1)]],
    device ConvolutionParameters & parameters [[buffer(0)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    const int height = inputTexture.get_height();
    
    float sum = 0;
    const int n = (int)parameters.count;
    const int o = (int)gid.y - (n / 2);
    for (int i = 0; i < n; i++) {
        int y = symmetrizedCoordinates(o + i, height);
        float c = inputTexture.read(ushort2(gid.x, y), parameters.inputDepth).r;
        sum += parameters.weights[i] * c;
    }
    outputTexture.write(float4(sum, 0, 0, 1), gid, parameters.outputDepth);
}
