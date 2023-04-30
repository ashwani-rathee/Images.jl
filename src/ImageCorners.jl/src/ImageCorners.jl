module ImageCorners

using ColorTypes
using ColorVectorSpace
using ImageCore: NumberLike
using ImageFiltering
using StaticArrays
using StatsBase

include("utils.jl")
include("cornerapi.jl")

export
    imcorner,
    imcorner_subpixel,
    corner2subpixel,
    harris,
    shi_tomasi,
    kitchen_rosenfeld,
    fastcorners,
    meancovs,
    gammacovs,

    Percentile,
    HomogeneousPoint

end # module ImageCorners
