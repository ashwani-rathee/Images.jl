"""
    shiftedkernel = centered(kernel)

Shift the origin-of-coordinates to the center of `kernel`. The
center-element of `kernel` will be accessed by `shiftedkernel[0, 0,
...]`.

This function makes it easy to supply kernels using regular Arrays,
and provides compatibility with other languages that do not support
arbitrary axes.

See also: [`imfilter`](@ref).
"""
function centered(A::AbstractArray)
    offsetted = first.(axes(A)) .- 1
    total_offsets = .-((size(A) .+ 1 ) .÷ 2)
    OffsetArray(A, total_offsets .- offsetted)
end

"""
    kernfft = freqkernel([T::Type], kern, sz=size(kern); rfft=false)

Return a frequency-space representation of `kern`.
This embeds `kern` in an array of size `sz`, in a manner that implicitly imposes periodic boundary
conditions, and then returns the fourier transform. This is sometimes called the optical transfer
function, and known in some frameworks as `psf2otf`. If `rfft` is `true`, the fft for real-valued
arrays (`rfft`) is returned instead and the first dimension size will be approximately half of `sz[1]`.

`kern` should be zero-centered, i.e., `kern[0, 0]` should reference the center of your kernel.
See [`centered`](@ref). Optionally specify the numeric type `T` (which must be one of the
types supported by FFTW, either `Float32` or `Float64`).

The inverse of `freqkernel` is [`spacekernel`](@ref).
"""
function freqkernel(::Type{T}, kern::AbstractArray, sz::Dims=size(kern); rfft=false) where T<:Union{Float32,Float64}
    wrapindex(i, s) = i<1 ? i+s : i
    all(size(kern) .<= sz) || throw(DimensionMismatch("kernel size $(size(kern)) is bigger than supplied size $sz"))
    kernw = zeros(T, sz...)
    for I in CartesianIndices(kern)
        J = CartesianIndex(map(wrapindex, Tuple(I), sz))
        kernw[J] = kern[I]
    end
    return rfft ? FFTW.rfft(kernw) : fft(kernw)
end
freqkernel(kern::AbstractArray{T}, args...; rfft=false) where T =
    freqkernel(ffteltype(T), kern, args...; rfft=rfft)

"""
    kern = spacekernel(kernfft, axs; rfftsz=0)

Return a real-space representation of `kernfft`, a frequency-space representation of a kernel.
This performs an inverse fourier transform, implicitly imposes periodic boundary conditions,
and then trims & truncates axes of the output to `axs`. By default `kernfft` is assumed to have
been generated by `fft`; if it was instead generated by `rfft`, specify the original size
of the first dimension. (If `kernfft` was generated by [`freqkernel`](@ref), this is just `sz[1]`.)

The inverse of `spacekernel` is [`freqkernel`](@ref).
"""
function spacekernel(kernfft::AbstractArray, axs::Indices; rfftsz=0)
    wrapindex(i, s) = i<1 ? i+s : i
    kernw = rfftsz > 0 ? irfft(kernfft, rfftsz) : ifft(kernfft)
    kern = zeros(eltype(kernw), axs...)
    sz = size(kernw)
    for I in CartesianIndices(kern)
        J = CartesianIndex(map(wrapindex, Tuple(I), sz))
        kern[I] = kernw[J]
    end
    return kern
end
function spacekernel(kernfft::AbstractArray; rfftsz=0)
    sz = size(kernfft)
    if rfftsz > 0
        sz = (rfftsz, Base.tail(sz)...)
    end
    upper = map(s->s>>1, sz)
    axs = map((u, s)-> u-s+1:u, upper, sz)
    return spacekernel(kernfft, axs; rfftsz=rfftsz)
end

ffteltype(::Type{T}) where T<:Union{Float32,Float64} = T
ffteltype(::Type{Float16}) = Float32
ffteltype(::Type{T}) where T<:Normed = ffteltype(FixedPointNumbers.floattype(T))
ffteltype(::Type{T}) where T = Float64

dummyind(::Base.OneTo) = Base.OneTo(1)
dummyind(::AbstractUnitRange) = 0:0

dummykernel(inds::Indices{N}) where {N} = fill(1, map(dummyind, inds))

nextendeddims(inds::Indices) = sum(ind->length(ind)>1, inds)
nextendeddims(a::AbstractArray) = nextendeddims(axes(a))

function checkextended(inds::Indices, n)
    dimstr = n == 1 ? "dimension" : "dimensions"
    nextendeddims(inds) != n && throw(ArgumentError("need $n extended $dimstr, got axes $inds"))
    nothing
end
checkextended(a::AbstractArray, n) = checkextended(axes(a), n)

_reshape(A::OffsetArray{<:Any,N}, ::Val{N}) where N = A
_reshape(A::OffsetArray, ::Val{N}) where {N} = OffsetArray(reshape(parent(A), Val(N)), fill_to_length(A.offsets, -1, Val(N)))
_reshape(A::AbstractArray, ::Val{N}) where {N} = reshape(A, Val(N))

_vec(a::AbstractVector) = a
_vec(a::AbstractArray) = (checkextended(a, 1); a)
_vec(a::OffsetArray{<:Any,1}) = a
function _vec(a::OffsetArray)
    inds = axes(a)
    checkextended(inds, 1)
    i = findall(ind->length(ind)>1, inds)
    OffsetArray(vec(parent(a)), inds[i])
end

samedims(::Val{N}, kernel) where {N} = _reshape(kernel, Val(N))
samedims(::Val{N}, kernel::Tuple) where {N} = map(k->_reshape(k, Val(N)), kernel)
samedims(::AbstractArray{<:Any,N}, kernel) where {N} = samedims(Val(N), kernel)

_tail(R::CartesianIndices{0}) = R
_tail(R::CartesianIndices) = CartesianIndices(tail(axes(R)))

# ensure that overflow is detected, by ensuring that it doesn't happen
# at intermediate stages of the computation
accumfilter(pixelval, filterval) = pixelval * filterval
const SmallInts = Union{UInt8,Int8,UInt16,Int16}
accumfilter(pixelval::SmallInts, filterval::SmallInts) = Int(pixelval)*Int(filterval)
# advice: don't use FixedPoint for the kernel
accumfilter(pixelval::N0f8, filterval::N0f8) = Float32(pixelval)*Float32(filterval)
accumfilter(pixelval::Colorant{N0f8}, filterval::N0f8) = float32(c)*Float32(filterval)

# In theory, the following might need to be specialized. For safety, make it a
# standalone function call.
safe_for_prod(x, ref) = oftype(ref, x)
