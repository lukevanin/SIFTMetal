//
//  NearestNeighborDownScale.metal
//  SkyLight
//
//  Created by Luke Van In on 2023/01/07.
//

#include <metal_stdlib>

#import "../include/NearestNeighbor.h"

using namespace metal;


kernel void nearestNeighborDownScale(
    texture2d_array<float, access::write> outputTexture [[texture(0)]],
    texture2d_array<float, access::read> inputTexture [[texture(1)]],
    device NearestNeighborScaleParameters & parameters [[buffer(0)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    outputTexture.write(inputTexture.read(gid * 2, parameters.inputSlice), gid, parameters.outputSlice);
}
