% %volshow(Reconstructed...)
% %volumeview(..)

%% Ayarlar
clc;
fprintf('--- Başlangıç: Ayarlar Yükleniyor ---\n');
norm_type = 1;          % L1 Norm (hesaplama metrikleri için kullanılacak)
tol = 1e-4;             % Genel tolerans (örneğin ISTA için, fakat Lp_solver için Recon.tol ayrı tanımlanıyor)
max_itr = 10000;
cfg.unitinmm = 0.1;
fprintf('Seçilen norm: L%d, tol = %e, max_itr = %d\n', norm_type, tol, max_itr);

%% Veri Oluşturma/Yükleme (Örnek veri)
fprintf('Veriler oluşturuluyor...\n');
b_ideal_normalized = cfg.b / max(abs(cfg.b(:)));
noise_std = 0.00001;
desired_mean = mean(b_ideal_normalized(:));
noise_normal = noise_std * randn(size(b_ideal_normalized)) + desired_mean;
noise_clip = noise_normal;
noise_clip(noise_clip < 0) = 0;
b_case2 = b_ideal_normalized + noise_clip;

% Sıfır ortalamalı gürültü üret:
noise = noise_std * randn(size(b_ideal_normalized)).^2;
noise = noise - mean(noise(:)) + mean(b_ideal_normalized);
b_case2 = b_ideal_normalized + noise;

%% SNR ve Gürültü İstatistikleri
signal_rms = std(b_ideal_normalized(:));
noise_rms = std(noise(:));
SNR_dB = 20 * log10(signal_rms / noise_rms);
fprintf('SNR (dB): %.2f\n', SNR_dB);
mean_noise_clip = mean(noise_clip(:));
std_noise_clip = std(noise_clip(:));
fprintf('Noise mean: %.4f, Noise Standart Deviation: %.4f\n', mean_noise_clip, std_noise_clip);

%% Gürültü Haritası Görselleştirme
figure;
imagesc(noise);
colormap('jet');
colorbar;
title('Gürültü Görselleştirme');
xlabel('X Piksel Konumu');
ylabel('Y Piksel Konumu');
axis on;

%% Normalizasyon
% Orijinal kodda A ve b_case1 kullanılıyordu. Burada Lp solver için
% cfg.ms ve cfg.b üzerinden sens_norm ve b_norm hesaplanıyor.
b_norm = cfg.b ./ max(abs(cfg.b(:)));
sens_norm = cfg.ms ./ max(abs(cfg.ms(:)));
[m, n] = size(sens_norm);
delta_target = noise_rms * m * sqrt(2/pi);  % Makale Eq.21

%% D Matrisinin Hesaplanması
tic;
E = sens_norm' * sens_norm;
toc;
Recon.rootfact = 0.5;  % Örneğin 0.5
tic;
Dtmp = (eye(n) * diag(E)).^Recon.rootfact;
toc;
D = Dtmp ./ max(Dtmp(:));

