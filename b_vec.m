%% Adım 1: Temel Parametreler
disp('Adım 1: Parametreler yükleniyor...');
source_pos      = [364,255];   % Kaynak [yatay=sütun(y), dikey=satır(x)]  [218,367]->opak1
% NOT: Tüm dosyada TEK konvansiyon -> x = SATIR (1.boyut/dikey), y = SÜTUN (2.boyut/yatay).
%      Kamera görüntüsü I(satır,sütun) okunur. source_pos(1)=sütun, source_pos(2)=satır.
scanX           = 50;           % Tarama noktaları X yönü
scanY           = 50;           % Tarama noktaları Y yönü

%% Adım 2: Dedektör Grid Parametreleri
disp('Adım 2: Dedektör grid parametreleri alınıyor...');
detector_rows    = 9;
detector_cols    = 9;
detector_spacing = 22; %13
detector_radius  = 8;           % MCX (A_matrix) tarafıyla AYNI: dairesel disk yarıçapı (piksel)

%% Adım 3: Görüntüleri Oku (12-bit ham veri olarak)
disp('Adım 3: Görüntü dosyaları yükleniyor...');

image_folder = "D:\Images\30_01_26\sw1\avaraj_arkaplan_cikarilmis\renamed_swapped"; %"D:\Images\30_01_26\sw3\avrg\renamed_swapped";  
files = dir(fullfile(image_folder,'pos_*.png'));

% (scanX, scanY) gridine yerleştirilecek
image_grid = cell(scanX, scanY);

for k = 1:numel(files)
    fn = files(k).name;
    % Dosya adından X,Y koordinatlarını çıkar
    tok = regexp(fn, 'pos_(\d+)x(\d+)\.png', 'tokens', 'once');
    x   = str2double(tok{1});
    y   = str2double(tok{2});

    % Görüntüyü oku ve 12-bit’e indir
    path = fullfile(image_folder, fn);
    info = imfinfo(path);
    A    = imread(path);
    if ndims(A)==3, A = rgb2gray(A); end
    A16  = uint16(A);
    if info.BitDepth>12 && max(A16(:))>4095
        raw12 = bitshift(A16, -(info.BitDepth-12));
    else
        raw12 = A16;
    end

    % Doğrudan doğru hücreye ata
    image_grid{x, y} = double(raw12);
end

disp('Adım 3 tamamlandı!');

%% Adım 4: Dedektör Pozisyonlarını Hesapla
% NOT: a_matrix (MCX) tarafi dedektorleri "satir (x) yavas / sutun (y) hizli" sirasinda
% uretiyor. Burayi da AYNI siraya hizalamak icin satir'i yavas/dis indeks yapiyoruz.
% detpos sutun duzeni korunur -> col1 = sutun (det_col), col2 = satir (det_row).
sutun_vals = linspace(source_pos(1)-(detector_rows-1)/2*detector_spacing, ...
                      source_pos(1)+(detector_rows-1)/2*detector_spacing, detector_rows); % yatay = sutun (y)
satir_vals = linspace(source_pos(2)-(detector_cols-1)/2*detector_spacing, ...
                      source_pos(2)+(detector_cols-1)/2*detector_spacing, detector_cols); % dikey = satir (x)
[SAT, SUT] = meshgrid(satir_vals, sutun_vals);   % SAT: satir kolon boyunca (yavas), SUT: sutun satir boyunca (hizli)
all_pos    = [SUT(:), SAT(:)];                    % col1 = sutun (det_col), col2 = satir (det_row)
is_center = abs(all_pos(:,1)-source_pos(1))<eps & abs(all_pos(:,2)-source_pos(2))<eps;
detpos    = all_pos(~is_center, :);                                                                              % merkez hariç
num_detectors = size(detpos,1);

