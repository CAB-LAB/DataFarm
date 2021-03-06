module SurrogateCube
import Distributions: Normal, Laplace, Cauchy, Categorical
using Docile
#
#
#
# We want to model a disturbed dataset of the form X_xyt = μ + n + M
# where μ is some constant, periodic, or quasiperiodic mean, n is some kind
# of Noise and M is the disturbance

# Define the return Datastructure of genDataset, so that it can be easily saved
type DataCube
	variables::Array{Float64,4}
	components::Array{Float64,4}
	eventmap::Array{Float64,4}
	baselines::Vector
	compnoise::Vector
	events::Vector
	varnoise::Vector
	coupling::Vector
	weight::Vector
	k1::Float64
	k2::Float64
	k3::Float64
	k4::Float64
end
export DataCube
include("noise.jl")
include("baseline.jl")
include("event.jl")
include("io.jl")
include("datafarm.jl")
include("coupling.jl")
include("variableweights.jl")

"""
Function that generates a single datacube, this can serve as a basis to build an independent component of a dataset. The input is as follows:
- mt: Baseline, the process mean
- nt: Noise, the noise chosen
- dt: Event, the disturbance event
- Nlon: Number of longitudes
- Nlat: Number of Latitudes
- Ntime: Number of Time steps
- `kb` : Strength of baseline modulation by event, kb=0 means no modulation, kb=1 means double amplitude, kb=-1 means half amplitude
- `kn` : Strength of noise modulation by event, kn=0, means no modulation, kn=1 double noise, kn=-1 half noise
- `ks`: Strength of mean shift event, ks=0 no shift ks=-1 shift in negative direction by one sd(noise), ks=1 shift by one sd(noise) in positive direction
"""
function genDataStream(mt::Baseline,nt::Noise,dt::Event,Ntime,Nlat,Nlon,kb,kn,ks)
    b  = genBaseline(mt,Ntime,Nlat,Nlon)
    n  = genNoise(nt,Ntime,Nlat,Nlon)
    ev = genEvent(dt,Ntime,Nlat,Nlon)
    x = b .* 2.^(kb*ev) + n .* 2.^(kn*ev) + std(n) * ks * ev
    outevent!(dt,ev)
    return(x,ev)
end
#If only one k is given, apply it to k3
genDataStream(mt::Baseline,nt::Noise,dt::Event,Ntime,Nlat,Nlon,k)=genDataStream(mt,nt,dt,Ntime,Nlat,Nlon,0.0,0.0,k)
export genDataStream

"""
This function generates a whole multivariate datacube, the input is as follows. It needs the followings input:
- mt: Baseline or Vector{Baseline}, the process mean for the components
- nt: Noise or Vector{Noise}, the noise chosen for the independent components
- dt: Event or Vector{Event}, the distirbance events for each component
- dataNoise: Noise or Vector{Noise}, the noise added to each variable of the DataCube
- Ncomp: Number of independent components to generate
- Nvar: Number of variables to generate
- Nlon: Number of longitudes
- Nlat: Number of Latitudes
- Ntime: Number of Time steps
- `kb` : Strength of baseline modulation by event, kb=0 means no modulation, kb=1 means double amplitude, kb=-1 means half amplitude
- `kn` : Strength of noise modulation by event, kn=0, means no modulation, kn=1 double noise, kn=-1 half noise
- `ks` : Strength of mean shift event, ks=0 no shift ks=-1 shift in negative direction by one sd(noise), ks=1 shift by one sd(noise) in positive direction
"""
function genDataCube{T<:Baseline,U<:Noise,V<:Event,W<:Noise}(
	mt::Union{Vector{T},T},
	nt::Union{Vector{U},U},
	dt::Union{Vector{V},V},
	dataNoise::Union{Vector{W},W},
	coupling::Vector,
	weight::Vector,
	Ncomp,
	Nvar,
	Ntime,
	Nlat,
	Nlon,
	kb::Number,
	kn::Number,
	ks::Number,
	kw::Number)
	#Make vectors if single values were given by the user
	mt2 = isa(mt,Vector) ? mt : fill(mt,Ncomp)
	nt2 = isa(nt,Vector) ? nt : fill(nt,Ncomp)
	dt2 = isa(dt,Vector) ? dt : fill(dt,Ncomp)
  dataNoise2 = isa(dataNoise,Vector) ? dataNoise : fill(dataNoise,Nvar)

	# First generate the independent components of the datacube
	acomp = zeros(Float64,Ntime,Nlat,Nlon,Ncomp)
	dcomp = zeros(Float64,Ntime,Nlat,Nlon,Ncomp)

	for i = 1:Ncomp
		x,d = genDataStream(mt2[i],nt2[i],dt2[i],Ntime,Nlat,Nlon,kb,kn,ks)
		acomp[:,:,:,i]=x
		dcomp[:,:,:,i]=d
	end

	# Generate weights to generate variables out of the independent components
	xout = zeros(Float64,Ntime,Nlat,Nlon,Nvar)
  combineComponents!(xout,acomp,dcomp,coupling,dataNoise2,weight,kw)


	DataCube(xout,acomp,dcomp,mt2,nt2,dt2,dataNoise2,coupling,weight,kb,kn,ks,kw)
