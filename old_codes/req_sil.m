% === LC: x(λ*) vektörü + 3B hacim olarak kaydet (otomatik boyut çıkarımı) ===
% Gerekli: X_lambdas, idx_LC, opt_lambda_LC
% (vx/nt yoksa otomatik bulmaya çalışır)

% 1) LC çözümünü al
x_LC = X_lambdas{idx_LC};
Nvox = numel(x_LC);

% 2) vx ve nt'yi belirle (varsa kullan, yoksa otomatik tahmin)
vx_local = []; nt_local = [];

if exist('vx','var')==1 && exist('nt','var')==1 ...
        && isnumeric(vx) && isnumeric(nt) && isfinite(vx) && isfinite(nt) ...l
        && vx>0 && nt>0 && mod(Nvox, vx^2)==0 && Nvox/(vx^2)==nt
    vx_local = vx; 
    nt_local = nt;
else
    % Büyükten küçüğe aday vx taraması: Nx^2 Nvox'i tam bölsün
    maxCand = floor(sqrt(Nvox));
    found = false;
    for cand = maxCand:-1:2
        if mod(Nvox, cand^2) == 0
            vx_local = cand;
            nt_local = Nvox / (cand^2);
            found = true;
            break
        end
    end
    % Yedek: perfect cube ise kübik varsay
    if ~found
        cand = round(Nvox^(1/3));
        if cand^3 == Nvox
            vx_local = cand;
            nt_local = cand;
            found = true;
        end
    end
end

% 3) Hacme şekillendir (mümkünse)
V_LC = [];
if ~isempty(vx_local) && ~isempty(nt_local) && isfinite(vx_local) && isfinite(nt_local) ...
        && mod(Nvox, vx_local^2)==0 && Nvox/(vx_local^2)==nt_local
    V_LC = reshape(x_LC, [vx_local vx_local nt_local]);
    infoStr = sprintf('vx=%d, nt=%d (Nvox=%d)', vx_local, nt_local, Nvox);
else
    infoStr = sprintf('Hacme şekillendirme için uygun (vx,nt) bulunamadı (Nvox=%d). Sadece x_LC kaydediliyor.', Nvox);
end

% 4) Dosya adı
fn = sprintf('LC_x_and_volume_lambda_%0.3e_%s.mat', opt_lambda_LC, datestr(now,'yyyymmdd_HHMMSS'));

% 5) Kaydet
if ~isempty(V_LC)
    save(fn, 'x_LC','V_LC','opt_lambda_LC','idx_LC','vx_local','nt_local','-v7.3');
else
    save(fn, 'x_LC','opt_lambda_LC','idx_LC','-v7.3');
end

% 6) Bilgi
if ~isempty(V_LC)
    sz = size(V_LC);
    fprintf('Kaydedildi: %s\n%s\nx_LC uzunluğu: %d | V_LC boyutu: [%d %d %d]\n', ...
        fn, infoStr, Nvox, sz(1), sz(2), sz(3));
else
    fprintf('Kaydedildi: %s\n%s\nx_LC uzunluğu: %d\n', fn, infoStr, Nvox);
end
%%

%% === Dedektör koordinatlarını listele & görselleştir ===
% Bu blok: voksel ve mm cinsinden x,y,z; yarıçap; kaynağa uzaklık (mm) hesaplar,
% tablo yazdırır, CSV'ye kaydeder ve harita üzerinde indeksleri gösterir.

% -- Parametreler (mevcut cfg'den okunur) --
unit = cfg.unitinmm;              % mm/voxel
src  = cfg.srcpos(1:3);           % [x y z] voxel
volsz = size(cfg.vol);            % [Nx Ny Nz]
save_csv = true;                  % CSV kaydı istiyorsan true

% -- Dedektör setini al / yoksa üret --
if exist('detpos_filtered','var') && ~isempty(detpos_filtered)
    D = detpos_filtered;          % [x y z r] voxel
elseif isfield(cfg,'detpos') && ~isempty(cfg.detpos)
    D = cfg.detpos;               % [x y z r] voxel
else
    % Senin kurulumun: 5x5 grid, spacing=4 voxel, merkez (kaynak) hariç
    grid_size = [5 5];
    spacing_x_manual = 4; spacing_y_manual = 4;
    detector_radius = 2;
    [gx, gy] = meshgrid(-floor(grid_size(1)/2):floor(grid_size(1)/2), ...
                        -floor(grid_size(2)/2):floor(grid_size(2)/2));
    gx = gx * spacing_x_manual + src(1);
    gy = gy * spacing_y_manual + src(2);
    D = [gx(:), gy(:), zeros(numel(gx),1), repmat(detector_radius, numel(gx),1)];
    is_src = (D(:,1)==src(1)) & (D(:,2)==src(2)) & (D(:,3)==0);
    D = D(~is_src, :);
end

% -- Hesaplamalar --
N = size(D,1);
xv = D(:,1); yv = D(:,2); zv = D(:,3); rv = D(:,4);         % voxel
xm = xv*unit; ym = yv*unit; zm = zv*unit; rm = rv*unit;     % mm
% Kaynağa düzlemde (x,y) Öklid uzaklığı (mm)
dxy_mm = hypot( (xv-src(1))*unit, (yv-src(2))*unit );

% Halka (ring) indeksi: kaynağa voksel cinsinden mesafeye göre
ring_vox = round(hypot(xv-src(1), yv-src(2)));  % 4, 8, 12 ... gibi

% -- Tablo oluştur --
T = table( (1:N).', xv, yv, zv, rv, xm, ym, zm, rm, dxy_mm, ring_vox, ...
    'VariableNames', {'idx','x_vox','y_vox','z_vox','r_vox', ...
                      'x_mm','y_mm','z_mm','r_mm','dist_xy_mm','ring_vox'});

disp('--- Detector coordinates (voxel & mm) ---');
disp(T);

if save_csv
    csvname = sprintf('detector_coords_%s.csv', datestr(now,'yyyymmdd_HHMMSS'));
    writetable(T, csvname);
    fprintf('Saved: %s\n', csvname);
end

% -- Görselleştirme (üst yüzeyde x-y düzlemi) --
figure; hold on; box on; grid on;
scatter(xv, yv, 60, 'b', 'filled');                   % dedektörler
scatter(src(1), src(2), 80, 'r', 'filled');           % kaynak
text(xv+0.4, yv+0.4, string((1:N).'), 'Color','k');   % indeks etiketleri
xlim([1 volsz(1)]); ylim([1 volsz(2)]);
xlabel('x (voxel)'); ylabel('y (voxel)');
title(sprintf('Detectors (N=%d), source @ [%d %d %d]', N, src));
legend('Detectors','Source','Location','bestoutside');

% Opsiyonel: ring’leri farklı renk/işaret ile görmek istersen:
% gscatter(xv, yv, ring_vox); axis([1 volsz(1) 1 volsz(2)]); grid on;
%%
% Dosya ismini belirle
filename = 'detector_coords_20250905_003414.csv';

% CSV dosyasını oku
T = readtable(filename);

% Sadece gerekli kolonları al (idx, x_vox, y_vox, z_vox, r_vox)
T = T(:, {'idx','x_vox','y_vox','z_vox','r_vox'});

% Tabloyu göster
disp(T);

% Excel'e kaydetmek istersen
writetable(T, 'detector_coords_simple.xlsx');


