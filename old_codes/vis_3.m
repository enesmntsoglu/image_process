% % Define the Excel filename and sheet name
% filename = 'enes_cube_parameters.xlsx';
% sheet = 'Sheet1';
% 
% % Display the filename and sheet being used
% disp(['Writing to file: ', filename]);
% disp(['Using sheet: ', sheet]);
% 
% % Check if the Excel file exists
% if isfile(filename)
%     % Read the current data to determine the next row to write
%     try
%         dataTable = readtable(filename, 'Sheet', sheet);
%         nextRow = height(dataTable) + 1;
%     catch
%         % If sheet not found, start from the first row
%         nextRow = 1;
%         dataTable = table();
%     end
% else
%     % If file does not exist, start from the first row
%     nextRow = 1;
%     dataTable = table();
% end
% 
% % Display the next row to be written
% disp(['Next row to be written: ', num2str(nextRow)]);


%% Lp Solver Parameter Setting for SENS
b_norm = b ./ max(b(:));
sens_norm = ms ./ max(ms(:));
[~, n] = size(sens_norm);

tic
E = sens_norm' * sens_norm;
toc

Recon.rootfact = 0.50; % 0.5
tic;
Dtmp = (eye(n) * diag(E)).^Recon.rootfact;
toc
D = Dtmp ./ max(Dtmp);
clear Dtmp
%% Lp Solver for SENS
tic
lambda_Lcurve = 2; % 0.8; 7 for D1
i = 1;
Recon.lambda_iter = lambda_Lcurve;
Recon.eps = 1e-10; % 1 for p=1/4
Recon.p = 1; % 1/4
Recon.tol = 1e-3;
Recon.max_itr = 10000;
Recon.nu = 1e-4;
x_initial = zeros(n, 1);
tic
x_approxLp = Lp_solver_depthver2(sens_norm, b_norm, Recon.p, Recon.lambda_iter(i), ...
    Recon.tol, Recon.max_itr, Recon.nu, ...
    Recon.eps, x_initial, D); %% LP_solver from mcx
Recon.timeRecon = toc;
load gong.mat;
sound(y / 32, Fs);
display(Recon.lambda_iter(i));
clear Fs
toc

Sol3d = reshape(x_approxLp, size(vol_preX, 1), size(vol_preX, 2), size(vol_preX, 3));
%%
% Threshold the volumetric image to create a binary image
%volimage = vol_preX;  
volimage = Sol3d;
volimage_binary = volimage > 0.05;  % Adjust threshold as needed

% Define the parameters for the vol2surf function
ix = 1:size(volimage, 1);
iy = 1:size(volimage, 2);
iz = 1:size(volimage, 3);
opt = struct('radbound', 1, 'distbound', 0.01, 'maxsurf', 1);  % Adjusted for fine control
method = 'cgalsurf';  % Correct mesh generation method
dofix = 1;  % Perform mesh validation & repair
isovalues = [0.5];  % Adjust isovalues as needed for mesh extraction

% Call the vol2surf function
[node, elem, regions, holes] = vol2surf(volimage_binary, ix, iy, iz, opt, dofix, method, isovalues);

% Visualize the resulting mesh
figure;
plotmesh(node, elem);
title('Generated Volumetric Mesh');
axis equal;

