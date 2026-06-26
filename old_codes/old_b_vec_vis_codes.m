%% --- ÖN KONTROLLER (tek seferlik) ---
% Gereken değişkenler: source_pos, scanX, scanY, detpos, detector_radius, ms, image_grid
if ~exist('num_detectors','var') || isempty(num_detectors)
    num_detectors = size(detpos,1);
end
num_images = scanX * scanY;

assert(exist('ms','var')==1, 'Hata: ms tanımlı değil (num_detectors x num_images olmalı).');
assert(size(ms,1)==num_detectors, 'Hata: ms satır sayısı (dedektör) num_detectors ile uyuşmuyor.');
assert(size(ms,2)==num_images,    'Hata: ms sütun sayısı scanX*scanY ile uyuşmuyor.');

%% Görselleştirme 1: 
disp('Görselleştirme 1: Seçilen dedektörün konumu');
detector_idx = input(sprintf('1–%d arasında dedektör indeksi seçin: ', num_detectors));

% --- 1) Overlay: Seçilen dedektörü arka plan üzerinde göster ---
bg_frame = 1;  % arka plan olarak kullanacağınız frame indeksi
Iback = image_grid{ind2sub([scanX, scanY], bg_frame)};
figure; imshow(Iback, []); hold on; axis equal off;

% Tüm dedektörleri soluk mavi daire, kaynağı kırmızı
theta = linspace(0,2*pi,200);
for d = 1:num_detectors
    x0 = detpos(d,1);  y0 = detpos(d,2);
    plot(x0, y0, 'o', 'MarkerEdgeColor',[0.7 0.9 1], ...
         'MarkerSize',8, 'LineWidth',1);
    xc = x0 + detector_radius*cos(theta);
    yc = y0 + detector_radius*sin(theta);
    plot(xc, yc, '--', 'Color',[0.7 0.9 1], 'LineWidth',1);
end
% Kaynağı çiz
plot(source_pos(1), source_pos(2), 'rs', 'MarkerSize',12, 'LineWidth',2);
viscircles(source_pos, detector_radius, 'Color','r','LineWidth',1.5);

% Seçilen dedektörü vurgula: kırmızı dolu daire + numara
x_sel = detpos(detector_idx,1);
y_sel = detpos(detector_idx,2);
plot(x_sel, y_sel, 'ro', 'MarkerFaceColor','r', 'MarkerSize',10, 'LineWidth',2);
text(x_sel, y_sel, sprintf('%d', detector_idx), ...
     'Color','w','FontSize',10,'FontWeight','bold', ...
     'HorizontalAlignment','center','VerticalAlignment','middle');

title(sprintf('Dedektör %d Konumu (Image %d)', detector_idx, bg_frame));
hold off;
%%   Görselleştirme 2
figure;
plot(1:num_images, ms(detector_idx,:), '-o', 'LineWidth',1.5, 'MarkerSize',6);
xlabel('Image İndisi');
ylabel('Yoğunluk');
title(sprintf('Dedektör %d – Sinyal Serisi', detector_idx));
grid on;

%%  Görselleştirme 3

disp('Görselleştirme 1: Bir dedektör frame 2D olarak göster');
detector_idx = input(sprintf('1–%d arasında dedektör indeksi seçin: ', num_detectors));

% 1) Zaman serisini vektör halinde al
z = ms(detector_idx, :);

% 2) 2D ızgaraya çevir (scanX satır × scanY sütun)
Z = reshape(z, scanX, scanY)';

% 3) Görselleştir
figure;
imagesc(Z, [0 700]);  %4095
%imagesc(Z, [min(z) max(z)]);
axis equal tight;
colormap hot;
colorbar;
title(sprintf('Dedektör %d – Dedektor Frame Heatmap', detector_idx));

% Ekseni kapatma yerine etiketleyelim
xlabel('Scan Y indeksi');
ylabel('Scan X indeksi');


%% Görselleştirme 4
disp('Görselleştirme 2: Image Heat Map');
frame_idx = input(sprintf('1–%d arasında image indeksi seçin: ', num_images));
ints      = ms(:, frame_idx);

% Boş bir nan-matris oluştur
intGrid = nan(detector_cols, detector_rows);

% Satır/kolon indekslerini hesapla
dx     = (detpos(:,1) - source_pos(1)) / detector_spacing;
dy     = (detpos(:,2) - source_pos(2)) / detector_spacing;
rowIdx = round(dy + (detector_cols+1)/2);
colIdx = round(dx + (detector_rows+1)/2);

% Yoğunluk değerlerini matrise yerleştir
for k = 1:length(ints)
    if rowIdx(k)>=1 && rowIdx(k)<=detector_cols && colIdx(k)>=1 && colIdx(k)<=detector_rows
        intGrid(rowIdx(k), colIdx(k)) = ints(k);
    end