%% Lp Solver Parametre Ayarları
% Lp_solver_depthver2 fonksiyonu aşağıdaki argümanları bekliyor:
%   (J0, b0, p, lambda0, tol, max_itr, nu, eps, [x0, D])
Recon.p         = 1;           % p değeri; 1 ise L1 norm (isterseniz 1/4 gibi non-konveks bir değer de seçebilirsiniz)
Recon.tol       = 1e-3;        % İterasyon durma toleransı
Recon.max_itr   = 10000;       % Maksimum iterasyon sayısı
Recon.nu        = 1e-4;        % Adım büyüklüğü (1/norm(A,2)^2'den küçük olmalı)
Recon.eps       = 1e-10;       % Küçük sabit (bölme işlemleri için)
Recon.x_initial = zeros(n, 1); % Başlangıç tahmini

%% Lambda Aralığı (Genişletilmiş)
lambda_range = logspace(-2, 2, 100);
num_lambda = length(lambda_range);
iso_value = 0.65;

%% Hesaplama Metrikleri Başlatma
res_norm_case1 = zeros(num_lambda, 1);
reg_norm_case1 = zeros(num_lambda, 1);
gcv_case1      = zeros(num_lambda, 1);
res_norm_case2 = zeros(num_lambda, 1);
reg_norm_case2 = zeros(num_lambda, 1);
gcv_case2      = zeros(num_lambda, 1);
morozov_case2  = zeros(num_lambda, 1);

X_lambda_ideal = cell(num_lambda, 1);
X_lambda_noisy = cell(num_lambda, 1);

%% Lambda Seçim Döngüsü (Lp_solver_depthver2 Kullanılarak)
fprintf('Lambda seçim döngüsü başlıyor...\n');
tic_lambda = tic;
epsilon_val = 1e-3;  % DoF hesaplaması için küçük sabit
for i = 1:num_lambda
    lam = lambda_range(i);
    fprintf('Lambda %d/%d: λ = %.2e ... ', i, num_lambda, lam);
    
    % Her iterasyonda seçilen lambda'yı Recon yapısına atıyoruz:
    Recon.lambda_iter = lam;
    
    % Lp_solver_depthver2 çağrıları; ideal veri için b_norm, gürültülü için b_case2 kullanılıyor.
    x_lambda_case1 = Lp_solver_depthver2(sens_norm, b_norm, Recon.p, Recon.lambda_iter, ...
        Recon.tol, Recon.max_itr, Recon.nu, Recon.eps, Recon.x_initial, D);
    x_lambda_case2 = Lp_solver_depthver2(sens_norm, b_case2, Recon.p, Recon.lambda_iter, ...
        Recon.tol, Recon.max_itr, Recon.nu, Recon.eps, Recon.x_initial, D);
    
    recon.x_lambda_case1{i} = x_lambda_case1;
    recon.x_lambda_case2{i} = x_lambda_case2;
    
    % Belirlenen eşik değeri altındaki değerler sıfırlanıyor
    x_lambda_case1(x_lambda_case1 < max(x_lambda_case1) * iso_value) = 0;
    x_lambda_case2(x_lambda_case2 < max(x_lambda_case2) * iso_value) = 0;
    
    X_lambda_ideal{i} = x_lambda_case1;
    X_lambda_noisy{i} = x_lambda_case2;
    
    recon.X_lambda_ideal{i} = X_lambda_ideal{i};
    recon.X_lambda_noisy{i} = X_lambda_noisy{i};
    
    % Norm hesaplamaları (sistem: sens_norm*x vs. b_norm veya b_case2)
    res1 = norm(sens_norm * x_lambda_case1 - b_norm, 2);
    res2 = norm(sens_norm * x_lambda_case2 - b_case2, 2);
    reg1 = norm(x_lambda_case1, norm_type);
    reg2 = norm(x_lambda_case2, norm_type);
    
    % Dereceli Serbestlik (DoF) hesaplaması (düzeltildi)
    df_smooth1 = sum( abs(x_lambda_case1) ./ sqrt(x_lambda_case1.^2 + epsilon_val^2) );
    df_smooth2 = sum( abs(x_lambda_case2) ./ sqrt(x_lambda_case2.^2 + epsilon_val^2) );
    
    % GCV hesaplaması (Makale formülü)
    gcv_case1(i) = (res1^2) / (m - df_smooth1)^2;
    gcv_case2(i) = (res2^2) / (m - df_smooth2)^2;
    
    % Morozov: delta_target ile fark
    delta_est_case2(i) = noise_rms * df_smooth2 * sqrt(2/pi);
    morozov_case2(i) = abs(res2 - delta_target);
    
    % Norm ve regularizasyon değerlerini sakla
    res_norm_case1(i) = res1;
    reg_norm_case1(i) = reg1;
    res_norm_case2(i) = res2;
    reg_norm_case2(i) = reg2;
    
    fprintf('Res: %.2e, Reg: %.2e\n', res1, reg1);
end
fprintf('Döngü tamamlandı, süre: %.1f s\n', toc(tic_lambda));


%% Optimal Lambda Seçimi (Curvature Yöntemi)
[~, ~, curvature1] = compute_curvature(reg_norm_case1, res_norm_case1, lambda_range);
[~, idx_LC_case1] = max(curvature1);
opt_lambda_LC_case1 = lambda_range(idx_LC_case1);

[~, ~, curvature2] = compute_curvature(reg_norm_case2, res_norm_case2, lambda_range);
[~, idx_LC_case2] = max(curvature2);
opt_lambda_LC_case2 = lambda_range(idx_LC_case2);

[~, idx_GCV_case1] = min(gcv_case1);
opt_lambda_GCV_case1 = lambda_range(idx_GCV_case1);

[~, idx_GCV_case2] = min(gcv_case2);
opt_lambda_GCV_case2 = lambda_range(idx_GCV_case2);

[~, idx_Morozov_case2] = min(morozov_case2);
opt_lambda_Morozov_case2 = lambda_range(idx_Morozov_case2);

fprintf('Optimal Lambda Değerleri (Curvature Yöntemi):\n');
fprintf('  L-Curve (İdeal): %.5e\n', opt_lambda_LC_case1);
fprintf('  L-Curve (Gürültülü): %.5e\n', opt_lambda_LC_case2);
fprintf('  GCV (İdeal): %.5e\n', opt_lambda_GCV_case1);
fprintf('  GCV (Gürültülü): %.5e\n', opt_lambda_GCV_case2);
fprintf('  Morozov (Gürültülü): %.5e\n', opt_lambda_Morozov_case2);
%% L CURVE TEKNİKLERİ
% 1) Üçgen Yöntemi (corner_by_triangle)
lx1 = log(reg_norm_case1);
ly1 = log(res_norm_case1);
[lx2, ly2] = deal(log(reg_norm_case2), log(res_norm_case2));

