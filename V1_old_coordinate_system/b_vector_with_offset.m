%% Adım 1: Temel Parametreler
disp('Adım 1: Parametreler yükleniyor...');
source_pos      = [332, 268];   % Kaynak (x,y)     [218, 367]-> opak1
scanX           = 50;           % Tarama noktaları X yönü
scanY           = 50;           % Tarama noktaları Y yönü

%% Adım 2: Dedektör Grid Parametreleri
disp('Adım 2: Dedektör grid parametreleri alınıyor...');
detector_rows    = 7;
detector_cols    = 7;
detector_spacing = 25; %13
detector_radius  = 7;

%% Adım 3: Görüntüleri Oku (12-bit ham veri olarak)
disp('Adım 3: Görüntü dosyaları yükleniyor...');

image_folder = "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\30_01_26\sw3\avrg_bg_cikarilmis\renamed_swapped";
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
disp('Adım 4: Dedektör pozisyonları hesaplanıyor...');
[GX, GY] = meshgrid( ...
    linspace(source_pos(1)-(detector_rows-1)/2*detector_spacing, source_pos(1)+(detector_rows-1)/2*detector_spacing, detector_rows), ...
    linspace(source_pos(2)-(detector_cols-1)/2*detector_spacing, source_pos(2)+(detector_cols-1)/2*detector_spacing, detector_cols) ...
);
all_pos   = [GX(:), GY(:)];
is_center = abs(all_pos(:,1)-source_pos(1))<eps & abs(all_pos(:,2)-source_pos(2))<eps;
detpos    = all_pos(~is_center, :);                                                                              % merkez hariç
num_detectors = size(detpos,1);

%% Adım 5: Dedektör serileri (ms) + Source serisi (ms_source)
disp('Adım 5: ms (dedektörler) ve ms_source (kaynak) hesaplanıyor...');
num_images = scanX*scanY;

ms         = nan(num_detectors, num_images);   % dedektörlere ait seri
ms_source  = nan(1, num_images);               % merkez (source) serisi

sx = round(source_pos(1));    % source x
sy = round(source_pos(2));    % source y

for idx = 1:num_images
    [x_img, y_img] = ind2sub([scanX, scanY], idx);
    I = image_grid{x_img, y_img};

    % Dedektör okumaları
    for d = 1:num_detectors
        xi = round(detpos(d,1));
        yi = round(detpos(d,2));
        if xi>=1 && xi<=size(I,2) && yi>=1 && yi<=size(I,1)
            ms(d,idx) = I(yi,xi);
        else
            ms(d,idx) = NaN;
        end
    end

    % Source (merkez piksel) okuması
    if sy>=1 && sy<=size(I,1) && sx>=1 && sx<=size(I,2)
        ms_source(idx) = I(sy, sx);
    else
        ms_source(idx) = NaN;
    end
end

fprintf('ms (dedektör) aralığı: min=%g, max=%g\n', min(ms(:)), max(ms(:)));
fprintf('ms_source (kaynak) aralığı: min=%g, max=%g\n', min(ms_source(:)), max(ms_source(:)));

% Kaynak için 2D heat map matrisi (görselleştirmeyi sonra yapacağız)
Z_source = reshape(ms_source, scanX, scanY)';   % (scanY x scanX)

%% Adım 6: sens sırasına göre b oluştur (Yalnızca dedektörler)
vx        = 25;                % A_matrix'teki vx ile aynı
recons_offset_x = 12;           % 0..(scanX-vx) araligi (scan ROI secimi)
recons_offset_y = 14;           % 0..(scanY-vx) araligi
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

% Not: Görselleştirmeyi daha sonra yapacağız.
return
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
            set(ax,'YDir','normal');
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
        set(ax,'YDir','normal');

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
vx = 25;                              % sens() fonksiyonundaki pencere boyutu
recons_start_x = recons_offset_x + 1; % Recons başlangıç X (tarama koordinatında)
recons_start_y = recons_offset_y + 1; % Recons başlangıç Y (tarama koordinatında)
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
    set(gca,'YDir','normal');
else
    imagesc(Zsrc');            % otomatik skala
    set(gca,'YDir','normal');
end
axis image tight;
colormap hot; 
cb = colorbar('eastoutside'); 
cb.Label.String = 'Source yoğunluğu';

% ====== RECONS BÖLGESİNİ GÖSTEREN ÇERÇEVEYİ ÇİZ ======
hold on;
% Dikdörtgen: [x, y, width, height] - Zsrc' sonrası eksenler (x=kolon, y=satır)
rect_x = recons_start_x - 0.5;
rect_y = recons_start_y - 0.5;
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
    set(gca,'YDir','normal');
    title(ttl, 'FontWeight','normal');
    h2.ButtonDownFcn = @(~,~) close(hF);
    setappdata(src,'FullFig', hF);
end
