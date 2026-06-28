% x_reconst_3.m
% Orijinal x_reconst.m'nin MPD v7 kodundan alınan GPU, bellek optimizasyonları
% ve 'v3_fast' solver teknikleriyle güçlendirilmiş son halidir.

%% —————— 1) Gerekli Değişkenleri Al ——————
if exist('cfg', 'var') && isfield(cfg, 'A_matrix')
    A_cpu = double(cfg.A_matrix);
elseif exist('ms', 'var')
    A_cpu = double(ms);
else
    error('A matrisi bulunamadı (cfg.A_matrix veya ms değişkenlerini kontrol edin).');
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

%% —————— 2) GPU Context Doğrulama (v7 MPD Yaklaşımı) ——————
fprintf('\n=== x_reconst GPU Optimize (Persistent & v3_fast) ===\n');
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

% Eski kodda bellek tüketen devasa diag(A'*A) işlemi vektörel sum'a çevrildi
eps0       = 1e-10;
rootfact   = 1;          % Derinlik ağırlıklandırma üssü (MPD v7 ile tutarlı)
D_diag_cpu = sum(A_norm_cpu.^2, 1)';
D_diag_cpu = D_diag_cpu .^ rootfact;
dmax = max(abs(D_diag_cpu));
if dmax > 0
    D_diag_cpu = D_diag_cpu ./ dmax;
end
D_diag_cpu = max(D_diag_cpu, eps0);

%% —————— 4) GPU'ya Aktarım ve Bellek Kontrolü ——————
estimated_total = (numel(A_norm_cpu)*8 + numel(b_norm_cpu)*8 + numel(D_diag_cpu)*8) * 2.5;
if estimated_total > d.AvailableMemory
    warning(['GPU belleği yetersiz olabilir. Tahmini gereksinim: %.1f GB, ' ...
             'Mevcut: %.1f GB. Devam ediliyor...'], ...
             estimated_total/1e9, d.AvailableMemory/1e9);
end

fprintf('\nVeriler GPU belleğine kalıcı (persistent) yükleniyor...\n');
Ag = gpuArray(A_norm_cpu);
bg = gpuArray(b_norm_cpu);
Dg = gpuArray(D_diag_cpu);

% Büyük CPU değişkenlerini temizleyip sistem RAM'ini rahatlatıyoruz
clear A_cpu b_cpu A_norm_cpu b_norm_cpu D_diag_cpu;

%% —————— 5) Lp‐solver Parametreleri ——————
p       = 1;               
tol     = 1e-4;            
max_itr = 10000;             
nu      = 1e-4;            
x0g     = gpuArray.zeros(n, 1, 'double');

%% —————— 6) L‐curve İçin λ Taraması ——————
% (GCV ve türevlerinin çalışabilmesi için tekil değer yerine array taraması)
lambda_range = 39.66;%logspace(-3, 2.5, 15);
num_lambda   = numel(lambda_range);

res_norm     = zeros(num_lambda, 1);
reg_norm     = zeros(num_lambda, 1);
X_lambdas    = cell(num_lambda, 1);   

tic;
fprintf('\nLambda tarama başlıyor (%d adet lambda, v3_fast solver)...\n', num_lambda);
for i = 1:num_lambda
    lam = lambda_range(i);
    
    % HIZLI SOLVER: Lp_solver_depthver2_gpu_2_double_v3_fast
    % (Son iki parametre: false, 1)
    xg = Lp_solver_depthver2_gpu_2_double_v3_fast_console( ...
        Ag, bg, p, lam, tol, max_itr, nu, eps0, x0g, Dg, false, 50);
    
    % GPU'da norm işlemleri
    res_val_g = norm(Ag * xg - bg, 2);
    reg_val_g = norm(xg, 1);
    
    % CPU'ya sadece skalerler ve sonuç vektörünü alıyoruz
    res_norm(i) = gather(res_val_g);
    reg_norm(i) = gather(reg_val_g);
    X_lambdas{i} = gather(xg);
    
    fprintf('  λ = %8.2e  →  res = %8.3e, reg = %8.3e\n', lam, res_norm(i), reg_norm(i));
