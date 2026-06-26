% x_reconst_4_combined.m
% Combined script: x_reconst_3.m + mpd_new_inverse_lambda_finder_v7.m
% Bu script, hem iteratif MPD algoritmasını çalıştırarak optimal \lambda'yı bulur, 
% hem de geleneksel \lambda taramasını (L-Curve, vs.) yaparak sonuçları tek bir 
% ekranda karşılaştırmalı olarak sunar.

%% —————— 1) Gerekli Değişkenleri Al ve MPD Parametreleri ——————
if exist('cfg', 'var') && isfield(cfg, 'A_matrix')
    A_cpu = double(cfg.A_matrix);
elseif exist('cfg', 'var') && isfield(cfg, 'ms')
    A_cpu = double(cfg.ms);
elseif exist('ms', 'var')
    A_cpu = double(ms);
else
    error('A matrisi bulunamadı (cfg.A_matrix veya cfg.ms veya ms değişkenlerini kontrol edin).');
end

if exist('cfg', 'var') && isfield(cfg, 'b')
    b_cpu = double(cfg.b(:));
elseif exist('b', 'var')
    b_cpu = double(b(:));
else
    error('b vektörü bulunamadı (cfg.b veya b değişkenlerini kontrol edin).');
end

if exist('cfg', 'var') && isfield(cfg, 'vx')
    vx = cfg.vx;
else
    vx = 25; 
end
nt = 20;

[m, n] = size(A_cpu);
if numel(b_cpu) ~= m
    error('Boyut uyumsuz: size(A,1)=%d, numel(b)=%d', m, numel(b_cpu));
end
%%
if exist('vol_preX', 'var') && ~isempty(vol_preX)
    has_phantom = true;
    if exist('cfg', 'var') && isfield(cfg, 'unitinmm')
        unitInMM = cfg.unitinmm;
    else
        unitInMM = 0.1;
    end
else
    has_phantom = false;
end
%%
% --- MPD v7 Parametreleri ---
params = struct();
params.p = 1;                    
params.tol = 1e-4;               
params.max_itr = 10000;          
params.nu = 1e-4;                
params.eps0 = 1e-10;             
params.rootfact = 0.5;           
params.iso_ratio = 0.3;          
params.lambda_init = 1;          
params.lambda_min = 1e-8;        
params.lambda_max = 200;         
params.lambda_damping = 0.5;     
params.lambda_rel_tol = 1e-4;    
params.outer_max_iter = 50;      
params.trace_samples = 8;        
params.trace_tol = 1e-3;         
params.trace_maxit = 100;        
params.trace_seed = 1234;        
params.trace_use_gpu = true;     
params.trace_verbose = true;     
params.trace_print_stride = 10;  
params.use_calibration = true;   
params.lambda_cal = 20;          
params.max_itr_cal = 5000;       
params.tol_cal = 1e-3;           
params.cal_min = 0.001;          
params.cal_max = 1000;           
params.sigma2_mode = 'trimmed';  
params.sigma2_trim_pct = 0.05;   
params.sigma2_max = 0.1;         

%% —————— 2) GPU Context Doğrulama ——————
fprintf('\n=== x_reconst_4_combined (MPD + Lambda Sweep) ===\n');
gpu_ok = false;
for attempt = 1:3
    try
        d = gpuDevice();
        wait(d);
        testArr = gpuArray(ones(10, 1, 'double'));
        testSum = sum(testArr); %#ok<NASGU>
        clear testArr testSum;
        gpu_ok = true;
        break;
    catch
        fprintf('[GPU] Context bozuk (deneme %d/3), sıfırlanıyor...\n', attempt);
        try
            reset(gpuDevice());
        catch
        end
        pause(1);
    end
end
if ~gpu_ok
    error('GPU context kurtarılamadı. MATLAB''i yeniden başlatın.');
end
fprintf('GPU: %s (CC=%s, Bellek=%.1f GB, Boş=%.1f GB)\n', ...
    d.Name, d.ComputeCapability, d.TotalMemory/1e9, d.AvailableMemory/1e9);

%% —————— 3) Normalizasyon ve CPU Hazırlık (Hafıza Dostu) ——————
sA = max(abs(A_cpu(:))); if sA == 0, sA = 1; end
A_norm_cpu = A_cpu ./ sA;

sb = max(abs(b_cpu(:))); if sb == 0, sb = 1; end
b_norm_cpu = b_cpu ./ sb;

D_diag_cpu = sum(A_norm_cpu.^2, 1)';
D_diag_cpu = D_diag_cpu .^ params.rootfact;
dmax = max(abs(D_diag_cpu));
if dmax > 0
    D_diag_cpu = D_diag_cpu ./ dmax;
end
D_diag_cpu = max(D_diag_cpu, params.eps0);
D2_cpu = D_diag_cpu .^ 2;
AtA_diag_cpu = sum(A_norm_cpu.^2, 1).';

%% —————— 4) GPU'ya Aktarım ve Bellek Kontrolü ——————
estimated_total = (numel(A_norm_cpu)*8 + numel(b_norm_cpu)*8 + numel(D_diag_cpu)*8*3 + numel(AtA_diag_cpu)*8) * 2.5;
if estimated_total > d.AvailableMemory
    warning(['GPU belleği yetersiz olabilir. Tahmini gereksinim: %.1f GB, ' ...
             'Mevcut: %.1f GB. Devam ediliyor...'], ...
             estimated_total/1e9, d.AvailableMemory/1e9);
end

fprintf('\nVeriler GPU belleğine kalıcı (persistent) yükleniyor...\n');
Ag = gpuArray(A_norm_cpu);
bg = gpuArray(b_norm_cpu);
Dg = gpuArray(D_diag_cpu);
D2g = gpuArray(D2_cpu);
AtA_diagg = gpuArray(AtA_diag_cpu);

clear A_cpu b_cpu A_norm_cpu b_norm_cpu D_diag_cpu D2_cpu AtA_diag_cpu;

%% —————— 5) MPD v7 İle Optimal \lambda Bulunması ——————
fprintf('\n======================================================\n');
fprintf('Aşama 1: MPD v7 Algoritması ile İteratif \\lambda Bulunması\n');
fprintf('======================================================\n');

