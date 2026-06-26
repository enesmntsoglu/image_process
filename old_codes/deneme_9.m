%% figure; imshow(Iback, []); otomatikleri sonra kapat ,,, dedektörleri eski halie getir,, radiustan pixele çevir, cos formülünü değiştir

%% Tam MATLAB Script: 12-bit Görüntü Okuma, Dedektör Yoğunlukları ve Görselleştirme
%clc; clear; close all;

%% Adım 1: Temel Parametreler
disp('Adım 1: Parametreler yükleniyor...');
source_pos      = [231, 339];   % Kaynak (x,y)
scanX           = 50;           % Tarama noktaları X yönü
scanY           = 50;           % Tarama noktaları Y yönü
%% Adım 2: Dedektör Grid Parametreleri
disp('Adım 2: Dedektör grid parametreleri alınıyor...');
detector_rows    = 11;
detector_cols    = 11;
detector_spacing = 10;
detector_radius  = 2;

%% Adım 3: Görüntüleri Oku (12-bit ham veri olarak)
disp('Adım 3: Görüntü dosyaları yükleniyor...');

image_folder = "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\24_09_25_\1_0_deep\cell\Scan_1_24_09_25_12_47_16";
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

%% Adım 5: ms Matrisi Oluştur
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

% —————— EK: Tüm framelerden ölçüm vektörü b oluştur ——————
b = reshape(ms, [], 1);    % [num_detectors*num_images × 1] vektör
return

%%
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
    
    hImg = imagesc(ax, Z, [0 2000]);
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



%%
%% Görselleştirme 3: Tüm dedektör frame heatmap’leri (her biri kendi scale ile)
n      = num_detectors;
nCols  = ceil(sqrt(n));
nRows  = ceil(n/nCols);

fig = figure('Name','Tüm Dedektör Frame Heatmap','NumberTitle','off');  
tl  = tiledlayout(nRows, nCols, ...
      'Padding','none', ...      % kenar boşlukları yok
      'TileSpacing','none');     % subplot arası boşluk yok
colormap(hot);

for d = 1:n
    ax = nexttile;
    Z  = reshape(ms(d,:), scanX, scanY)';    % 2D frame
    
    % Her dedektör için kendi min-max scale
    hImg = imagesc(ax, Z);
    axis(ax,'equal','off');
    title(ax, sprintf('Detektör %d', d), 'FontSize', 8);
    caxis(ax, [min(Z(:)) max(Z(:))]);

    % Veriyi ve indeksi sakla
    setappdata(hImg, 'Zdata',   Z);
    setappdata(hImg, 'detIdx',  d);

    % Tıklama callback
    hImg.ButtonDownFcn = @openCloseCallback;
end
%% FUNCT


% --- Local function: tıklayınca aç / tekrar tıklayınca kapat ---
function openCloseCallback(src, ~)
    oldFig = getappdata(src,'FullFig');
    if ~isempty(oldFig) && isvalid(oldFig)
        close(oldFig);
        rmappdata(src,'FullFig');
        return;
    end
    
    % Yeni pencere
    Z   = getappdata(src,'Zdata');
    idx = getappdata(src,'detIdx');
    hF  = figure('Name', sprintf('Detektör %d – Büyütülmüş', idx), ...
                 'NumberTitle','off');
    
    h2  = imagesc(Z);                 % sabit limit yok
    axis equal off;
    colormap(hot);
    colorbar;
    caxis([min(Z(:)) max(Z(:))]);     % otomatik kendi scale
    title(sprintf('Detektör %d', idx));
    
    % Bu pencereyi tıklayınca kapat
    h2.ButtonDownFcn = @(~,~) close(hF);
    
    setappdata(src,'FullFig', hF);
end