end

% Görselleştir, otomatik ölçek yerine sabit 12-bit aralık (0–4095) kullanılıyor
figure;
imagesc(intGrid, [0 4095]);   % sabit ölçek
axis equal tight off;
colormap hot;
colorbar;
title(sprintf('Image %d –  (0–4095 Sabit Ölçek)', frame_idx));

% Hücre ortasına değerleri yaz
for i = 1:detector_cols
    for j = 1:detector_rows
        v = intGrid(i,j);
        if ~isnan(v)
            text(j, i, sprintf('%.0f', v), ...
                 'HorizontalAlignment','center', ...
                 'VerticalAlignment','middle', ...
                 'Color','w','FontWeight','bold');
        end
    end
end



%% Görselleştirme 5
disp('Görselleştirme 3: Arkaplan üzerine overlay');
bg_frame = 60;  % background için kullanacağınız frame
Iback = image_grid{ind2sub([scanX, scanY], bg_frame)};
figure; imshow(Iback, []); hold on; axis equal off;

theta = linspace(0,2*pi,200);
for d = 1:num_detectors
    x0 = detpos(d,1);
    y0 = detpos(d,2);
    % Dedektör merkezi
    plot(x0, y0, 'bo', 'MarkerSize',10, 'LineWidth',2);
    % Dedektör numarası
    text(x0, y0, sprintf('%d', d), ...
         'Color','y', ...                  % sarı yazı
         'FontSize',10, ...                % biraz daha büyük font
         'FontWeight','bold', ...
         'HorizontalAlignment','center', ...
         'VerticalAlignment','middle');
    % Dedektör yarıçapı
    xc = x0 + detector_radius*cos(theta);
    yc = y0 + detector_radius*sin(theta);
    plot(xc, yc, 'b--', 'LineWidth',1.5);
end

% Kaynak işaretlemesi
plot(source_pos(1), source_pos(2), 'rs', 'MarkerSize',20, 'LineWidth',3);
viscircles(source_pos, detector_radius, 'Color','r','LineWidth',2);

title('Arkaplan – Dedektörler & Kaynak');
hold off;


%% Görselleştirme 6
disp('Görselleştirme 4: Ortalama yoğunluk haritası');

% 1) Her dedektörün zamana göre ortalama değeri
avgVals = mean(ms, 2);

% 2) Satır/kolon indekslerini hesapla
dx     = (detpos(:,1) - source_pos(1)) / detector_spacing;
dy     = (detpos(:,2) - source_pos(2)) / detector_spacing;
rowIdx = round(dy + (detector_cols+1)/2);
colIdx = round(dx + (detector_rows+1)/2);

% 3) Boş bir nan-matris oluştur (kaynak hücresi nan kalacak)
avgGrid = nan(detector_cols, detector_rows);

% 4) Ortalama değerleri matrise yerleştir
for k = 1:numel(avgVals)
    r = rowIdx(k);
    c = colIdx(k);
    if r>=1 && r<=detector_cols && c>=1 && c<=detector_rows
        avgGrid(r, c) = avgVals(k);
    end
end

% 5) Görselleştir, otomatik ölçek kaldırıldı, sabit 12-bit aralık kullanılıyor
figure;
imagesc(avgGrid);
colormap hot;
colorbar;
caxis([0 4095]);   % 12-bit aralığı sabitlendi
axis equal tight off;
title('Ortalama Yoğunluk – Dedektör Izgarası (0–4095 Sabit Ölçek)');

% 6) Hücre ortasına değerleri yaz
for i = 1:detector_cols
    for j = 1:detector_rows
        v = avgGrid(i,j);
        if ~isnan(v)
            text(j, i, sprintf('%.1f', v), ...
                 'HorizontalAlignment','center', ...
                 'VerticalAlignment','middle', ...
                 'Color','w','FontWeight','bold');
        end
    end
end
%%
% 1) Zaman serisini vektör halinde al
z = ms(detector_idx, :);

% 2) 2D ızgaraya çevir ve transpoze et
%    önce (scanY sütun × scanX satır) olarak oluştur, sonra ' ile döndür
Z = reshape(z, scanY, scanX)';

% 3) Görselleştir (0–4095 aralığında)
figure;
imagesc(Z, [0 4095]);
axis equal tight off;
colormap hot;
colorbar;
title(sprintf('Dedektör %d – Dedektor Frame Heatmap', detector_idx));

xlabel('Scan Y indeksi');
ylabel('Scan X indeksi');

%% Görselleştirme 3: Tüm dedektör frame heatmap’leri (tıkla aç/kapat)
n      = num_detectors;
nCols  = ceil(sqrt(n));
nRows  = ceil(n/nCols);