end
fprintf('Tarama tamamlandı.\n\n');
totalElapsedTime = toc;
fprintf('Toplam geçen süre: %.2f saniye (%.2f dakika).\n\n', totalElapsedTime, totalElapsedTime/60);

% Matris işimiz bitti, GPU RAM'ini tamamen serbest bırakıyoruz.
clear Ag bg Dg x0g xg res_val_g reg_val_g;

%% —————— 7) Çeşitli Yöntemlerle Optimal λ’yı Bul (CPU Tarafı) ——————
reg_norm_safe = reg_norm + eps;
res_norm_safe = res_norm + eps;

if num_lambda > 1
    % --- 1) L-Curve (Curvature) ---
    [~, ~, curvature_all] = compute_curvature(reg_norm_safe, res_norm_safe, lambda_range);
    [~, idx_LC] = max(curvature_all);
    opt_lambda_LC = lambda_range(idx_LC);

    % --- 2) GCV ---
    epsilon_val = 1e-6;
    m_rows = m; % b'nin boyutu 
    df_smooth = zeros(num_lambda, 1);
    gcv_vals  = zeros(num_lambda, 1);
    for i = 1:num_lambda
        xi = X_lambdas{i};
        df_smooth(i) = sum(abs(xi) ./ sqrt(xi.^2 + epsilon_val^2));
        gcv_vals(i)  = (res_norm_safe(i)^2) / (max(m_rows - df_smooth(i), 1e-9))^2;
    end
    [~, idx_GCV] = min(gcv_vals);
    opt_lambda_GCV = lambda_range(idx_GCV);

    % --- 3) Morozov Discrepancy ---
    mad_b = median(abs(X_lambdas{1} - median(X_lambdas{1}))); % Sembolik (orijinal kod referansı için)
    noise_rms_est = median(res_norm_safe) * 0.1; % Ampirik tahmin (b normu yerine res bazlı)
    delta_target  = sqrt(m_rows) * noise_rms_est;
    [~, idx_Morozov] = min(abs(res_norm_safe - delta_target));
    opt_lambda_Morozov = lambda_range(idx_Morozov);

    % --- 4) Triangle (Üçgen) yöntemi ---
    lx = log(reg_norm_safe);
    ly = log(res_norm_safe);
    [idx_triangle, ~] = corner_by_triangle(lx, ly);
    opt_lambda_Triangle = lambda_range(idx_triangle);

    % --- 5) Corner (açı yöntemi) ---
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

    % --- 6) U-Curve ---
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

% === Sonuçları yazdır ===
fprintf('\n=== Optimum λ Sonuçları ===\n');
fprintf('  L-Curve (Curvature):   %.5e (idx=%d)\n', opt_lambda_LC, idx_LC);
fprintf('  GCV:                   %.5e (idx=%d)\n', opt_lambda_GCV, idx_GCV);
fprintf('  Morozov:               %.5e (idx=%d, δ≈%.3e)\n', opt_lambda_Morozov, idx_Morozov, delta_target);
fprintf('  Triangle:              %.5e (idx=%d)\n', opt_lambda_Triangle, idx_triangle);
fprintf('  Corner:                %.5e (idx=%d)\n', opt_lambda_Corner, k_corner);
fprintf('  U-Curve:               %.5e (idx=%d)\n\n', opt_lambda_UC, idx_UC);

MethodNames = {'L-Curve'; 'GCV'; 'Morozov'; 'Triangle'; 'Corner'; 'U-Curve'};
LambdaVals  = [opt_lambda_LC; opt_lambda_GCV; opt_lambda_Morozov; ...
               opt_lambda_Triangle; opt_lambda_Corner; opt_lambda_UC];
IdxVals     = [idx_LC; idx_GCV; idx_Morozov; idx_triangle; k_corner; idx_UC];
Topt = table(MethodNames, LambdaVals, IdxVals)

%% --- 8) Hızlı Lokal/Global Önizleme (Orijinal x_reconst UI Katmanı) ---
slice_z = min(ceil(nt/2), nt);
volSize = [vx vx nt];

