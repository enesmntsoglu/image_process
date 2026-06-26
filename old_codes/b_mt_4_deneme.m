%volshow(Reconstructed...)
%volumeview(..)

%% Ayarlar
fprintf('--- Başlangıç: Ayarlar Yükleniyor ---\n');
norm_type = 1;  % L1 Norm
tol = 1e-4;
max_itr = 10000;
fprintf('Seçilen norm: L%d, tol = %e, max_itr = %d\n', norm_type, tol, max_itr);

%% Veri Oluşturma/Yükleme (Örnek veri)
fprintf('Veriler oluşturuluyor...\n');

% % Gürültü ekleme (Normalizasyon SONRASI) OLD
% b_ideal_normalized = cfg.b / max(abs(cfg.b(:)));
% noise_std = 0.01;
% alpha = (randn(size(b_ideal_normalized))).^2 ;
% %%b_case2 = b_ideal_normalized + noise_std * abs(randn(size(b_ideal_normalized)));
% b_case2 = b_ideal_normalized + noise_std * alpha ;
% Sinyali normalize ettikten sonra:

b_ideal_normalized = cfg.b / max(abs(cfg.b(:)));
noise_std = 0.00001;
% Sıfır ortalamalı gürültü üret:
noise = noise_std * randn(size(b_ideal_normalized)).^2;
% Gürültünün ortalamasını sinyalin ortalamasıyla eşitle:
noise = noise - mean(noise(:)) + mean(b_ideal_normalized);
% Gürültüyü sinyale ekle:
b_case2 = b_ideal_normalized + noise;
%% db
signal_rms = std(b_ideal_normalized(:));
noise_rms = std(noise(:));

noise_level_dB = 20 * log10(noise_rms / signal_rms);
SNR_dB = 20 * log10(signal_rms / noise_rms);


fprintf('Gürültü Seviyesi: %.2f dB\n', noise_level_dB);
fprintf('SNR (dB): %.2f\n', SNR_dB);
%%
hold on ;
figure;
imagesc(b_case2); % Gürültü haritasını göster
colormap('gray'); 
colorbar; 
title('Gürültü Görselleştirme');
xlabel('X Piksel Konumu'); 
ylabel('Y Piksel Konumu'); 
axis on ;
hold off ;


%% Normalizasyon
A = cfg.ms ./ max(abs(cfg.ms(:)));
b_case1 = b_ideal_normalized;  % Zaten normalize edildi
[m, n] = size(A);
delta_target = noise_std * sqrt(m);  % Makale Eq.21

%% L1 Çözücü Fonksiyon (Optimize Edilmiş)
l1_solution = @(lam, b_in) ista_solver(A, b_in, lam, tol, max_itr, 10000);

%% Lambda Aralığı (Genişletilmiş)
lambda_range = logspace(-2, 1.7, 10); 
num_lambda = length(lambda_range);
iso_value = 0.25;
%% Hesaplama Metrikleri
res_norm_case1 = zeros(num_lambda,1);
reg_norm_case1 = zeros(num_lambda,1);
gcv_case1 = zeros(num_lambda,1);
res_norm_case2 = zeros(num_lambda,1);
reg_norm_case2 = zeros(num_lambda,1);
gcv_case2 = zeros(num_lambda,1);
morozov_case2 = zeros(num_lambda,1);

X_lambda_ideal = cell(num_lambda,1);
X_lambda_noisy = cell(num_lambda,1);

%% Lambda Seçim Döngüsü
fprintf('Lambda seçim döngüsü başlıyor...\n');
tic_lambda = tic;
epsilon_val = 1e-4;
for i = 1:num_lambda
    lam = lambda_range(i);
    fprintf('Lambda %d/%d: λ = %.2e ... ', i, num_lambda, lam);
    
    % Çözümler
    x_lambda_case1 = l1_solution(lam, b_case1);
    x_lambda_case2 = l1_solution(lam, b_case2);

    recon.x_lambda_case1{i} = x_lambda_case1 ;
    recon.x_lambda_case2{i} = x_lambda_case2 ; 
    
    x_lambda_case1(x_lambda_case1 < max(x_lambda_case1) * iso_value) = 0;
    x_lambda_case2(x_lambda_case2 < max(x_lambda_case2) * iso_value) = 0;

    X_lambda_ideal{i} = x_lambda_case1;
    X_lambda_noisy{i} = x_lambda_case2;
    
    recon.X_lambda_ideal{i} = X_lambda_ideal{i} ;
    recon.X_lambda_ideal{i} = X_lambda_noisy{i} ;


    % Normlar
    res1 = norm(A*x_lambda_case1 - b_case1, 2);
    res2 = norm(A*x_lambda_case2 - b_case2, 2);
    reg1 = norm(x_lambda_case1, norm_type);
    reg2 = norm(x_lambda_case2, norm_type);
    
    % DoF (DÜZELTİLDİ)
    df_smooth1 = sum( abs(x_lambda_case1) ./ sqrt(x_lambda_case1.^2 + epsilon_val^2) );
    df_smooth2 = sum( abs(x_lambda_case2) ./ sqrt(x_lambda_case2.^2 + epsilon_val^2) );
    
    % GCV (Makale Formülü)
    gcv_case1(i) = (res1^2) / (m - df_smooth1)^2;
    gcv_case2(i) = (res2^2) / (m - df_smooth2)^2;
    
    % Morozov
    delta_est_case2(i) = noise_std * sqrt(df_smooth2);
    morozov_case2(i) = abs(res2 - delta_target);
    
    % Normları sakla
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
[k_corner_ideal, info_ideal] = corner(res_norm_case1, reg_norm_case1, 1);
opt_lambda_corner_ideal = lambda_range(k_corner_ideal);
fprintf('Optimal Lambda (Corner Method - İdeal): %.5e (k = %d, info = %d)\n', opt_lambda_corner_ideal, k_corner_ideal, info_ideal);