cal_factor = 1.0;
if params.use_calibration
    fprintf('\n--- Kalibrasyon Adımı ---\n');
    x_cal_init = gpuArray.zeros(n, 1, 'double');
    x_coarse_g = Lp_solver_depthver2_gpu_2_double_v3_fast( ...
        Ag, bg, params.p, params.lambda_cal, params.tol_cal, ...
        params.max_itr_cal, params.nu, params.eps0, x_cal_init, Dg, false, 1);
    b_predicted_g = Ag * x_coarse_g;
    b_dot_b_cpu = gather(bg' * bg);
    b_dot_bp_cpu = gather(bg' * b_predicted_g);

    if abs(b_dot_b_cpu) > params.eps0 && isfinite(b_dot_bp_cpu)
        cal_factor = b_dot_bp_cpu / b_dot_b_cpu;
        cal_factor = max(min(cal_factor, params.cal_max), params.cal_min);
    else
        cal_factor = 1.0;
    end
    bg = bg * cal_factor; % b'yi kalibre et
    fprintf('Kalibrasyon faktörü: %.6g\n', cal_factor);
end

% MPD İterasyonu
if params.use_calibration && exist('x_coarse_g', 'var')
    xg_mpd = x_coarse_g;
else
    xg_mpd = gpuArray.zeros(n, 1, 'double');
end

lambda_mpd = min(max(params.lambda_init, params.lambda_min), params.lambda_max);
try gpurng(params.trace_seed); catch; end
rng(params.trace_seed);

mpd_hist_len = 0;
lam_hist = zeros(params.outer_max_iter, 1);
res_hist = zeros(params.outer_max_iter, 1);
reg_hist = zeros(params.outer_max_iter, 1);
X_hist   = cell(params.outer_max_iter, 1);

for k = 1:params.outer_max_iter
    xg_mpd = Lp_solver_depthver2_gpu_2_double_v3_fast( ...
        Ag, bg, params.p, lambda_mpd, params.tol, params.max_itr, ...
        params.nu, params.eps0, xg_mpd, Dg, false, 1);

    residuals_g = Ag * xg_mpd - bg;
    res2 = gather(sum(residuals_g.^2));
    Tx1 = gather(sum(abs(Dg .* xg_mpd)));

    % Trace estimation (Sequential PCG)
    traceT = estimate_trace_t_gpu_local(Ag, AtA_diagg, D2g, lambda_mpd, ...
        params.trace_samples, params.trace_tol, params.trace_maxit, ...
        params.eps0, params.trace_verbose, params.trace_print_stride, k);

    traceA = n - lambda_mpd * traceT;
    denomSigma = max(m - traceA, params.eps0);
    sigma2_standard = res2 / denomSigma;
    
    if strcmp(params.sigma2_mode, 'trimmed')
        residuals_cpu = gather(residuals_g);
        sorted_res2 = sort(residuals_cpu.^2);
        lo = max(1, ceil(params.sigma2_trim_pct * m));
        hi = min(m, floor((1 - params.sigma2_trim_pct) * m));
        if hi > lo
            trimmed_sum = sum(sorted_res2(lo:hi));
            eff_denom = denomSigma * ((hi - lo + 1) / m);
            sigma2 = trimmed_sum / max(eff_denom, params.eps0);
        else
            sigma2 = sigma2_standard;
        end
    else
        sigma2 = sigma2_standard;
    end
    sigma2 = min(sigma2, params.sigma2_max);

    delta = (2 * lambda_mpd * traceT)^2 + 8 * (n^2) * (Tx1^2);
    zeta = (2 * lambda_mpd * traceT + sqrt(max(delta, 0))) / (2 * n^2);
    lambdaRaw = (2^(3/2)) * sigma2 / max(zeta, params.eps0);
    lambdaRaw = min(max(lambdaRaw, params.lambda_min), params.lambda_max);

    lambdaNew = (1 - params.lambda_damping) * lambda_mpd + params.lambda_damping * lambdaRaw;
    lambdaNew = min(max(lambdaNew, params.lambda_min), params.lambda_max);
    rel = abs(lambdaNew - lambda_mpd) / max(lambda_mpd, params.eps0);

    mpd_hist_len = k;
    lam_hist(k) = lambda_mpd;
    res_hist(k) = gather(norm(residuals_g, 2));
    reg_hist(k) = gather(norm(xg_mpd, 1));
    X_hist{k}   = gather(xg_mpd);

    fprintf('[MPD iter %02d] lam=%.4g → new=%.4g (rel=%.2e) | sig2=%.3e\n', ...
        k, lambda_mpd, lambdaNew, rel, sigma2);

    lambda_mpd = lambdaNew;
    if rel < params.lambda_rel_tol
        fprintf('MPD Yakınsadı! (iterasyon %d)\n', k);
        break;
    end
end

% Final MPD Refit
opt_lambda_MPD = lambda_mpd;
xg_mpd = Lp_solver_depthver2_gpu_2_double_v3_fast( ...
    Ag, bg, params.p, opt_lambda_MPD, params.tol, params.max_itr, ...
    params.nu, params.eps0, xg_mpd, Dg, false, 1);
x_MPD = gather(xg_mpd);

% MPD için Res/Reg Normu (Diagnostik çizimi için)
res_val_mpd = norm(Ag * xg_mpd - bg, 2);
reg_val_mpd = norm(xg_mpd, 1);
res_norm_MPD = gather(res_val_mpd);
reg_norm_MPD = gather(reg_val_mpd);

% --- Ekstra Test: MPD Geçmişine Inverse Metotları Uygulama ---
lam_hist = lam_hist(1:mpd_hist_len);
res_hist = res_hist(1:mpd_hist_len);
reg_hist = reg_hist(1:mpd_hist_len);
X_hist   = X_hist(1:mpd_hist_len);

if mpd_hist_len > 1
    % L-Curve vb. gradyan tabanlı hesaplamalar sıralı dizi gerektirir
    [lam_hist_sorted, sort_idx] = sort(lam_hist);
    res_hist_sorted = res_hist(sort_idx);
    reg_hist_sorted = reg_hist(sort_idx);
    X_hist_sorted   = X_hist(sort_idx);

    reg_safe = reg_hist_sorted + eps;
    res_safe = res_hist_sorted + eps;

    [~, ~, curv_hist] = compute_curvature(reg_safe, res_safe, lam_hist_sorted);
    [~, i_LC] = max(curv_hist);
    opt_hist_LC = lam_hist_sorted(i_LC);

    gcv_hist = zeros(mpd_hist_len, 1);
    for i = 1:mpd_hist_len
        xi = X_hist_sorted{i};
        df = sum(abs(xi) ./ sqrt(xi.^2 + 1e-6^2));
        gcv_hist(i) = (res_safe(i)^2) / (max(m - df, 1e-9))^2;
    end
    [~, i_GCV] = min(gcv_hist);
    opt_hist_GCV = lam_hist_sorted(i_GCV);

    delta_t = sqrt(m) * (median(res_safe) * 0.1);
    [~, i_Mor] = min(abs(res_safe - delta_t));
    opt_hist_Morozov = lam_hist_sorted(i_Mor);

    [i_Tri, ~] = corner_by_triangle(log(reg_safe), log(res_safe));
    opt_hist_Triangle = lam_hist_sorted(i_Tri);

    lx = log(reg_safe); ly = log(res_safe);
    P = [ly(:), lx(:)];
    ang_hist = inf(mpd_hist_len, 1);
    for kk = 2:mpd_hist_len-1
        v1 = P(kk-1,:) - P(kk,:);
        v2 = P(kk+1,:) - P(kk,:);
        if any(~isfinite([v1 v2]), 'all'), continue; end
        cth = max(-1, min(1, dot(v1, v2) / (norm(v1) * norm(v2) + eps)));
        ang_hist(kk) = acos(cth);
    end
    [~, i_Cor] = min(ang_hist);
    opt_hist_Corner = lam_hist_sorted(i_Cor);

    u_hist = 1./(res_safe.^2) + 1./(reg_safe.^2);
    [~, i_UC] = min(u_hist);
    opt_hist_UC = lam_hist_sorted(i_UC);
%%
    fprintf('\n------------------------------------------------------\n');
    fprintf('EKSTRA TEST: MPD''nin İterasyonlarda Geçtiği Lambdalar Üzerinde Geleneksel Yöntemler\n');
    fprintf('Arama uzayımız sadece MPD''nin geçtiği lambdalar (%d adet) olsaydı:\n', mpd_hist_len);
    fprintf('  L-Curve   : %.5e\n', opt_hist_LC);
    fprintf('  GCV       : %.5e\n', opt_hist_GCV);
    fprintf('  Morozov   : %.5e\n', opt_hist_Morozov);
    fprintf('  Triangle  : %.5e\n', opt_hist_Triangle);
    fprintf('  Corner    : %.5e\n', opt_hist_Corner);
    fprintf('  U-Curve   : %.5e\n', opt_hist_UC);
    fprintf('  MPD Sonuç : %.5e\n', opt_lambda_MPD);
    fprintf('------------------------------------------------------\n\n');
%%
    if has_phantom
        fprintf('EKSTRA TEST METRİKLERİ: MPD geçmişinden seçilen lambdaların Phantom metrikleri\n');
        
        idx_list = [i_LC, i_GCV, i_Mor, i_Tri, i_Cor, i_UC];
        method_names_hist = {'L-Curve (Hist)'; 'GCV (Hist)'; 'Morozov (Hist)'; 'Triangle (Hist)'; 'Corner (Hist)'; 'U-Curve (Hist)'};
        
        NR_h = zeros(7,1); NSSD_h = zeros(7,1); NSAD_h = zeros(7,1);
        CentErrMM_h = zeros(7,1); VolErrMM3_h = zeros(7,1);
        vSize = [vx vx nt];
        
        for j = 1:6
            x_raw_h = X_hist_sorted{idx_list(j)};
            vol_raw_h = reshape(x_raw_h, vSize);
            vol_thr_h = apply_iso_threshold(vol_raw_h, params.iso_ratio);
            
            m_vals = compute_metrics(vol_preX, vol_thr_h, unitInMM);
            NR_h(j) = m_vals.nr;
            NSSD_h(j) = m_vals.nssd;
            NSAD_h(j) = m_vals.nsad;
            CentErrMM_h(j) = m_vals.centroid_error_mm;
            VolErrMM3_h(j) = m_vals.volume_error_mm3;
        end
        
        % 7. method is MPD final
        vol_raw_mpd = reshape(x_MPD, vSize);
        vol_thr_mpd = apply_iso_threshold(vol_raw_mpd, params.iso_ratio);
        m_vals_mpd = compute_metrics(vol_preX, vol_thr_mpd, unitInMM);
        NR_h(7) = m_vals_mpd.nr;
        NSSD_h(7) = m_vals_mpd.nssd;
        NSAD_h(7) = m_vals_mpd.nsad;
        CentErrMM_h(7) = m_vals_mpd.centroid_error_mm;
        VolErrMM3_h(7) = m_vals_mpd.volume_error_mm3;
        
        LambdaVals_h = [opt_hist_LC; opt_hist_GCV; opt_hist_Morozov; opt_hist_Triangle; opt_hist_Corner; opt_hist_UC; opt_lambda_MPD];
        method_names_hist{7} = 'MPD Sonuç';
        
        MetricsTableHist = table(method_names_hist, LambdaVals_h, NR_h, NSSD_h, NSAD_h, CentErrMM_h, VolErrMM3_h, ...
            'VariableNames', {'Method', 'Lambda', 'NR', 'NSSD', 'NSAD', 'CentErrMM', 'VolErrMM3'});
        disp(MetricsTableHist);
    end
end

%% —————— 6) L‐curve İçin \lambda Taraması (Geleneksel Metotlar) ——————
fprintf('\n======================================================\n');
fprintf('Aşama 2: Geleneksel \\lambda Taraması ve Karşılaştırma\n');
fprintf('======================================================\n');

lambda_range = logspace(-3, 1.5, 30);
num_lambda   = numel(lambda_range);

res_norm     = zeros(num_lambda, 1);
reg_norm     = zeros(num_lambda, 1);
X_lambdas    = cell(num_lambda, 1);   

tic;
x0g = gpuArray.zeros(n, 1, 'double');
fprintf('Lambda tarama başlıyor (%d adet lambda)...\n', num_lambda);
for i = 1:num_lambda
    lam = lambda_range(i);
    xg = Lp_solver_depthver2_gpu_2_double_v3_fast( ...
        Ag, bg, params.p, lam, params.tol, 1e5, params.nu, params.eps0, x0g, Dg, false, 1);
    
    res_val_g = norm(Ag * xg - bg, 2);
    reg_val_g = norm(xg, 1);
    
    res_norm(i) = gather(res_val_g);
    reg_norm(i) = gather(reg_val_g);
    X_lambdas{i} = gather(xg);
    
    fprintf('  \\lambda = %8.2e  →  res = %8.3e, reg = %8.3e\n', lam, res_norm(i), reg_norm(i));
end
fprintf('Tarama tamamlandı. Toplam geçen süre: %.2f saniye.\n', toc);

clear Ag bg Dg x0g xg xg_mpd D2g AtA_diagg res_val_g reg_val_g;

%% —————— 7) Çeşitli Yöntemlerle Optimal \lambda’yı Bul (CPU Tarafı) ——————
reg_norm_safe = reg_norm + eps;
res_norm_safe = res_norm + eps;

