%% figure; imshow(Iback, []); otomatikleri sonra kapat ,,, dedektörleri eski halie getir,, radiustan pixele çevir, cos formülünü değiştir

%% Tam MATLAB Script: 12-bit Görüntü Okuma, Dedektör Yoğunlukları ve Görselleştirme
%clc; clear; close all;

%% Adım 1: Temel Parametreler
disp('Adım 1: Parametreler yükleniyor...');
source_pos      = [220, 344];   % Kaynak (x,y)
scanX           = 50;           % Tarama noktaları X yönü
scanY           = 50;           % Tarama noktaları Y yönü
%% Adım 2: Dedektör Grid Parametreleri
disp('Adım 2: Dedektör grid parametreleri alınıyor...');
detector_rows    = 7;
detector_cols    = 7;
detector_spacing = 14;
detector_radius  = 2;
 
%% Adım 3: Görüntüleri Oku (12-bit ham veri olarak)
disp('Adım 3: Görüntü dosyaları yükleniyor...');

image_folder = "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\24_09_25_\1_0_deep\cell3\no_bg";
files = dir(fullfile(image_folder,'pos_*.png'));

% Önce scanX ve scanY tanımlı olmalı:
% (örneğin daha önce: scanX = 51; scanY = 51;)
% Burada onları kullanıyoruz:
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
disp('Adım 4: Dedektör pozisyonları hesaplanıyor...');
[GX, GY] = meshgrid( ...
    linspace(source_pos(1)-(detector_rows-1)/2*detector_spacing, source_pos(1)+(detector_rows-1)/2*detector_spacing, detector_rows), ...
    linspace(source_pos(2)-(detector_cols-1)/2*detector_spacing, source_pos(2)+(detector_cols-1)/2*detector_spacing, detector_cols) ...
);
all_pos   = [GX(:), GY(:)];
is_center = abs(all_pos(:,1)-source_pos(1))<eps & abs(all_pos(:,2)-source_pos(2))<eps;
detpos    = all_pos(~is_center, :);                                                                             
num_detectors = size(detpos,1);

%% — sens sıralamasına göre b oluştur —
num_images = scanX*scanY;
ms = zeros(num_detectors, num_images);
for idx = 1:num_images
    [x_img, y_img] = ind2sub([scanX, scanY], idx);
    I = image_grid{x_img, y_img};
    for d = 1:num_detectors
        xi = round(detpos(d,1));
        yi = round(detpos(d,2));
        if xi>=1 && xi<=size(I,2) && yi>=1 && yi<=size(I,1)
            ms(d,idx) = I(yi,xi);
        else
            ms(d,idx) = NaN;
        end
    end
end
fprintf('Yeni ms aralığı: min=%g, max=%g\n', min(ms(:)), max(ms(:)));

vx        = 25;                % sens fonksiyonundaki blok kenarı
scanX     = 50;                % tarama boyutu
scanY     = 50;
num_det   = size(detpos,1);    % dedektör sayısı
num_blocks= vx * vx;           % sens döngüsündeki toplam k (j,i kombinasyonu)


% orijinal ms: num_det x (scanX*scanY)
% şimdi b'yi sens sıralamasına göre boyutlandır
b2 = nan(num_blocks * num_det, 1);

k = 0;
for j = 1:vx                % sens fonksiyonundaki 'j' döngüsü
  for i = 1:vx              % sens fonksiyonundaki 'i' döngüsü
    k = k + 1;              % blok indeksi

    % bu bloğa karşılık gelen frame numarası (ind2sub sıralamasına uygun)
    frame_idx = i + (j-1)*scanX;  

    for d = 1:num_det
      % ms(d, frame_idx) zaten o detektörün o frame'deki okumaları
      row      = (d-1)*num_blocks + k;
      b2(row) = ms(d, frame_idx);
    end
  end
end

% Sonuç: A = sens(jac) ile tamamen örtüşen sıralamada b:
b = b2;
return

%%
%% Görselleştirme 1: Seçilen dedektörün konumu (overlay)
disp('Görselleştirme 1: Seçilen dedektörün konumu');
detector_idx = input(sprintf('1–%d arasında dedektör indeksi seçin: ', num_detectors));

bg_frame = 1;  % arka plan için frame
[ix, iy] = ind2sub([scanX, scanY], bg_frame);
Iback    = image_grid{ix, iy};

