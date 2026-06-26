
% Only clear the 'cfg' variable to avoid clearing other data
clear
clear cfg cfgs
clc

% Define the volume size
volume_size = [51, 51, 20];
cfg.nphoton = 5e7;
cfg.vol = uint8(ones(volume_size)); % Detector field of view (FOV)
cfg.srcpos = [26, 26, 1]; % Source position at the center
cfg.unitinmm = 0.1; %0.2
cfg.srcdir = [0, 0, 1];
cfg.gpuid = 1;
cfg.autopilot = 1;
cfg.issrcfrom0 = 0;
cfg.prop = [0 0 1 1; 0.02 1 1.34 0.81]; % [mua, mus, n, g]
cfg.tstart = 0;
cfg.tend = 100e-9;
cfg.tstep = 100e-10;
cfg.seed = 29012392;
%%
% Define fixed detector positions (4 corners)
fixed_positions = [
    1, 1, 0, 2;   % Fixed detector 1 (bottom-left corner, radius=2)
    1, 51, 0, 2;  % Fixed detector 2 (top-left corner, radius=2)
    51, 1, 0, 2;  % Fixed detector 3 (bottom-right corner, radius=2)
    51, 51, 0, 2; % Fixed detector 4 (top-right corner, radius=2)
];

% Define grid size
grid_size = [9,9]; % [number of detectors in x-direction, number of detectors in y-direction]
detector_radius = 2; % Radius of each detector

% Get the volume size in the xy-plane
volume_size_xy = [51, 51];

% Start placing detectors by filling rows and columns where the fixed points are located
detectors = fixed_positions;

% Identify the rows and columns where fixed detectors are located
fixed_rows = unique(fixed_positions(:, 1));
fixed_cols = unique(fixed_positions(:, 2));

% Place detectors starting from the fixed points
for row = 1:grid_size(1)
    for col = 1:grid_size(2)
        pos_x = (row - 1) * (volume_size_xy(1) - 1) / (grid_size(1) - 1) + 1;
        pos_y = (col - 1) * (volume_size_xy(2) - 1) / (grid_size(2) - 1) + 1;

        % Skip this position if it coincides with one of the fixed detectors
        if ismember(round([pos_x, pos_y]), round(fixed_positions(:, 1:2)), 'rows')
            continue;
        end

        % Add the detector
        detectors = [detectors; pos_x, pos_y, 0, detector_radius];
    end
end

cfg.detpos = detectors;

% Display the number of generated detectors
disp(['Number of detectors: ', num2str(size(detectors, 1))]);

% Plot detector positions
figure;
scatter(detectors(:, 1), detectors(:, 2), 'filled', 'b'); % Detectors in blue
hold on;
scatter(cfg.srcpos(1), cfg.srcpos(2), 'filled', 'r'); % Source in red
title('Detector and Source Positions');
xlabel('X Position');
ylabel('Y Position');
grid on;
axis([0 volume_size_xy(1) 0 volume_size_xy(2)]);
legend('Detectors', 'Source', 'Location', 'best');

%%
% Simulation loop
d_p = size(detectors, 1); % Number of detector positions 
ms = double.empty;

tic
for q = 1:d_p
    cfg.detpos = detectors(q, :);

    % Run the first MCX simulation
    [flux, detp, vol, seeds] = mcxlab(cfg);

    % Ensure correct seed data is passed for the second simulation
    newcfg = cfg;
    newcfg.seed = seeds.data;
    newcfg.outputtype = 'jacobian';
    newcfg.detphotons = detp.data;
    [flux2, detp2, vol2, seeds2] = mcxlab(newcfg);

    % Calculate the sensitivity matrix for this detector position
    jac = sum(flux2.data, 4);
    ms = [ms; sens(jac)]; % Sensitivity matrix
end
toc
%%
% Display the results
figure; 
a_vx = 26 * 26; % FOV area
for z = 1:a_vx
    test = reshape(ms(z, :), 26, 26, 20);
    imagesc(log10(abs(squeeze(test(:, :, 1))))); colorbar
end

%%
% Create a numerical phantom and calculate the b matrix
vol_preX = zeros(26, 26, 20);
q_Y = 0.15; % 0.15
vol_preX(12:14, 12:14, 4:6) = q_Y; % Cube with different quantum yield inside

vol_preX(6:10,10:12,7:7)= q_Y; %
vol_preX(6:6,10:12,3:7)= q_Y;  % 
vol_preX(8:8,10:12,3:7)= q_Y;  % 
vol_preX(10:10,10:12,3:7)= q_Y; % 


X = reshape(vol_preX, [], 1); % X vector
b = ms * X; % Create the detector reading matrix

cfg.ms = ms;
cfg.b = b;

% Save the configuration data
%%save('config_data.mat', 'cfg');

%% Create Sensitivity Matrix%
function m3 = sens(jac)
    vx = 26; % source location
    k = 0;

    for j = vx:-1:1
        for i = vx:-1:1
            m1 = jac(i:vx+i-1, j:vx+j-1, 1:20, 1);
            volm1 = size(m1, 1) * size(m1, 2) * size(m1, 3);
            m2 = reshape(m1, [], volm1);
            k = k + 1;
            m3(k, :) = m2; 
        end
    end
end