if num_lambda > 1
    % 1) L-Curve (Curvature)
    [~, ~, curvature_all] = compute_curvature(reg_norm_safe, res_norm_safe, lambda_range);
    [~, idx_LC] = max(curvature_all);
    opt_lambda_LC = lambda_range(idx_LC);

    % 2) GCV
    epsilon_val = 1e-6;
    m_rows = m;
    df_smooth = zeros(num_lambda, 1);
    gcv_vals  = zeros(num_lambda, 1);
    for i = 1:num_lambda
        xi = X_lambdas{i};
        df_smooth(i) = sum(abs(xi) ./ sqrt(xi.^2 + epsilon_val^2));
        gcv_vals(i)  = (res_norm_safe(i)^2) / (max(m_rows - df_smooth(i), 1e-9))^2;
    end
    [~, idx_GCV] = min(gcv_vals);
    opt_lambda_GCV = lambda_range(idx_GCV);

    % 3) Morozov
    noise_rms_est = median(res_norm_safe) * 0.1;
    delta_target  = sqrt(m_rows) * noise_rms_est;
    [~, idx_Morozov] = min(abs(res_norm_safe - delta_target));
    opt_lambda_Morozov = lambda_range(idx_Morozov);

    % 4) Triangle
    lx = log(reg_norm_safe);
    ly = log(res_norm_safe);
    [idx_triangle, ~] = corner_by_triangle(lx, ly);
    opt_lambda_Triangle = lambda_range(idx_triangle);

    % 5) Corner
    P = [ly(:), lx(:)];
    angles = inf(num_lambda, 1);
    for k = 2:num_lambda-1
        v1 = P(k-1,:) - P(k,:);
        v2 = P(k+1,:) - P(k,:);
        if any(~isfinite([v1 v2]), 'all'), continue; end
        cth = max(-1, min(1, dot(v1, v2) / (norm(v1) * norm(v2) + eps)));
        angles(k) = acos(cth);
    end
    [~, k_corner] = min(angles);
    opt_lambda_Corner = lambda_range(k_corner);

    % 6) U-Curve
    U_vals = 1./(res_norm_safe.^2) + 1./(reg_norm_safe.^2);
    [~, idx_UC] = min(U_vals);
    opt_lambda_UC = lambda_range(idx_UC);