figure; imshow(Iback, []); hold on; axis equal off;
theta = linspace(0,2*pi,200);
for d = 1:num_detectors
    x0 = detpos(d,1);  y0 = detpos(d,2);
    plot(x0, y0, 'o', 'MarkerEdgeColor',[0.7 0.9 1], 'MarkerSize',8, 'LineWidth',1);
    xc = x0 + detector_radius*cos(theta);
    yc = y0 + detector_radius*sin(theta);
    plot(xc, yc, '--', 'Color',[0.7 0.9 1], 'LineWidth',1);
end
plot(source_pos(1), source_pos(2), 'rs', 'MarkerSize',12, 'LineWidth',2);
viscircles(source_pos, detector_radius, 'Color','r','LineWidth',1.5);

x_sel = detpos(detector_idx,1);
y_sel = detpos(detector_idx,2);
plot(x_sel, y_sel, 'ro', 'MarkerFaceColor','r', 'MarkerSize',10, 'LineWidth',2);
text(x_sel, y_sel, sprintf('%d', detector_idx), 'Color','w','FontSize',10,'FontWeight','bold', ...
     'HorizontalAlignment','center','VerticalAlignment','middle');
title(sprintf('Dedektör %d Konumu (Image %d)', detector_idx, bg_frame));
hold off;

%% Görselleştirme 2: Seçilen dedektörün zaman serisi
figure;
plot(1:num_images, ms(detector_idx,:), '-o', 'LineWidth',1.5, 'MarkerSize',6);
xlabel('Image İndisi'); ylabel('Yoğunluk');
title(sprintf('Dedektör %d – Sinyal Serisi', detector_idx));
grid on;

%% Görselleştirme 3: Bir dedektör için 2D frame heatmap
disp('Görselleştirme 3: Bir dedektör frame 2D olarak göster');
detector_idx_2 = input(sprintf('1–%d arasında dedektör indeksi seçin: ', num_detectors));

z = ms(detector_idx_2, :);                 % 1) zaman serisi
Z = reshape(z, scanX, scanY)';             % 2) 2D ızgara (scanX satır × scanY sütun) → transpose
figure;
imagesc(Z, [0 700]); axis equal tight;     % 700 istersen 4095 yap
colormap hot; colorbar;
title(sprintf('Dedektör %d – Dedektör Frame Heatmap', detector_idx_2));
xlabel('Scan Y indeksi'); ylabel('Scan X indeksi');

%% Görselleştirme 4: Belirli bir frame için dedektör ızgarası ısı haritası
disp('Görselleştirme 4: Image Heat Map');
frame_idx = input(sprintf('1–%d arasında image indeksi seçin: ', num_images));
ints      = ms(:, frame_idx);

intGrid = nan(detector_cols, detector_rows);  % 7x7 grid, merkez NaN kalabilir
dx     = (detpos(:,1) - source_pos(1)) / detector_spacing;
dy     = (detpos(:,2) - source_pos(2)) / detector_spacing;
rowIdx = round(dy + (detector_cols+1)/2);
colIdx = round(dx + (detector_rows+1)/2);

for k = 1:length(ints)
    if rowIdx(k)>=1 && rowIdx(k)<=detector_cols && colIdx(k)>=1 && colIdx(k)<=detector_rows
        intGrid(rowIdx(k), colIdx(k)) = ints(k);
    end
end

figure;
imagesc(intGrid, [0 4095]); axis equal tight off;
colormap hot; colorbar;
title(sprintf('Image %d – (0–4095 Sabit Ölçek)', frame_idx));
for i = 1:detector_cols
    for j = 1:detector_rows
        v = intGrid(i,j);
        if ~isnan(v)
            text(j, i, sprintf('%.0f', v), 'HorizontalAlignment','center', ...
                 'VerticalAlignment','middle','Color','w','FontWeight','bold');
        end
    end
end

%% Görselleştirme 5: Arkaplan üzerine tüm dedektörler (overlay)


disp('Görselleştirme 5: Arkaplan üzerine overlay');
bg_frame = 60;  % background için frame
[ix, iy] = ind2sub([scanX, scanY], bg_frame);
Iback    = image_grid{ix, iy};