fig = figure('Name','Tüm Dedektör Frame Heatmap','NumberTitle','off');  
tl  = tiledlayout(nRows, nCols, ...
      'Padding','none', ...      % kenar boşlukları yok
      'TileSpacing','none');     % subplot arası boşluk yok
colormap(hot);

% Her dedektör için bir tile
for d = 1:n
    ax = nexttile;
    Z  = reshape(ms(d,:), scanX, scanY)';    % 2D frame
    
    hImg = imagesc(ax, Z, [0 4100]);
    axis(ax,'equal','off');
    title(ax, sprintf('Detektör %d', d), 'FontSize', 8);
    
    % Frame verisini ve indeksi sakla
    setappdata(hImg, 'Zdata',   Z);
    setappdata(hImg, 'detIdx',  d);
    
    % Tıklayınca callback çalışsın
    hImg.ButtonDownFcn = @openCloseCallback;
end

% Ortak renk çubuğu
cb = colorbar('eastoutside');
cb.Limits = [0 4100];

% % --- Local function: tıklayınca aç / tekrar tıklayınca kapat ---
% function openCloseCallback(src, ~)
%     % Eğer daha önce açılmış bir figür varsa kapat
%     oldFig = getappdata(src,'FullFig');
%     if ~isempty(oldFig) && isvalid(oldFig)
%         close(oldFig);
%         rmappdata(src,'FullFig');
%         return;
%     end
%     
%     % Yeni bir pencere açıp görüntüyü çiz
%     Z   = getappdata(src,'Zdata');
%     idx = getappdata(src,'detIdx');
%     hF  = figure('Name', sprintf('Detektör %d – Büyütülmüş', idx), ...
%                  'NumberTitle','off');
%     
%     h2  = imagesc(Z, [0 4100]);
%     axis equal off;
%     colormap(hot);
%     colorbar;
%     title(sprintf('Detektör %d', idx));
%     
%     % Bu penceredeki image’a tıklayınca kapanması için
%     h2.ButtonDownFcn = @(~,~) close(hF);
%     
%     % Handle’ı sakla ki tekrar tıklayınca kapatabilelim
%     setappdata(src,'FullFig', hF);
% end

%%%%%
%%

%% === Çoklu Optimum λ Seçimi: LC/GCV/Morozov/Triangle/Corner/U-Curve ===
% Bu blok, daha önce hesaplanmış olan:
%   - lambda_range, X_lambdas, res_norm, reg_norm
%   - A_norm, b_norm
% değişkenlerini kullanır.

% Koruma: log(0) ve bölme hataları olmasın
reg_norm_safe = reg_norm + eps;
res_norm_safe = res_norm + eps;

% --- 1) L-Curve (Curvature) ---
[~, ~, curvature_all] = compute_curvature(reg_norm_safe, res_norm_safe, lambda_range);
[~, idx_LC] = max(curvature_all);
opt_lambda_LC = lambda_range(idx_LC);

% --- 2) GCV ---
% DoF (df) için yumuşak sayım: sum(|x| / sqrt(x^2 + eps^2))
epsilon_val = 1e-6;
m = size(A_norm,1);
num_lambda = numel(lambda_range);
df_smooth = zeros(num_lambda,1);
gcv_vals   = zeros(num_lambda,1);

for i = 1:num_lambda
    xi = X_lambdas{i};
    df_smooth(i) = sum( abs(xi) ./ sqrt(xi.^2 + epsilon_val^2) );
    % Literatürde farklı ölçekler var; senin paylaştığın formu koruyorum:
    % GCV(λ) = ||r||^2 / (m - df)^2
    gcv_vals(i)  = (res_norm_safe(i)^2) / (max(m - df_smooth(i), 1e-9))^2;
end
[~, idx_GCV] = min(gcv_vals);
opt_lambda_GCV = lambda_range(idx_GCV);

% --- 3) Morozov Discrepancy ---
% Gürültü RMS (σ) tahmini: b_norm üzerinden MAD→σ
% σ ≈ MAD/0.6745, hedef delta ≈ sqrt(m)*σ   (||noise||_2).
mad_b = median(abs(b_norm - median(b_norm)));
noise_rms_est = mad_b / 0.6745;
delta_target  = sqrt(m) * noise_rms_est;

% Klasik Morozov: ||r(λ)||_2 ≈ δ_target
[~, idx_Morozov] = min(abs(res_norm_safe - delta_target));
opt_lambda_Morozov = lambda_range(idx_Morozov);

% (İsteğe bağlı: paylaştığın formüle benzer δ(λ) eğrisi)
delta_est_curve = noise_rms_est * df_smooth * sqrt(2/pi); 

% --- 4) Triangle (Üçgen) Yöntemi ---
lx = log(reg_norm_safe);
ly = log(res_norm_safe);
[idx_triangle, ~] = corner_by_triangle(lx, ly);
opt_lambda_Triangle = lambda_range(idx_triangle);