%% Adım 4b: Dairesel Disk Maskesi (MCX dedektör açıklığı ile aynı)
% MCX'te detpos=[x y z r] -> merkeze öklid mesafesi <= r olan voxelleri toplar.
% Burada aynısını kamera pikselleri üzerinde yapıyoruz: r=detector_radius
% yarıçaplı dairesel maske içindeki pikselleri TOPLUYORUZ (sum, mean değil),
% çünkü A_matrix tarafı da foton integrali (sum) niteliğindedir.
r_px = detector_radius;
[mx, my] = meshgrid(-ceil(r_px):ceil(r_px), -ceil(r_px):ceil(r_px));
disk_mask = (mx.^2 + my.^2) <= r_px^2;   % dairesel maske
disk_dx = mx(disk_mask);                  % maske içi x offsetleri
disk_dy = my(disk_mask);                  % maske içi y offsetleri
fprintf('Disk maskesi: yarıçap=%g piksel, maske içi piksel sayısı=%d\n', r_px, numel(disk_dx));

%% Adım 5: Dedektör serileri (ms) + Source serisi (ms_source)  [DİSK TOPLAMI]
% =====================================================================
% TEK KONVANSİYON:  x = SATIR (görüntünün 1.boyutu, dikey)
%                   y = SÜTUN (görüntünün 2.boyutu, yatay)
% Kamera görüntüsü daima I(SATIR, SÜTUN) = I(row, col) olarak okunur.
% detpos kamera pikselinde tanımlı:
%   detpos(:,1) = yatay piksel = SÜTUN (y)
%   detpos(:,2) = dikey piksel = SATIR (x)
% Bu yüzden hem dedektör hem source AYNI sırayla okunur:
%   sub2ind([H W], SATIR, SÜTUN)
% =====================================================================
disp('Adım 5: ms (dedektörler) ve ms_source (kaynak) DİSK TOPLAMI ile hesaplanıyor...');
num_images = scanX*scanY;

ms         = nan(num_detectors, num_images);   % dedektörlere ait seri
ms_source  = nan(1, num_images);               % merkez (source) serisi

src_row = round(source_pos(2));    % x = SATIR  (dikey)
src_col = round(source_pos(1));    % y = SÜTUN  (yatay)

for idx = 1:num_images
    [x_img, y_img] = ind2sub([scanX, scanY], idx);   % x_img = SATIR, y_img = SÜTUN
    I = image_grid{x_img, y_img};
    H = size(I,1);  W = size(I,2);

    % Dedektör okumaları (disk içi piksel toplamı)
    for d = 1:num_detectors
        det_row = round(detpos(d,2));    % x = SATIR (dikey)
        det_col = round(detpos(d,1));    % y = SÜTUN (yatay)
        % Disk içindeki mutlak piksel koordinatları
        rs = det_row + disk_dy;          % SATIR koordinatları
        cs = det_col + disk_dx;          % SÜTUN koordinatları
        % Görüntü sınırları içinde kalanlar (satır<=H, sütun<=W)
        valid = rs>=1 & rs<=H & cs>=1 & cs<=W;
        if any(valid)
            lin = sub2ind([H W], rs(valid), cs(valid));   % (SATIR, SÜTUN)
            ms(d,idx) = sum(I(lin));     % TOPLAM (MCX disk açıklığı gibi)
        else
            ms(d,idx) = NaN;
        end
    end

    % Source (merkez) okuması (disk içi piksel toplamı) - dedektörle AYNI mantık
    rs = src_row + disk_dy;              % SATIR koordinatları
    cs = src_col + disk_dx;              % SÜTUN koordinatları
    valid = rs>=1 & rs<=H & cs>=1 & cs<=W;
    if any(valid)
        lin = sub2ind([H W], rs(valid), cs(valid));   % (SATIR, SÜTUN)
        ms_source(idx) = sum(I(lin));
    else
        ms_source(idx) = NaN;
    end
end

fprintf('ms (dedektör) aralığı: min=%g, max=%g\n', min(ms(:)), max(ms(:)));
fprintf('ms_source (kaynak) aralığı: min=%g, max=%g\n', min(ms_source(:)), max(ms_source(:)));

% Kaynak için 2D heat map matrisi (x=SATIR, y=SÜTUN -> transpoze YOK)
Z_source = reshape(ms_source, scanX, scanY);    % (scanX[satır] x scanY[sütun])

%% Adım 6: sens sırasına göre b oluştur (Yalnızca dedektörler)
vx        = 26;                % A_matrix'teki vx ile aynı
recons_offset_x = 1;            % 0..(scanX-vx) araligi (scan ROI secimi)12
recons_offset_y = 9;           % 0..(scanY-vx) araligi12
% scanX     = 50;              % (zaten 50) – tekrar yazmak şart değil
% scanY     = 50;              % (zaten 50)
num_det   = size(detpos,1);    % dedektör sayısı
num_blocks= vx * vx;           % sens döngüsündeki toplam k (j,i kombinasyonu)