else
    idx_LC = 1; idx_GCV = 1; idx_Morozov = 1; 
    idx_triangle = 1; k_corner = 1; idx_UC = 1;
    opt_lambda_LC = lambda_range(1); opt_lambda_GCV = lambda_range(1);
    opt_lambda_Morozov = lambda_range(1); opt_lambda_Triangle = lambda_range(1);
    opt_lambda_Corner = lambda_range(1); opt_lambda_UC = lambda_range(1);
    curvature_all = 0; gcv_vals = 0; U_vals = 0; delta_target = 0;
end

% Sonuç tablosu
MethodNames = {'L-Curve'; 'GCV'; 'Morozov'; 'Triangle'; 'Corner'; 'U-Curve'; 'MPD v7'};
LambdaVals  = [opt_lambda_LC; opt_lambda_GCV; opt_lambda_Morozov; ...
               opt_lambda_Triangle; opt_lambda_Corner; opt_lambda_UC; opt_lambda_MPD];
Topt = table(MethodNames, LambdaVals)
disp('MPD ve diğer yöntemlerin optimal \lambda sonuçları yukarıdadır.');

%% --- 8) Hızlı Lokal/Global Önizleme (3B ve 2D) ---
volSize = [vx vx nt];
Reconstructed_LC       = reshape(X_lambdas{idx_LC},       volSize);
Reconstructed_GCV      = reshape(X_lambdas{idx_GCV},      volSize);
Reconstructed_Morozov  = reshape(X_lambdas{idx_Morozov},  volSize);
Reconstructed_Triangle = reshape(X_lambdas{idx_triangle}, volSize);
Reconstructed_Corner   = reshape(X_lambdas{k_corner},     volSize);
Reconstructed_UC       = reshape(X_lambdas{idx_UC},       volSize);
Reconstructed_MPD      = reshape(x_MPD,                   volSize);

if mpd_hist_len > 1
    Reconstructed_LC_hist       = reshape(X_hist_sorted{i_LC},  volSize);
    Reconstructed_GCV_hist      = reshape(X_hist_sorted{i_GCV}, volSize);
    Reconstructed_Morozov_hist  = reshape(X_hist_sorted{i_Mor}, volSize);
    Reconstructed_Triangle_hist = reshape(X_hist_sorted{i_Tri}, volSize);
    Reconstructed_Corner_hist   = reshape(X_hist_sorted{i_Cor}, volSize);
    Reconstructed_UC_hist       = reshape(X_hist_sorted{i_UC},  volSize);
end

have_global = exist('scanX','var') && exist('scanY','var') && ...
              exist('recons_offset_x','var') && exist('recons_offset_y','var');
if have_global
    offx = recons_offset_x;
    offy = recons_offset_y;
    if offx >= 0 && offy >= 0 && offx <= (scanX - vx) && offy <= (scanY - vx)
        Vfull_LC       = zeros(scanY, scanX, nt); Vfull_LC(offy+(1:vx), offx+(1:vx), :) = Reconstructed_LC;
        Vfull_GCV      = zeros(scanY, scanX, nt); Vfull_GCV(offy+(1:vx), offx+(1:vx), :) = Reconstructed_GCV;
        Vfull_Morozov  = zeros(scanY, scanX, nt); Vfull_Morozov(offy+(1:vx), offx+(1:vx), :) = Reconstructed_Morozov;
        Vfull_Triangle = zeros(scanY, scanX, nt); Vfull_Triangle(offy+(1:vx), offx+(1:vx), :) = Reconstructed_Triangle;
        Vfull_Corner   = zeros(scanY, scanX, nt); Vfull_Corner(offy+(1:vx), offx+(1:vx), :) = Reconstructed_Corner;
        Vfull_UC       = zeros(scanY, scanX, nt); Vfull_UC(offy+(1:vx), offx+(1:vx), :) = Reconstructed_UC;
        Vfull_MPD      = zeros(scanY, scanX, nt); Vfull_MPD(offy+(1:vx), offx+(1:vx), :) = Reconstructed_MPD;
    else
        have_global = false;
    end
end

if has_phantom
    fprintf('\n======================================================\n');
    fprintf('Aşama 3: Phantom (vol_preX) Metrik Hesaplamaları\n');
    fprintf('======================================================\n');
    
    vol_methods = {Reconstructed_LC, Reconstructed_GCV, Reconstructed_Morozov, ...
                   Reconstructed_Triangle, Reconstructed_Corner, Reconstructed_UC, Reconstructed_MPD};
    MethodNames_All = {'L-Curve'; 'GCV'; 'Morozov'; 'Triangle'; 'Corner'; 'U-Curve'; 'MPD v7'};
    
    NR = zeros(7,1); NSSD = zeros(7,1); NSAD = zeros(7,1);
    CentErrMM = zeros(7,1); VolErrMM3 = zeros(7,1);
    
    for i = 1:7
        vol_thr = apply_iso_threshold(vol_methods{i}, params.iso_ratio);
        m_vals = compute_metrics(vol_preX, vol_thr, unitInMM);
        NR(i) = m_vals.nr;
        NSSD(i) = m_vals.nssd;
        NSAD(i) = m_vals.nsad;
        CentErrMM(i) = m_vals.centroid_error_mm;
        VolErrMM3(i) = m_vals.volume_error_mm3;
    end
    
    MetricsTable = table(MethodNames_All, LambdaVals, NR, NSSD, NSAD, CentErrMM, VolErrMM3, ...
        'VariableNames', {'Method', 'Lambda', 'NR', 'NSSD', 'NSAD', 'CentErrMM', 'VolErrMM3'});
    disp(MetricsTable);
    disp('Phantom kullanılarak hesaplanan kalite metrikleri yukarıdadır.');
end

%% ===== TEK PENCERE: Diagnostik + 3B Rekonstrüksiyon (Tıklayınca Büyüt) =====
f = figure('Name','Lambda Seçim Karşılaştırma (MPD vs Diğerleri)','Color','w','Units','normalized','Position',[0.05 0.05 0.9 0.9]);
tg = uitabgroup(f);

