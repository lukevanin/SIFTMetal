//
//  siftInterpolate.metal
//  SkyLight
//
//  Created by Luke Van In on 2023/01/07.
//

#include <metal_stdlib>

#include "Common.h"

#include "SIFTInterpolate.h"

using namespace metal;


bool isOnEdge(
    texture2d_array<float, access::read> t [[texture(0)]],
    int x,
    int y,
    int s,
    float edgeThreshold
) {
    const float v = t.read(ushort2(x, y), s).r;
    
    // Compute the 2d Hessian at pixel (i,j) - i = y, j = x
    // IPOL implementation uses hxx for y axis, and hyy for x axis
    const float zn = t.read(ushort2(x, y - 1), s).r;
    const float zp = t.read(ushort2(x, y + 1), s).r;
    const float pz = t.read(ushort2(x + 1, y), s).r;
    const float nz = t.read(ushort2(x - 1, y), s).r;
    const float pp = t.read(ushort2(x + 1, y + 1), s).r;
    const float np = t.read(ushort2(x - 1, y + 1), s).r;
    const float pn = t.read(ushort2(x + 1, y - 1), s).r;
    const float nn = t.read(ushort2(x - 1, y - 1), s).r;

    const float hxx = zn + zp - 2 * v;
    const float hyy = pz + nz - 2 * v;
    const float hxy = ((pp - np) - (pn - nn)) * 0.25;
    
    // Whess
    const float trace = hxx + hyy;
    const float determinant = (hxx * hyy) - (hxy * hxy);
    
    if (determinant <= 0) {
        // Negative determinant -> curvatures have different signs
        return true;
    }
    
//    let edgeThreshold = configuration.edgeThreshold
    const float threshold = ((edgeThreshold + 1) * (edgeThreshold + 1)) / edgeThreshold;
    const float curvature = (trace * trace) / determinant;
    
    if (curvature >= threshold) {
        // Feature is on an edge
        return true;
    }
    
    // Feature is not on an edge
    return false;
}


float3 derivatives3D(
    texture2d_array<float, access::read> t [[texture(0)]],
    int x,
    int y,
    int s
) {
    const float pzz = t.read(ushort2(x + 1, y), s).r;
    const float nzz = t.read(ushort2(x - 1, y), s).r;
    const float zpz = t.read(ushort2(x, y + 1), s).r;
    const float znz = t.read(ushort2(x, y - 1), s).r;
    const float zzp = t.read(ushort2(x, y), s + 1).r;
    const float zzn = t.read(ushort2(x, y), s - 1).r;

    // x: (i[c.z][c.x + 1, c.y] - i[c.z][c.x - 1, c.y]) * 0.5,
    // y: (i[c.z][c.x, c.y + 1] - i[c.z][c.x, c.y - 1]) * 0.5,
    // z: (i[c.z + 1][c.x, c.y] - i[c.z - 1][c.x, c.y]) * 0.5

    return float3(
        (pzz - nzz) * 0.5,
        (zpz - znz) * 0.5,
        (zzp - zzn) * 0.5
    );
}


float interpolateContrast(
    texture2d_array<float, access::read> t [[texture(0)]],
    int x,
    int y,
    int s,
    float3 alpha
) {
    const float3 dD = derivatives3D(t, x, y, s);
    const float3 c = dD * alpha;
    const float v = t.read(ushort2(x, y), s).r;
    return v + c.x * 0.5;
}


// Computes the 3D Hessian matrix.
//  ⎡ Ixx Ixy Ixs ⎤
//
//    Ixy Iyy Iys
//
//  ⎣ Ixs Iys Iss ⎦
float3x3 hessian3D(
    texture2d_array<float, access::read> t [[texture(0)]],
    int x,
    int y,
    int s
) {
    // z = zero, p = positive, n = negative
    const float zzz = t.read(ushort2(x, y), s).r;
    
    const float pzz = t.read(ushort2(x + 1, y), s).r;
    const float nzz = t.read(ushort2(x - 1, y), s).r;
    
    const float zpz = t.read(ushort2(x, y + 1), s).r;
    const float znz = t.read(ushort2(x, y - 1), s).r;

    const float zzp = t.read(ushort2(x, y), s + 1).r;
    const float zzn = t.read(ushort2(x, y), s - 1).r;
    
    const float ppz = t.read(ushort2(x + 1, y + 1), s).r;
    const float nnz = t.read(ushort2(x - 1, y - 1), s).r;
    
    const float npz = t.read(ushort2(x - 1, y + 1), s).r;
    const float pnz = t.read(ushort2(x + 1, y - 1), s).r;
    
    const float pzp = t.read(ushort2(x + 1, y), s + 1).r;
    const float nzp = t.read(ushort2(x - 1, y), s + 1).r;
    const float zpp = t.read(ushort2(x, y + 1), s + 1).r;
    const float znp = t.read(ushort2(x, y - 1), s + 1).r;
    
    const float pzn = t.read(ushort2(x + 1, y), s - 1).r;
    const float nzn = t.read(ushort2(x - 1, y), s - 1).r;
    const float zpn = t.read(ushort2(x, y + 1), s - 1).r;
    const float znn = t.read(ushort2(x, y - 1), s - 1).r;


    // let dxx = pzz + nzz - 2 * v
    // let dyy = zpz + znz - 2 * v
    // let dss = zzp + zzn - 2 * v
    const float dxx = pzz + nzz - 2 * zzz;
    const float dyy = zpz + znz - 2 * zzz;
    const float dss = zzp + zzn - 2 * zzz;

    // let dxy = (ppz - npz - pnz + nnz) * 0.25
    // let dxs = (pzp - nzp - pzn + nzn) * 0.25
    // let dys = (zpp - znp - zpn + znn) * 0.25

    const float dxy = (ppz - npz - pnz + nnz) * 0.25;
    const float dxs = (pzp - nzp - pzn + nzn) * 0.25;
    const float dys = (zpp - znp - zpn + znn) * 0.25;
    
    return float3x3(
        float3(dxx, dxy, dxs),
        float3(dxy, dyy, dys),
        float3(dxs, dys, dss)
    );
}