if recons_offset_x < 0 || recons_offset_y < 0 || ...
   recons_offset_x > (scanX - vx) || recons_offset_y > (scanY - vx)
    error('recons_offset_x/y scanX/scanY sinirlarini asiyor.');
end

% orijinal ms: num_det x (scanX*scanY)
% şimdi b'yi sens sıralamasına göre boyutlandır
b2 = nan(num_blocks * num_det, 1);

k = 0;
for j = 1:vx                % sens fonksiyonundaki 'j' döngüsü
  for i = 1:vx              % sens fonksiyonundaki 'i' döngüsü
    k = k + 1;              % blok indeksi

    % bu bloğa karşılık gelen frame numarası (ind2sub sıralamasına uygun)
    frame_x = recons_offset_x + i;
    frame_y = recons_offset_y + j;
    frame_idx = frame_x + (frame_y - 1) * scanX;

    for d = 1:num_det
      % ms(d, frame_idx) zaten o detektörün o frame'deki okumaları
      row      = (d-1)*num_blocks + k;
      b2(row) = ms(d, frame_idx);
    end
  end
end

% Sonuç: A = sens(jac) ile tamamen örtüşen sıralamada b:
b = b2;
cfg.b=b;
return
%%
% DEDEKTÖR VE SOURCE GERÇEK REKONSTRÜKSİYON FRAMELERİ (25x25) GÖRSELLEŞTİRME

% --- 2. Düzen Ayarları (Grid Layout) ---
n     = num_detectors;
nTile = n + 1;
nc = ceil(sqrt(nTile)); if mod(nc,2)==0, nc = nc+1; end
nr = ceil(nTile/nc);    if mod(nr,2)==0, nr = nr+1; end
while nr*nc < nTile
    if nr <= nc, nr = nr+2; else, nc = nc+2; end
end
r0 = (nr+1)/2;  c0 = (nc+1)/2;

% --- 3. Global Renk Ölçeği (b vektöründeki gerçek yoğunluk aralığı) ---
vals = b(:);
vals = vals(~isnan(vals));
if isempty(vals) || any(~isfinite([min(vals),max(vals)]))
    globalMin = 0; globalMax = 1;
else
    globalMin = min(vals); globalMax = max(vals);
    if globalMax <= globalMin, globalMin = 0; globalMax = 1; end
end

% --- 4. Figür ve Tiled Layout Hazırlığı ---
fig = figure('Name','Çözücüye Giden Gerçek 25x25 Dedektör Ölçüm Frameleri','NumberTitle','off', ...
             'Units','normalized','Position',[0 0.05 1 0.9], 'Color',[0.97 0.97 0.95]);

tl  = tiledlayout(nr, nc, 'Padding','none', 'TileSpacing','none', 'TileIndexing','columnmajor');
colormap(fig,'hot');

ringColors = [0.00 0.00 0.00; 0.20 0.20 0.80; 0.80 0.20 0.20; 0.20 0.60 0.20; 0.50 0.00 0.50];
frameLW = 2.0;