% --- 5) Corner (Ayrık açı tabanlı köşe) ---
% (l_corner yerine basit ayrık dönüş açısı ölçümü: en küçük iç açı = en keskin köşe)
% Çalışma uzayı: (log(res), log(reg)) nokta eğrisi
P = [ly(:), lx(:)];  % x: log(res), y: log(reg)
K = size(P,1);
angles = inf(K,1);
for k = 2:K-1
    v1 = P(k-1,:) - P(k,:);
    v2 = P(k+1,:) - P(k,:);
    if any(~isfinite([v1 v2], 'all')), continue; end
    cth = max(-1,min(1, dot(v1,v2)/(norm(v1)*norm(v2)+eps)));
    angles(k) = acos(cth); % [0, pi]
end
[~, k_corner] = min(angles); % en keskin dönüş (küçük açı)
opt_lambda_Corner = lambda_range(k_corner);

% --- 6) U-Curve ---
U_vals = 1./(res_norm_safe.^2) + 1./(reg_norm_safe.^2);
[~, idx_UC] = min(U_vals);
opt_lambda_UC = lambda_range(idx_UC);

%% === Konsol çıktısı (özet) ===
fprintf('\n=== Optimum λ Sonuçları ===\n');
fprintf('  L-Curve (Curvature):   % .5e   (idx=%d)\n', opt_lambda_LC, idx_LC);
fprintf('  GCV:                   % .5e   (idx=%d)\n', opt_lambda_GCV, idx_GCV);
fprintf('  Morozov (discrepancy): % .5e   (idx=%d, δ≈%.3e)\n', opt_lambda_Morozov, idx_Morozov, delta_target);
fprintf('  Triangle:              % .5e   (idx=%d)\n', opt_lambda_Triangle, idx_triangle);
fprintf('  Corner (discrete):     % .5e   (idx=%d)\n', opt_lambda_Corner, k_corner);
fprintf('  U-Curve:               % .5e   (idx=%d)\n', opt_lambda_UC, idx_UC);

% İstersen küçük bir tablo da göster:
MethodNames = {'L-Curve'; 'GCV'; 'Morozov'; 'Triangle'; 'Corner'; 'U-Curve'};
LambdaVals  = [opt_lambda_LC; opt_lambda_GCV; opt_lambda_Morozov; ...
               opt_lambda_Triangle; opt_lambda_Corner; opt_lambda_UC];
IdxVals     = [idx_LC; idx_GCV; idx_Morozov; idx_triangle; k_corner; idx_UC];
Topt = table(MethodNames, LambdaVals, IdxVals)

%%

%% —————— 10) Çeşitli yöntemlerle optimal λ’yı bul ——————
% (reg_norm, res_norm, lambda_range, X_lambdas tanımlı olmalı)

% Koruma için eps ekle
reg_norm_safe = reg_norm + eps;
res_norm_safe = res_norm + eps;

% --- 1) L-Curve (Curvature) ---
[~, ~, curvature_all] = compute_curvature(reg_norm_safe, res_norm_safe, lambda_range);
[~, idx_LC] = max(curvature_all);
opt_lambda_LC = lambda_range(idx_LC);

% --- 2) GCV ---
epsilon_val = 1e-6;
m = size(A_norm,1);
num_lambda = numel(lambda_range);
df_smooth = zeros(num_lambda,1);
gcv_vals   = zeros(num_lambda,1);
for i = 1:num_lambda
    xi = X_lambdas{i};
    df_smooth(i) = sum( abs(xi) ./ sqrt(xi.^2 + epsilon_val^2) );
    gcv_vals(i)  = (res_norm_safe(i)^2) / (max(m - df_smooth(i), 1e-9))^2;
end
[~, idx_GCV] = min(gcv_vals);
opt_lambda_GCV = lambda_range(idx_GCV);

% --- 3) Morozov Discrepancy ---
mad_b = median(abs(b_norm - median(b_norm)));
noise_rms_est = mad_b / 0.6745;
delta_target  = sqrt(m) * noise_rms_est;
[~, idx_Morozov] = min(abs(res_norm_safe - delta_target));
opt_lambda_Morozov = lambda_range(idx_Morozov);

% --- 4) Triangle (Üçgen) yöntemi ---
lx = log(reg_norm_safe);
ly = log(res_norm_safe);
[idx_triangle, ~] = corner_by_triangle(lx, ly);
opt_lambda_Triangle = lambda_range(idx_triangle);

% --- 5) Corner (açı yöntemi) ---
P = [ly(:), lx(:)];
K = size(P,1);
angles = inf(K,1);
for k = 2:K-1
    v1 = P(k-1,:) - P(k,:);
    v2 = P(k+1,:) - P(k,:);
    if any(~isfinite([v1 v2]),'all'), continue; end
    cth = max(-1,min(1, dot(v1,v2)/(norm(v1)*norm(v2)+eps)));
    angles(k) = acos(cth);
