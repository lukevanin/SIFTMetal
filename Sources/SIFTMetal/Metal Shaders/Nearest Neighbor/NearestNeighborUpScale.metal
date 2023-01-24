//
//  NearestNeighborUpScale.metal
//  SkyLight
//
//  Created by Luke Van In on 2023/01/07.
//

#include <metal_stdlib>
using namespace metal;


kernel void nearestNeighborUpScale(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    texture2d<float, access::read> inputTexture [[texture(1)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    ushort2 inputSize = ushort2(inputTexture.get_width(), inputTexture.get_height());
    ushort2 outputSize = ushort2(outputTexture.get_width(), outputTexture.get_height());

    ushort2 scale = outputSize / inputSize;
    outputTexture.write(inputTexture.read(gid / scale), gid);
}
