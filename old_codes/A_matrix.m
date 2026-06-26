% Only clear the 'cfg' variable to avoid clearing other data
clear
clear cfg cfgs
clc
% Define the volume size
volume_size = [20, 20, 10];
cfg.nphoton = 5e7;
cfg.vol = uint8(ones(volume_size)); % Detector field of view (FOV)
cfg.srcpos = [10, 10, 1]; % Source position at the center
cfg.unitinmm = 0.1; % Unit size in mm
cfg.srcdir = [0, 0, 1];
cfg.gpuid = 1;
cfg.autopilot = 1;
cfg.issrcfrom0 = 0;
cfg.prop = [0 0 1 1; 0.02 1 1.34 0.81]; % [mua, mus, næ, g]
cfg.tstart = 0;
cfg.tend = 100e-9;
cfg.tstep = 100e-10;
cfg.seed = 29012392;
%% Define the detector grid parameters
grid_size = [10, 10 ]; % [number of detectors along x, number of detectors along y]
detector_radius = 2; % radius of each detector
% Select whether to use manual spacing
use_manual_spacing = 2; % Set this to 1 for manual, 0 for automatic
if use_manual_spacing
% Manually set the spacing
spacing_x_manual = 2; % Manually set the spacing in x direction
spacing_y_manual = 2; % Manually set the spacing in y direction
% Check if manual spacing exceeds volume size
max_extent_x = cfg.srcpos(1) + (grid_size(1)-1)/2 * spacing_x_manual;
max_extent_y = cfg.srcpos(2) + (grid_size(2)-1)/2 * spacing_y_manual;
if max_extent_x > volume_size(1) || max_extent_y > volume_size(2)
error('Manual spacing exceeds volume size. Please adjust the spacing or grid size.');
end
% Generate detector positions manually around the source point
[det_x_manual, det_y_manual] = meshgrid(-floor(grid_size(1)/2):floor(grid_size(1)/2), -floor(grid_size(2)/2):floor(grid_size(2)/2));
det_x_manual = det_x_manual * spacing_x_manual + cfg.srcpos(1);
det_y_manual = det_y_manual * spacing_y_manual + cfg.srcpos(2);
% Create detector positions and remove the source position
detpos = [det_x_manual(:), det_y_manual(:), zeros(numel(det_x_manual), 1), repmat(detector_radius, numel(det_x_manual), 1)];
is_source = (detpos(:, 1) == cfg.srcpos(1)) & (detpos(:, 2) == cfg.srcpos(2));
detpos_filtered = detpos(~is_source, :);
else
% Automatically calculate the spacing based on grid size and source point
spacing_x_auto = floor(volume_size(1) / (grid_size(1) + 1));
spacing_y_auto = floor(volume_size(2) / (grid_size(2) + 1));
% Check if automatic spacing exceeds volume size
max_extent_x = cfg.srcpos(1) + (grid_size(1)-1)/2 * spacing_x_auto;
max_extent_y = cfg.srcpos(2) + (grid_size(2)-1)/2 * spacing_y_auto;
if max_extent_x > volume_size(1) || max_extent_y > volume_size(2)
error('Automatic spacing exceeds volume size. Please adjust the grid size or source position.');
end
% Generate detector positions automatically around the source point
[det_x_auto, det_y_auto] = meshgrid(-floor(grid_size(1)/2):floor(grid_size(1)/2), -floor(grid_size(2)/2):floor(grid_size(2)/2));
det_x_auto = det_x_auto * spacing_x_auto + cfg.srcpos(1);
det_y_auto = det_y_auto * spacing_y_auto + cfg.srcpos(2);
% Create detector positions and remove the source position
detpos = [det_x_auto(:), det_y_auto(:), zeros(numel(det_x_auto), 1), repmat(detector_radius, numel(det_x_auto), 1)];
is_source = (detpos(:, 1) == cfg.srcpos(1)) & (detpos(:, 2) == cfg.srcpos(2));
detpos_filtered = detpos(~is_source, :);
end
cfg.detpos = detpos_filtered;
% Display the number of detectors generated
disp(['Number of detectors: ', num2str(size(detpos_filtered, 1))]);
% Plot detector positions
figure;
scatter(detpos_filtered(:, 1), detpos_filtered(:, 2), 'filled', 'b'); % Detectors in blue
hold on;
scatter(cfg.srcpos(1), cfg.srcpos(2), 'filled', 'r'); % Source in red
title('Detector and Source Positions');
xlabel('X Position');
ylabel('Y Position');
grid on;
axis([0 volume_size(1) 0 volume_size(2)]);
legend('Detectors', 'Source', 'Location', 'best');
%% Simulation loop
d_p = size(detpos_filtered, 1); % Number of detector positions
ms = double.empty;
tic
for q = 1:d_p
cfg.detpos = detpos_filtered(q, :);
% Run the first MCX simulation
[flux, detp, vol, seeds] = mcxlabcl(cfg);
% Ensure correct seed data is passed for the second simulation
newcfg = cfg;
newcfg.seed = seeds.data;
newcfg.outputtype = 'jacobian';
newcfg.detphotons = detp.data;
[flux2, detp2, vol2, seeds2] = mcxlabcl(newcfg);
% Calculate the sensitivity matrix for this detector position
jac = sum(flux2.data, 4);
ms = [ms; sens(jac)]; % Sensitivity matrix
end
toc
%%
% Display the results
figure;
a_vx = 10 * 10; % FOV area
for z = 1:a_vx
test = reshape(ms(z, :), 10, 10, 10);
imagesc(log10(abs(squeeze(test(:, :, 1))))); colorbar
%waitforbuttonpress
end
%%
vol_preX = zeros(10, 10, 10);
q_Y = 0.15; % 0.15
 
% vol_preX(1:2,1:2,1:2) = q_Y;

vol_preX(3, 3:7, 4:6) = q_Y;
vol_preX(3:8, 3, 4:6) = q_Y;
vol_preX(3:8, 7, 4:6) = q_Y;
vol_preX(5, 3:7, 4:6) = q_Y;


% vol_preX(2:5,2:4,4:4)= q_Y; %
% vol_preX(2:2,2:4,1:4)= q_Y;  % 
% % vol_preX(4:4,2:4,1:4)= q_Y;  % 
% vol_preX(6:6,2:4,1:4)= q_Y; % 

X = reshape(vol_preX, [], 1); % X vector
b = ms * X; % Create the detector reading matrix

cfg.ms = ms;
cfg.b = b;

%%
cfg.volue_size = volume_size;
cfg.grid_size = grid_size;
cfg.detector_radius = detector_radius;
cfg.spacing_x_manual = spacing_x_manual;
cfg.spacing_y_manual = spacing_y_manual;
%%
%% Create Sensitivity Matrix%
function m3 = sens(jac)
vx = 10; % source location
k = 0;
for j = 1:vx
for i = 1:vx
m1 = jac(i:vx+i-1 , ...
j:vx+j-1 , ...
1:10, 1) ; % Blok seçimi (sabit boyutlu)
volm1 = size(m1, 1) * size(m1, 2) * size(m1, 3); % Blok hacmi
m2 = reshape(m1, [], volm1); % Blok düzleştirilmesi
k = k + 1;
m3(k, :) = m2; % Satır olarak eklenmesi
end
end
end