%%
% %% Mesh Generation and Visualization 
test = sum(Sol3d(:, :, 1:end));
figure; imagesc(squeeze(test)'); colorbar

volimage = Sol3d;
%volimage = vol_preX;
[node, elem, face] = vol2mesh(volimage > 0.05, 1:size(volimage, 1), 1:size(volimage, 2), ...
                              1:size(volimage, 3), 2, 2, 'cgalsurf'); 


figure;
plotmesh(node, face);
title(['RootFactor ', num2str(Recon.rootfact)])
axis equal;

%%
%visualize the resulting mesh
figure;
%isosurface(vol)
isosurface(vol_preX)
%title('3D Reconstruction vs. Original Construction')
axis equal;
%xlim([1,51]);ylim([1,51]);zlim([1,20])
hold on
%isosurface(vol_preX);
%title('3D Construction of Given Values')
axis equal;
%xlim([1,51]);ylim([1,51]);zlim([1,20])
hold off


%% ??

% x_approxLp = Recon.LoopXs{1}; % 
% 
% % Hücre dizisi ise, sayısal diziye dönüştürme
% if iscell(x_approxLp)
%     x_approxLp = cell2mat(x_approxLp);
% end
% 
% iso_value işlemi
% iso_value = 0.5;
% x_approxLp(x_approxLp < max(x_approxLp) * iso_value) = 0;


%% Apply iso value to x_approxLp
iso_value = 0.5;
x_approxLp(x_approxLp < max(x_approxLp) * iso_value) = 0;
Sol3d = reshape(x_approxLp, size(vol_preX, 1), size(vol_preX, 2), size(vol_preX, 3));

%% reconst

figure; 
for i = 1:20
    test = squeeze(Sol3d(:, :, i))';
    imagesc(test); colorbar
    pause(0.01)
  %  waitforbuttonpress
end
%% phantom
figure; 
for i = 1:20
    test = squeeze(vol_preX(:,:,i))';
    imagesc(test);colorbar
   pause(0.01)
    waitforbuttonpress
end

%% Graph
figure;
plot(x_approxLp, 'r-', 'LineWidth', 1.5); % x_approxLp kırmızı 
hold on
plot(X, 'b--', 'LineWidth', 1.5); % X mavi kesik çizgi
hold off
title(['Lambda ', num2str(lambda_Lcurve)])
xlabel('x_approxLp')
ylabel('X Cube')
legend('x\_approxLp', 'X', 'Location', 'Best') % hangi çizgi kimin
grid on


%% Calculate SBR and Background Noise (ENES)

signal_intensity = mean(Sol3d(vol_preX > 0));
background_intensity = mean(Sol3d(vol_preX == 0));
background_noise = std(Sol3d(vol_preX == 0));

% Calculate SBR
sbr = signal_intensity / background_intensity;

% Calculate CNR based on net (cnr_old)
cnr_old = (sbr - 1) * (background_intensity / background_noise);

% Calculate CNR based on paper (cnr_new)
cnr_new = (signal_intensity - background_intensity) / background_noise;

% Display results
disp(['Signal Intensity: ', num2str(signal_intensity)]);
disp(['Background Intensity: ', num2str(background_intensity)]);
disp(['Background Noise: ', num2str(background_noise)]);
disp(['SBR: ', num2str(sbr)]);
disp(['CNR (Old): ', num2str(cnr_old)]);
disp(['CNR (New): ', num2str(cnr_new)]);


%% Calculation of various Quality values of Reconstructed Volume (KAZIM)
x_approxLp = double(x_approxLp);
% [peaksnr, snr] = psnr(x_approxLp, X);
% 
% Recon.snr = snr;
% Recon.peaksnr = peaksnr;

% [ssimval, ssimmap] = ssim(x_approxLp, X);
% Recon.ssimval = ssimval;

Sol3d = double(Sol3d);
[score, qualityMaps] = multissim3(Sol3d, vol_preX);
min_score = min(qualityMaps{:,1}, [], [1 2 3]);
max_score = max(qualityMaps{:,1}, [], [1 2 3]);
Recon.score = score;
Recon.min_score = min_score;

image_contrast = 100 - ((max_score - min_score) / std2(X - x_approxLp));
%% Quality metrics calculation (ENES)

original_volume = vol_preX; % Original volume data
reconstructed_volume = Sol3d; % Reconstructed volume data

[volume_error_1, centroid_error_1, contrast_value_1] = quality_metrics(original_volume, reconstructed_volume);

% Calculate percentage values
volume_error_percentage_1 = (volume_error_1 / nnz(original_volume)) * 100;
max_distance_1 = norm(size(original_volume));
centroid_error_percentage_1 = (centroid_error_1 / max_distance_1) * 100;
contrast_percentage_1 = (contrast_value_1 / max(reconstructed_volume(:))) * 100;

disp(['Volume Error: ', num2str(volume_error_1), ' (', num2str(volume_error_percentage_1), '%)']);
disp(['Centroid Error: ', num2str(centroid_error_1), ' (', num2str(centroid_error_percentage_1), '%)']);
disp(['Contrast: ', num2str(contrast_value_1), ' (', num2str(contrast_percentage_1), '%)']);

%% Visualization of Reconstructed 3D Object (KAZIM)

figure;
isosurface(Sol3d);
title('Oluşturulan Nesne ile Ele Edilen Nesnenin Karşılaştırılması');
axis equal;
grid on;

xlim([1, 30]); ylim([1, 30]); zlim([1, 30]);
xticks(0:1:51);
tickLabels = arrayfun(@(x) sprintf('%g mm', x*0.1), 0:1:30, 'UniformOutput', false);
xticklabels(tickLabels);

yticks(0:1:30);
tickLabels = arrayfun(@(y) sprintf('%g mm', y*0.1), 0:1:30, 'UniformOutput', false);
yticklabels(tickLabels);

zticks(0:1:20);
tickLabels = arrayfun(@(z) sprintf('%g mm', z*0.1), 0:1:30, 'UniformOutput', false);
zticklabels(tickLabels);

hold on;
isosurface(vol_preX);
alpha(0.5); % Adjust the value as needed (0.5 for 50% transparency)
hold off;
%%  Hesaplamalarda hata yapıyorum. biraz daha araştırma yapıp tekrar dene kesik görüntülemeye uysun.
figure;

% Visualization of Original 3D Object
subplot(1, 3, 1);
h1 = patch(isosurface(vol_preX, max(vol_preX(:)) * 0.3)); % Adjust the threshold as needed
isonormals(vol_preX, h1);
set(h1, 'FaceColor', 'red', 'EdgeColor', 'none', 'FaceAlpha', 0.5); % Transparanlık eklendi
title('Original Object');
axis equal;
grid on;

% Visualization of Reconstructed 3D Object
subplot(1, 3, 2);
h2 = patch(isosurface(Sol3d, max(Sol3d(:)) * 0.3)); % Adjust the threshold as needed
isonormals(Sol3d, h2);
set(h2, 'FaceColor', 'blue', 'EdgeColor', 'none', 'FaceAlpha', 0.5); % Transparanlık eklendi
title('Reconstructed Object');
axis equal;
grid on;

% Overlay of Original and Reconstructed 3D Objects
subplot(1, 3, 3);
h3 = patch(isosurface(vol_preX, max(vol_preX(:)) * 0.3)); % Original object in red
isonormals(vol_preX, h3);
set(h3, 'FaceColor', 'red', 'EdgeColor', 'none', 'FaceAlpha', 0.5); % Transparanlık eklendi
hold on;
h4 = patch(isosurface(Sol3d, max(Sol3d(:)) * 0.3)); % Reconstructed object in green
isonormals(Sol3d, h4);
set(h4, 'FaceColor', 'green', 'EdgeColor', 'none', 'FaceAlpha', 0.5); % Transparanlık eklendi
title('Overlay of Original and Reconstructed');
axis equal;
grid on;
hold off;

% Common settings for all subplots
for i = 1:3
    subplot(1, 3, i);
    xlim([1, size(vol_preX, 1)]);
    ylim([1, size(vol_preX, 2)]);
    zlim([1, size(vol_preX, 3)]);
    xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
end




%%
% 
disp('Size of vol_preX:');
disp(size(vol_preX));

disp('Size of Sol3d:');
disp(size(Sol3d));

% compare
figure;
for i = 1:20
    subplot(1, 2, 1);
    imagesc(squeeze(vol_preX(:, :, i))'); colorbar; title('Original');
    
    subplot(1, 2, 2);
    imagesc(squeeze(Sol3d(:, :, i))'); colorbar; title('Reconstructed');
    
    %pause(0.5); 
     waitforbuttonpress;
end

%%
% % Logging Parameters to Excel
% 
% fileExists = isfile(filename);
% 
% % Define the parameters to be saved
% params = {'rootfact', 'lambda_iter', 'p', 'tol', 'max_itr', 'timeRecon', ...
%           'centroid_error_1', 'volume_error_1', 'contrast_value_1', ...
%           'centroid_error_percentage_1', 'volume_error_percentage_1', 'contrast_percentage_1', ...
%           'image_contrast'};
% 
% % Initialize the table with the parameters if it doesn't exist
% if fileExists == 0 || nextRow == 1
%     paramTable = array2table(cell(0, length(params)), 'VariableNames', params);
% else
%     paramTable = dataTable;
% end
% 
% % Create a new row of data
% newRow = table(Recon.rootfact, Recon.lambda_iter, Recon.p, Recon.tol, ...
%           Recon.max_itr, Recon.timeRecon, ...
%           centroid_error_1, volume_error_1, contrast_value_1, ...
%           centroid_error_percentage_1, volume_error_percentage_1, contrast_percentage_1, ...
%           image_contrast, ...
%           'VariableNames', params);
% 
% % Append the new row to the table
% paramTable = [paramTable; newRow];
% 
% % Write the updated table to the Excel file
% writetable(paramTable, filename, 'Sheet', sheet, 'WriteMode', 'replacefile');
% 

%% vol2surf ENES
% Threshold the volumetric image to create a binary image
volimage = Sol3d;
%volimage = vol_preX;
volimage_binary = volimage > 0.05;

% Define the parameters for the vol2surf function
ix = 1:size(volimage, 1);
iy = 1:size(volimage, 2);
iz = 1:size(volimage, 3);
opt = struct('radbound', 2, 'maxsurf', 1); % Adjust options as needed
dofix = 1; % Perform mesh validation and repair
method = 'cgalsurf'; % Choose the appropriate method
isovalues = 0.65; % Specify isovalues if needed

% Call the vol2surf function with error handling
try
    % Call the vol2surf function
    [node, elem, regions, holes] = vol2surf(volimage_binary, ix, iy, iz, opt, dofix, method, isovalues);

    % Display size of the resulting node matrix for debugging
    if ~isempty(node)
        disp('Size of node matrix:');
        disp(size(node));
    end

    % Visualize the resulting mesh
    figure;
    plotmesh(node, elem);
    title('Generated Surface Mesh');
    axis equal;
catch ME
    disp('An error occurred:');
    disp(ME.message);
    keyboard; % Pause execution for debugging
end



%% Quality Metrics Functions

function [volume_error, centroid_error, contrast_value] = quality_metrics(original_volume, reconstructed_volume)
    % Volume Error Calculation
    volume_error = abs(nnz(original_volume) - nnz(reconstructed_volume));
    
    % Centroid Error Calculation
    original_centroid = centroid(original_volume);
    reconstructed_centroid = centroid(reconstructed_volume);
    centroid_error = norm(original_centroid - reconstructed_centroid);
    
    % Contrast Calculation
    max_intensity = max(reconstructed_volume(:));
    min_intensity = min(reconstructed_volume(:));
    contrast_value = max_intensity - min_intensity;
end

function c = centroid(volume)
    % Calculate the centroid of a 3D volume
    [x, y, z] = ndgrid(1:size(volume, 1), 1:size(volume, 2), 1:size(volume, 3));
    total_mass = sum(volume(:));
    c = [sum(x(:) .* volume(:)) / total_mass, ...
         sum(y(:) .* volume(:)) / total_mass, ...
         sum(z(:) .* volume(:)) / total_mass];
end