[idx_triangle_case1, ~] = corner_by_triangle(lx1, ly1);
opt_lambda_triangle_ideal = lambda_range(idx_triangle_case1);

[idx_triangle_case2, ~] = corner_by_triangle(lx2, ly2);
opt_lambda_triangle_noisy = lambda_range(idx_triangle_case2);

fprintf('Optimal Lambda (Triangle Method):\n');
fprintf('  İdeal: %.5e\n', opt_lambda_triangle_ideal);
fprintf('  Gürültülü: %.5e\n', opt_lambda_triangle_noisy);

% 2) Corner Function (Adaptive Pruning / Angles) Cornerdeki hatayı kapattım
[k_corner_ideal, info_ideal] = l_corner(res_norm_case1, reg_norm_case1, 1);
opt_lambda_corner_ideal = lambda_range(k_corner_ideal);
fprintf('Optimal Lambda (Corner Method - İdeal): %.5e (k = %d, info = %d)\n', opt_lambda_corner_ideal, k_corner_ideal, info_ideal);

[k_corner_noisy, info_noisy] = l_corner(res_norm_case2, reg_norm_case2, 1);
opt_lambda_corner_noisy = lambda_range(k_corner_noisy);
fprintf('Optimal Lambda (Corner Method - Gürültülü): %.5e (k = %d, info = %d)\n', opt_lambda_corner_noisy, k_corner_noisy, info_noisy);


%% L-Curve GRAFİĞİ (İdeal ve Gürültülü)
figure;
subplot(1,2,1);
loglog(res_norm_case1, reg_norm_case1, 'bo-', 'LineWidth',1.5); hold on;
loglog(res_norm_case1(idx_LC_case1), reg_norm_case1(idx_LC_case1), 'rs', 'MarkerSize',10, 'LineWidth',2);
loglog(res_norm_case1(idx_triangle_case1), reg_norm_case1(idx_triangle_case1), 'g^', 'MarkerSize',10, 'LineWidth',2);
loglog(res_norm_case1(k_corner_ideal), reg_norm_case1(k_corner_ideal), 'kd', 'MarkerSize',10, 'LineWidth',2);
xlabel('||A x_{\lambda} - b||_2'); ylabel('||x_{\lambda}||_1');
title('L-Curve (İdeal Veri)');
legend('L-Curve', 'Curvature Opt', 'Triangle Opt', 'Corner Opt','Location','best');
grid on; 
set(gca, 'FontSize', 20);
hold off;

