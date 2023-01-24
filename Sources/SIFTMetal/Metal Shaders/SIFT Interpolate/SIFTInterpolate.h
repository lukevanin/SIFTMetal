//
//  SIFTInterpolate.h
//  SkyLight
//
//  Created by Luke Van In on 2023/01/09.
//

#include <simd/simd.h>

#ifndef SIFTInterpolate_h
#define SIFTInterpolate_h


struct SIFTInterpolateParameters {
    float dogThreshold;
    int32_t maxIterations;
    float maxOffset;
    int32_t width;
    int32_t height;
    float octaveDelta;
    float edgeThreshold;
    int32_t numberOfScales;
};


// This should match SIFTExtremaResult
struct SIFTInterpolateInputKeypoint {
    int32_t x;
    int32_t y;
    int32_t scale;
};


struct SIFTInterpolateOutputKeypoint {
    int32_t converged;
    int32_t scale;
    float subScale;
    int32_t relativeX;
    int32_t relativeY;
    float absoluteX;
    float absoluteY;
    float value;
    float alphaX;
    float alphaY;
    float alphaZ;
};


#endif /* SIFTInterpolate_h */