figure; imshow(Iback, []); hold on; axis equal off;
theta = linspace(0,2*pi,200);
for d = 1:num_detectors
    x0 = detpos(d,1); y0 = detpos(d,2);
    plot(x0, y0, 'bo', 'MarkerSize',10, 'LineWidth',2);
    text(x0, y0, sprintf('%d', d), 'Color','y','FontSize',10,'FontWeight','bold', ...
         'HorizontalAlignment','center','VerticalAlignment','middle');
    xc = x0 + detector_radius*cos(theta);
    yc = y0 + detector_radius*sin(theta);
    plot(xc, yc, 'b--', 'LineWidth',1.5);
end
plot(source_pos(1), source_pos(2), 'rs', 'MarkerSize',20, 'LineWidth',3);
viscircles(source_pos, detector_radius, 'Color','r','LineWidth',2);
title('Arkaplan – Dedektörler & Kaynak');
hold off;

%% Görselleştirme 6: Ortalama yoğunluk ısı haritası (7x7)
disp('Görselleştirme 6: Ortalama yoğunluk haritası');
avgVals = mean(ms, 2);

dx     = (detpos(:,1) - source_pos(1)) / detector_spacing;
dy     = (detpos(:,2) - source_pos(2)) / detector_spacing;
rowIdx = round(dy + (detector_cols+1)/2);
colIdx = round(dx + (detector_rows+1)/2);

avgGrid = nan(detector_cols, detector_rows);
for k = 1:numel(avgVals)
    r = rowIdx(k); c = colIdx(k);
    if r>=1 && r<=detector_cols && c>=1 && c<=detector_rows
        avgGrid(r, c) = avgVals(k);
    end
end

figure;
imagesc(avgGrid); colormap hot; colorbar;
caxis([0 4095]); axis equal tight off;
title('Ortalama Yoğunluk – Dedektör Izgarası (0–4095 Sabit Ölçek)');
for i = 1:detector_cols
    for j = 1:detector_rows
        v = avgGrid(i,j);
        if ~isnan(v)
            text(j, i, sprintf('%.1f', v), 'HorizontalAlignment','center', ...
                 'VerticalAlignment','middle','Color','w','FontWeight','bold');
        end
    end
end

%% Ek: Seçilen dedektör için 2D frame (0–4095 ölçek)
z = ms(detector_idx, :);
Z = reshape(z, scanY, scanX)';    % (scanY x scanX) sonra transpoze
figure;
imagesc(Z, [0 4095]); axis equal tight off;
colormap hot; colorbar;
title(sprintf('Dedektör %d – Dedektör Frame Heatmap', detector_idx));
xlabel('Scan Y indeksi'); ylabel('Scan X indeksi');

%% Görselleştirme 7: Tüm dedektör frame heatmap’leri (tıkla aç/kapat)
n      = num_detectors;
nCols  = ceil(sqrt(n));
nRows  = ceil(n/nCols);

% --- GLOBAL OTOMATİK SKALA (NaN hariç)
vals = ms(:);
vals = vals(~isnan(vals));
if isempty(vals)
    minV = 0; maxV = 1;
else
    % Basit min/max:
    minV = min(vals);  maxV = max(vals);
    % (İstersen outlier kırpma)
    % minV = prctile(vals,1); maxV = prctile(vals,99);
    if ~(isfinite(minV) && isfinite(maxV)) || maxV <= minV
        minV = 0; maxV = 1;
    end
end

fig = figure('Name','Tüm Dedektör Frame Heatmap','NumberTitle','off');  
tl  = tiledlayout(nRows, nCols, 'Padding','none', 'TileSpacing','none');
colormap(hot);

for d = 1:n
Z   = reshape(ms(d,:), scanX, scanY)';      
hIm = imagesc(ax, Z, [globalMin, globalMax]);
axis(ax,'image'); axis(ax,'off');           % off kullanmaya devam

ringIdx  = max(abs(r - r0), abs(c - c0));
frameCol = ringColors(mod(ringIdx, size(ringColors,1)) + 1, :);

% Renkli çerçeve (normalized birimlerde)
rectangle(ax,'Position',[0 0 1 1], 'Units','normalized', ...
          'EdgeColor',frameCol, 'LineWidth',frameLW, ...
          'FaceColor','none', 'Clipping','on');

