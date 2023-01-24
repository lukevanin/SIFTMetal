//
//  SIFTExtrema.h
//  SkyLight
//
//  Created by Luke Van In on 2023/01/10.
//

#include <simd/simd.h>

#ifndef SIFTExtrema_h
#define SIFTExtrema_h

// This should match SIFTInterpolateInputKeypoint
struct SIFTExtremaResult {
    int32_t x;
    int32_t y;
    int32_t scale;
};

#endif /* SIFTExtrema_h */