subplot(1,2,2);
loglog(res_norm_case2, reg_norm_case2, 'r*-', 'LineWidth',1.5); hold on;
loglog(res_norm_case2(idx_LC_case2), reg_norm_case2(idx_LC_case2), 'ys', 'MarkerSize',10, 'LineWidth',2);
loglog(res_norm_case2(idx_triangle_case2), reg_norm_case2(idx_triangle_case2), 'g^', 'MarkerSize',10, 'LineWidth',2);
loglog(res_norm_case2(k_corner_noisy), reg_norm_case2(k_corner_noisy), 'kd', 'MarkerSize',10, 'LineWidth',2);
xlabel('||A x_{\lambda} - b||_2'); ylabel('||x_{\lambda}||_1');
title('L-Curve (Gürültülü Veri)');
legend('L-Curve', 'Curvature Opt', 'Triangle Opt', 'Corner Opt','Location','best');
grid on; 
set(gca, 'FontSize', 20);
hold off;


%% U-Curve Yöntemi (Ideal ve Gürültülü)
% U-Curve, her lambda için; U(λ) = 1/||A*xλ - b||² + 1/||xλ||² şeklinde tanımlanabilir.
U_curve_case1 = 1./(res_norm_case1.^2) + 1./(reg_norm_case1.^2);
U_curve_case2 = 1./(res_norm_case2.^2) + 1./(reg_norm_case2.^2);

[~, idx_UC_case1] = min(U_curve_case1);
[~, idx_UC_case2] = min(U_curve_case2);

opt_lambda_UC_ideal = lambda_range(idx_UC_case1);
opt_lambda_UC_noisy = lambda_range(idx_UC_case2);

fprintf('Optimal Lambda (U-Curve Method):\n');
fprintf('  İdeal: %.5e\n', opt_lambda_UC_ideal);
fprintf('  Gürültülü: %.5e\n', opt_lambda_UC_noisy);
%% U-Curve Grafiği
figure;
subplot(1,2,1);
semilogx(lambda_range, U_curve_case1, 'bo-', 'LineWidth',1.5);
hold on;
% Optimum lambda'nın bulunduğu noktayı kırmızı kare ile işaretle
semilogx(lambda_range(idx_UC_case1), U_curve_case1(idx_UC_case1), 'rs', 'MarkerSize',10, 'LineWidth',2);
hold off;
xlabel('\lambda'); ylabel('U-Curve Değeri');
title('U-Curve (İdeal Veri)');
grid on;
set(gca,'FontSize',20);

subplot(1,2,2);
semilogx(lambda_range, U_curve_case2, 'r*-', 'LineWidth',1.5);
hold on;