end
genDataCube{T<:Baseline,U<:Noise,V<:Event,W<:Noise}(mt::Union{Vector{T},T},nt::Union{Vector{U},U},dt::Union{Vector{V},V},dataNoise::Union{Vector{W},W},Ncomp,Nvar,Ntime,Nlat,Nlon,k)=genDataCube(mt,nt,dt,dataNoise,Ncomp,Nvar,Ntime,Nlat,Nlon,0.0,0.0,k)
export genDataCube

"""
This function generates a series of whole multivariate datacubes for a vector of k-values given, the input is as follows. It needs the followings input:
- `mt`: Baseline or Vector{Baseline}, the process mean for the components
- `nt`: Noise or Vector{Noise}, the noise chosen for the independent components
- `dt`: Event or Vector{Event}, the distirbance events for each component
- `dataNoise`: Noise or Vector{Noise}, the noise added to each variable of the DataCube
- `Ncomp`: Number of independent components to generate
- `Nvar`: Number of variables to generate
- `Nlon`: Number of longitudes
- `Nlat`: Number of Latitudes
- `Ntime`: Number of Time steps
- `kb` : Strength of baseline modulation by event, kb=0 means no modulation, kb=1 means double amplitude, kb=-1 means half amplitude, can be a vector
- `kn` : Strength of noise modulation by event, kn=0, means no modulation, kn=1 double noise, kn=-1 half noise, can be a vector
- `ks` : Strength of mean shift event, ks=0 no shift ks=-1 shift in negative direction by one sd(noise), ks=1 shift by one sd(noise) in positive direction, can be a vector
-
"""
function genDataCube{T<:Baseline,U<:Noise,V<:Event,W<:Noise}(mt::Union{Vector{T},T},nt::Union{Vector{U},U},dt::Union{Vector{V},V},dataNoise::Union{Vector{W},W},coupling,weight,Ncomp,Nvar,Ntime,Nlat,Nlon,kb,kn,ks,kw,experimentname,path = joinpath(Pkg.dir(),"SurrogateCube","data"));

    isdir(joinpath(path,experimentname)) ? error("Directory $path already exists.") : mkdir(joinpath(path,experimentname))

    for ikb = 1:length(kb), ikn=1:length(kn), iks=1:length(ks), ikw = 1:length(kw)

        dc = genDataCube(mt,nt,dt,dataNoise,coupling,weight,Ncomp,Nvar,Ntime,Nlat,Nlon,kb[ikb],kn[ikn],ks[iks],kw[ikw])

        save_cube(dc,joinpath(path,experimentname),string("cube_kb",kb[ikb],"kn_",kn[ikn],"_ks",ks[iks],"_kw",kw[ikw],".nc"))
    end
end

end  #Module

include("experiments/small2dfarm.jl")