float3 interpolationStep(
    texture2d_array<float, access::read> t [[texture(0)]],
    int x,
    int y,
    int scale
) {
    const float3x3 H = hessian3D(t, x, y, scale);
    float3x3 Hi = -1.0 * invert(H);
    const float3 dD = derivatives3D(t, x, y, scale);
    return Hi * dD;
}


bool outOfBounds(int x, int y, int scale, int width, int height, int scales) {
    // TODO: Configurable border.
    const int border = 5;
    const int minX = border;
    const int maxX = width - border - 1;
    const int minY = border;
    const int maxY = height - border - 1;
    const int minS = 1;
    const int maxS = scales;
    return x < minX || x > maxX || y < minY || y > maxY || scale < minS || scale > maxS;
}


kernel void siftInterpolate(
    device SIFTInterpolateOutputKeypoint * outputKeypoints [[buffer(0)]],
    device SIFTInterpolateInputKeypoint * inputKeypoints [[buffer(1)]],
    device SIFTInterpolateParameters & parameters [[buffer(2)]],
    texture2d_array<float, access::read> dogTextures [[texture(0)]],
    ushort gid [[thread_position_in_grid]]
) {
    SIFTInterpolateInputKeypoint input = inputKeypoints[gid];
    SIFTInterpolateOutputKeypoint output;
    output.converged = 0;
    outputKeypoints[gid] = output;
    
    float value = dogTextures.read(ushort2(input.x, input.y), input.scale).r;
        
    // Discard keypoint that is way below the brightness threshold
    if (abs(value) <= parameters.dogThreshold * 0.8) {
        return;
    }

    const int maxIterations = parameters.maxIterations;
    const float maxOffset = parameters.maxOffset;
    const int width = parameters.width;
    const int height = parameters.height;
    const int scales = parameters.numberOfScales;
    const float delta = parameters.octaveDelta;

    int x = input.x;
    int y = input.y;
    int scale = input.scale;

    if (outOfBounds(x, y, scale, width, height, scales)) {
        return;
    }

    bool converged = false;
    float3 alpha = float3(0);

    int i = 0;
    while (i < maxIterations) {
        alpha = interpolationStep(dogTextures, x, y, scale);
            
        if ((abs(alpha.x) < maxOffset) && (abs(alpha.y) < maxOffset) && (abs(alpha.z) < maxOffset)) {
            converged = true;
            break;
        }
            
        // Whess
        // coordinate.x += Int(alpha.x.rounded())
        // coordinate.y += Int(alpha.y.rounded())
        // coordinate.z += Int(alpha.z.rounded())
        
        // IPOL
        // TODO: >=
        if (alpha.x > +maxOffset) {
            x += 1;
        }
        if (alpha.x < -maxOffset) {
            x -= 1;
        }
        if (alpha.y > +maxOffset) {
            y += 1;
        }
        if (alpha.y < -maxOffset) {
            y -= 1;
        }
        if (alpha.z > +maxOffset) {
            scale += 1;
        }
        if (alpha.z < -maxOffset) {
            scale -= 1;
        }
        
        if (outOfBounds(x, y, scale, width, height, scales)) {
            return;
        }
        
        i += 1;
    }
        
    if (!converged) {
        return;
    }

    value = interpolateContrast(dogTextures, x, y, scale, alpha);
        
    if (abs(value) <= parameters.dogThreshold) {
        return;
    }
        
    // Discard keypoint with high edge response
    if (isOnEdge(dogTextures, x, y, scale, parameters.edgeThreshold)) {
        return;
    }

    // Return keypoint
    output.converged = 1;
    output.scale = scale;
    output.subScale = alpha.z;
    output.relativeX = x;
    output.relativeY = y;
    output.absoluteX = ((float)x + alpha.x) * delta;
    output.absoluteY = ((float)y + alpha.y) * delta;
    output.value = value;
    output.alphaX = alpha.x;
    output.alphaY = alpha.y;
    output.alphaZ = alpha.z;
    outputKeypoints[gid] = output;
}