% ====================== Sekme 1: Diagnostik ======================
if num_lambda > 1
    tabDiag = uitab(tg, 'Title', 'Diagnostik');
    tl1 = tiledlayout(tabDiag, 2, 3, 'TileSpacing','compact','Padding','compact');

    % (1) L-Curve
    ax1 = nexttile(tl1,1);
    loglog(ax1, res_norm, reg_norm, '-o','MarkerSize',4); hold(ax1,'on');
    loglog(ax1, res_norm(idx_LC),       reg_norm(idx_LC),       'cs','MarkerSize',10,'LineWidth',1.5);
    loglog(ax1, res_norm(idx_triangle), reg_norm(idx_triangle), 'g^','MarkerSize',8,'LineWidth',1.5);
    loglog(ax1, res_norm_MPD,           reg_norm_MPD,           'p','MarkerEdgeColor','k','MarkerFaceColor','y','MarkerSize',14,'LineWidth',1.5);
    hold(ax1,'off'); grid(ax1,'on');
    xlabel(ax1,'Residual ‖A x(\lambda)-b‖_2'); ylabel(ax1,'Regularizer ‖x(\lambda)‖_1');
    title(ax1,'L-Curve + MPD');
    legend(ax1, 'Sweep','LC','Triangle','MPD','Location','best');
    makeClickable(ax1);

    % (2) Curvature vs \lambda
    ax2 = nexttile(tl1,2);
    semilogx(ax2, lambda_range, curvature_all, '-o','MarkerSize',4); hold(ax2,'on');
    semilogx(ax2, lambda_range(idx_LC), curvature_all(idx_LC), 'cs','MarkerSize',10,'LineWidth',1.5);
    xline(ax2, opt_lambda_MPD, 'y--', 'LineWidth', 2, 'DisplayName', 'MPD \lambda');
    hold(ax2,'off'); grid(ax2,'on');
    xlabel(ax2,'\lambda'); ylabel(ax2,'Curvature');
    title(ax2,'Eğrilik vs \lambda');
    legend(ax2,'Eğrilik','LC Opt','MPD','Location','best');
    makeClickable(ax2);

    % (3) GCV
    ax3 = nexttile(tl1,3);
    semilogx(ax3, lambda_range, gcv_vals, 'r*-','LineWidth',1.2); hold(ax3,'on');
    semilogx(ax3, lambda_range(idx_GCV), gcv_vals(idx_GCV), 'ms','MarkerSize',9,'LineWidth',1.5);
    xline(ax3, opt_lambda_MPD, 'y--', 'LineWidth', 2, 'DisplayName', 'MPD \lambda');
    hold(ax3,'off'); grid(ax3,'on');
    xlabel(ax3,'\lambda'); ylabel(ax3,'GCV');
    title(ax3,'GCV Kriteri');
    legend(ax3,'GCV','GCV Opt','MPD','Location','best');
    makeClickable(ax3);

    % (4) Morozov
    ax4 = nexttile(tl1,4);
    semilogx(ax4, lambda_range, res_norm, 'b-o','LineWidth',1.2); hold(ax4,'on');
    semilogx(ax4, lambda_range, ones(size(lambda_range))*delta_target, 'r-.','LineWidth',1.2);
    semilogx(ax4, lambda_range(idx_Morozov), res_norm(idx_Morozov), 'ms','MarkerSize',9,'LineWidth',1.5);
    plot(ax4, opt_lambda_MPD, res_norm_MPD, 'p','MarkerEdgeColor','k','MarkerFaceColor','y','MarkerSize',14);
    hold(ax4,'off'); grid(ax4,'on');
    xlabel(ax4,'\lambda'); ylabel(ax4,'‖A x(\lambda)-b‖_2');
    title(ax4, sprintf('Morozov: hedef \\delta \\approx %.2e', delta_target));
    legend(ax4,'Rezidü Norm','\delta hedef','Morozov','MPD','Location','best');
    makeClickable(ax4);

    % (5) U-Curve
    ax5 = nexttile(tl1,5);
    semilogx(ax5, lambda_range, U_vals, 'k-^','LineWidth',1.2); hold(ax5,'on');
    semilogx(ax5, lambda_range(idx_UC), U_vals(idx_UC), 'ms','MarkerSize',9,'LineWidth',1.5);
    xline(ax5, opt_lambda_MPD, 'y--', 'LineWidth', 2, 'DisplayName', 'MPD \lambda');
    hold(ax5,'off'); grid(ax5,'on');
    xlabel(ax5,'\lambda'); ylabel(ax5,'U(\lambda)');
    title(ax5,'U-Curve');
    legend(ax5,'U','U-Curve Opt','MPD','Location','best');
    makeClickable(ax5);

    % (6) Özet
    ax6 = nexttile(tl1,6);
    axis(ax6,'off');
    text(0,1, sprintf(['Optimal \\lambda Sonuçları:\n' ...
        '  L-Curve   : %.5e\n' ...
        '  GCV       : %.5e\n' ...
        '  Morozov   : %.5e\n' ...
        '  Triangle  : %.5e\n' ...
        '  Corner    : %.5e\n' ...
        '  U-Curve   : %.5e\n' ...
        '  MPD v7    : %.5e\n'], ...
        opt_lambda_LC, opt_lambda_GCV, opt_lambda_Morozov, ...
        opt_lambda_Triangle, opt_lambda_Corner, opt_lambda_UC, opt_lambda_MPD), ...
        'Parent',ax6,'VerticalAlignment','top','FontName','Consolas','FontSize',10);
    title(ax6,'Özet');
    makeClickable(ax6);
end

% ====================== Sekme 2: 3B Rekon ======================
tab3DLocal = uitab(tg, 'Title', '3B Lokal');
p3DLocal = uipanel('Parent', tab3DLocal, 'BorderType','none', 'Units','normalized', 'Position',[0 0 1 1]);
% 7 metot olduğu için 2x4 grid yapıyoruz
tl2 = tiledlayout(p3DLocal, 2, 4, 'TileSpacing','compact','Padding','compact');

iso_ratio = 0.30;
[Ny, Nx, Nz] = size(Reconstructed_LC);
drawIso = @(ax, V, ttl, fcolor) drawIsoSurface(ax, V, iso_ratio, ttl, fcolor, Nx, Ny, Nz);

ax = nexttile(tl2,1); drawIso(ax, Reconstructed_MPD,      'MPD v7',   [1 0.8 0]); % MPD'yi ilk sıraya koyalım
ax = nexttile(tl2,2); drawIso(ax, Reconstructed_LC,       'LC',       [1 0 0]);
ax = nexttile(tl2,3); drawIso(ax, Reconstructed_GCV,      'GCV',      [0 0.6 0]);
ax = nexttile(tl2,4); drawIso(ax, Reconstructed_Morozov,  'Morozov',  [1 0 1]);
ax = nexttile(tl2,5); drawIso(ax, Reconstructed_Triangle, 'Triangle', [0 1 1]);
ax = nexttile(tl2,6); drawIso(ax, Reconstructed_Corner,   'Corner',   [0.8 0.8 0]);
ax = nexttile(tl2,7); drawIso(ax, Reconstructed_UC,       'U-Curve',  [0 0 1]);
if has_phantom
    ax = nexttile(tl2,8); drawIso(ax, vol_preX, 'Phantom (vol_preX)', [0.5 0.5 0.5]);