end
[~, k_corner] = min(angles);
opt_lambda_Corner = lambda_range(k_corner);

% --- 6) U-Curve ---
U_vals = 1./(res_norm_safe.^2) + 1./(reg_norm_safe.^2);
[~, idx_UC] = min(U_vals);
opt_lambda_UC = lambda_range(idx_UC);

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
%%
%%
%%
%% ===== TEK PENCERE: Diagnostik + 3B Rekonstrüksiyon (Tıklayınca Büyüt) =====
% Girdi varsayımları:
%  lambda_range, res_norm, reg_norm, curvature_all, ...
%  idx_LC, idx_GCV, idx_Morozov, idx_triangle, k_corner, idx_UC, ...
%  gcv_vals, U_vals, delta_target
%  Reconstructed_LC, Reconstructed_GCV, Reconstructed_Morozov,
%  Reconstructed_Triangle, Reconstructed_Corner, Reconstructed_UC
%  vol_preX (orijinal), cfg.unitinmm (isteğe bağlı)
%
% NOT: Eğer curvature_all adını curvature kullandıysan, 'curvature_all'ı ona eşitle:
% curvature_all = curvature;

% ------------- Ana pencere + sekmeler -------------
f = figure('Name','Lambda Seçim Karşılaştırma','Color','w','Units','normalized','Position',[0.05 0.05 0.9 0.9]);
tg = uitabgroup(f);

tabDiag = uitab(tg, 'Title', 'Diagnostik');
tab3D   = uitab(tg, 'Title', '3B Rekon');

% ====================== Sekme 1: Diagnostik ======================
% 2x3 ızgara: [L-Curve(+işaretler), Curvature, GCV; Morozov, U-Curve, Özet Tablo]
tl1 = tiledlayout(tabDiag, 2, 3, 'TileSpacing','compact','Padding','compact');

% --- (1) L-Curve: loglog(res, reg) + tüm optima işaretleri ---
ax1 = nexttile(tl1,1);
loglog(ax1, res_norm, reg_norm, '-o','MarkerSize',4); hold(ax1,'on');
loglog(ax1, res_norm(idx_LC),       reg_norm(idx_LC),       'ys','MarkerSize',9,'LineWidth',1.5);    % LC
loglog(ax1, res_norm(idx_triangle), reg_norm(idx_triangle), 'g^','MarkerSize',9,'LineWidth',1.5);    % Triangle
loglog(ax1, res_norm(k_corner),     reg_norm(k_corner),     'kd','MarkerSize',9,'LineWidth',1.5);    % Corner
hold(ax1,'off'); grid(ax1,'on');
xlabel(ax1,'Residual ‖A x(\lambda)-b‖_2'); ylabel(ax1,'Regularizer ‖x(\lambda)‖_1');
title(ax1,'L-Curve + Köşe İşaretleri');
legend(ax1, 'L-Curve','LC Opt','Triangle Opt','Corner Opt','Location','best');
makeClickable(ax1);

% --- (2) Curvature vs λ (LC) ---
ax2 = nexttile(tl1,2);
semilogx(ax2, lambda_range, curvature_all, '-o','MarkerSize',4); hold(ax2,'on');
semilogx(ax2, lambda_range(idx_LC), curvature_all(idx_LC), 'ro','MarkerSize',8,'LineWidth',1.5);
hold(ax2,'off'); grid(ax2,'on');
xlabel(ax2,'\lambda'); ylabel(ax2,'Curvature');
title(ax2,'L-Curve Eğrilik vs \lambda');
legend(ax2,'Eğrilik','LC Opt','Location','best');
makeClickable(ax2);

% --- (3) GCV ---
ax3 = nexttile(tl1,3);
semilogx(ax3, lambda_range, gcv_vals, 'r*-','LineWidth',1.2); hold(ax3,'on');
semilogx(ax3, lambda_range(idx_GCV), gcv_vals(idx_GCV), 'ms','MarkerSize',9,'LineWidth',1.5);
hold(ax3,'off'); grid(ax3,'on');
xlabel(ax3,'\lambda'); ylabel(ax3,'GCV');
title(ax3,'GCV Kriteri');
legend(ax3,'GCV','GCV Opt','Location','best');
makeClickable(ax3);

