%% --- Klasör Tanımlamaları ---
folder1 = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Analiz\24_04\sw_1\first_loop\sonuclar_average';
folder2 = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Analiz\24_04\sw_1\second_loop\sonuclar_average';

%% --- Parametreler ---
source_pos      = [290, 320];   % Kaynak (x,y)
scanX           = 51;           % Tarama X
scanY           = 51;           % Tarama Y

%% --- Dedektör Grid Parametreleri (aynı iki dataset için) ---
detector_rows    = input('Dedektör grid satır sayısı (örn: 11): ');
detector_cols    = input('Dedektör grid sütun sayısı (örn: 11): ');
detector_spacing = input('Dedektörler arası mesafe (pixel): ');
detector_radius  = input('Dedektör yarıçapı (örnek: 1): ');
if isempty(detector_radius), detector_radius = 0.5; end

%% --- Dataset’lerden ms1 ve ms2 hesapla ---
fprintf('Dataset 1 okuma... '); 
ms1 = build_ms_from_folder(folder1,scanX,scanY,source_pos,...
      detector_rows,detector_cols,detector_spacing); 
fprintf('tamam.\n');
fprintf('Dataset 2 okuma... '); 
ms2 = build_ms_from_folder(folder2,scanX,scanY,source_pos,...
      detector_rows,detector_cols,detector_spacing); 
fprintf('tamam.\n');

%% --- Karşılaştırmalı Heatmap ---
num_detectors = size(ms1,1);
d = input(sprintf('Karşılaştırmak istediğiniz dedektör indeksini girin (1–%d): ', num_detectors));

z1 = ms1(d,:);
z2 = ms2(d,:);
Z1 = reshape(z1, scanX, scanY);
Z2 = reshape(z2, scanX, scanY);

figure;
subplot(1,2,1);
imagesc(Z1,[0 4095]); axis equal tight off;
colormap hot; colorbar;
title(sprintf('Dataset1 – Det.%d Heatmap',d));

subplot(1,2,2);
imagesc(Z2,[0 4095]); axis equal tight off;
colormap hot; colorbar;
title(sprintf('Dataset2 – Det.%d Heatmap',d));

fprintf('ms1 range: [%g  %g]\n', min(z1), max(z1));
fprintf('ms2 range: [%g  %g]\n', min(z2), max(z2));

%% --- Overlay İçin image_grid & detpos Oluştur ---
% yalnızca folder1'i kullanıyoruz ki arkaplan resmi alalım
fprintf('Overlay için image_grid oluşturuluyor... ');
files = dir(fullfile(folder1,'pos_*.png'));
N = numel(files);
% 1) coords ve sıralama
coords = zeros(N,2);
for k=1:N
    tok = regexp(files(k).name,'pos_(\d+)x(\d+)\.png','tokens');
    coords(k,:) = [str2double(tok{1}{1}), str2double(tok{1}{2})];
end
[~,order] = sortrows(coords,[1 2]);  % önce X sonra Y
files  = files(order);
coords = coords(order,:);
% 2) image_grid doldur
image_grid = cell(scanX, scanY);
for k=1:N
    x = coords(k,1);  y = coords(k,2);
    A = imread(fullfile(folder1,files(k).name));
    if ndims(A)==3, A = rgb2gray(A); end
    info = imfinfo(fullfile(folder1,files(k).name));
    A16  = uint16(A);
    if info.BitDepth>12 && max(A16(:))>4095
        raw12 = bitshift(A16, -(info.BitDepth-12));
    else
        raw12 = A16;
    end
    image_grid{x,y} = double(raw12);
