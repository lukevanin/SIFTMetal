# SIFTMetal

Luke Van In, 2023

An implementation of the Scale Invariant Feature Transform (SIFT) algorithm, for 
Apple devices, written in Swift using Metal compute.

SIFT is described in the paper "Distinctive Image Features from Scale-Invariant 
Keypoints" by David Lowe published in 2004[1].

This implementation is based on the source code from the "Anatomy of the SIFT 
Method" by Ives Ray-Otero and Mauricio Delbracio published in the Image 
Processing Online (IPOL) journal in 2014[2], and source code by Rob Whess[3]. 

The scale-invariant feature transform (SIFT) is a computer vision algorithm to 
detect, describe, and match local features in images, invented by David Lowe in 
1999. Applications include object recognition, robotic mapping and navigation, 
image stitching, 3D modeling, gesture recognition, video tracking, individual 
identification of wildlife and match moving.[4]

A novel Approximate K Nearest Neighbors algorithm is provided for matching SIFT 
descriptors, using a trie data structure. The complexity of the algorithm is:
- Initial construction and update is linear O(n) complexity.
- Nearest neighbor search is O(1) complexity.

SIFT keypoints of objects are first extracted from a set of reference images[1] and stored in a database. An object is recognized in a new image by individually comparing each feature from the new image to this database and finding candidate matching features based on Euclidean distance of their feature vectors. From the full set of matches, subsets of keypoints that agree on the object and its location, scale, and orientation in the new image are identified to filter out good matches. The determination of consistent clusters is performed rapidly by using an efficient hash table implementation of the generalised Hough transform. Each cluster of 3 or more features that agree on an object and its pose is then subject to further detailed model verification and subsequently outliers are discarded. Finally the probability that a particular set of features indicates the presence of an object is computed, given the accuracy of fit and number of probable false matches. Object matches that pass all these tests can be identified as correct with high confidence.[2]
[1]: https://www.cs.ubc.ca/~lowe/papers/ijcv04.pdf "Distinctive Image Features from Scale-Invariant Keypoints", Lowe, International Journal of Computer Vision, 2004
[2]: https://github.com/robwhess/opensift OpenSIFT, Whess, GitHub, 2012
[3]: http://www.ipol.im/pub/art/2014/82/article.pdf "Anatomy of the SIFT Method", Rey-Otero & Delbracio, IPOL, 2014
[4]: https://en.wikipedia.org/wiki/Scale-invariant_feature_transform Scale-invariant feature transform, Wikipedia