% --- (4) Morozov Discrepancy ---
ax4 = nexttile(tl1,4);
semilogx(ax4, lambda_range, res_norm, 'b-o','LineWidth',1.2); hold(ax4,'on');
semilogx(ax4, lambda_range, ones(size(lambda_range))*delta_target, 'r-.','LineWidth',1.2);
semilogx(ax4, lambda_range(idx_Morozov), res_norm(idx_Morozov), 'ms','MarkerSize',9,'LineWidth',1.5);
hold(ax4,'off'); grid(ax4,'on');
xlabel(ax4,'\lambda'); ylabel(ax4,'‖A x(\lambda)-b‖_2');
title(ax4, sprintf('Morozov: hedef \\delta \\approx %.2e', delta_target));
legend(ax4,'Rezidü Norm','\delta hedef','Morozov Opt','Location','best');
makeClickable(ax4);

% --- (5) U-Curve ---
ax5 = nexttile(tl1,5);
semilogx(ax5, lambda_range, U_vals, 'k-^','LineWidth',1.2); hold(ax5,'on');
semilogx(ax5, lambda_range(idx_UC), U_vals(idx_UC), 'ms','MarkerSize',9,'LineWidth',1.5);
hold(ax5,'off'); grid(ax5,'on');
xlabel(ax5,'\lambda'); ylabel(ax5,'U(\lambda)');
title(ax5,'U-Curve');
legend(ax5,'U','U-Curve Opt','Location','best');
makeClickable(ax5);

% --- (6) Özet tablo (metin olarak) ---
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
% (Bu kutu da büyütülebilir)
makeClickable(ax6);

x_opt_LC       = X_lambdas{idx_LC};
x_opt_GCV      = X_lambdas{idx_GCV};
x_opt_Morozov  = X_lambdas{idx_Morozov};
x_opt_Triangle = X_lambdas{idx_triangle};
x_opt_Corner   = X_lambdas{k_corner};
x_opt_UC       = X_lambdas{idx_UC};
volSize = [vx vx nt];

Reconstructed_LC       = reshape(x_opt_LC,       volSize);
Reconstructed_GCV      = reshape(x_opt_GCV,      volSize);
Reconstructed_Morozov  = reshape(x_opt_Morozov,  volSize);
Reconstructed_Triangle = reshape(x_opt_Triangle, volSize);
Reconstructed_Corner   = reshape(x_opt_Corner,   volSize);
Reconstructed_UC       = reshape(x_opt_UC,       volSize);
% ====================== Sekme 2: 3B Rekon ======================
% Güvenli kurulum: figure -> tabgroup -> '3B Rekon' sekmesi -> panel -> tiledlayout
if ~exist('f','var') || ~isgraphics(f,'figure')
    f = figure('Name','Lambda Seçim Karşılaştırma', 'Color','w', ...
               'Units','normalized','Position',[0.05 0.05 0.9 0.9]);
end
if ~exist('tg','var') || ~isgraphics(tg,'uitabgroup') || ~isequal(ancestor(tg,'figure'), f)
    tg = uitabgroup(f);
end
if ~exist('tab3D','var') || ~isgraphics(tab3D,'uitab') || ~isequal(ancestor(tab3D,'uitabgroup'), tg)
    tab3D = uitab(tg, 'Title', '3B Rekon');
end
if ~exist('p3D','var') || ~isgraphics(p3D,'uipanel') || ~isequal(get(p3D,'Parent'), tab3D)
    p3D = uipanel('Parent', tab3D, 'BorderType','none', ...
                  'Units','normalized', 'Position',[0 0 1 1]);
end

% 2x3 ızgara: her yöntemin 3B isosurface'i (aynı eşik oranı)
tl2 = tiledlayout(p3D, 2, 3, 'TileSpacing','compact','Padding','compact');

% Ortak eşik (oran)
iso_ratio = 0.25;

% Boyutlar
[Ny, Nx, Nz] = size(Reconstructed_LC);

% Yardımcı anonim fonksiyon (tek panel çiz)
drawIso = @(ax, V, ttl, fcolor) drawIsoSurface(ax, V, iso_ratio, ttl, fcolor, Nx, Ny, Nz);

% --- LC ---
ax = nexttile(tl2,1); drawIso(ax, Reconstructed_LC,       'LC',       [1 0 0]);      % kırmızı
% --- GCV ---
ax = nexttile(tl2,2); drawIso(ax, Reconstructed_GCV,      'GCV',      [0 0.6 0]);    % yeşil
% --- Morozov ---
ax = nexttile(tl2,3); drawIso(ax, Reconstructed_Morozov,  'Morozov',  [1 0 1]);      % magenta
% --- Triangle ---
ax = nexttile(tl2,4); drawIso(ax, Reconstructed_Triangle, 'Triangle', [0 1 1]);      % cyan
% --- Corner ---
ax = nexttile(tl2,5); drawIso(ax, Reconstructed_Corner,   'Corner',   [1 1 0]);      % sarı
% --- U-Curve ---
ax = nexttile(tl2,6); drawIso(ax, Reconstructed_UC,       'U-Curve',  [0 0 1]);      % mavi
%
%% ====================== Sekme 3: 2D Dilimler (robust, subplot, NaN->arka plan) ======================
if ~exist('f','var') || ~isgraphics(f,'figure')
    f = figure('Name','Lambda Seçim Karşılaştırma', 'Color','w', ...
               'Units','normalized','Position',[0.05 0.05 0.9 0.9]);
