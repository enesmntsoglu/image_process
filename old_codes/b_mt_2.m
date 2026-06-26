%% Ayarlar
fprintf('--- Başlangıç: Ayarlar Yükleniyor ---\n');
norm_type = 1;  % L1 Norm
tol = 1e-7;
max_itr = 10000;
fprintf('Seçilen norm: L%d, tol = %e, max_itr = %d\n', norm_type, tol, max_itr);

%% Veri Oluşturma/Yükleme (Örnek veri)
fprintf('Veriler oluşturuluyor...\n');

% Gürültü ekleme (Normalizasyon SONRASI)
b_ideal_normalized = cfg.b / max(abs(cfg.b(:)));
noise_std = 0.03;
b_case2 = b_ideal_normalized + noise_std * randn(size(b_ideal_normalized));

%% Normalizasyon
A = cfg.ms ./ max(abs(cfg.ms(:)));
b_case1 = b_ideal_normalized;  % Zaten normalize edildi
[m, n] = size(A);
delta_target = noise_std * sqrt(m);  % Makale Eq.21

%% L1 Çözücü Fonksiyon (Optimize Edilmiş)
l1_solution = @(lam, b_in) ista_solver(A, b_in, lam, tol, max_itr, 10000);

%% Lambda Aralığı (Genişletilmiş)
lambda_range = logspace(-1, 1.5, 10); % Örneğin 10^-2 ile 10^2 arası
num_lambda = length(lambda_range);

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
    
    X_lambda_ideal{i} = x_lambda_case1;
    X_lambda_noisy{i} = x_lambda_case2;
    
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

%% Optimal Lambda Seçimi (Triangle / Knee Method)
lx1 = log(reg_norm_case1);
ly1 = log(res_norm_case1);
[lx2, ly2] = deal(log(reg_norm_case2), log(res_norm_case2));

% Üçgen yöntemi ile köşe belirleme
[idx_triangle_case1, ~] = corner_by_triangle(lx1, ly1);
opt_lambda_triangle_case1 = lambda_range(idx_triangle_case1);

[idx_triangle_case2, ~] = corner_by_triangle(lx2, ly2);
opt_lambda_triangle_case2 = lambda_range(idx_triangle_case2);

fprintf('Optimal Lambda Değerleri (Triangle Method):\n');
fprintf('  L-Curve (İdeal): %.5e\n', opt_lambda_triangle_case1);
fprintf('  L-Curve (Gürültülü): %.5e\n', opt_lambda_triangle_case2);
%% Optimal Lambda Seçimi (Triangle / Knee Method)
% İdeal durum için
[k_corner_ideal, info_ideal] = corner(res_norm_case1, reg_norm_case1, 1);
opt_lambda_ideal = lambda_range(k_corner_ideal);
fprintf('Optimal lambda (İdeal): %.5e (k = %d, info = %d)\n', opt_lambda_ideal, k_corner_ideal, info_ideal);

% Gürültülü durum için 
[k_corner_noisy, info_noisy] = corner(res_norm_case2, reg_norm_case2, 1);
opt_lambda_noisy = lambda_range(k_corner_noisy);
fprintf('Optimal lambda (Gürültülü): %.5e (k = %d, info = %d)\n', opt_lambda_noisy, k_corner_noisy, info_noisy);

%% L-Curve: İdeal ve Gürültülü (Tek Pencere, Yan Yana Subplot)
figure;
subplot(1,2,1);
loglog(reg_norm_case1, res_norm_case1, 'bo-', 'LineWidth',1.5);
hold on;
loglog(reg_norm_case1(idx_LC_case1), res_norm_case1(idx_LC_case1), 'rs', 'MarkerSize',10, 'LineWidth',2);
loglog(reg_norm_case1(idx_triangle_case1), res_norm_case1(idx_triangle_case1), 'g^', 'MarkerSize',10, 'LineWidth',2);
loglog(reg_norm_case1(k_corner_ideal), res_norm_case1(k_corner_ideal), 'm*', 'MarkerSize',10, 'LineWidth',2);
xlabel('||x_{\lambda}||_1'); 
ylabel('||A x_{\lambda} - b||_2');
title('L-Curve (İdeal Veri)');
legend('L-Curve', 'Curvature Opt', 'Triangle Opt', 'Location','best');
grid on;

