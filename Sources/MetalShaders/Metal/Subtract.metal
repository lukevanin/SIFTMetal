//
//  Subtract.metal
//  SkyLight
//
//  Created by Luke Van In on 2023/01/07.
//

#include <metal_stdlib>
using namespace metal;


kernel void subtract(
    texture2d_array<float, access::write> outputTexture [[texture(0)]],
    texture2d_array<float, access::read> inputTexture [[texture(1)]],
    ushort3 gid [[thread_position_in_grid]]
) {
    float4 a = inputTexture.read(gid.xy, gid.z + 1);
    float4 b = inputTexture.read(gid.xy, gid.z);
    float4 c = a - b;
    outputTexture.write(c, gid.xy, gid.z);
}


