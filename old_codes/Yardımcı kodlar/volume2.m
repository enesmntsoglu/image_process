% Define your 3D volume (for demonstration, let's create a binary cube)
% volume = zeros(10, 10, 10);
% volume(3:7, 3:7, 3:7) = 1; % Cube in the center

volume = vol_preX;

% Get the coordinates of non-zero elements
[x, y, z] = ind2sub(size(volume), find(volume));

% Calculate the centroid
centroid = [mean(x), mean(y), mean(z)];

volume_voxels = nnz(volume);

disp('Centroid coordinates:');
disp(centroid);
disp(volume_voxels);
