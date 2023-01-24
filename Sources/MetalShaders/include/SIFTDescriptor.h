//
//  SIFTDescriptor.h
//  SkyLight
//
//  Created by Luke Van In on 2023/01/08.
//

#include <simd/simd.h>

#ifndef SIFTDescriptor_h
#define SIFTDescriptor_h


#define SIFT_DESCRIPTOR_HISTOGRAM_WIDTH 4
#define SIFT_DESCRIPTOR_ORIENTATION_BINS 8
#define SIFT_DESCRIPTOR_FEATURE_COUNT 128


struct SIFTDescriptorParameters {
    float delta;
    int32_t scalesPerOctave;
    int32_t width;
    int32_t height;
};


struct SIFTDescriptorInput {
    int32_t keypoint;
    int32_t absoluteX;
    int32_t absoluteY;
    int32_t scale;
    float subScale;
    float theta;
};


struct SIFTDescriptorResult {
    int32_t valid;
    int32_t keypoint;
    float theta;
    int32_t features[SIFT_DESCRIPTOR_FEATURE_COUNT];
};


#endif /* SIFTDescriptor_h */
