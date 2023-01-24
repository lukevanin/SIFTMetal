//
//  SIFTOrientation.h
//  SkyLight
//
//  Created by Luke Van In on 2023/01/08.
//
#include <simd/simd.h>

#ifndef SIFTOrientation_h
#define SIFTOrientation_h

#define SIFT_ORIENTATION_HISTOGRAM_BINS 36

struct SIFTOrientationParameters {
    float delta;
    float lambda;
    float orientationThreshold;
};


struct SIFTOrientationKeypoint {
    int32_t index;
    int32_t absoluteX;
    int32_t absoluteY;
    int32_t scale;
    float sigma;
};


struct SIFTOrientationResult {
    int32_t keypoint;
    int32_t count;
    float orientations[SIFT_ORIENTATION_HISTOGRAM_BINS];
};

#endif /* SIFTOrientation_h */