d = 1;
for c = 1:nc
    for r = 1:nr
        ax = nexttile(tl);

        % --- MERKEZ: SOURCE HEATMAP (Seçili ROI alanında kırpılmış 25x25) ---
        if r==r0 && c==c0
            if exist('ms_source', 'var')
                s_roi = nan(vx*vx, 1);
                k = 0;
                for j_idx = 1:vx
                    for i_idx = 1:vx
                        k = k + 1;
                        frame_idx = (recons_offset_x + i_idx) + (recons_offset_y + j_idx - 1) * scanX;
                        s_roi(k) = ms_source(frame_idx);
                    end
                end
                Zs = reshape(s_roi, vx, vx);
            else
                Zs = zeros(vx, vx);
            end

            hIm = imagesc(ax, Zs, [globalMin, globalMax]);
            axis(ax,'image');

            set(ax,'YDir','reverse');

            set(ax,'Box','on','LineWidth',frameLW, ...
                'XTick',[],'YTick',[],'Layer','top','Color','none', ...
                'XColor',[0.3 0.3 0.3],'YColor',[0.3 0.3 0.3]);

            text(ax, 0.02, 0.98, 'Source (ROI)', 'Units','normalized', ...
                'HorizontalAlignment','left','VerticalAlignment','top', ...
                'FontSize',8, 'FontWeight','bold', 'Color',[0.95 0.95 0.95], ...
                'BackgroundColor',[0 0 0], 'Margin',1, 'Clipping','on');

            setappdata(hIm,'Zdata', Zs);
            setappdata(hIm,'detIdx', 'Source (ROI)');
            hIm.ButtonDownFcn = @openCloseLocal;

            continue
        end

        % Boş kutular için dolgu
        if d>n
            axis(ax,'image');
            set(ax,'Box','on','LineWidth',1, ...
                'XTick',[],'YTick',[],'Layer','top','Color','none', ...
                'XColor',[0.85 0.85 0.85],'YColor',[0.85 0.85 0.85]);
            continue
        end

        % --- DEDEKTÖR ---
        start_idx = (d-1)*(vx*vx) + 1;
        end_idx   = d*(vx*vx);
        Z = reshape(b(start_idx:end_idx), vx, vx);

        hIm = imagesc(ax, Z, [globalMin, globalMax]);
        axis(ax,'image');

        set(ax,'YDir','reverse');

        ringIdx  = max(abs(r - r0), abs(c - c0));
        frameCol = ringColors(mod(ringIdx, size(ringColors,1)) + 1, :);
        set(ax,'Box','on','LineWidth',frameLW, ...
            'XTick',[],'YTick',[],'Layer','top','Color','none', ...
            'XColor',frameCol,'YColor',frameCol);

        text(ax, 0.02, 0.98, sprintf('Det %d', d), 'Units','normalized', ...
            'HorizontalAlignment','left','VerticalAlignment','top', ...
            'FontSize',7, 'FontWeight','bold', 'Color',[0.95 0.95 0.95], ...
            'BackgroundColor',[0 0 0], 'Margin',1, 'Clipping','on');

        setappdata(hIm,'Zdata', Z);
        setappdata(hIm,'detIdx', d);
        hIm.ButtonDownFcn = @openCloseLocal;

        d = d + 1;
    end
end

cb = colorbar('Location','southoutside');
cb.Limits = [globalMin, globalMax];
cb.Label.String = 'Ölçüm Şiddeti (Kırpılmış ROI - Intensity)';
cb.Layout.Tile = 'south';
% Eksen etiketleri (tüm layout için ortak): x = SATIR (dikey), y = SÜTUN (yatay)
xlabel(tl, 'y  (sütun \rightarrow)', 'FontWeight','bold');
ylabel(tl, 'x  (satır \downarrow)', 'FontWeight','bold');
%%
%% TÜM_ALAN
xi0 = round(source_pos(1));
yi0 = round(source_pos(2));
s   = nan(1, num_images);
for idx = 1:num_images
    [x_img, y_img] = ind2sub([scanX, scanY], idx);
    I = image_grid{x_img, y_img};
    if ~isempty(I) && xi0>=1 && xi0<=size(I,2) && yi0>=1 && yi0<=size(I,1)
        s(idx) = I(yi0, xi0);
    end
end

% Görselleştirme 8 — Source dahil ama global skala sadece dedektörlerden
n     = num_detectors;                % source hariç
nTile = n + 1;                        % +1: source için merkez kutu
nc = ceil(sqrt(nTile)); if mod(nc,2)==0, nc = nc+1; end
nr = ceil(nTile/nc);   if mod(nr,2)==0, nr = nr+1; end
while nr*nc < nTile
    if nr <= nc, nr = nr+2; else, nc = nc+2; end
end
r0 = (nr+1)/2;  c0 = (nc+1)/2;        % merkez

% --- GLOBAL skala: YALNIZCA dedektörlerden
vals = ms(:);
vals = vals(~isnan(vals));
if isempty(vals) || any(~isfinite([min(vals),max(vals)]))
    globalMin = 0; globalMax = 1;
else
    globalMin = min(vals); globalMax = max(vals);
    if globalMax <= globalMin, globalMin = 0; globalMax = 1; end
