//
//  ConvolutionSeries.h
//  SkyLight
//
//  Created by Luke Van In on 2023/01/08.
//

#include <simd/simd.h>

#ifndef ConvolutionSeries_h
#define ConvolutionSeries_h

#define CONVOLUTION_WEIGHTS_LENGTH 32


struct ConvolutionParameters {
    int32_t inputDepth;
    int32_t outputDepth;
    int32_t count;
    float weights[CONVOLUTION_WEIGHTS_LENGTH];
};


#endif /* ConvolutionSeries_h */
