using SurrogateCube
# Define some Parameters
Ncomp = 3 #We want 3 independent components
Nvar  = 8 # we want 10 measured variables
noise = RedNoise(0.2,1.0,1.0,1.0) #Each component has a noise with sigma=0.5
means = [ConstantBaseline(0.0),ConstantBaseline(0.0),ConstantBaseline(0.0)] # All Baselines are flat
dists = [CubeEvent(0.2),EmptyEvent(),EmptyEvent()] # Only one of the components is disturbed with a size of 20% in each dimension
varNoise = WhiteNoise(0.1) # each variable generated has some independent white noise
k=10.0  # How strongly do we want to perturb
#Set dimensions
Nlon = 10
Nlat = 10
Ntime =100
ds = genDataCube(means,noise,dists,varNoise,Ncomp,Nvar,Ntime,Nlat,Nlon,k);
#Save the datacube to a file
save_cube(ds)
#Plot something
using PyPlot
pygui(true)
f=figure()
#plot(int(d[1,5,5,:][:]))
for i=1:Nvar
plot(ds.variables[:,5,5,i][:])
end