end

% Figür & layout
fig = figure('Name','Tüm Dedektör + Source Heatmap','NumberTitle','off', ...
             'Units','normalized','Position',[0 0 1 1], 'Color',[0.97 0.97 0.95]);
tl  = tiledlayout(nr, nc, 'Padding','none', 'TileSpacing','none');
colormap(fig,'hot');

% Halka bazlı çerçeve renkleri
ringColors = [0.00 0.00 0.00; 0.20 0.20 0.80; 0.80 0.20 0.20; 0.20 0.60 0.20; 0.50 0.00 0.50];
frameLW = 2.0;

d = 1;
for r = 1:nr
    for c = 1:nc
        ax = nexttile(tl);

        % --- MERKEZ: SOURCE HEATMAP ---
        if r==r0 && c==c0
            Zs  = reshape(s, scanX, scanY);                    % (scanX[satır] x scanY[sütun]) - transpoze YOK
            hIm = imagesc(ax, Zs, [globalMin, globalMax]);     % global skala = dedektörlere göre
            axis(ax,'image');
            set(ax,'YDir','reverse');                          % satır 1 üstte (x=satır)
            % Çerçeve (source için koyu gri)
            set(ax,'Box','on','LineWidth',frameLW, ...
                'XTick',[],'YTick',[],'Layer','top','Color','none', ...
                'XColor',[0.3 0.3 0.3],'YColor',[0.3 0.3 0.3]);

            % Üstte “Source” etiketi
            text(ax, 0.02, 0.98, 'Source', 'Units','normalized', ...
                'HorizontalAlignment','left','VerticalAlignment','top', ...
                'FontSize',8, 'FontWeight','bold', 'Color',[0.95 0.95 0.95], ...
                'BackgroundColor',[0 0 0], 'Margin',1, 'Clipping','on');

            % Tıklayınca lokal skala
            setappdata(hIm,'Zdata', Zs);
            setappdata(hIm,'detIdx', 'Source');
            hIm.ButtonDownFcn = @openCloseLocal;
            continue
        end

        % Dedektör kalmadıysa boş kutu
        if d>n
            axis(ax,'image');
            set(ax,'Box','on','LineWidth',1, ...
                'XTick',[],'YTick',[],'Layer','top','Color','none', ...
                'XColor',[0.85 0.85 0.85],'YColor',[0.85 0.85 0.85]);
            continue
        end

        % --- Dedektör heatmap ---
        Z   = reshape(ms(d,:), scanX, scanY);                  % (scanX[satır] x scanY[sütun]) - transpoze YOK
        hIm = imagesc(ax, Z, [globalMin, globalMax]);          % dedektör global skalası
        axis(ax,'image');
        set(ax,'YDir','reverse');                              % satır 1 üstte (x=satır)

        % Halka rengine göre çerçeve
        ringIdx  = max(abs(r - r0), abs(c - c0));
        frameCol = ringColors(mod(ringIdx, size(ringColors,1)) + 1, :);
        set(ax,'Box','on','LineWidth',frameLW, ...
            'XTick',[],'YTick',[],'Layer','top','Color','none', ...
            'XColor',frameCol,'YColor',frameCol);

        % Sol-üstte küçük indeks
        text(ax, 0.02, 0.98, sprintf('%d', d), 'Units','normalized', ...
            'HorizontalAlignment','left','VerticalAlignment','top', ...
            'FontSize',7, 'FontWeight','bold', 'Color',[0.95 0.95 0.95], ...
            'BackgroundColor',[0 0 0], 'Margin',1, 'Clipping','on');

        % Tıklayınca lokal skala
        setappdata(hIm,'Zdata', Z);
        setappdata(hIm,'detIdx', d);
        hIm.ButtonDownFcn = @openCloseLocal;

        d = d + 1;
    end
end