[k_corner_noisy, info_noisy] = corner(res_norm_case2, reg_norm_case2, 1);
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

threshold_LC       = 0.001 * max(Reconstructed_LC(:));
threshold_GCV      = 0.001 * max(Reconstructed_GCV(:));
threshold_Morozov  = 0.001 * max(Reconstructed_Morozov(:));
threshold_Triangle = 0.001 * max(Reconstructed_Triangle(:));
threshold_Corner   = 0.001 * max(Reconstructed_Corner(:));
threshold_UC       = 0.001 * max(Reconstructed_UC(:));  


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

    [volume_error, centroid_error] = quality_metrics(vol_preX, R);
    fprintf('%s:\n  Volume Error = %.4e\n  Centroid Error = %.4e\n\n', ...
               methods{i}, volume_error, centroid_error);
   
end

all_metrics = [nssd_array; nsad_array; nr_array];
common_ylim = [min(all_metrics)*0.95, max(all_metrics)*1.05];

figure('Name','Hata Metrikleri Karşılaştırması');

subplot(1,3,1);
bar(nssd_array);
set(gca, 'XTick', 1:num_methods, 'XTickLabel', methods, 'FontSize', 14);
xlabel('Yöntemler'); ylabel('NSSD');
title('Normalized Sum of Squared Differences');
grid on;
ylim(common_ylim);

subplot(1,3,2);
bar(nsad_array);
set(gca, 'XTick', 1:num_methods, 'XTickLabel', methods, 'FontSize', 14);
xlabel('Yöntemler'); ylabel('NSAD');
title('Normalized Sum of Absolute Differences');
grid on;
ylim(common_ylim);

subplot(1,3,3);
bar(nr_array);
set(gca, 'XTick', 1:num_methods, 'XTickLabel', methods, 'FontSize', 14);
xlabel('Yöntemler'); ylabel('NR');
title('Normalized Residual');
grid on;
ylim(common_ylim);

%% save
recon.tol = tol ;
recon.max_itr = max_itr ;
recon.noise_std = noise_std ;
recon.noise_level_dB = noise_level_dB ;
recon.SNR_dB = SNR_dB ;
recon.lambda_range = lambda_range ;
recon.num_lambda = num_lambda ;
recon.iso_value = iso_value ;
save('recon_data.mat', 'recon');

%% Destek Fonksiyonları
function x = ista_solver(A, b, lam, tol, max_itr, display_interval)
    if nargin < 6, display_interval = 10; end
    
    [~, n] = size(A);
    x = zeros(n,1);
    L = norm(A,2)^2;
    tau = 1/L;
    ATA = A'*A;  % Önceden hesapla
    ATb = A'*b;  % Önceden hesapla
    
    fprintf('ISTA başladı (λ=%.2e, max_itr=%d)...\n', lam, max_itr);
    t_start = tic;
    
    for iter = 1:max_itr
        x_old = x;
        grad = ATA*x - ATb; % Optimize edilmiş gradyan
        x = sign(x - tau*grad) .* max(abs(x - tau*grad) - lam*tau, 0);
        
        % İlerleme raporu
        if mod(iter, display_interval) == 0
            elapsed = toc(t_start);
            eta = (elapsed/iter) * (max_itr-iter);
            fprintf('Iter %5d | ||x||_1: %.2e | ETA: %.1fs\n', iter, norm(x,1), eta);
        end
        
        if norm(x - x_old, 2) < tol
            fprintf('Yakınsama: iter=%d, hata=%.1e\n', iter, norm(x - x_old,2));
            break;
        end
    end
    fprintf('Toplam süre: %.1fs\n', toc(t_start));
end

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

function [volume_error, centroid_error, contrast_value] = quality_metrics(original_volume, reconstructed_volume)
    % Volume Error Calculation
    volume_error = abs(nnz(original_volume) - nnz(reconstructed_volume));
    
    % Centroid Error Calculation
    original_centroid = centroid(original_volume);
    reconstructed_centroid = centroid(reconstructed_volume);
    centroid_error = norm(original_centroid - reconstructed_centroid); 
    
    % Contrast Calculation
    % [volume_error, centroid_error, contrast_value]
    % max_intensity = max(reconstructed_volume(:));
    % min_intensity = min(reconstructed_volume(:));
    % mean_intensity = mean(reconstructed_volume(:));
    % contrast_value = (max_intensity - min_intensity) / mean_intensity;
end

function c = centroid(volume)
    % Calculate the centroid of a 3D volume
    [x, y, z] = ndgrid(1:size(volume, 1), 1:size(volume, 2), 1:size(volume, 3));
    total_mass = sum(volume(:));
    c = [sum(x(:) .* volume(:)) / total_mass, ...
         sum(y(:) .* volume(:)) / total_mass, ...
         sum(z(:) .* volume(:)) / total_mass];

end