Reconstructed_LC       = reshape(X_lambdas{idx_LC},       volSize);
Reconstructed_GCV      = reshape(X_lambdas{idx_GCV},      volSize);
Reconstructed_Morozov  = reshape(X_lambdas{idx_Morozov},  volSize);
Reconstructed_Triangle = reshape(X_lambdas{idx_triangle}, volSize);
Reconstructed_Corner   = reshape(X_lambdas{k_corner},     volSize);
Reconstructed_UC       = reshape(X_lambdas{idx_UC},       volSize);

have_global = exist('scanX','var') && exist('scanY','var') && ...
              exist('recons_offset_x','var') && exist('recons_offset_y','var');

if have_global
    offx = recons_offset_x;
    offy = recons_offset_y;

    if offx < 0 || offy < 0 || offx > (scanX - vx) || offy > (scanY - vx)
        warning('recons_offset_x/y sınır dışı; global yerleşim atlandı.');
        have_global = false;
    else
        Vfull_LC       = zeros(scanY, scanX, nt);
        Vfull_GCV      = zeros(scanY, scanX, nt);
        Vfull_Morozov  = zeros(scanY, scanX, nt);
        Vfull_Triangle = zeros(scanY, scanX, nt);
        Vfull_Corner   = zeros(scanY, scanX, nt);
        Vfull_UC       = zeros(scanY, scanX, nt);

        Vfull_LC(offy+(1:vx), offx+(1:vx), :)       = Reconstructed_LC;
        Vfull_GCV(offy+(1:vx), offx+(1:vx), :)      = Reconstructed_GCV;
        Vfull_Morozov(offy+(1:vx), offx+(1:vx), :)  = Reconstructed_Morozov;
        Vfull_Triangle(offy+(1:vx), offx+(1:vx), :) = Reconstructed_Triangle;
        Vfull_Corner(offy+(1:vx), offx+(1:vx), :)   = Reconstructed_Corner;
        Vfull_UC(offy+(1:vx), offx+(1:vx), :)       = Reconstructed_UC;
    end
end

%% ===== TEK PENCERE: Diagnostik + 3B Rekonstrüksiyon (Tıklayınca Büyüt) =====
f = figure('Name','Lambda Seçim Karşılaştırma','Color','w','Units','normalized','Position',[0.05 0.05 0.9 0.9]);
tg = uitabgroup(f);