% İndeks etiketi
text(ax, 0.02, 0.98, sprintf('%d', d), 'Units','normalized', ...
     'HorizontalAlignment','left','VerticalAlignment','top', ...
     'FontSize',7, 'FontWeight','bold', 'Color',[0.95 0.95 0.95], ...
     'BackgroundColor',[0 0 0], 'Margin',1, 'Clipping','on');
end

% Ortak colorbar da global aralığa ayarlı
cb = colorbar('eastoutside');
cb.Limits = [minV, maxV];



%%
%% Görselleştirme 8 (büyütülmüş, sadece numara, ortak global skala + RENKLİ ÇERÇEVE)
n     = num_detectors;
nTile = n + 1;                          % merkezde boşluk
nc = ceil(sqrt(nTile)); if mod(nc,2)==0, nc = nc+1; end
nr = ceil(nTile/nc);   if mod(nr,2)==0, nr = nr+1; end
while nr*nc < nTile
    if nr <= nc, nr = nr+2; else, nc = nc+2; end
end
r0 = (nr+1)/2;  c0 = (nc+1)/2;

% GLOBAL skala
vals = ms(:); vals = vals(~isnan(vals));
if isempty(vals) || any(~isfinite([min(vals),max(vals)]))
    globalMin = 0; globalMax = 1;
else
    globalMin = min(vals); globalMax = max(vals);
    if globalMax <= globalMin, globalMin = 0; globalMax = 1; end
end