end
if ~exist('tg','var') || ~isgraphics(tg,'uitabgroup') || ~isequal(ancestor(tg,'figure'), f)
    old_tgs = findall(f, 'Type','uitabgroup');
    if ~isempty(old_tgs), delete(old_tgs); end
    tg = uitabgroup('Parent', f);
end

% 2D sekmesini hazırla/temizle
if exist('tab2D','var') && isgraphics(tab2D,'uitab') && isequal(ancestor(tab2D,'uitabgroup'), tg)
    delete(allchild(tab2D));
else
    tab2D = uitab(tg, 'Title', '2D Dilimler');
end

% Yöntemlerin sekmeleri
if ~exist('iso_ratio','var'); iso_ratio = 0.25; end
MethodNames2D = {'LC','GCV','Morozov','Triangle','Corner','U-Curve'};
Volumes2D = {Reconstructed_LC, Reconstructed_GCV, Reconstructed_Morozov, ...
             Reconstructed_Triangle, Reconstructed_Corner, Reconstructed_UC};

for mth = 1:numel(MethodNames2D)
    V = Volumes2D{mth};
    V(isnan(V)) = 0;  % güvenlik: NaN temizle

    % Eşik uygula (3B ile aynı oran)
    vmaxAll = max(V(:)); if ~isfinite(vmaxAll), vmaxAll = 0; end
    thr = vmaxAll * iso_ratio;
    Mask = V >= thr;
    Vplot = V; Vplot(~Mask) = NaN;  % eşik altını NaN yap: arka planı göstereceğiz

    % Grid boyutu
    [~,~,ntM] = size(Vplot);
    nCols = ceil(sqrt(ntM));
    nRows = ceil(ntM/nCols);

    % Alt sekme + panel
    tabM = uitab(tab2D.Parent, 'Title', MethodNames2D{mth});  % alt sekme
    pM   = uipanel('Parent', tabM, 'BorderType','none', 'Units','normalized', 'Position',[0 0 1 1]);

    % Ortak CLim: yalnız görünür değerlerden
    visVals = Vplot(~isnan(Vplot));
    if isempty(visVals)
        vmin = 0; vmax = 1;
    else
        vmin = min(visVals); vmax = max(visVals);
        if ~isfinite(vmin) || ~isfinite(vmax) || vmin >= vmax
            vmin = 0; vmax = max(1, vmaxAll);
        end
    end

    % Subplotlarla çiz
    for t = 1:ntM
        ax = subplot(nRows, nCols, t, 'Parent', pM);
        img = Vplot(:,:,t);

        hImg = imagesc(ax, img, [vmin vmax]);
        axis(ax,'equal'); axis(ax,'off');
        title(ax, sprintf('Slice %d', t), 'FontSize', 8);

        % Arka planı siyah yap: NaN alanlar siyah görünsün
        set(ax, 'Color', 'k');

        % Colormap eksen bazında
        colormap(ax, 'hot');

        % tıklanınca büyüt
        set(ax, 'ButtonDownFcn', @(h,~) enlargeAxes2D(h));
        set(hImg, 'HitTest','off','PickableParts','none'); % tık aksese düşsün
    end

    % Tek colorbar: son eksene ekle ve kenara taşı
    axlast = subplot(nRows, nCols, ntM, 'Parent', pM);
    try
        cb = colorbar(axlast, 'Location','eastoutside');
    catch
        cb = colorbar(axlast); cb.Location = 'eastoutside';
    end
    cb.Label.String = sprintf('%s intensity (iso = %.2g·max)', MethodNames2D{mth}, iso_ratio);

    % Başlık
    annotation(pM, 'textbox', [0 0.96 1 0.04], 'String', ...
        sprintf('%s — 2D Dilimler (iso = %.2g·max)', MethodNames2D{mth}, iso_ratio), ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'EdgeColor','none','FontWeight','bold');

    drawnow; pause(0.01); % UI yerleşimi için
end

%% ================== Yerel yardımcı: büyütme penceresi ==================
function enlargeAxes2D(ax)
    f2 = figure('Name','Büyütülmüş Dilim', 'Color','w', ...
                'Units','normalized', 'Position',[0.2 0.2 0.6 0.6]);
    ax2 = axes('Parent', f2);
    copyobj(allchild(ax), ax2);
    axis(ax2,'equal'); axis(ax2,'off');
    try, ax2.CLim = ax.CLim; catch, end
    title(ax2, ax.Title.String);
    colormap(ax2, colormap(ax));
    set(ax2, 'Color', get(ax,'Color'));
    colorbar(ax2);
