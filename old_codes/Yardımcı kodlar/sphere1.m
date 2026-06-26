% Define the radius and the number of points for the sphere
center = [13, 13, 5]; % Center of the volume
radius = 2;
num_points = 50;

% Define the new center coordinates
center_x = center(1,1);
center_y = center(1,2);
center_z = center(1,3);

% Generate the points on the sphere
[x, y, z] = sphere(num_points);

% Scale the points by the radius
x = radius * x + center_x;
y = radius * y + center_y;
z = radius * z + center_z;

% Plot the sphere
figure;
isosurface(x, y, z);
axis equal; % Equal scaling for all axes
xlabel('X');
ylabel('Y');
zlabel('Z');
title('3D Sphere with Changed Center');


%%
% Define the dimensions of the volume
volume_size = [26, 26, 20]; % Define a 100x100x100 volume

% Create a meshgrid representing the volume
[x, y, z] = meshgrid(1:volume_size(1), 1:volume_size(2), 1:volume_size(3));

% Define the center and radius of the sphere
sphere_center = [13, 13, 5]; % Center of the volume
sphere_radius = 2;

% Calculate the distance of each point in the volume from the center of the sphere
distance = sqrt((x - sphere_center(1)).^2 + (y - sphere_center(2)).^2 + (z - sphere_center(3)).^2);

% Create a binary mask where points within the sphere are 1 and points outside are 0
sphere_mask = distance <= sphere_radius;
sphere_mask = double(sphere_mask);

% Display the volume with the inserted sphere
figure;
slice(x, y, z, sphere_mask, sphere_center(1), sphere_center(2), sphere_center(3));
xlabel('X');
ylabel('Y');
zlabel('Z');
title('Volume with Inserted Sphere');

%%

[X,Y,Z]=meshgrid(linspace(12,14,200),linspace(12,14,200),linspace(4,6,200));
x=X(:);y=Y(:);z=Z(:);
rem=((x-13).^2+(y-13).^2+(z-5).^2)>1^2;
x(rem) = 0.15; y(rem)=0.15;z(rem)=0.15;
figure, scatter3(x,y,z)

% V= zeros(26,26,20);
% q_Y= 0.15;%0.15
% V(x,y,z)= q_Y; %inside rectangular with different quantum yield

%%

% Define sphere parameters
center = [13, 13, 13]; % Center of the volume
radius = 1;

% Define grid
[x, y, z] = meshgrid(linspace(-radius, radius, 100));

% Calculate the distance from each point on the grid to the center of the sphere
distance = sqrt((x - center(1)).^2 + (y - center(2)).^2 + (z - center(3)).^2);

% Create the isosurface
isosurface(x, y, z, distance, radius);

%Adjust plot settings
axis equal;
xlabel('X');
ylabel('Y');
zlabel('Z');
title('Sphere using Isosurface');
view(3); % View in 3D

