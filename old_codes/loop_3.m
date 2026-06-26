% Define the Excel filename and sheet name
filename = 'enes_cube_parameters.xlsx';
sheet = 'Sheet1';

% Display the filename and sheet being used
disp(['Writing to file: ', filename]);
disp(['Using sheet: ', sheet]);

% Check if the Excel file exists
if isfile(filename)
    % Read the current data to determine the next row to write
    try
        dataTable = readtable(filename, 'Sheet', sheet);
        nextRow = height(dataTable) + 1;
    catch
        % If sheet not found, start from the first row
        nextRow = 1;
        dataTable = table();
    end
else
    % If file does not exist, start from the first row
    nextRow = 1;
    dataTable = table();
end

% Display the next row to be written
disp(['Next row to be written: ', num2str(nextRow)]);
%%
b=cfg.b;
ms=cfg.ms;
% Lp Solver Parameter Setting for SENS
b_norm = b ./ max(b(:));
sens_norm = ms ./ max(ms(:));
[~, n] = size(sens_norm);

tic
E = sens_norm' * sens_norm;
toc

Recon.rootfact = 0.5; % 0.5
tic;
Dtmp = (eye(n) * diag(E)).^Recon.rootfact;
toc
D = Dtmp ./ max(Dtmp);
clear Dtmp

% Initialize the table with the parameters if it doesn't exist
if isfile(filename) == 0 || nextRow == 1
    paramTable = array2table(cell(0, 13), 'VariableNames', {'rootfact', 'lambda_iter', 'p', 'tol', ...
          'max_itr', 'timeRecon', 'sbr', 'cbr', ...
          'centroid_error', 'volume_error', 'contrast_value', ...
          'centroid_error_percentage', 'volume_error_percentage'});
else
    paramTable = dataTable;
end

lambda_Lcurve = 1:1:30;
sizeL = length(lambda_Lcurve);

% change if its needed
iso_value = 0.5 ; 

for i = 1:sizeL
    % Lp Solver for SENS
    tic
    Recon.lambda_iter = lambda_Lcurve(i);
    Recon.eps = 1e-10; % 1 for p=1/4
    Recon.p = 1; % 1/4
    Recon.tol = 1e-3;
    Recon.max_itr = 10000;
    Recon.nu = 1e-4;
    Recon.x_initial = zeros(n, 1);
    tic
    x_approxLp = Lp_solver_depthver2(sens_norm, b_norm, Recon.p, Recon.lambda_iter, ...
        Recon.tol, Recon.max_itr, Recon.nu, ...
        Recon.eps, Recon.x_initial, D); %% LP_solver from mcx
    Recon.timeRecon(i) = toc;
    Recon.LoopXs{i} = x_approxLp;
    load gong.mat;
    sound(y / 32, Fs);
    display(Recon.lambda_iter);
    clear Fs
    toc
    
   

    % Apply iso value to x_approxLp
    x_approxLp(x_approxLp < max(x_approxLp) * iso_value) = 0;
    
    % Reconstruct
    Sol3d = reshape(x_approxLp, size(vol_preX, 1), size(vol_preX, 2), size(vol_preX, 3));

    % Calculate SBR, CNR, and CBR
    signal_intensity = mean(Sol3d(vol_preX > 0));
    background_intensity = mean(Sol3d(vol_preX == 0));

    % Calculate SBR Signal-to-Background Ratio
    sbr = signal_intensity / background_intensity;

    % Calculate CBR Contrast-to-Background Ratio
    cbr = (signal_intensity - background_intensity) / background_intensity;
    
    % Display results
    disp(['Signal Intensity: ', num2str(signal_intensity)]);
    disp(['Background Intensity: ', num2str(background_intensity)]);
    disp(['SBR: ', num2str(sbr)]);
    disp(['CBR: ', num2str(cbr)]);

    % Quality metrics calculation (ENES)
    original_volume = vol_preX; % Original volume data
    reconstructed_volume = Sol3d; % Reconstructed volume data

    [volume_error, centroid_error, contrast_value] = quality_metrics(original_volume, reconstructed_volume);

    % Calculate percentage values
    volume_error_percentage = (volume_error / nnz(original_volume)) * 100;
    %%%%%max_distance = norm(size(original_volume));
    centroid_error_percentage = (centroid_error / max_distance) * 100;

    disp(['Volume Error: ', num2str(volume_error), ' (', num2str(volume_error_percentage), '%)']);
    disp(['Centroid Error: ', num2str(centroid_error), ' (', num2str(centroid_error_percentage), '%)']);
    disp(['Contrast: ', num2str(contrast_value)]);

    % Create a new row of data
    newRow = table(Recon.rootfact, Recon.lambda_iter, Recon.p, Recon.tol, ...
          Recon.max_itr, Recon.timeRecon(i), sbr, cbr, ...
          centroid_error, volume_error, contrast_value, ...
          centroid_error_percentage, volume_error_percentage, ...
          'VariableNames', {'rootfact', 'lambda_iter', 'p', 'tol', 'max_itr', 'timeRecon', 'sbr', 'cbr', ...
          'centroid_error', 'volume_error', 'contrast_value', ...
          'centroid_error_percentage', 'volume_error_percentage'});

    % Append the new row to the table
    paramTable = [paramTable; newRow];
end

% Write the updated table to the Excel file
writetable(paramTable, filename, 'Sheet', sheet, 'WriteMode', 'replacefile');
disp('Results have been saved to the Excel file.');

save('0.mat', 'Recon');

%% Helper Functions

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
    mean_intensity = mean(reconstructed_volume(:));
    contrast_value = (max_intensity - min_intensity) / mean_intensity;
end

function c = centroid(volume)
    % Calculate the centroid of a 3D volume
    [x, y, z] = ndgrid(1:size(volume, 1), 1:size(volume, 2), 1:size(volume, 3));
    total_mass = sum(volume(:));
    c = [sum(x(:) .* volume(:)) / total_mass, ...
         sum(y(:) .* volume(:)) / total_mass, ...
         sum(z(:) .* volume(:)) / total_mass];

end