% ====================== Sekme 1: Diagnostik ======================
if num_lambda > 1
    tabDiag = uitab(tg, 'Title', 'Diagnostik');
    tl1 = tiledlayout(tabDiag, 2, 3, 'TileSpacing','compact','Padding','compact');

    % (1) L-Curve
    ax1 = nexttile(tl1,1);
    loglog(ax1, res_norm, reg_norm, '-o','MarkerSize',4); hold(ax1,'on');
    loglog(ax1, res_norm(idx_LC),       reg_norm(idx_LC),       'cs','MarkerSize',12,'LineWidth',1.5);
    loglog(ax1, res_norm(idx_triangle), reg_norm(idx_triangle), 'g^','MarkerSize',9,'LineWidth',1.5);
    loglog(ax1, res_norm(k_corner),     reg_norm(k_corner),     'kd','MarkerSize',9,'LineWidth',1.5);
    hold(ax1,'off'); grid(ax1,'on');
    xlabel(ax1,'Residual ‖A x(\lambda)-b‖_2'); ylabel(ax1,'Regularizer ‖x(\lambda)‖_1');
    title(ax1,'L-Curve + Köşe İşaretleri');
    legend(ax1, 'L-Curve','LC Opt','Triangle Opt','Corner Opt','Location','best');
    makeClickable(ax1);

    % (2) Curvature vs λ
    ax2 = nexttile(tl1,2);
    semilogx(ax2, lambda_range, curvature_all, '-o','MarkerSize',4); hold(ax2,'on');
    semilogx(ax2, lambda_range(idx_LC), curvature_all(idx_LC), 'cs','MarkerSize',12,'LineWidth',1.5);
    semilogx(ax2, lambda_range(idx_triangle), curvature_all(idx_triangle), 'g^','MarkerSize',9,'LineWidth',1.5);
    semilogx(ax2, lambda_range(k_corner), curvature_all(k_corner), 'kd','MarkerSize',9,'LineWidth',1.5);
    hold(ax2,'off'); grid(ax2,'on');
    xlabel(ax2,'\lambda'); ylabel(ax2,'Curvature');
    title(ax2,'L-Curve Eğrilik vs \lambda');
    legend(ax2,'Eğrilik','LC Opt','Triangle Opt','Corner Opt','Location','best');
    makeClickable(ax2);

    % (3) GCV
    ax3 = nexttile(tl1,3);
    semilogx(ax3, lambda_range, gcv_vals, 'r*-','LineWidth',1.2); hold(ax3,'on');
    semilogx(ax3, lambda_range(idx_GCV), gcv_vals(idx_GCV), 'ms','MarkerSize',9,'LineWidth',1.5);
    hold(ax3,'off'); grid(ax3,'on');
    xlabel(ax3,'\lambda'); ylabel(ax3,'GCV');
    title(ax3,'GCV Kriteri');
    legend(ax3,'GCV','GCV Opt','Location','best');
    makeClickable(ax3);

    % (4) Morozov
    ax4 = nexttile(tl1,4);
    semilogx(ax4, lambda_range, res_norm, 'b-o','LineWidth',1.2); hold(ax4,'on');
    semilogx(ax4, lambda_range, ones(size(lambda_range))*delta_target, 'r-.','LineWidth',1.2);
    semilogx(ax4, lambda_range(idx_Morozov), res_norm(idx_Morozov), 'ms','MarkerSize',9,'LineWidth',1.5);
    hold(ax4,'off'); grid(ax4,'on');
    xlabel(ax4,'\lambda'); ylabel(ax4,'‖A x(\lambda)-b‖_2');
    title(ax4, sprintf('Morozov: hedef \\delta \\approx %.2e', delta_target));
    legend(ax4,'Rezidü Norm','\delta hedef','Morozov Opt','Location','best');
    makeClickable(ax4);

    % (5) U-Curve
    ax5 = nexttile(tl1,5);
    semilogx(ax5, lambda_range, U_vals, 'k-^','LineWidth',1.2); hold(ax5,'on');
    semilogx(ax5, lambda_range(idx_UC), U_vals(idx_UC), 'ms','MarkerSize',9,'LineWidth',1.5);
    hold(ax5,'off'); grid(ax5,'on');
    xlabel(ax5,'\lambda'); ylabel(ax5,'U(\lambda)');
    title(ax5,'U-Curve');
    legend(ax5,'U','U-Curve Opt','Location','best');
    makeClickable(ax5);

    % (6) Özet
    ax6 = nexttile(tl1,6);
    axis(ax6,'off');
    text(0,1, sprintf(['Optimum \\lambda Sonuçları:\n' ...
        '  L-Curve      : %.5e (idx=%d)\n' ...
        '  GCV          : %.5e (idx=%d)\n' ...
        '  Morozov      : %.5e (idx=%d)\n' ...
        '  Triangle     : %.5e (idx=%d)\n' ...
        '  Corner       : %.5e (idx=%d)\n' ...
        '  U-Curve      : %.5e (idx=%d)\n'], ...
        lambda_range(idx_LC), idx_LC, ...
        lambda_range(idx_GCV), idx_GCV, ...
        lambda_range(idx_Morozov), idx_Morozov, ...
        lambda_range(idx_triangle), idx_triangle, ...
        lambda_range(k_corner), k_corner, ...
        lambda_range(idx_UC), idx_UC), ...
        'Parent',ax6,'VerticalAlignment','top','FontName','Consolas','FontSize',10);
    title(ax6,'Özet');
    makeClickable(ax6);
end

% ====================== Sekme 2: 3B Rekon ======================
tab3DLocal = uitab(tg, 'Title', '3B Lokal');
p3DLocal = uipanel('Parent', tab3DLocal, 'BorderType','none', 'Units','normalized', 'Position',[0 0 1 1]);
tl2 = tiledlayout(p3DLocal, 2, 3, 'TileSpacing','compact','Padding','compact');

