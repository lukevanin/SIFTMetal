//
//  SIFTGradient.metal
//  SkyLight
//
//  Created by Luke Van In on 2023/01/07.
//

#include <metal_stdlib>

#include "Common.hpp"

using namespace metal;


kernel void siftGradient(
     texture2d_array<float, access::write> outputTexture [[texture(0)]],
     texture2d_array<float, access::read> inputTexture [[texture(1)]],
     ushort3 gid [[thread_position_in_grid]]
) {
    const int gx = (int)gid.x;
    const int gy = (int)gid.y;
    const int gz = (int)gid.z;
    const int dx = inputTexture.get_width();
    const int dy = inputTexture.get_height();
    const ushort px = symmetrizedCoordinates(gx + 1, dx);
    const ushort mx = symmetrizedCoordinates(gx - 1, dx);
    const ushort py = symmetrizedCoordinates(gy + 1, dy);
    const ushort my = symmetrizedCoordinates(gy - 1, dy);
    const float cpx = inputTexture.read(ushort2(px, gy), gz).r;
    const float cmx = inputTexture.read(ushort2(mx, gy), gz).r;
    const float cpy = inputTexture.read(ushort2(gx, py), gz).r;
    const float cmy = inputTexture.read(ushort2(gx, my), gz).r;
    const float tx = (cpx - cmx) * 0.5;
    const float ty = (cpy - cmy) * 0.5;
    #warning("FIXME: IPOL implementation swaps dx and dy")
    float oa = atan2(tx, ty);
    float om = sqrt(tx * tx + ty * ty);
    outputTexture.write(float4(oa, om, 0, 0), ushort2(gx, gy), gz);
}