else
    ax = nexttile(tl2,8); axis(ax,'off'); title(ax,'(Boş)');
end
set(findall(gcf,'-property','FontSize'),'FontSize',12)

if have_global
    tab3DGlobal = uitab(tg, 'Title', '3B Global');
    p3DGlobal = uipanel('Parent', tab3DGlobal, 'BorderType','none', 'Units','normalized', 'Position',[0 0 1 1]);
    tl3 = tiledlayout(p3DGlobal, 2, 4, 'TileSpacing','compact','Padding','compact');
    [NyG, NxG, NzG] = size(Vfull_LC);
    drawIsoG = @(ax, V, ttl, fcolor) drawIsoSurface(ax, V, iso_ratio, ttl, fcolor, NxG, NyG, NzG);

    ax = nexttile(tl3,1); drawIsoG(ax, Vfull_MPD,      'MPD v7',   [1 0.8 0]);
    ax = nexttile(tl3,2); drawIsoG(ax, Vfull_LC,       'LC',       [1 0 0]);
    ax = nexttile(tl3,3); drawIsoG(ax, Vfull_GCV,      'GCV',      [0 0.6 0]);
    ax = nexttile(tl3,4); drawIsoG(ax, Vfull_Morozov,  'Morozov',  [1 0 1]);
    ax = nexttile(tl3,5); drawIsoG(ax, Vfull_Triangle, 'Triangle', [0 1 1]);
    ax = nexttile(tl3,6); drawIsoG(ax, Vfull_Corner,   'Corner',   [0.8 0.8 0]);
    ax = nexttile(tl3,7); drawIsoG(ax, Vfull_UC,       'U-Curve',  [0 0 1]);
    if has_phantom
        Vfull_Phantom = zeros(scanY, scanX, nt); 
        Vfull_Phantom(offy+(1:vx), offx+(1:vx), :) = vol_preX;
        ax = nexttile(tl3,8); drawIsoG(ax, Vfull_Phantom, 'Phantom (vol_preX)', [0.5 0.5 0.5]);
    else
        ax = nexttile(tl3,8); axis(ax,'off'); title(ax,'(Boş)');
    end
end

% ====================== Sekme 3: 2D Dilimler ======================
tab2D = uitab(tg, 'Title', '2D Dilimler');
tg2D = uitabgroup(tab2D);
if has_phantom
    Volumes2D = {Reconstructed_MPD, Reconstructed_LC, Reconstructed_GCV, Reconstructed_Morozov, ...
                 Reconstructed_Triangle, Reconstructed_Corner, Reconstructed_UC, vol_preX};
    MethodNames2D_ordered = {'MPD v7', 'LC', 'GCV', 'Morozov', 'Triangle', 'Corner', 'U-Curve', 'Phantom'};
else
    Volumes2D = {Reconstructed_MPD, Reconstructed_LC, Reconstructed_GCV, Reconstructed_Morozov, ...
                 Reconstructed_Triangle, Reconstructed_Corner, Reconstructed_UC};
    MethodNames2D_ordered = {'MPD v7', 'LC', 'GCV', 'Morozov', 'Triangle', 'Corner', 'U-Curve'};
end

for mth = 1:numel(MethodNames2D_ordered)
    V = Volumes2D{mth};
    V(isnan(V)) = 0;
    vmaxAll = max(V(:)); if ~isfinite(vmaxAll), vmaxAll = 0; end
    thr = vmaxAll * iso_ratio;
    Mask = V >= thr;
    Vplot = V; Vplot(~Mask) = NaN;

    [~,~,ntM] = size(Vplot);
    nCols = ceil(sqrt(ntM));
    nRows = ceil(ntM/nCols);

    tabM = uitab(tg2D, 'Title', MethodNames2D_ordered{mth});
    pM   = uipanel('Parent', tabM, 'BorderType','none', 'Units','normalized', 'Position',[0 0 1 1]);

    visVals = Vplot(~isnan(Vplot));
    if isempty(visVals)
        vmin = 0; vmax = 1;
    else
        vmin = min(visVals); vmax = max(visVals);
        if ~isfinite(vmin) || ~isfinite(vmax) || vmin >= vmax
            vmin = 0; vmax = max(1, vmaxAll);
        end
    end

    for t = 1:ntM
        ax = subplot(nRows, nCols, t, 'Parent', pM);
        img = Vplot(:,:,t);
        hImg = imagesc(ax, img, [vmin vmax]);
        axis(ax,'equal'); axis(ax,'off');
        title(ax, sprintf('Slice %d', t), 'FontSize', 8);
        set(ax, 'Color', 'k');
        colormap(ax, 'hot');
        set(ax, 'ButtonDownFcn', @(h,~) enlargeAxes2D(h));
        set(hImg, 'HitTest','off','PickableParts','none');
    end

    axlast = subplot(nRows, nCols, ntM, 'Parent', pM);
    try
        cb = colorbar(axlast, 'Location','eastoutside');
    catch
        cb = colorbar(axlast); cb.Location = 'eastoutside';
    end
    cb.Label.String = sprintf('%s intensity (iso = %.2g)', MethodNames2D_ordered{mth}, iso_ratio);
    
    annotation(pM, 'textbox', [0 0.96 1 0.04], 'String', ...
        sprintf('%s — 2D Dilimler (iso = %.2g·max)', MethodNames2D_ordered{mth}, iso_ratio), ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'EdgeColor','none','FontWeight','bold');
end