end
fprintf('tamam.\n');
% 3) detpos hesapla
[GX,GY] = meshgrid( ...
    linspace(source_pos(1)-(detector_rows-1)/2*detector_spacing, source_pos(1)+(detector_rows-1)/2*detector_spacing, detector_rows), ...
    linspace(source_pos(2)-(detector_cols-1)/2*detector_spacing, source_pos(2)+(detector_cols-1)/2*detector_spacing, detector_cols) ...
);
all_pos    = [GX(:), GY(:)];
is_center  = abs(all_pos(:,1)-source_pos(1))<eps & abs(all_pos(:,2)-source_pos(2))<eps;
detpos     = all_pos(~is_center, :);
num_detectors = size(detpos,1);

%% --- Görselleştirme 5: Arkaplan üzerine overlay ---
disp('Görselleştirme 5: Arkaplan üzerine overlay');
bg_frame = 1000;  
Iback = image_grid{ind2sub([scanX, scanY], bg_frame)};
figure; imshow(Iback, []); hold on; axis equal off;

theta = linspace(0,2*pi,200);
for d0 = 1:num_detectors
    x0 = detpos(d0,1);  
    y0 = detpos(d0,2);
    plot(x0, y0, 'bo', 'MarkerSize',10, 'LineWidth',2);
    text(x0, y0, sprintf('%d', d0), 'Color','y', 'FontSize',10, ...
         'HorizontalAlignment','center','VerticalAlignment','middle');
    xc = x0 + detector_radius*cos(theta);
    yc = y0 + detector_radius*sin(theta);
    plot(xc, yc, 'b--', 'LineWidth',1.5);
end

plot(source_pos(1), source_pos(2), 'rs', 'MarkerSize',14, 'LineWidth',3);
viscircles(source_pos, detector_radius, 'Color','r','LineWidth',2);
title('Arkaplan – Dedektörler & Kaynak');
hold off;

%% --- Fonksiyon: bir klasörü oku ve ms döndür ---
function ms = build_ms_from_folder(folder, scanX, scanY, source_pos, detector_rows, detector_cols, detector_spacing)
    files  = dir(fullfile(folder,'pos_*.png'));
    N      = numel(files);
    coords = zeros(N,2);
    for k=1:N
      tok = regexp(files(k).name,'pos_(\d+)x(\d+)\.png','tokens');
      coords(k,:) = [str2double(tok{1}{1}), str2double(tok{1}{2})];
    end
    [~,order] = sortrows(coords,[1 2]);  % önce X sonra Y
    files  = files(order);
    coords = coords(order,:);
    image_grid = cell(scanX, scanY);
    for k=1:N
      x=coords(k,1); y=coords(k,2);
      A = imread(fullfile(folder,files(k).name));
      if ndims(A)==3, A = rgb2gray(A); end
      info = imfinfo(fullfile(folder,files(k).name));
      A16  = uint16(A);
      if info.BitDepth>12 && max(A16(:))>4095
          raw12 = bitshift(A16, -(info.BitDepth-12));
      else
          raw12 = A16;
      end
      image_grid{x,y} = double(raw12);
    end
    [GX,GY] = meshgrid( ...
      linspace(source_pos(1)-(detector_rows-1)/2*detector_spacing, source_pos(1)+(detector_rows-1)/2*detector_spacing, detector_rows), ...
      linspace(source_pos(2)-(detector_cols-1)/2*detector_spacing, source_pos(2)+(detector_cols-1)/2*detector_spacing, detector_cols) ...
    );
    all_pos   = [GX(:), GY(:)];
    is_center = abs(all_pos(:,1)-source_pos(1))<eps & abs(all_pos(:,2)-source_pos(2))<eps;
    detpos    = all_pos(~is_center,:);
    num_detectors = size(detpos,1);
    num_images = scanX*scanY;
    ms = nan(num_detectors, num_images);
    for idx = 1:num_images
      [x_img,y_img] = ind2sub([scanX,scanY],idx);
      I = image_grid{x_img,y_img};
      for d=1:num_detectors
        xi = round(detpos(d,1));  yi = round(detpos(d,2));
        if xi>=1 && xi<=size(I,2) && yi>=1 && yi<=size(I,1)
          ms(d,idx) = I(yi,xi);
        end
      end
    end
end
