using FFTW

@testset "functions" begin
    ag = rand(Gray{Float32}, 4, 5)
    ac = rand(RGB{Float32}, 4, 5)
    for (f, args) in ((fft, (ag,)), (fft, (ag, 1:2)), (plan_fft, (ag,)),
                      (rfft, (ag,)), (rfft, (ag, 1:2)), (plan_rfft, (ag,)),
                      (fft, (ac,)), (fft, (ac, 1:2)), (plan_fft, (ac,)),
                      (rfft, (ac,)), (rfft, (ac, 1:2)), (plan_rfft, (ac,)))
        dims_str = eltype(args[1])<:Gray ? "1:2" : "2:3"
        ret = @test_throws "channelview, and likely $dims_str" f(args...)
    end
    for (a, dims) in ((ag, 1:2), (ac, 2:3))
        @test ifft(fft(channelview(a), dims), dims) ≈ channelview(a)
        ret = @test_throws "channelview, and likely $dims" rfft(a)
        @test irfft(rfft(channelview(a), dims), 4, dims) ≈ channelview(a)
    end


    a = [RGB(1,0,0), RGB(0,1,0), RGB(0,0,1)]
    @test a' == [RGB(1,0,0) RGB(0,1,0) RGB(0,0,1)]

    a = [RGB(1,0,0) RGB(0,1,0); RGB(0,0,1) RGB(0, 0, 0)]
    @test a' == [RGB(1,0,0) RGB(0,0,1); RGB(0,1,0) RGB(0, 0, 0)]
end

nothing