% --- ORTAK (GLOBAL) COLORBAR: layout'un güneyine ---
cb = colorbar('Location','southoutside');
cb.Limits = [globalMin, globalMax];
cb.Label.String = 'Global ölçek (dedektörler)';
cb.Layout.Tile = 'south';
% Eksen etiketleri (tüm layout için ortak): x = SATIR (dikey), y = SÜTUN (yatay)
xlabel(tl, 'y  (sütun \rightarrow)', 'FontWeight','bold');
ylabel(tl, 'x  (satır \downarrow)', 'FontWeight','bold');
%%
%% OFF_SET_SOURCE_ÜZERİNDE GÖRÜNTÜLEME  (DÜZELTİLMİŞ: x=satır, y=kolon)
% GEREKENLER: source_pos, scanX, scanY, image_grid (scanX x scanY hücre, her biri 2D görüntü)
%             recons_offset_x, recons_offset_y
%
% KONVANSİYON (tüm dosyada sabit):
%   x -> Zsrc'nin 1. boyutu (SATIR)   -> imagesc'te DİKEY eksen
%   y -> Zsrc'nin 2. boyutu (KOLON)   -> imagesc'te YATAY eksen
%   Bu yüzden TRANSPOZE YOK: imagesc(Zsrc) doğrudan x=satır, y=kolon gösterir.

% Ayarlar
source_radius_px = 14;   % source etrafında ortalama alınacak disk yarıçapı (px)
use_percentile_scale = true;   % true → p1–p99; false → min–max

% ====== RECONS BÖLGESİ PARAMETRELERİ ======
vx = 26;                              % sens() fonksiyonundaki pencere boyutu
recons_start_x = recons_offset_x + 1; % Recons başlangıç X (tarama koordinatında, SATIR yönü)
recons_start_y = recons_offset_y + 1; % Recons başlangıç Y (tarama koordinatında, KOLON yönü)
% ==========================================

% Disk maskesi (sabit, performans için bir kez üretelim)
[YY, XX] = meshgrid(-source_radius_px:source_radius_px, -source_radius_px:source_radius_px);
diskMask = (XX.^2 + YY.^2) <= source_radius_px^2;

% Çıkış matrisi: Zsrc(ix, iy) -> dim1=x (satır), dim2=y (kolon)
Zsrc = nan(scanX, scanY);

for ix = 1:scanX
    for iy = 1:scanY
        I = image_grid{ix, iy};          % bu frame'in görüntüsü
        if isempty(I), continue; end

        % Source merkezini sınırlar içinde kırp
        cx = round(source_pos(1));
        cy = round(source_pos(2));
        h  = size(I,1);  w = size(I,2);

        % ROI sınırları
        x1 = max(1, cx - source_radius_px);
        x2 = min(w, cx + source_radius_px);
        y1 = max(1, cy - source_radius_px);
        y2 = min(h, cy + source_radius_px);

        % Patch'i al
        patch = I(y1:y2, x1:x2);

        % Disk maskesini patch boyutuna kırp
        msk = diskMask( (end-(y2-y1)):end-(0), (end-(x2-x1)):end-(0) );

        % NaN'leri yoksayarak ortalama
        vals = double(patch(msk));
        vals = vals(isfinite(vals));
        if isempty(vals)
            Zsrc(ix, iy) = nan;
        else
            Zsrc(ix, iy) = mean(vals);
        end
    end
end

% Görselleştir
figure('Name','Source Heatmap + Recons Bölgesi','Color','w');
if use_percentile_scale
    vv = Zsrc(:); vv = vv(isfinite(vv));
    if isempty(vv), lo = 0; hi = 1; else, lo = prctile(vv,1); hi = prctile(vv,99); if hi<=lo, lo=0; hi=max(1,hi); end, end
    imagesc(Zsrc, [lo hi]);   % TRANSPOZE YOK: dikey=x(satır), yatay=y(kolon)
else
    imagesc(Zsrc);            % otomatik skala
end
% Satır 1 (x=1) en üstte dursun (matris/görüntü görünümü). Alta istersen 'normal' yap.
set(gca,'YDir','reverse');
axis image tight;
colormap hot;
cb = colorbar('eastoutside');
cb.Label.String = 'Source yoğunluğu';

% ====== RECONS BÖLGESİNİ GÖSTEREN ÇERÇEVEYİ ÇİZ ======
% DİKKAT: rectangle('Position',[X Y W H]) -> X=YATAY eksen, Y=DİKEY eksen (MATLAB sabit).
% imagesc(Zsrc) ile yatay=y(kolon), dikey=x(satır) olduğu için:
%   YATAY (X) <- recons_start_y   |   DİKEY (Y) <- recons_start_x
hold on;
rect_x = recons_start_y - 0.5;   % yatay eksen = y (kolon)
rect_y = recons_start_x - 0.5;   % dikey eksen = x (satır)
rect_w = vx;                     % yatay genişlik (y boyunca)
rect_h = vx;                     % dikey yükseklik (x boyunca)