semilogx(lambda_range(idx_UC_case2), U_curve_case2(idx_UC_case2), 'ms', 'MarkerSize',10, 'LineWidth',2);
hold off;
xlabel('\lambda'); ylabel('U-Curve Değeri');
title('U-Curve (Gürültülü Veri)');
grid on;
set(gca,'FontSize',20);
%% MOROZOV DISCREPANCY (Gürültülü Veri)
figure;
semilogx(lambda_range, res_norm_case2, 'b-o', 'LineWidth',1.5); hold on;
semilogx(lambda_range, delta_est_case2, 'm--', 'LineWidth',1.5);
semilogx(lambda_range, ones(size(lambda_range)) * delta_target, 'r-.', 'LineWidth',1.5);
% Optimum lambda'nın bulunduğu noktayı işaretle (örneğin, morozov_case2'nin minimum değeri)
semilogx(lambda_range(idx_Morozov_case2), res_norm_case2(idx_Morozov_case2), 'ms', 'MarkerSize',10, 'LineWidth',2);
xlabel('\lambda'); ylabel('Değer');
title('Morozov Discrepancy (Gürültülü Veri)');
legend('Rezidü Norm', 'Dinamik \delta(\lambda)', 'Delta Target', 'Optimum \lambda', 'Location','best');
grid on; hold off;
set(gca,'FontSize',20);
%% GCV KRİTERİ (İdeal ve Gürültülü)
figure;
subplot(1,2,1);
semilogx(lambda_range, gcv_case1, 'bo-', 'LineWidth',1.5); hold on;
% Optimum lambda için işaretleme (ideal veri)
semilogx(lambda_range(idx_GCV_case1), gcv_case1(idx_GCV_case1), 'rs', 'MarkerSize',10, 'LineWidth',2);
xlabel('\lambda'); ylabel('GCV');
title('GCV Kriteri (İdeal Veri)');
grid on; hold off;
set(gca,'FontSize',20);
subplot(1,2,2);
semilogx(lambda_range, gcv_case2, 'r*-', 'LineWidth',1.5); hold on;
% Optimum lambda için işaretleme (gürültülü veri)
semilogx(lambda_range(idx_GCV_case2), gcv_case2(idx_GCV_case2), 'ms', 'MarkerSize',10, 'LineWidth',2);
xlabel('\lambda'); ylabel('GCV');
title('GCV Kriteri (Gürültülü Veri)');
grid on; hold off;
set(gca,'FontSize',20);

%% 3B REKONSTRÜKSİYON (Her Yöntem için Ayrı Threshold)
% Örnek olarak, burada LC, GCV, Morozov, Triangle, Corner ve U-Curve yöntemleri için:
x_opt_LC_noisy       = X_lambda_noisy{idx_LC_case2};
x_opt_GCV_noisy      = X_lambda_noisy{idx_GCV_case2};
x_opt_Morozov_noisy  = X_lambda_noisy{idx_Morozov_case2};
x_opt_triangle_noisy = X_lambda_noisy{idx_triangle_case2};
x_opt_corner_noisy   = X_lambda_noisy{k_corner_noisy};
x_opt_UC_noisy       = X_lambda_noisy{idx_UC_case2};  

Reconstructed_LC       = reshape(x_opt_LC_noisy, size(vol_preX));
Reconstructed_GCV      = reshape(x_opt_GCV_noisy, size(vol_preX));
Reconstructed_Morozov  = reshape(x_opt_Morozov_noisy, size(vol_preX));
Reconstructed_Triangle = reshape(x_opt_triangle_noisy, size(vol_preX));
Reconstructed_Corner   = reshape(x_opt_corner_noisy, size(vol_preX));
Reconstructed_UC       = reshape(x_opt_UC_noisy, size(vol_preX));  % 

% threshold_LC       = 0.0001 * max(Reconstructed_LC(:));
% threshold_GCV      = 0.0001 * max(Reconstructed_GCV(:));
% threshold_Morozov  = 0.0001 * max(Reconstructed_Morozov(:));
% threshold_Triangle = 0.0001 * max(Reconstructed_Triangle(:));
% threshold_Corner   = 0.0001 * max(Reconstructed_Corner(:));
% threshold_UC       = 0.0001 * max(Reconstructed_UC(:));  

threshold_LC       = 0.001 * max(Reconstructed_LC(:));
threshold_GCV      = 0.001 * max(Reconstructed_GCV(:));
threshold_Morozov  = 0.001 * max(Reconstructed_Morozov(:));
threshold_Triangle = 0.001 * max(Reconstructed_Triangle(:));
threshold_Corner   = 0.001 * max(Reconstructed_Corner(:));
threshold_UC       = 0.001 * max(Reconstructed_UC(:));  