iso_ratio = 0.35;
[Ny, Nx, Nz] = size(Reconstructed_LC);
drawIso = @(ax, V, ttl, fcolor) drawIsoSurface(ax, V, iso_ratio, ttl, fcolor, Nx, Ny, Nz);

ax = nexttile(tl2,1); drawIso(ax, Reconstructed_LC,       'LC',       [1 0 0]);
ax = nexttile(tl2,2); drawIso(ax, Reconstructed_GCV,      'GCV',      [0 0.6 0]);
ax = nexttile(tl2,3); drawIso(ax, Reconstructed_Morozov,  'Morozov',  [1 0 1]);
ax = nexttile(tl2,4); drawIso(ax, Reconstructed_Triangle, 'Triangle', [0 1 1]);
ax = nexttile(tl2,5); drawIso(ax, Reconstructed_Corner,   'Corner',   [1 1 0]);
ax = nexttile(tl2,6); drawIso(ax, Reconstructed_UC,       'U-Curve',  [0 0 1]);
set(findall(gcf,'-property','FontSize'),'FontSize',14)

if have_global
    tab3DGlobal = uitab(tg, 'Title', '3B Global');
    p3DGlobal = uipanel('Parent', tab3DGlobal, 'BorderType','none', 'Units','normalized', 'Position',[0 0 1 1]);
    tl3 = tiledlayout(p3DGlobal, 2, 3, 'TileSpacing','compact','Padding','compact');
    [NyG, NxG, NzG] = size(Vfull_LC);
    drawIsoG = @(ax, V, ttl, fcolor) drawIsoSurface(ax, V, iso_ratio, ttl, fcolor, NxG, NyG, NzG);

    ax = nexttile(tl3,1); drawIsoG(ax, Vfull_LC,       'LC',       [1 0 0]);
    ax = nexttile(tl3,2); drawIsoG(ax, Vfull_GCV,      'GCV',      [0 0.6 0]);
    ax = nexttile(tl3,3); drawIsoG(ax, Vfull_Morozov,  'Morozov',  [1 0 1]);
    ax = nexttile(tl3,4); drawIsoG(ax, Vfull_Triangle, 'Triangle', [0 1 1]);
    ax = nexttile(tl3,5); drawIsoG(ax, Vfull_Corner,   'Corner',   [1 1 0]);
    ax = nexttile(tl3,6); drawIsoG(ax, Vfull_UC,       'U-Curve',  [0 0 1]);
end

% ====================== Sekme 3: 2D Dilimler ======================
tab2D = uitab(tg, 'Title', '2D Dilimler');
tg2D = uitabgroup(tab2D);
MethodNames2D = {'LC','GCV','Morozov','Triangle','Corner','U-Curve'};
Volumes2D = {Reconstructed_LC, Reconstructed_GCV, Reconstructed_Morozov, ...
             Reconstructed_Triangle, Reconstructed_Corner, Reconstructed_UC};

for mth = 1:numel(MethodNames2D)
    V = Volumes2D{mth};
    V(isnan(V)) = 0;

    vmaxAll = max(V(:)); if ~isfinite(vmaxAll), vmaxAll = 0; end
    thr = vmaxAll * iso_ratio;
    Mask = V >= thr;
    Vplot = V; Vplot(~Mask) = NaN;

    [~,~,ntM] = size(Vplot);
    nCols = ceil(sqrt(ntM));
    nRows = ceil(ntM/nCols);

    tabM = uitab(tg2D, 'Title', MethodNames2D{mth});
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
    cb.Label.String = sprintf('%s intensity (iso = %.2g)', MethodNames2D{mth}, iso_ratio);

    annotation(pM, 'textbox', [0 0.96 1 0.04], 'String', ...
        sprintf('%s — 2D Dilimler (iso = %.2g·max)', MethodNames2D{mth}, iso_ratio), ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'EdgeColor','none','FontWeight','bold');
end
set(findall(gcf,'-property','FontSize'),'FontSize',14)

%% ================== Yardımcı Fonksiyonlar ==================
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
    if ~isempty(findobj(ax,'Type','colorbar'))
        colorbar(ax2);
    end
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