% ====================== Sekme 5: 3B Lokal ve 2D Dilimler (Hist) ======================
if mpd_hist_len > 1
    % --- 3B Lokal (Hist) ---
    tab3DLocalHist = uitab(tg, 'Title', '3B Lokal (Hist)');
    p3DLocalHist = uipanel('Parent', tab3DLocalHist, 'BorderType','none', 'Units','normalized', 'Position',[0 0 1 1]);
    tl4 = tiledlayout(p3DLocalHist, 2, 4, 'TileSpacing','compact','Padding','compact');

    ax = nexttile(tl4,1); drawIso(ax, Reconstructed_MPD,           'MPD v7 (Ref)', [1 0.8 0]);
    ax = nexttile(tl4,2); drawIso(ax, Reconstructed_LC_hist,       'LC (Hist)',    [1 0 0]);
    ax = nexttile(tl4,3); drawIso(ax, Reconstructed_GCV_hist,      'GCV (Hist)',   [0 0.6 0]);
    ax = nexttile(tl4,4); drawIso(ax, Reconstructed_Morozov_hist,  'Morozov (H)',  [1 0 1]);
    ax = nexttile(tl4,5); drawIso(ax, Reconstructed_Triangle_hist, 'Triangle (H)', [0 1 1]);
    ax = nexttile(tl4,6); drawIso(ax, Reconstructed_Corner_hist,   'Corner (H)',   [0.8 0.8 0]);
    ax = nexttile(tl4,7); drawIso(ax, Reconstructed_UC_hist,       'U-Curve (H)',  [0 0 1]);
    if has_phantom
        ax = nexttile(tl4,8); drawIso(ax, vol_preX, 'Phantom (vol_preX)', [0.5 0.5 0.5]);
    else
        ax = nexttile(tl4,8); axis(ax,'off'); title(ax,'(Boş)');
    end
    set(findall(tab3DLocalHist,'-property','FontSize'),'FontSize',12)

    % --- 2D Dilimler (Hist) ---
    tab2DHist = uitab(tg, 'Title', '2D Dilimler (Hist)');
    tg2DHist = uitabgroup(tab2DHist);
    if has_phantom
        Volumes2DHist = {Reconstructed_MPD, Reconstructed_LC_hist, Reconstructed_GCV_hist, Reconstructed_Morozov_hist, ...
                     Reconstructed_Triangle_hist, Reconstructed_Corner_hist, Reconstructed_UC_hist, vol_preX};
        MethodNames2DHist = {'MPD v7 (Ref)', 'LC (H)', 'GCV (H)', 'Morozov (H)', 'Triangle (H)', 'Corner (H)', 'U-Curve (H)', 'Phantom'};
    else
        Volumes2DHist = {Reconstructed_MPD, Reconstructed_LC_hist, Reconstructed_GCV_hist, Reconstructed_Morozov_hist, ...
                     Reconstructed_Triangle_hist, Reconstructed_Corner_hist, Reconstructed_UC_hist};
        MethodNames2DHist = {'MPD v7 (Ref)', 'LC (H)', 'GCV (H)', 'Morozov (H)', 'Triangle (H)', 'Corner (H)', 'U-Curve (H)'};
    end

    for mth = 1:numel(MethodNames2DHist)
        V = Volumes2DHist{mth};
        V(isnan(V)) = 0;
        vmaxAll = max(V(:)); if ~isfinite(vmaxAll), vmaxAll = 0; end
        thr = vmaxAll * iso_ratio;
        Mask = V >= thr;
        Vplot = V; Vplot(~Mask) = NaN;

        [~,~,ntM] = size(Vplot);
        nCols = ceil(sqrt(ntM));
        nRows = ceil(ntM/nCols);

        tabM = uitab(tg2DHist, 'Title', MethodNames2DHist{mth});
        pM   = uipanel('Parent', tabM, 'BorderType','none', 'Units','normalized', 'Position',[0 0 1 1]);

        visVals = Vplot(~isnan(Vplot));
        if isempty(visVals)
            vmin = 0; vmax = 1;
        else
            vmin = min(visVals); vmax = max(visVals);
            if ~isfinite(vmin) || ~isfinite(vmax) || vmin >= vmax
                vmin = 0; vmax = max(1, vmaxAll);
            end
        end

        for t = 1:ntM
            ax = subplot(nRows, nCols, t, 'Parent', pM);
            img = Vplot(:,:,t);
            hImg = imagesc(ax, img, [vmin vmax]);
            axis(ax,'equal'); axis(ax,'off');
            title(ax, sprintf('Slice %d', t), 'FontSize', 8);
            set(ax, 'Color', 'k');
            colormap(ax, 'hot');
            set(ax, 'ButtonDownFcn', @(h,~) enlargeAxes2D(h));
            set(hImg, 'HitTest','off','PickableParts','none');
        end

        axlast = subplot(nRows, nCols, ntM, 'Parent', pM);
        try
            cb = colorbar(axlast, 'Location','eastoutside');
        catch
            cb = colorbar(axlast); cb.Location = 'eastoutside';
        end
        cb.Label.String = sprintf('%s intensity (iso = %.2g)', MethodNames2DHist{mth}, iso_ratio);
        
        annotation(pM, 'textbox', [0 0.96 1 0.04], 'String', ...
            sprintf('%s — 2D Dilimler (iso = %.2g·max)', MethodNames2DHist{mth}, iso_ratio), ...
            'HorizontalAlignment','center','VerticalAlignment','middle', ...
            'EdgeColor','none','FontWeight','bold');
    end
end

%% ================== Yardımcı Fonksiyonlar ==================

% --- MPD Trace ve PCG Fonksiyonları ---
function traceT = estimate_trace_t_gpu_local(Ag, AtA_diagg, D2g, lambda, sampleCount, tol, maxit, eps0, verbose, printStride, outerIter)
    n = size(Ag, 2);
    diagHg = max(AtA_diagg + lambda * D2g, eps0);
    valsg = zeros(1, sampleCount, 'double');
    for s = 1:sampleCount
        zg = sign(gpuArray.randn(n, 1, 'double'));
        zg(zg == 0) = 1;
        rhsg = D2g .* zg;
        wg = pcg_gpu_single_local(Ag, D2g, lambda, diagHg, rhsg, tol, maxit, verbose, printStride, outerIter, s);
        valsg(s) = gather(sum(zg .* wg));
    end
    traceT = mean(valsg);
    traceT = max(traceT, eps0);
end

function x = pcg_gpu_single_local(Ag, D2g, lambda, diagHg, b, tol, maxit, verbose, printStride, outerIter, sampleIdx)
    n = size(Ag, 2);
    x = gpuArray.zeros(n, 1, 'double');
    r = b;
    z = r ./ diagHg;
    p = z;
    rz_old = sum(r .* z);
    bnorm = norm(b);
    if bnorm == 0, bnorm = 1; end
    for it = 1:maxit
        Hp = Ag' * (Ag * p) + lambda * (D2g .* p);
        denom = sum(p .* Hp);
        if denom == 0, denom = eps; end
        alpha = rz_old / denom;
        x = x + p * alpha;
        r = r - Hp * alpha;
        if mod(it, printStride) == 0 || it == maxit
            relres = norm(r) / bnorm;
            if verbose
                fprintf('      trace outer=%d sample=%d cg=%d relres=%.3e\n', outerIter, sampleIdx, it, gather(relres));
            end
            if relres <= tol, break; end
        end
        z = r ./ diagHg;
        rz_new = sum(r .* z);
        beta = rz_new / rz_old;
        p = z + p * beta;
        rz_old = rz_new;
    end
end

% --- Çizim ve Etkileşim Fonksiyonları ---
function makeClickable(ax)
    set(ax, 'ButtonDownFcn', @(h,~) enlargeAxes(h));
    ch = allchild(ax);
    set(ch, 'HitTest','off','PickableParts','none');
end