%% 3D Vis İçin flip ediyoruz çünkü origin sol aşağıda oluşuyor
if ~exist('flipApplied', 'var') || flipApplied == 0
    vol_preX = flip(vol_preX, 3);
    
    Reconstructed_LC       = reshape(x_opt_LC_noisy, size(vol_preX));
    Reconstructed_GCV      = reshape(x_opt_GCV_noisy, size(vol_preX));
    Reconstructed_Morozov  = reshape(x_opt_Morozov_noisy, size(vol_preX));
    Reconstructed_Triangle = reshape(x_opt_triangle_noisy, size(vol_preX));
    Reconstructed_Corner   = reshape(x_opt_corner_noisy, size(vol_preX));
    Reconstructed_UC       = reshape(x_opt_UC_noisy, size(vol_preX));
    
    Reconstructed_LC       = flip(Reconstructed_LC, 3);
    Reconstructed_GCV      = flip(Reconstructed_GCV, 3);
    Reconstructed_Morozov  = flip(Reconstructed_Morozov, 3);
    Reconstructed_Triangle = flip(Reconstructed_Triangle, 3);
    Reconstructed_Corner   = flip(Reconstructed_Corner, 3);
    Reconstructed_UC       = flip(Reconstructed_UC, 3);
    
    flipApplied = 1;
end

%%
Ny = size(vol_preX,1);
Nx = size(vol_preX,2);
Nz = size(vol_preX,3);

figure('Name','3B Rekonstrüksiyon');

% --- 1) Orijinal Phantom
subplot(2,4,1);
patch(isosurface(vol_preX), 'FaceColor','blue', 'EdgeColor','none');
title('Orijinal Phantom');
view(3); 
axis equal;           % Eksen oranlarını eşitle
% axis tight;         % (Kullanma!)
xlim([1 Nx]); ylim([1 Ny]); zlim([1 Nz]);  % Ortak eksen sınırları
camlight; 
set(gca,'FontSize',20);

% --- 2) LC
subplot(2,4,2);
patch(isosurface(Reconstructed_LC, threshold_LC), 'FaceColor','red', 'EdgeColor','none');
title('LC Rekonstrüksiyon');
view(3); 
axis equal;
xlim([1 Nx]); ylim([1 Ny]); zlim([1 Nz]);
camlight;
set(gca,'FontSize',20);

% --- 3) GCV
subplot(2,4,3);
patch(isosurface(Reconstructed_GCV, threshold_GCV), 'FaceColor','green', 'EdgeColor','none');
title('GCV Rekonstrüksiyon');
view(3); 
axis equal;
xlim([1 Nx]); ylim([1 Ny]); zlim([1 Nz]);
camlight;
set(gca,'FontSize',20);

% --- 4) Morozov
subplot(2,4,4);
patch(isosurface(Reconstructed_Morozov, threshold_Morozov), 'FaceColor','magenta', 'EdgeColor','none');
title('Morozov Rekonstrüksiyon');
view(3); 
axis equal;
xlim([1 Nx]); ylim([1 Ny]); zlim([1 Nz]);
camlight;
set(gca,'FontSize',20);

% --- 5) Triangle
subplot(2,4,5);
patch(isosurface(Reconstructed_Triangle, threshold_Triangle), 'FaceColor','cyan', 'EdgeColor','none');
title('Triangle Method Rekonstrüksiyon');
view(3);
axis equal;
xlim([1 Nx]); ylim([1 Ny]); zlim([1 Nz]);
camlight;
set(gca,'FontSize',20);

% --- 6) Corner
subplot(2,4,6);
patch(isosurface(Reconstructed_Corner, threshold_Corner), 'FaceColor','yellow', 'EdgeColor','none');
title('Corner Method Rekonstrüksiyon');
view(3); 
axis equal;
xlim([1 Nx]); ylim([1 Ny]); zlim([1 Nz]);
camlight;
set(gca,'FontSize',20);

% --- 7) U-Curve
subplot(2,4,7);
patch(isosurface(Reconstructed_UC, threshold_UC), 'FaceColor','cyan', 'EdgeColor','none');
title('U-Curve Rekonstrüksiyon');
view(3); 
axis equal;
xlim([1 Nx]); ylim([1 Ny]); zlim([1 Nz]);
camlight;
set(gca,'FontSize',20);

