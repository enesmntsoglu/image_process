% mpd_new_inverse_lambda_finder_v7.m
% Paper-based MPD / MAP-ML lambda update for weighted L1 penalty.
%
% v7 Degisiklikler (SIRALI PCG + PERSISTENT GPU):
%   1. HAFIF PARAMETRELER: 8 Hutchinson ornegi, 1e-3 PCG toleransi ve 100 max PCG iterasyonu.
%   2. SEQUENTIAL PCG: Sizin donaniminizda matris carpimi (batched) yerine 
%      v2'nin vektorel dongusu (sequential) kat kat hizli calistigi icin 
%      PCG tamamen v2'deki haline geri donduruldu.
%   3. PERSISTENT GPU ARRAYs: v2'deki gibi her dis dongude matrisleri CPU'dan
%      GPU'ya yukleyip silmek (reset(gpuDevice())) yerine, v6'daki gibi
%      matrisler bir kez GPU'ya alinir ve surekli orada tutulur. 
%      (v2'nin PCG hizi + v6'nin GPU bellek optimizasyonu).
%   4. HIZLI v3 SOLVER (stride = 1): Orijinal v3_fast solver kullanilir.
%
% Source model:
%   Li et al. (2023), MPD strategy
%
% Expected in workspace:
%   cfg.ms       (sensitivity / A matrix, A_matrix.m'den)
%   cfg.b        (measurement vector, b_vec.m'den)
% ===================================================================
% User settings: edit these directly
% ===================================================================
% ===================================================================
% User settings: edit these directly (OVERNIGHT ULTRA-PRECISION MODE)
% ===================================================================
params = struct();

% --- Inner solver (Maksimum Hassasiyet) ---
params.p = 1;                    
params.tol = 1e-4;               % (Eski: 1e-3) Voksel değerleri mikroskobik hataya inene kadar çözücü durmaz.
params.max_itr = 10000;          % İhtiyaç duyarsa 20.000 adıma kadar ince ayar yapabilir.
params.nu = 1e-4;                
params.eps0 = 1e-10;             
params.rootfact = 0.75;           
params.iso_ratio = 0.3;          

% --- Lambda iteration (Tam Yakınsama) ---
params.lambda_init = 10;          
params.lambda_min = 1e-4;        
params.lambda_max = 150;        % Lambda limitini serbest bıraktık.
params.lambda_damping = 0.75;  %0.5   
params.lambda_rel_tol = 1e-3;    % (Eski: 1e-3) Lambda'nın virgülden sonraki 5. hanesi bile oturana kadar pes etmez.
params.outer_max_iter = 50;     % (Eski: 50) Sabaha kadar vakti var, tam sonuca ulaşması için limit 200'e çekildi.

% --- Trace estimation (Yüksek İstatistiksel Doğruluk) ---
params.trace_samples = 16;       % (Eski: 4) Hutchinson tahminindeki istatistiksel gürültüyü devasa oranda bastırır.
params.trace_tol = 1e-4;         % (Eski: 1e-2) Rastgele vektörler bile hedefe tam oturana kadar çözülür.
params.trace_maxit = 200;       % PCG'ye hedefe varması için çok geniş bir limit verildi.
params.trace_seed = 1234;        
params.trace_use_gpu = true;     
params.trace_verbose = false;     % Gece veya sabah PC'ye baktığınızda kodun hangi adımda olduğunu görün diye açtık.
params.trace_print_stride = 50;  

% --- Kalibrasyon (Daha Derin Uyum) ---
params.use_calibration = false;   
params.lambda_cal = 10;          
params.max_itr_cal = 10000;      % Kalibrasyon adımı da çok daha hassas yapılacak.
params.tol_cal = 1e-4;           
params.cal_min = 0.001;          
params.cal_max = 1000;           

% --- Robust sigma^2 ---
params.sigma2_mode = 'trimmed';  
params.sigma2_trim_pct = 0.05;   
params.sigma2_max = 0.1;
% ===================================================================
% Input validation
% ===================================================================
if params.p ~= 1
    error('Bu script L1 MPD guncellemesini kuruyor. params.p = 1 olmali.');
end
if ~params.trace_use_gpu
    error('mpd GPU modunda calisir. params.trace_use_gpu = true olmali.');
end
if exist('gpuDeviceCount', 'file') ~= 2 || gpuDeviceCount < 1
    error('mpd v7 icin GPU gerekli. gpuDeviceCount bulunamadi veya GPU yok.');
end
if ~exist('cfg', 'var') || ~isstruct(cfg) || ~isfield(cfg, 'ms') || isempty(cfg.ms)
    error('cfg.ms gerekli.');
end
if ~isfield(cfg, 'b') || isempty(cfg.b)
    error('cfg.b yok. Once b_vec.m calistirarak cfg.b olusturun.');
end
if ~isfield(cfg, 'unitinmm') || isempty(cfg.unitinmm)
    cfg.unitinmm = 0.1;
end
scriptDir = fileparts(mfilename('fullpath'));
cand = {
    fullfile(scriptDir, 'ortak_kod')
    fullfile(fileparts(scriptDir), 'ortak_kod')
    fullfile(pwd, 'ortak_kod')
    };
for i = 1:numel(cand)
    if isfolder(cand{i})
        addpath(cand{i});
    end
end
if exist('Lp_solver_depthver2_gpu_2_double_v3_fast', 'file') ~= 2
    error('Lp_solver_depthver2_gpu_2_double_v3_fast bulunamadi.');
end
% ===================================================================
% Phase 0: Data preparation & GPU Transfer
% ===================================================================
A_cpu = double(cfg.A_matrix);
b_cpu = double(cfg.b(:));
[m, n] = size(A_cpu);
if numel(b_cpu) ~= m
    error('Boyut uyumsuz: size(cfg.ms,1)=%d, numel(cfg.b)=%d', m, numel(b_cpu));
end
fprintf('\n=== MPD exact MAP-ML v7 (Sirali PCG + Persistent GPU) ===\n');
fprintf('Boyutlar: m=%d (olcum), n=%d (voksel)\n', m, n);
% --- A normalizasyonu ---
sA = max(abs(A_cpu(:)));
if sA == 0, sA = 1; end
A_cpu = A_cpu ./ sA;
% --- D vektoru (derinlik agirligi) ---
D_cpu = sum(abs(A_cpu).^2, 1).';
D_cpu = D_cpu .^ params.rootfact;
dmax = max(abs(D_cpu));
if dmax > 0
    D_cpu = D_cpu ./ dmax;
end
D_cpu = max(D_cpu, params.eps0);
D2_cpu = D_cpu .^ 2;
AtA_diag_cpu = sum(A_cpu.^2, 1).';
% --- GPU context dogrulama ve kurtarma ---
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
        fprintf('[GPU] Context bozuk (deneme %d/3), sifirlaniyor...\n', attempt);
        try
            reset(gpuDevice());
        catch
        end
        pause(1);
    end
end
if ~gpu_ok
    error('GPU context kurtarilamadi. MATLAB''i yeniden baslatin.');
end
fprintf('GPU: %s (CC=%s, Bellek=%.1f GB, Bos=%.1f GB)\n', ...
    d.Name, d.ComputeCapability, d.TotalMemory/1e9, d.AvailableMemory/1e9);
estimated_total = (numel(A_cpu)*8 + numel(b_cpu)*8 + numel(D_cpu)*8*3 + numel(AtA_diag_cpu)*8) * 2.5;
if estimated_total > d.AvailableMemory
    warning(['GPU bellegi yetersiz olabilir. Tahmini gereksinim: %.1f GB, ' ...
             'Mevcut: %.1f GB. Devam ediliyor...'], ...
             estimated_total/1e9, d.AvailableMemory/1e9);
end
% Move to GPU once
Ag = gpuArray(A_cpu);
bg = gpuArray(b_cpu);
Dg = gpuArray(D_cpu);
D2g = gpuArray(D2_cpu);
AtA_diagg = gpuArray(AtA_diag_cpu);
% ===================================================================
% Phase 1: b Normalizasyonu + Kalibrasyon
% ===================================================================
sb = max(abs(b_cpu(:)));
if sb == 0, sb = 1; end
bg = bg ./ sb;
cal_factor = 1.0;
if params.use_calibration
    fprintf('\n--- Kalibrasyon Adimi ---\n');
    fprintf('Kaba cozum: lambda_cal=%.4g, max_itr=%d\n', params.lambda_cal, params.max_itr_cal);
    x_cal_init = gpuArray.zeros(n, 1, 'double');
    x_coarse_g = Lp_solver_depthver2_gpu_2_double_v3_fast( ...
        Ag, bg, params.p, params.lambda_cal, params.tol_cal, ...
        params.max_itr_cal, params.nu, params.eps0, x_cal_init, Dg, false, 100);
    b_predicted_g = Ag * x_coarse_g;
    b_dot_b = bg' * bg;
    b_dot_bp = bg' * b_predicted_g;
    b_dot_b_cpu = gather(b_dot_b);
    b_dot_bp_cpu = gather(b_dot_bp);
    if abs(b_dot_b_cpu) > params.eps0 && isfinite(b_dot_bp_cpu)
        cal_factor = b_dot_bp_cpu / b_dot_b_cpu;
        cal_factor = max(min(cal_factor, params.cal_max), params.cal_min);
    else
        warning('Kalibrasyon hesaplanamadi, cal_factor=1.0 kullaniliyor.');
        cal_factor = 1.0;
    end
    bg = bg * cal_factor;
    b_cal_cpu = gather(bg);
    b_pred_cpu = gather(b_predicted_g);
    res_after = norm(b_pred_cpu - b_cal_cpu);
    fprintf('Kalibrasyon faktoru (c_cal): %.6g\n', cal_factor);
    x_coarse_cpu = gather(x_coarse_g);
    fprintf('Kaba cozum: nnz(x_coarse)=%d / %d (%%%.1f)\n', ...
        nnz(x_coarse_cpu > max(x_coarse_cpu)*0.01), n, 100*nnz(x_coarse_cpu > max(x_coarse_cpu)*0.01)/n);
    fprintf('norm(b_predicted)=%.4g, norm(b_calibrated)=%.4g\n', ...
        norm(b_pred_cpu), norm(b_cal_cpu));
    fprintf('Residual (kaba): ||A*x_coarse - b_cal|| = %.4g\n', res_after);
    fprintf('--- Kalibrasyon Tamamlandi ---\n\n');
end
% ===================================================================
% Phase 2: MPD Iterasyonu
% ===================================================================
if isfield(params, 'x_initial') && ~isempty(params.x_initial)
    xg = gpuArray(double(params.x_initial(:)));
elseif params.use_calibration && exist('x_coarse_g', 'var')
    xg = x_coarse_g;
    fprintf('Warm-start: kalibrasyon cozumu kullaniliyor.\n');
else
    xg = gpuArray.zeros(n, 1, 'double');
end
lambda = min(max(params.lambda_init, params.lambda_min), params.lambda_max);
K = params.outer_max_iter;
try gpurng(params.trace_seed); catch; end
rng(params.trace_seed);
hIter = zeros(K, 1); hLambda = zeros(K, 1); hTraceT = zeros(K, 1);
hSigma2 = zeros(K, 1); hSigma2_robust = zeros(K, 1); hZeta = zeros(K, 1);
hLambdaRaw = zeros(K, 1); hRel = zeros(K, 1); hRes2 = zeros(K, 1);
hTx1 = zeros(K, 1); hTimeSolve = zeros(K, 1); hTimeTrace = zeros(K, 1);
fprintf('MPD iterasyonu basliyor: lambda_init=%.4g, damping=%.2f, sigma2_mode=%s\n', ...
    lambda, params.lambda_damping, params.sigma2_mode);
fprintf('Lambda sinirlar: [%.2e, %.2e], sigma2_max=%.2e\n\n', ...
    params.lambda_min, params.lambda_max, params.sigma2_max);
for k = 1:K
    tSolve = tic;
    xg = Lp_solver_depthver2_gpu_2_double_v3_fast( ...
        Ag, bg, params.p, lambda, params.tol, params.max_itr, ...
        params.nu, params.eps0, xg, Dg, false, 1);
    hTimeSolve(k) = toc(tSolve);
    residuals_g = Ag * xg - bg;
    res2_g = sum(residuals_g.^2);
    Tx1_g = sum(abs(Dg .* xg));
    res2 = gather(res2_g);
    Tx1 = gather(Tx1_g);
    % --- Trace estimation (Sequential PCG) ---
    tTrace = tic;
    traceT = estimate_trace_t_gpu_local(Ag, AtA_diagg, D2g, lambda, ...
        params.trace_samples, params.trace_tol, params.trace_maxit, ...
        params.eps0, params.trace_verbose, params.trace_print_stride, k);
    hTimeTrace(k) = toc(tTrace);
    traceA = n - lambda * traceT;
    denomSigma = m - traceA;
    if denomSigma <= params.eps0, denomSigma = params.eps0; end
    sigma2_standard = res2 / denomSigma;
    switch params.sigma2_mode
        case 'standard'
            sigma2 = sigma2_standard;
        case 'trimmed'
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
        case 'mad'
            residuals_cpu = gather(residuals_g);
            sigma2 = (median(abs(residuals_cpu)) / 0.6745)^2;
        otherwise
            sigma2 = sigma2_standard;
    end
    sigma2_before_cap = sigma2;
    sigma2 = min(sigma2, params.sigma2_max);
    delta = (2 * lambda * traceT)^2 + 8 * (n^2) * (Tx1^2);
    zeta = (2 * lambda * traceT + sqrt(max(delta, 0))) / (2 * n^2);
    lambdaRaw = (2^(3/2)) * sigma2 / max(zeta, params.eps0);
    lambdaRaw = min(max(lambdaRaw, params.lambda_min), params.lambda_max);
    lambdaNew = (1 - params.lambda_damping) * lambda + params.lambda_damping * lambdaRaw;
    lambdaNew = min(max(lambdaNew, params.lambda_min), params.lambda_max);
    rel = abs(lambdaNew - lambda) / max(lambda, params.eps0);
    hIter(k) = k; hLambda(k) = lambda; hTraceT(k) = traceT;
    hSigma2(k) = sigma2; hSigma2_robust(k) = sigma2_before_cap;
    hZeta(k) = zeta; hLambdaRaw(k) = lambdaRaw; hRel(k) = rel;
    hRes2(k) = res2; hTx1(k) = Tx1;
    cap_str = '';
    if sigma2_before_cap > params.sigma2_max, cap_str = ' [CAPPED]'; end
    
    x_cpu_temp = gather(xg);
    nnz_val = nnz(abs(x_cpu_temp) > max(abs(x_cpu_temp))*0.01);
    fprintf('[%02d] lam=%.4g → raw=%.4g → new=%.4g (rel=%.2e) | sig2=%.3e%s | zeta=%.3e | trT=%.2e | nnz=%d\n', ...
        k, lambda, lambdaRaw, lambdaNew, rel, sigma2, cap_str, zeta, traceT, nnz_val);
    lambda = lambdaNew;
    if rel < params.lambda_rel_tol
        fprintf('\nYakinsadi: rel=%.2e < tol=%.2e (iterasyon %d)\n', rel, params.lambda_rel_tol, k);
        hIter = hIter(1:k); hLambda = hLambda(1:k); hTraceT = hTraceT(1:k);
        hSigma2 = hSigma2(1:k); hSigma2_robust = hSigma2_robust(1:k);
        hZeta = hZeta(1:k); hLambdaRaw = hLambdaRaw(1:k); hRel = hRel(1:k);
        hRes2 = hRes2(1:k); hTx1 = hTx1(1:k); hTimeSolve = hTimeSolve(1:k); hTimeTrace = hTimeTrace(1:k);
        break;
    end
end
% ===================================================================
% Phase 3: Final refit & output
% ===================================================================
mpd_exact_lambda_final = lambda;
last_lambda_used = hLambda(end);
mpd_exact_refit_time_sec = 0;
mpd_exact_cal_factor = cal_factor;
if abs(mpd_exact_lambda_final - last_lambda_used) > params.lambda_rel_tol * max(last_lambda_used, params.eps0)
    fprintf('\nFinal refit with lambda = %.8g\n', mpd_exact_lambda_final);
    tRefit = tic;
    xg = Lp_solver_depthver2_gpu_2_double_v3_fast( ...
        Ag, bg, params.p, mpd_exact_lambda_final, params.tol, params.max_itr, ...
        params.nu, params.eps0, xg, Dg, false, 50);
    mpd_exact_refit_time_sec = toc(tRefit);
    fprintf('Final refit time: %.2f s\n', mpd_exact_refit_time_sec);
end
mpd_exact_lambda_used = mpd_exact_lambda_final;
mpd_exact_x_final = gather(xg);
mpd_exact_x_thresholded = mpd_exact_x_final;
xmax = max(mpd_exact_x_thresholded);
if isfinite(xmax) && xmax > 0
    mpd_exact_x_thresholded(mpd_exact_x_thresholded < xmax * params.iso_ratio) = 0;
end
mpd_exact_history = table( ...
    hIter, hLambda, hLambdaRaw, hRel, hTraceT, hSigma2, hSigma2_robust, hZeta, hRes2, hTx1, hTimeSolve, hTimeTrace, ...
    'VariableNames', {'Iter', 'Lambda', 'LambdaRaw', 'RelLambda', 'TraceT', 'Sigma2', 'Sigma2_BeforeCap', 'Zeta', 'ResidualNorm2', 'TxL1', 'SolveTimeSec', 'TraceTimeSec'});
mpd_exact_x_refit = mpd_exact_x_final;
mpd_exact_x_refit_thresholded = mpd_exact_x_thresholded;
mpd_exact_result_v7 = struct();
mpd_exact_result_v7.lambda_final = mpd_exact_lambda_final;
mpd_exact_result_v7.lambda_used = mpd_exact_lambda_used;
mpd_exact_result_v7.x_final = mpd_exact_x_final;
mpd_exact_result_v7.x_thresholded = mpd_exact_x_thresholded;
mpd_exact_result_v7.history = mpd_exact_history;
mpd_exact_result_v7.params = params;
mpd_exact_result_v7.cal_factor = cal_factor;
%%
fprintf('\n=== MPD v7 Sonuclar ===\n');
fprintf('Final lambda       = %.8g\n', mpd_exact_lambda_final);
fprintf('Kalibrasyon faktoru = %.6g\n', cal_factor);
fprintf('Toplam iterasyon    = %d\n', numel(hIter));
fprintf('Son sigma2          = %.6e (%s)\n', hSigma2(end), params.sigma2_mode);
fprintf('nnz(x_final)        = %d / %d\n', nnz(mpd_exact_x_final > max(mpd_exact_x_final)*0.01), numel(mpd_exact_x_final));
total_solve_sec = sum(hTimeSolve);
total_trace_sec = sum(hTimeTrace);
total_iter_sec  = total_solve_sec + total_trace_sec;
total_all_sec   = total_iter_sec + mpd_exact_refit_time_sec;
fprintf('\n--- Sure Ozeti ---\n');
fprintf('Solve toplam       = %.2f s  (ort: %.2f s/iter)\n', total_solve_sec, total_solve_sec/numel(hIter));
fprintf('Trace toplam       = %.2f s  (ort: %.2f s/iter)\n', total_trace_sec, total_trace_sec/numel(hIter));
fprintf('Iterasyon toplam   = %.2f s\n', total_iter_sec);
fprintf('Final refit        = %.2f s\n', mpd_exact_refit_time_sec);
fprintf('GENEL TOPLAM       = %.2f s  (%.1f dk)\n', total_all_sec, total_all_sec/60);
%%
%% ==================== GÖRSELLEŞTIRME ====================
% Rekonstruksiyon sonuclarinin gorsellestirilmesi
% 4 figur:
%   1. Katman gorunumu — Ham (4x5 grid, 20 z-dilimi)
%   2. Katman gorunumu — Esiklenmis (4x5 grid, 20 z-dilimi)
%   3. 3D gorunum — Ham + Esiklenmis (yan yana)

vol_size = [26, 26, 20];
unitinmm = cfg.unitinmm;  % 0.1 mm/voksel

% Reshape
V_raw = reshape(mpd_exact_x_final, vol_size);
V_thr = reshape(mpd_exact_x_thresholded, vol_size);

% Eksen vektorleri (mm cinsinden, voksel merkezleri)
x_mm = (0:vol_size(1)-1) * unitinmm;  % 0.0 ~ 2.4 mm
y_mm = (0:vol_size(2)-1) * unitinmm;  % 0.0 ~ 2.4 mm
z_mm = (0:vol_size(3)-1) * unitinmm;  % 0.0 ~ 1.9 mm

% Renk skalalari
cmax_raw = max(V_raw(:));
if ~isfinite(cmax_raw) || cmax_raw <= 0, cmax_raw = 1; end
clim_raw = [0, cmax_raw];

cmax_thr = max(V_thr(:));
if ~isfinite(cmax_thr) || cmax_thr <= 0, cmax_thr = 1; end
clim_thr = [0, cmax_thr];

nz    = vol_size(3);
ncols = 5;
nrows = ceil(nz / ncols);

% ---------------------------------------------------------------
% FIGÜR 1: Katman Görünümü — Ham (Raw)
% ---------------------------------------------------------------
fig1 = figure('Name', 'MPD v2 — Katman: Ham', 'NumberTitle', 'off', ...
    'Color', 'w', 'Units', 'normalized', 'Position', [0.01 0.52 0.48 0.44]);

for z_idx = 1:nz
    subplot(nrows, ncols, z_idx);
    % TEK KONVANSIYON: x = SATIR (dim1, dikey), y = SUTUN (dim2, yatay) -> transpoze YOK
    % imagesc(yatay=y_mm[Y/sutun], dikey=x_mm[X/satir])
    slice_data = squeeze(V_raw(:,:,z_idx));
    imagesc(y_mm, x_mm, slice_data, clim_raw);
    set(gca, 'YDir', 'reverse');   % x=1 (satir) en ustte
    axis image;
    colormap(gca, 'hot');

    title(sprintf('Z=%d (%.1f mm)', z_idx, z_mm(z_idx)), 'FontSize', 7);

    % Sol sutun: X ekseni etiketi (dikey = x = satir)
    if mod(z_idx-1, ncols) == 0
        ylabel('X (mm)', 'FontSize', 7);
    else
        set(gca, 'YTickLabel', []);
    end
    % Alt satir: Y ekseni etiketi (yatay = y = sutun)
    if z_idx > (nrows-1)*ncols
        xlabel('Y (mm)', 'FontSize', 7);
    else
        set(gca, 'XTickLabel', []);
    end
    set(gca, 'FontSize', 6);
end

sgtitle(sprintf('Ham Rekonstrüksiyon — \\lambda=%.4g  |  X: 0–%.1f mm, Y: 0–%.1f mm', ...
    mpd_exact_lambda_final, x_mm(end), y_mm(end)), 'FontWeight', 'bold', 'FontSize', 10);
cb1 = colorbar('Position', [0.93 0.08 0.015 0.84]);
cb1.Label.String = 'Yoğunluk';
cb1.Label.FontSize = 8;
%%
% ---------------------------------------------------------------
% FIGÜR 2: Katman Görünümü — Eşiklenmiş (Thresholded)
% ---------------------------------------------------------------
fig2 = figure('Name', 'MPD v2 — Katman: Eşiklenmiş', 'NumberTitle', 'off', ...
    'Color', 'w', 'Units', 'normalized', 'Position', [0.51 0.52 0.48 0.44]);

for z_idx = 1:nz
    subplot(nrows, ncols, z_idx);
    % TEK KONVANSIYON: x = SATIR (dim1, dikey), y = SUTUN (dim2, yatay) -> transpoze YOK
    slice_data = squeeze(V_thr(:,:,z_idx));
    imagesc(y_mm, x_mm, slice_data, clim_thr);
    set(gca, 'YDir', 'reverse');   % x=1 (satir) en ustte
    axis image;
    colormap(gca, 'hot');

    title(sprintf('Z=%d (%.1f mm)', z_idx, z_mm(z_idx)), 'FontSize', 7);

    if mod(z_idx-1, ncols) == 0
        ylabel('X (mm)', 'FontSize', 7);   % dikey = x = satir
    else
        set(gca, 'YTickLabel', []);
    end
    if z_idx > (nrows-1)*ncols
        xlabel('Y (mm)', 'FontSize', 7);   % yatay = y = sutun
    else
        set(gca, 'XTickLabel', []);
    end
    set(gca, 'FontSize', 6);
end

sgtitle(sprintf('Eşiklenmiş Rekonstrüksiyon (iso=%.0f%%) — \\lambda=%.4g', ...
    params.iso_ratio*100, mpd_exact_lambda_final), 'FontWeight', 'bold', 'FontSize', 10);
cb2 = colorbar('Position', [0.93 0.08 0.015 0.84]);
cb2.Label.String = 'Yoğunluk';
cb2.Label.FontSize = 8;
%%
% ---------------------------------------------------------------
% FIGÜR 3: 3D Görünüm — Ham + Eşiklenmiş (Yan Yana)
% ---------------------------------------------------------------
fig3 = figure('Name', 'MPD v2 — 3D Görünüm', 'NumberTitle', 'off', ...
    'Color', 'w', 'Units', 'normalized', 'Position', [0.05 0.02 0.9 0.46]);

% --- 3D Ham (sol panel) ---
ax1 = subplot(1,2,1);
hold(ax1, 'on');
iso_val_raw = cmax_raw * params.iso_ratio;
try
    V_smooth = smooth3(V_raw, 'gaussian', 3);
    fv1 = isosurface(V_smooth, iso_val_raw);
    if ~isempty(fv1.vertices) && size(fv1.vertices,1) >= 3
        % Voksel indekslerini mm'ye cevir
        % isosurface(V) → vertices sırası: [dim2(Y), dim1(X), dim3(Z)]
        verts_mm = zeros(size(fv1.vertices));
        verts_mm(:,1) = (fv1.vertices(:,2) - 1) * unitinmm;  % X (mm)
        verts_mm(:,2) = (fv1.vertices(:,1) - 1) * unitinmm;  % Y (mm)
        verts_mm(:,3) = (fv1.vertices(:,3) - 1) * unitinmm;  % Z (mm)
        p1 = patch(ax1, 'Vertices', verts_mm, 'Faces', fv1.faces);
        set(p1, 'FaceColor', [0.85 0.25 0.10], 'EdgeColor', 'none', 'FaceAlpha', 0.6);
        % Dis kabuk
        iso_outer = cmax_raw * 0.05;
        if iso_outer > 0 && iso_outer < iso_val_raw
            fv1b = isosurface(V_smooth, iso_outer);
            if ~isempty(fv1b.vertices) && size(fv1b.vertices,1) >= 3
                vb = zeros(size(fv1b.vertices));
                vb(:,1) = (fv1b.vertices(:,2)-1)*unitinmm;
                vb(:,2) = (fv1b.vertices(:,1)-1)*unitinmm;
                vb(:,3) = (fv1b.vertices(:,3)-1)*unitinmm;
                p1b = patch(ax1, 'Vertices', vb, 'Faces', fv1b.faces);
                set(p1b, 'FaceColor', [1 0.6 0.3], 'EdgeColor', 'none', 'FaceAlpha', 0.12);
            end
        end
    else
        warning('Ham isosurface bos veya cok kucuk, scatter3 kullaniliyor.');
        error('fallback');  % scatter3'e dusur
    end
catch
    % Fallback: scatter3 ile voksel gosterimi
    [ix, iy, iz] = ind2sub(vol_size, find(V_raw(:) > iso_val_raw));
    vals = V_raw(V_raw(:) > iso_val_raw);
    if ~isempty(ix)
        scatter3(ax1, (ix-1)*unitinmm, (iy-1)*unitinmm, (iz-1)*unitinmm, ...
            30, vals, 'filled', 'MarkerFaceAlpha', 0.6);
        colormap(ax1, 'hot');
    end
    fprintf('[UYARI] isosurface hatasi, scatter3 fallback kullanildi.\n');
end

% (1,1,1) orijin isaretcisi — voksel (1,1,1) = (0,0,0) mm
plot3(ax1, 0, 0, 0, 'p', 'MarkerSize', 16, 'MarkerFaceColor', [0 0.8 0], ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
text(ax1, 0.05, 0.05, -0.05, '  (1,1,1) Orijin', ...
    'Color', [0 0.6 0], 'FontWeight', 'bold', 'FontSize', 9, ...
    'BackgroundColor', [1 1 1 0.7], 'Margin', 2);

% Hacim sinir kutusu
draw_volume_box_local(ax1, x_mm(end), y_mm(end), z_mm(end));
hold(ax1, 'off');
xlabel(ax1, 'X (mm)'); ylabel(ax1, 'Y (mm)'); zlabel(ax1, 'Z — Derinlik (mm)');
title(ax1, sprintf('Ham 3D  (\\lambda=%.4g)', mpd_exact_lambda_final), 'FontSize', 10);
axis(ax1, 'equal'); grid(ax1, 'on'); box(ax1, 'on');
set(ax1, 'ZDir', 'reverse');
view(ax1, [-37 30]);
camlight('headlight'); lighting gouraud;
set(ax1, 'FontSize', 8);

% --- 3D Eşiklenmiş (sag panel) ---
ax2 = subplot(1,2,2);
hold(ax2, 'on');
iso_val_thr = cmax_thr * 0.5;
if iso_val_thr <= 0, iso_val_thr = cmax_thr * params.iso_ratio; end
try
    V_thr_smooth = smooth3(V_thr, 'gaussian', 3);
    fv2 = isosurface(V_thr_smooth, iso_val_thr);
    if ~isempty(fv2.vertices) && size(fv2.vertices,1) >= 3
        verts2_mm = zeros(size(fv2.vertices));
        verts2_mm(:,1) = (fv2.vertices(:,2) - 1) * unitinmm;
        verts2_mm(:,2) = (fv2.vertices(:,1) - 1) * unitinmm;
        verts2_mm(:,3) = (fv2.vertices(:,3) - 1) * unitinmm;
        p2 = patch(ax2, 'Vertices', verts2_mm, 'Faces', fv2.faces);
        set(p2, 'FaceColor', [0.20 0.45 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    else
        error('fallback');
    end
catch
    [ix, iy, iz] = ind2sub(vol_size, find(V_thr(:) > 0));
    vals = V_thr(V_thr(:) > 0);
    if ~isempty(ix)
        scatter3(ax2, (ix-1)*unitinmm, (iy-1)*unitinmm, (iz-1)*unitinmm, ...
            30, vals, 'filled', 'MarkerFaceAlpha', 0.7);
        colormap(ax2, 'winter');
    end
    fprintf('[UYARI] Esiklenmis isosurface hatasi, scatter3 fallback kullanildi.\n');
end

% (1,1,1) orijin isaretcisi
plot3(ax2, 0, 0, 0, 'p', 'MarkerSize', 16, 'MarkerFaceColor', [0 0.8 0], ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
text(ax2, 0.05, 0.05, -0.05, '  (1,1,1) Orijin', ...
    'Color', [0 0.6 0], 'FontWeight', 'bold', 'FontSize', 9, ...
    'BackgroundColor', [1 1 1 0.7], 'Margin', 2);

% Hacim sinir kutusu
draw_volume_box_local(ax2, x_mm(end), y_mm(end), z_mm(end));
hold(ax2, 'off');
xlabel(ax2, 'X (mm)'); ylabel(ax2, 'Y (mm)'); zlabel(ax2, 'Z — Derinlik (mm)');
title(ax2, sprintf('Esiklenmis 3D  (iso=%.0f%%)', params.iso_ratio*100), 'FontSize', 10);
axis(ax2, 'equal'); grid(ax2, 'on'); box(ax2, 'on');
set(ax2, 'ZDir', 'reverse');
view(ax2, [-37 30]);
camlight('headlight'); lighting gouraud;
set(ax2, 'FontSize', 8);

% Ust baslik
sgtitle(sprintf('MPD v2 — 3D Rekonstrüksiyon  |  Hacim: %.1f×%.1f×%.1f mm³', ...
    x_mm(end), y_mm(end), z_mm(end)), 'FontWeight', 'bold', 'FontSize', 11);

fprintf('\nGörselleştirme tamamlandı: %d figür açıldı.\n', 3);


%% ================== Yardimci Fonksiyonlar ==================

function traceT = estimate_trace_t_local(A, AtA_diag, D2, lambda, sampleCount, tol, maxit, eps0, useGpu, verbose, printStride, outerIter)
    if ~useGpu
        error('mpd v2 CPU fallback kullanmaz. trace_use_gpu kapatilamaz.');
    end

    if exist('gpuDeviceCount', 'file') ~= 2 || gpuDeviceCount < 1
        error('mpd v2 trace hesabi icin GPU gerekli.');
    end

    traceT = estimate_trace_t_gpu_local(A, AtA_diag, D2, lambda, sampleCount, tol, maxit, eps0, verbose, printStride, outerIter);
end


function reset_gpu_safe_local()
    try
        reset(gpuDevice());
    catch
    end
end

function draw_volume_box_local(ax, xmax, ymax, zmax)
    % Hacim sinirlarini wireframe kutu olarak cizer
    % 8 kose, 12 kenar
    verts = [0 0 0; xmax 0 0; xmax ymax 0; 0 ymax 0;
             0 0 zmax; xmax 0 zmax; xmax ymax zmax; 0 ymax zmax];
    edges = [1 2; 2 3; 3 4; 4 1;   % alt yüz
             5 6; 6 7; 7 8; 8 5;   % üst yüz
             1 5; 2 6; 3 7; 4 8];  % dikey kenarlar
    for e = 1:size(edges,1)
        plot3(ax, verts(edges(e,:),1), verts(edges(e,:),2), verts(edges(e,:),3), ...
            'Color', [0.4 0.4 0.4 0.5], 'LineWidth', 0.8, 'LineStyle', '--');
    end
    % Kose etiketleri (sadece orijin ve karsit kose)
    text(ax, xmax, ymax, zmax, sprintf(' (%.1f, %.1f, %.1f) mm', xmax, ymax, zmax), ...
        'FontSize', 7, 'Color', [0.3 0.3 0.3]);
end


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
    if bnorm == 0
        bnorm = 1;
    end
    
    for it = 1:maxit
        Hp = Ag' * (Ag * p) + lambda * (D2g .* p);
        
        denom = sum(p .* Hp);
        if denom == 0
            denom = eps;
        end
        
        alpha = rz_old / denom;
        x = x + p * alpha;
        r = r - Hp * alpha;
        
        if mod(it, printStride) == 0 || it == maxit
            relres = norm(r) / bnorm;
            if verbose
                fprintf('      trace outer=%d sample=%d cg=%d relres=%.3e\n', outerIter, sampleIdx, it, gather(relres));
            end
            if relres <= tol
                break;
            end
        end
        
        z = r ./ diagHg;
        rz_new = sum(r .* z);
        beta = rz_new / rz_old;
        p = z + p * beta;
        rz_old = rz_new;
    end
end
