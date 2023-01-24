//
//  BilinearUpScale.metal
//  SkyLight
//
//  Created by Luke Van In on 2023/01/07.
//

#include <metal_stdlib>
using namespace metal;


kernel void bilinearUpScale(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    texture2d<float, access::read> inputTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    
    const int wo = outputTexture.get_width();
    const int ho = outputTexture.get_height();
    
    const int wi = inputTexture.get_width();
    const int hi = inputTexture.get_height();
    
    const float dx = (float)wi / (float)wo;
    const float dy = (float)hi / (float)ho;
    
    int i = gid.x;
    int j = gid.y;
    const float x = (float)i * dx;
    const float y = (float)j * dy;
    int im = (int)x;
    int jm = (int)y;
    int ip = im + 1;
    int jp = jm + 1;
    
    //image extension by symmetrization
    if (ip >= wi) {
        ip = 2 * wi - 1 - ip;
    }
    if (im >= wi) {
        im = 2 * wi - 1 - im;
    }
    if (jp >= hi) {
        jp = 2 * hi - 1 - jp;
    }
    if (jm >= hi) {
        jm = 2 * hi - 1 - jm;
    }

    const float fractional_x = x - floor(x);
    const float fractional_y = y - floor(y);
    
    const float c0 = inputTexture.read(uint2(ip, jp)).r;
    const float c1 = inputTexture.read(uint2(ip, jm)).r;
    const float c2 = inputTexture.read(uint2(im, jp)).r;
    const float c3 = inputTexture.read(uint2(im, jm)).r;

    const float output = fractional_x * (fractional_y * c0
                           + (1 - fractional_y) * c1 )
             + (1 - fractional_x) * ( fractional_y  * c2
                           + (1 - fractional_y) * c3 );

    outputTexture.write(float4(output, 0, 0, 1), gid);
}