%% Optiumum için arama methotları
% Yöntem isimleri ve rekonstrüksiyonlar
methods = {'LC', 'GCV', 'Morozov', 'Triangle', 'Corner', 'UC'};
Reconstructed = {Reconstructed_LC, Reconstructed_GCV, Reconstructed_Morozov, Reconstructed_Triangle, Reconstructed_Corner, Reconstructed_UC};

num_methods = length(methods);
nssd_array = zeros(num_methods,1);
nsad_array = zeros(num_methods,1);
nr_array   = zeros(num_methods,1);

% Önce hata dizilerini başlatıyoruz:
nssd_array = zeros(num_methods,1);
nsad_array = zeros(num_methods,1);
nr_array   = zeros(num_methods,1);
volErrVoxel_array = zeros(num_methods,1);
volErrMM_array    = zeros(num_methods,1);
centErrVoxel_array = zeros(num_methods,1);
centErrMM_array    = zeros(num_methods,1);

% Her rekonstrüksiyon için metrikleri hesapla   
for i = 1:num_methods
    R = Reconstructed{i};
    % NSSD: Kare farkların toplamının gerçek çekimin karelerinin toplamına oranı
    nssd_array(i) = sum((R(:) - vol_preX(:)).^2) / sum(vol_preX(:).^2);
    % NSAD: Mutlak farkların toplamının, gerçek çekimin mutlak değerlerinin toplamına oranı
    nsad_array(i) = sum(abs(R(:) - vol_preX(:))) / sum(abs(vol_preX(:)));
    % NR: Norm residual (2-norm fark/2-norm gerçek)
    nr_array(i)   = norm(R(:) - vol_preX(:)) / norm(vol_preX(:));
    fprintf('%s: NSSD = %.4e, NSAD = %.4e, NR = %.4e\n', methods{i}, nssd_array(i), nsad_array(i), nr_array(i));

    % quality_metrics fonksiyonu voxel ve mm cinsinden değerleri hesaplar
    [volErrVoxel, volErrMM, centErrVoxel, centErrMM] = quality_metrics(vol_preX, R, cfg.unitinmm);
    volErrVoxel_array(i) = volErrVoxel;
    volErrMM_array(i) = volErrMM;
    centErrVoxel_array(i) = centErrVoxel;
    centErrMM_array(i) = centErrMM;
    fprintf('%s:\n  Volume Error = %.4e voxels, %.4e mm^3\n  Centroid Error = %.4e voxels, %.4e mm\n\n', ...
            methods{i}, volErrVoxel, volErrMM, centErrVoxel, centErrMM);
end

% Tüm metriklerin ortak y ekseni sınırlarını belirlemek için
all_metrics = [nssd_array; nsad_array; nr_array];
common_ylim = [min(all_metrics)*0.95, max(all_metrics)*1.05];

% Yeni metrikler için ayrı sınırlar belirlemek:
common_ylim_vol = [min(volErrMM_array)*0.95, max(volErrMM_array)*1.05];
common_ylim_cent = [min(centErrMM_array)*0.95, max(centErrMM_array)*1.05];

figure('Name','Hata Metrikleri Karşılaştırması');

% 1) NSSD
subplot(1,5,1);
bar(nssd_array);
set(gca, 'XTick', 1:num_methods, 'XTickLabel', methods, 'FontSize', 14);
xlabel('Yöntemler'); ylabel('NSSD');
title('Normalized Sum of Squared Differences');
grid on;
ylim(common_ylim);

% 2) NSAD
subplot(1,5,2);
bar(nsad_array);
set(gca, 'XTick', 1:num_methods, 'XTickLabel', methods, 'FontSize', 14);
xlabel('Yöntemler'); ylabel('NSAD');
title('Normalized Sum of Absolute Differences');
grid on;
ylim(common_ylim);

% 3) NR
subplot(1,5,3);
bar(nr_array);
set(gca, 'XTick', 1:num_methods, 'XTickLabel', methods, 'FontSize', 14);
xlabel('Yöntemler'); ylabel('NR');
title('Normalized Residual');
grid on;
ylim(common_ylim);