rectangle('Position', [rect_x, rect_y, rect_w, rect_h], ...
          'EdgeColor', 'cyan', 'LineWidth', 2.5, 'LineStyle', '-');

% Etiket (kutunun üst kenarının biraz üstüne)
text(rect_x + rect_w/2, rect_y - 1.5, sprintf('Recons: %dx%d', vx, vx), ...
     'Color', 'cyan', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
     'FontSize', 10, 'BackgroundColor', [0 0 0 0.5]);

hold off;
xlabel('y (sütun)'); ylabel('x (satır)');
title(sprintf('Source Heatmap (yarıçap = %d px) — Cyan = Recons Bölgesi', source_radius_px));

%%
disp('Görselleştirme 5: Arkaplan üzerine overlay');
bg_frame = 60;  % background için frame
[ix, iy] = ind2sub([scanX, scanY], bg_frame);
Iback    = image_grid{ix, iy};

% NOT: Bu blok görüntünün KENDİSİ üzerine overlay. imshow ekseninde yatay=SÜTUN(y),
% dikey=SATIR(x) olduğundan plot ilk argümanı YATAY ister -> plot(detpos(:,1)=sütun, detpos(:,2)=satır).
% Aynı (x=satır,y=sütun) konvansiyonu; sadece çizim ekseni görüntü düzeninde.
figure; imshow(Iback, []); hold on; axis equal off;
theta = linspace(0,2*pi,200);
for d = 1:num_detectors
    x0 = detpos(d,1); y0 = detpos(d,2);   % x0 = sütun(yatay), y0 = satır(dikey)
    plot(x0, y0, 'co', 'MarkerSize',10, 'LineWidth',2);          % camgöbeği nokta
    text(x0, y0, sprintf('%d', d), 'Color','y','FontSize',10,'FontWeight','bold', ...
         'HorizontalAlignment','center','VerticalAlignment','middle');
    xc = x0 + detector_radius*cos(theta);
    yc = y0 + detector_radius*sin(theta);
    plot(xc, yc, 'c-', 'LineWidth',1.5);                         % düz, camgöbeği daire
end
plot(source_pos(1), source_pos(2), 'rs', 'MarkerSize',20, 'LineWidth',3);
plot(source_pos(1)+detector_radius*cos(theta), ...
     source_pos(2)+detector_radius*sin(theta), 'r-', 'LineWidth',2);   % düz kırmızı daire
title('Arkaplan – Dedektörler & Kaynak');
hold off;

%%
% =========================================================================
% TIKLAMA (LOCAL) FONKSİYONU
% =========================================================================
function openCloseLocal(src, ~)
    oldFig = getappdata(src,'FullFig');
    if ~isempty(oldFig) && isvalid(oldFig)
        close(oldFig); rmappdata(src,'FullFig'); return;
    end
    Z   = getappdata(src,'Zdata');
    idx = getappdata(src,'detIdx');

    zVals = Z(:); zVals = zVals(~isnan(zVals));
    if isempty(zVals) || any(~isfinite([min(zVals),max(zVals)]))
        locMin = 0; locMax = 1;
    else
        locMin = min(zVals); locMax = max(zVals);
        if locMax <= locMin, locMin = 0; locMax = 1; end
    end

    if isnumeric(idx), ttl = sprintf('Det %d', idx); else, ttl = char(idx); end
    hF = figure('Name', sprintf('%s – Büyütülmüş (Lokal)', ttl), ...
                'NumberTitle','off', 'Color','w');
    h2 = imagesc(Z, [locMin, locMax]); axis image; colormap(hot); colorbar;

    set(gca,'YDir','reverse');
    xlabel('y (sütun)'); ylabel('x (satır)');   % x = SATIR (dikey), y = SÜTUN (yatay)

    title(ttl, 'FontWeight','normal');
    h2.ButtonDownFcn = @(~,~) close(hF);
    setappdata(src,'FullFig', hF);
end