end



%% ================== Yardımcı Fonksiyonlar ==================
function makeClickable(ax)
    % Alt grafiği tıklayınca yeni pencerede büyüt
    set(ax, 'ButtonDownFcn', @(h,~) enlargeAxes(h));
    % Çocukları tıklanmaz yap ki tık aksese düşsün
    ch = allchild(ax);
    set(ch, 'HitTest','off','PickableParts','none');
end

function enlargeAxes(ax)
    % Mevcut axes içeriğini kopyalayıp büyük pencerede gösterir
    f2 = figure('Name','Büyütülmüş Görünüm','Color','w','Units','normalized','Position',[0.2 0.2 0.6 0.6]);
    ax2 = axes('Parent',f2);
    copyobj(allchild(ax), ax2);
    axis(ax2, axis(ax));  % limitleri koru
    view(ax2, camva(ax)); % 3B view benzer olsun (cam* ayarları)
    try
        % Eğer 3B ise mevcut view açılarını da kopyalamaya çalış
        [az, el] = view(ax);
        view(ax2, az, el);
    catch
    end
    grid(ax2, ax.GridLineStyle ~= 'none');
    xlabel(ax2, ax.XLabel.String); ylabel(ax2, ax.YLabel.String); zlabel(ax2, ax.ZLabel.String);
    title(ax2, ax.Title.String);
    colormap(ax2, colormap(ax));
    % Colorbar varsa kopyalamak yerine yeniden eklemek genelde daha sağlam:
    if ~isempty(findobj(ax,'Type','colorbar'))
        colorbar(ax2);
    end
end

function drawIsoSurface(ax, V, iso_ratio, ttl, fcolor, Nx, Ny, Nz)
    % V: 3B hacim, iso_ratio: [0-1] aralığında eşik oranı (max(V)*iso_ratio)
    thr = max(V(:)) * iso_ratio;
    [F, Vert] = isosurface(V, thr);
    p = patch(ax, 'Faces',F, 'Vertices',Vert, 'FaceColor',fcolor, 'EdgeColor','none','FaceAlpha',0.85);
    hold(ax,'on');
    % XY projeksiyonu (z=1)
    Vxy = Vert; Vxy(:,3) = 1;
    patch(ax, 'Faces',F, 'Vertices',Vxy, 'FaceColor',fcolor, 'EdgeColor','k', 'FaceAlpha',0.15, 'LineWidth',0.7);
    % XZ projeksiyonu (y=1)
    Vxz = Vert; Vxz(:,2) = 1;
    patch(ax, 'Faces',F, 'Vertices',Vxz, 'FaceColor',fcolor, 'EdgeColor','k', 'FaceAlpha',0.15, 'LineWidth',0.7);
    % YZ projeksiyonu (x=1)
    Vyz = Vert; Vyz(:,1) = 1;
    patch(ax, 'Faces',F, 'Vertices',Vyz, 'FaceColor',fcolor, 'EdgeColor','k', 'FaceAlpha',0.15, 'LineWidth',0.7);
    hold(ax,'off');
    daspect(ax,[1 1 1]); view(ax,3); grid(ax,'on'); axis(ax,'tight');
    xlim(ax,[1 Nx]); ylim(ax,[1 Ny]); zlim(ax,[1 Nz]);
    % tikleri 1'den başlat
    xticks(ax, 1:5:max(1,Nx)); yticks(ax, 1:5:max(1,Ny)); zticks(ax, 1:5:max(1,Nz));
    xlabel(ax,'X'); ylabel(ax,'Y'); zlabel(ax,'Z');
    title(ax, ttl);
    camlight(ax,'headlight'); lighting(ax,'gouraud'); material(ax,'dull');
    % tıklayınca büyütme
    makeClickable(ax);
    % Patch çocuklarını da pasifleştir ki axes tıklaması çalışsın
    set(p, 'HitTest','off','PickableParts','none');
end
%%



%% —————— Yardımcı fonksiyon: Triangle köşe bulucu ——————
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

function [log_reg, log_res, curvature] = compute_curvature(reg_norm, res_norm, lambda_range)
    log_reg = log(reg_norm(:));
    log_res = log(res_norm(:));
    t = log(lambda_range(:));
    
    % Birinci türevler
    dlogr = gradient(log_reg, t);
    dlogR = gradient(log_res, t);
    
    % İkinci türevler
    d2logr = gradient(dlogr, t);
    d2logR = gradient(dlogR, t);
    
    % Eğrilik hesaplaması (NaN korumalı)
    curvature = abs(d2logR .* dlogr - dlogR .* d2logr) ./ (dlogR.^2 + dlogr.^2 + eps()).^(3/2);
end