% 4) Volume Error (mm^3)
subplot(1,5,4);
bar(volErrMM_array);
set(gca, 'XTick', 1:num_methods, 'XTickLabel', methods, 'FontSize', 14);
xlabel('Yöntemler'); ylabel('Volume Error (mm^3)');
title('Volume Error');
grid on;
ylim(common_ylim_vol);

% 5) Centroid Error (mm)
subplot(1,5,5);
bar(centErrMM_array);
set(gca, 'XTick', 1:num_methods, 'XTickLabel', methods, 'FontSize', 14);
xlabel('Yöntemler'); ylabel('Centroid Error (mm)');
title('Centroid Error');
grid on;
ylim(common_ylim_cent);



%% Save - recon verilerinin saklanması ve excel
saveReconData('recon_data.mat', 'recon_data.xlsx');
function [log_reg, log_res, curvature] = compute_curvature(reg_norm, res_norm, lambda_range)
    log_reg = log(reg_norm(:));
    log_res = log(res_norm(:));
    t = log(lambda_range(:));
    
    % Birinci türevler (gradyan ile boyut korunarak)
    dlogr = gradient(log_reg, t); % log_reg'in t'ye göre türevi
    dlogR = gradient(log_res, t); % log_res'in t'ye göre türevi
    
    % İkinci türevler (gradyan ile boyut korunarak)
    d2logr = gradient(dlogr, t);  % dlogr'ın t'ye göre türevi
    d2logR = gradient(dlogR, t);  % dlogR'ın t'ye göre türevi
    
    % Eğrilik formülü (NaN korumalı)
    curvature = abs(d2logR .* dlogr - dlogR .* d2logr) ./ (dlogR.^2 + dlogr.^2 + eps()).^(3/2);
end

function [idx_corner, distances] = corner_by_triangle(xvals, yvals)
    % xvals, yvals : L-curve noktaları (log(||x_lambda||), log(||Ax_lambda - b||))
    % idx_corner   : Üçgen yöntemine göre köşe noktasının indeksi
    % distances    : Her noktaya ait dik uzaklıklar
    
    % İlk ve son noktalar:
    x1 = xvals(1);  y1 = yvals(1);
    xN = xvals(end); yN = yvals(end);
    
    % İki nokta arasındaki doğru uzunluğu:
    denom = sqrt((yN - y1)^2 + (xN - x1)^2);
    
    n = length(xvals);
    distances = zeros(n,1);
    for i = 1:n
        % Nokta ile chord arasındaki dik mesafe:
        distances(i) = abs((yN - y1)*xvals(i) - (xN - x1)*yvals(i) + xN*y1 - yN*x1) / denom;
    end
    
    [~, idx_corner] = max(distances);
end

function [volErrVoxel, volErrMM, centErrVoxel, centErrMM] = quality_metrics(original_volume, reconstructed_volume, unitInMM)
    % Volume Error Calculation (Voxel cinsinden)
    volErrVoxel = abs(nnz(original_volume) - nnz(reconstructed_volume));
    % Volume Error (mm^3): Her voxelün hacmi (unitInMM)^3
    volErrMM = volErrVoxel * unitInMM^3;
    
    % Centroid Error Calculation (Voxel cinsinden)
    origCentroid = centroid(original_volume);
    reconCentroid = centroid(reconstructed_volume);
    centErrVoxel = norm(origCentroid - reconCentroid);
    % Centroid Error (mm): Voxel cinsinden hatayı unitInMM ile çarpıyoruz.
    centErrMM = centErrVoxel * unitInMM;
end

function c = centroid(volume)
    % 3B hacmin centroidini hesaplar (voxel cinsinden)
    [x, y, z] = ndgrid(1:size(volume, 1), 1:size(volume, 2), 1:size(volume, 3));
    totalMass = sum(volume(:));
    c = [sum(x(:) .* volume(:)) / totalMass, ...
         sum(y(:) .* volume(:)) / totalMass, ...
         sum(z(:) .* volume(:)) / totalMass];
end