% Figür ve layout
fig = figure('Name','Tüm Dedektör Frame Heatmap','NumberTitle','off', ...
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

        % Merkez boşluk (SOURCE) — çerçeveli
        if r==r0 && c==c0
            axis(ax,'image');
            set(ax,'Box','on','LineWidth',2, ...
                'XTick',[],'YTick',[],'Layer','top','Color','none', ...
                'XColor',[0.6 0.6 0.6],'YColor',[0.6 0.6 0.6]);
            text(ax,0.5,0.5,'(Source)','Units','normalized', ...
                'HorizontalAlignment','center','VerticalAlignment','middle', ...
                'FontAngle','italic','Color',[0.6 0.6 0.6]);
            continue
        end

        % Dedektör kalmadıysa boş kutu — açık gri çerçeve
        if d>n
            axis(ax,'image');
            set(ax,'Box','on','LineWidth',1, ...
                'XTick',[],'YTick',[],'Layer','top','Color','none', ...
                'XColor',[0.85 0.85 0.85],'YColor',[0.85 0.85 0.85]);
            continue
        end

        % 2D frame
        Z   = reshape(ms(d,:), scanX, scanY)';  % (scanY x scanX)
        hIm = imagesc(ax, Z, [globalMin, globalMax]);
        axis(ax,'image');

        % Halka rengine göre çerçeve (AXES görünür, tikler kapalı)
        ringIdx  = max(abs(r - r0), abs(c - c0));
        frameCol = ringColors(mod(ringIdx, size(ringColors,1)) + 1, :);
        set(ax,'Box','on','LineWidth',frameLW, ...
            'XTick',[],'YTick',[],'Layer','top','Color','none', ...
            'XColor',frameCol,'YColor',frameCol);

        % Sol-üst köşeye küçük indeks (sadece sayı)
        text(ax, 0.02, 0.98, sprintf('%d', d), 'Units','normalized', ...
            'HorizontalAlignment','left','VerticalAlignment','top', ...
            'FontSize',7, 'FontWeight','bold', 'Color',[0.95 0.95 0.95], ...
            'BackgroundColor',[0 0 0], 'Margin',1, 'Clipping','on');

        % Büyütmede LOKAL skala kullanmak için veriyi sakla
        setappdata(hIm,'Zdata', Z);
        setappdata(hIm,'detIdx', d);
        hIm.ButtonDownFcn = @openCloseLocal;

        d = d + 1;
    end
end

% --- ORTAK (GLOBAL) COLORBAR: layout'un güneyine ---
cb = colorbar('Location','southoutside');
cb.Limits = [globalMin, globalMax];
cb.Label.String = 'Global ölçek';
cb.Layout.Tile = 'south';
%%
%% (ÖNCE) Source zaman serisi
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
            Zs  = reshape(s, scanX, scanY)';                   % (scanY x scanX)
            hIm = imagesc(ax, Zs, [globalMin, globalMax]);     % global skala = dedektörlere göre
            axis(ax,'image');
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
        Z   = reshape(ms(d,:), scanX, scanY)';                 % (scanY x scanX)
        hIm = imagesc(ax, Z, [globalMin, globalMax]);          % dedektör global skalası
        axis(ax,'image');

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
%%
%% --- SADECE SOURCE HEATMAP'İ ---
% GEREKENLER: source_pos, scanX, scanY, image_grid (scanX x scanY hücre, her biri 2D görüntü)

% Ayarlar
source_radius_px = 2;   % source etrafında ortalama alınacak disk yarıçapı (px)
use_percentile_scale = true;   % true → p1–p99; false → min–max

% ====== RECONS BÖLGESİ PARAMETRELERİ ======
vx = 25;           % sens() fonksiyonundaki pencere boyutu
recons_start_x = 1;  % Recons başlangıç X (tarama koordinatında)
recons_start_y = 1;  % Recons başlangıç Y (tarama koordinatında)
% ==========================================

% Disk maskesi (sabit, performans için bir kez üretelim)
[YY, XX] = meshgrid(-source_radius_px:source_radius_px, -source_radius_px:source_radius_px);
diskMask = (XX.^2 + YY.^2) <= source_radius_px^2;

% Çıkış matrisi (scanX x scanY → görüntüler ekranda doğru dursun diye transpose ile göstereceğiz)
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
    imagesc(Zsrc', [lo hi]);   % transpose: ekranda (x→y, y→x) doğal görünür
else
    imagesc(Zsrc');            % otomatik skala
end
axis image tight;
colormap hot; 
cb = colorbar('eastoutside'); 
cb.Label.String = 'Source yoğunluğu';

% ====== RECONS BÖLGESİNİ GÖSTEREN ÇERÇEVEYİ ÇİZ ======
hold on;
% Dikdörtgen: [x, y, width, height] - imagesc transpose yaptığı için x↔y değişir
rect_x = recons_start_y - 0.5;  % imagesc'de y ekseni → x
rect_y = recons_start_x - 0.5;  % imagesc'de x ekseni → y
rect_w = vx;
rect_h = vx;

rectangle('Position', [rect_x, rect_y, rect_w, rect_h], ...
          'EdgeColor', 'cyan', 'LineWidth', 2.5, 'LineStyle', '-');

% Köşelere etiket ekle
text(rect_x + rect_w/2, rect_y - 1.5, sprintf('Recons: %dx%d', vx, vx), ...
     'Color', 'cyan', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
     'FontSize', 10, 'BackgroundColor', [0 0 0 0.5]);

hold off;
title(sprintf('Source Heatmap (yarıçap = %d px) — Cyan = Recons Bölgesi', source_radius_px));

% --- Büyütmede LOKAL skala (Source dahil) ---
function openCloseLocal(src, ~)
    oldFig = getappdata(src,'FullFig');
    if ~isempty(oldFig) && isvalid(oldFig)
        close(oldFig); rmappdata(src,'FullFig'); return;
    end
    Z   = getappdata(src,'Zdata');
    idx = getappdata(src,'detIdx');   % sayı veya 'Source'

    zVals = Z(:); zVals = zVals(~isnan(zVals));
    if isempty(zVals) || any(~isfinite([min(zVals),max(zVals)]))
        locMin = 0; locMax = 1;
    else
        locMin = min(zVals); locMax = max(zVals);
        if locMax <= locMin, locMin = 0; locMax = 1; end
    end

    if isnumeric(idx), ttl = sprintf('%d', idx); else, ttl = char(idx); end
    hF = figure('Name', sprintf('%s – Büyütülmüş (Lokal)', ttl), ...
                'NumberTitle','off', 'Color','w');
    h2 = imagesc(Z, [locMin, locMax]); axis image off; colormap(hot); colorbar;
    title(ttl, 'FontWeight','normal');
    h2.ButtonDownFcn = @(~,~) close(hF);
    setappdata(src,'FullFig', hF);
end

% --- Büyütmede LOKAL skala ---
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

    hF = figure('Name', sprintf('Dedektör %d – Büyütülmüş (Lokal)', idx), ...
                'NumberTitle','off', 'Color','w');
    h2 = imagesc(Z, [locMin, locMax]); axis image off; colormap(hot); colorbar;
    title(sprintf('%d', idx), 'FontWeight','normal');
    h2.ButtonDownFcn = @(~,~) close(hF);
    setappdata(src,'FullFig', hF);
end