subplot(1,2,2);
loglog(reg_norm_case2, res_norm_case2, 'r*-', 'LineWidth',1.5);
hold on;
loglog(reg_norm_case2(idx_LC_case2), res_norm_case2(idx_LC_case2), 'rs', 'MarkerSize',10, 'LineWidth',2);
loglog(reg_norm_case2(idx_triangle_case2), res_norm_case2(idx_triangle_case2), 'g^', 'MarkerSize',10, 'LineWidth',2);
loglog(reg_norm_case2(k_corner_noisy), res_norm_case2(k_corner_noisy), 'm*', 'MarkerSize',10, 'LineWidth',2);
xlabel('||x_{\lambda}||_1'); 
ylabel('||A x_{\lambda} - b||_2');
title('L-Curve (Gürültülü Veri)');
legend('L-Curve', 'Curvature Opt', 'Triangle Opt', 'Location','best');
grid on;

%% Morozov Discrepancy: Gürültülü Veri (Delta Target Eklenmiş)
figure;
semilogx(lambda_range, res_norm_case2, 'b-o', 'LineWidth',1.5); 
hold on;
semilogx(lambda_range, delta_est_case2, 'm--', 'LineWidth',1.5);  % Dinamik delta
semilogx(lambda_range, ones(size(lambda_range)) * delta_target, 'r-.', 'LineWidth',1.5);
xlabel('\lambda'); 
ylabel('Değer');
title('Morozov Discrepancy (Gürültülü Veri)');
legend('Rezidü Norm', 'Dinamik \delta(\lambda)', 'Delta Target','Location','best');
grid on;

%% GCV Kriteri: İdeal ve Gürültülü (Tek Pencere, Yan Yana Subplot)
figure;
subplot(1,2,1);
semilogx(lambda_range, gcv_case1, 'bo-', 'LineWidth',1.5);
xlabel('\lambda'); 
ylabel('GCV');
title('GCV Kriteri (İdeal Veri)');
grid on;

subplot(1,2,2);
semilogx(lambda_range, gcv_case2, 'r*-', 'LineWidth',1.5);
xlabel('\lambda'); 
ylabel('GCV');
title('GCV Kriteri (Gürültülü Veri)');
grid on;

%% 3B Rekonstrüksiyon
x_opt_LC_noisy = X_lambda_noisy{idx_LC_case2};
x_opt_GCV_noisy = X_lambda_noisy{idx_GCV_case2};
x_opt_GCV_ideal = X_lambda_ideal{idx_GCV_case1};
x_opt_Morozov_noisy = X_lambda_noisy{idx_Morozov_case2};
x_opt_triangle_noisy = X_lambda_noisy{idx_triangle_case2}; % Yeni eklenen satır

Reconstructed_LC = reshape(x_opt_LC_noisy, size(vol_preX));
Reconstructed_GCV = reshape(x_opt_GCV_noisy, size(vol_preX));
Reconstructed_GCV_ideal = reshape(x_opt_GCV_ideal, size(vol_preX));
Reconstructed_Morozov = reshape(x_opt_Morozov_noisy, size(vol_preX));
Reconstructed_Triangle = reshape(x_opt_triangle_noisy, size(vol_preX)); % Yeni eklenen satır

threshold = 0.1 * max([Reconstructed_LC(:); Reconstructed_GCV(:); Reconstructed_Morozov(:); Reconstructed_Triangle(:)]);

figure('Name','3B Rekonstrüksiyon');
subplot(2,3,1);
patch(isosurface(vol_preX), 'FaceColor','blue', 'EdgeColor','none');
title('Orijinal Phantom'); view(3); axis tight; camlight;

subplot(2,3,2);
patch(isosurface(Reconstructed_LC, threshold), 'FaceColor','red', 'EdgeColor','none');
title('L-Curve Rekonstrüksiyon'); view(3); axis tight; camlight;

subplot(2,3,3);
patch(isosurface(Reconstructed_GCV, threshold), 'FaceColor','green', 'EdgeColor','none');
title('GCV Rekonstrüksiyon'); view(3); axis tight; camlight;

subplot(2,3,4);
patch(isosurface(Reconstructed_Morozov, threshold), 'FaceColor','magenta', 'EdgeColor','none');
title('Morozov Rekonstrüksiyon'); view(3); axis tight; camlight;

subplot(2,3,5);
patch(isosurface(Reconstructed_Triangle, threshold), 'FaceColor','cyan', 'EdgeColor','none');
title('Triangle Method Rekonstrüksiyon'); view(3); axis tight; camlight;

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