function enlargeAxes(ax)
    f2 = figure('Name','Büyütülmüş Görünüm','Color','w','Units','normalized','Position',[0.2 0.2 0.6 0.6]);
    ax2 = axes('Parent',f2);
    copyobj(allchild(ax), ax2);
    axis(ax2, axis(ax)); 
    try
        [az, el] = view(ax);
        view(ax2, az, el);
        camva(ax2, camva(ax));
    catch
    end
    grid(ax2, ax.GridLineStyle ~= 'none');
    xlabel(ax2, ax.XLabel.String); ylabel(ax2, ax.YLabel.String); zlabel(ax2, ax.ZLabel.String);
    title(ax2, ax.Title.String);
    colormap(ax2, colormap(ax));
    if ~isempty(findobj(ax,'Type','colorbar')), colorbar(ax2); end
end

function drawIsoSurface(ax, V, iso_ratio, ttl, fcolor, Nx, Ny, Nz)
    if isempty(V) || all(~isfinite(V(:)))
        title(ax, [ttl ' (no data)']); return;
    end
    thr = max(V(:));
    if ~isfinite(thr) || thr<=0
        title(ax, [ttl ' (max<=0)']); return;
    end
    thr = thr * iso_ratio;

    [F, Vert] = isosurface(V, thr);
    if isempty(F) || isempty(Vert)
        cla(ax); title(ax, [ttl ' (no iso-surface)']);
        return;
    end
    F = double(F); Vert = double(Vert);

    p = patch(ax, 'Faces',F, 'Vertices',Vert, ...
        'FaceColor',fcolor, 'EdgeColor','none', 'FaceAlpha',0.85);
    hold(ax,'on');

    Vxy = Vert; Vxy(:,3) = 1;
    patch(ax, 'Faces',F, 'Vertices',Vxy, 'FaceColor','none', 'EdgeColor',fcolor, 'LineWidth',0.7, 'EdgeAlpha',0.35);

    Vxz = Vert; Vxz(:,2) = 1;
    patch(ax, 'Faces',F, 'Vertices',Vxz, 'FaceColor','none', 'EdgeColor',fcolor, 'LineWidth',0.7, 'EdgeAlpha',0.35);

    Vyz = Vert; Vyz(:,1) = 1;
    patch(ax, 'Faces',F, 'Vertices',Vyz, 'FaceColor','none', 'EdgeColor',fcolor, 'LineWidth',0.7, 'EdgeAlpha',0.35);

    daspect(ax,[1 1 1]); view(ax,3); grid(ax,'on'); axis(ax,'tight');
    xlim(ax,[1 Nx]); ylim(ax,[1 Ny]); zlim(ax,[1 Nz]);
    xticks(ax, 1:5:max(1,Nx)); yticks(ax, 1:5:max(1,Ny)); zticks(ax, 1:5:max(1,Nz));
    xlabel(ax,'X'); ylabel(ax,'Y'); zlabel(ax,'Z');
    title(ax, ttl);
    camlight(ax,'headlight'); lighting(ax,'gouraud'); material(ax,'dull');

    makeClickable(ax);
    set(p, 'HitTest','off','PickableParts','none');
    hold(ax,'off');
end

function [log_reg, log_res, curvature] = compute_curvature(reg_norm, res_norm, lambda_range)
    log_reg = log(reg_norm(:));
    log_res = log(res_norm(:));
    t       = log(lambda_range(:));
    dlogr = gradient(log_reg, t);
    dlogR = gradient(log_res, t);
    d2logr = gradient(dlogr, t);
    d2logR = gradient(dlogR, t);
    curvature = abs(d2logR .* dlogr - dlogR .* d2logr) ...
                ./ ((dlogR.^2 + dlogr.^2 + eps()).^(3/2));
end

function [idx_corner, distances] = corner_by_triangle(xvals, yvals)
    x1 = xvals(1);  y1 = yvals(1);
    xN = xvals(end); yN = yvals(end);
    denom = hypot(yN - y1, xN - x1) + eps;
    n = numel(xvals);
    distances = zeros(n,1);
    for i = 1:n
        distances(i) = abs((yN - y1)*xvals(i) - (xN - x1)*yvals(i) + xN*y1 - yN*x1) / denom;
    end
    [~, idx_corner] = max(distances);
end

function enlargeAxes2D(ax)
    f2 = figure('Name','Büyütülmüş Dilim', 'Color','w', 'Units','normalized', 'Position',[0.2 0.2 0.6 0.6]);
    ax2 = axes('Parent', f2);
    copyobj(allchild(ax), ax2);
    axis(ax2,'equal'); axis(ax2,'off');
    try, ax2.CLim = ax.CLim; catch, end
    title(ax2, ax.Title.String);
    colormap(ax2, colormap(ax));
    set(ax2, 'Color', get(ax,'Color'));
    colorbar(ax2);
end

% --- Phantom Metrics Helper Functions ---
function x = apply_iso_threshold(x, iso_ratio)
    xmax = max(x(:));
    if ~isfinite(xmax) || xmax <= 0
        return;
    end
    thr = xmax * iso_ratio;
    x(x < thr) = 0;
end
            
            function m = compute_metrics(original_volume, reconstructed_volume, unitInMM)
                den_nssd = sum(original_volume(:).^2);
                if den_nssd == 0, den_nssd = eps; end
                den_nsad = sum(abs(original_volume(:)));
                if den_nsad == 0, den_nsad = eps; end
                den_nr = norm(original_volume(:));
                if den_nr == 0, den_nr = eps; end
            
                m.nssd = sum((reconstructed_volume(:) - original_volume(:)).^2) / den_nssd;
                m.nsad = sum(abs(reconstructed_volume(:) - original_volume(:))) / den_nsad;
                m.nr = norm(reconstructed_volume(:) - original_volume(:)) / den_nr;
            
                [m.volume_error_vox, m.volume_error_mm3, m.centroid_error_vox, m.centroid_error_mm] = ...
                    quality_metrics(original_volume, reconstructed_volume, unitInMM);
            end

function [volErrVoxel, volErrMM, centErrVoxel, centErrMM] = quality_metrics(original_volume, reconstructed_volume, unitInMM)
    volErrVoxel = abs(nnz(original_volume) - nnz(reconstructed_volume));
    volErrMM = volErrVoxel * unitInMM^3;

    c1 = centroid(original_volume);
    c2 = centroid(reconstructed_volume);

    if any(~isfinite(c1)) || any(~isfinite(c2))
        centErrVoxel = NaN;
        centErrMM = NaN;
    else
        centErrVoxel = norm(c1 - c2);
        centErrMM = centErrVoxel * unitInMM;
    end
end

function c = centroid(volume)
    totalMass = sum(volume(:));
    if totalMass <= 0 || ~isfinite(totalMass)
        c = [NaN NaN NaN];
        return;
    end

    [x, y, z] = ndgrid(1:size(volume, 1), 1:size(volume, 2), 1:size(volume, 3));
    c = [sum(x(:) .* volume(:)) / totalMass, ...
         sum(y(:) .* volume(:)) / totalMass, ...
         sum(z(:) .* volume(:)) / totalMass];
end
