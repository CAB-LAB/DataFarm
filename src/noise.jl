# Define Noise as an abstract type, each subtype should define the following methods:
# genNoise(,n::Noise,Nlon,Nlat,Ntime)
abstract Noise

# White Noise, everything is uncorrelated
type WhiteNoise <: Noise
    σ::Float64
end
genNoise(n::WhiteNoise,Nlon,Nlat,Ntime)=reshape(rand(Normal(0.0,n.σ),Nlon*Nlat*Ntime),Nlon,Nlat,Ntime)