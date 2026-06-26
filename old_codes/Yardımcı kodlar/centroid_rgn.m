

bw2 = Sol3d;
bw1 = vol_preX;
bw = bw1 | bw2;

s = regionprops3(bw,"Centroid","PrincipalAxisLength");
centers = s.Centroid
diameters = mean(s.PrincipalAxisLength,2)
radii = diameters/2