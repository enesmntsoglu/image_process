
%% TEK TEK DEDEKTÖR
detectors = size(ms, 1); 
scans = size(ms, 2); 

ms_3d = reshape(ms, [sqrt(detectors), sqrt(detectors), scans]);

for idx = 1:size(ms_3d, 3)
    figure;
    surf(ms_3d(:, :, idx), 'EdgeColor', 'none');
    title(sprintf('Hassasiyet Matrisi Görselleştirme (Tarama Noktası %d)', idx));
    xlabel('Dedektör X Ekseni');
    ylabel('Dedektör Y Ekseni');
    zlabel('Yoğunluk');
    colormap jet;
    colorbar;
    grid on;
end
%% TEK BİR İMAGE
detectors = size(ms, 1); 
scans = size(ms, 2); 
ms_3d = reshape(ms, [sqrt(detectors), sqrt(detectors), scans]);
total_intensity = sum(ms_3d, 3);

figure;
surf(total_intensity, 'EdgeColor', 'none');
title('Toplam Yoğunluk Haritası (Tüm Dedektörlerden)');
xlabel('Dedektör X Ekseni');
ylabel('Dedektör Y Ekseni');
zlabel('Toplam Yoğunluk');
colormap jet;
colorbar;
grid on;
%% İKİSİ BİR ARADA
% Hassasiyet matrisi boyutları
detectors = size(ms, 1); % Dedektör sayısı
scans = size(ms, 2); % Görüntü/tarama noktası sayısı

ms_3d = reshape(ms, [sqrt(detectors), sqrt(detectors), scans]);

for idx = 1:size(ms_3d, 3)
    figure;
    surf(ms_3d(:, :, idx), 'EdgeColor', 'none');
    title(sprintf('Hassasiyet Matrisi (Dedektör Noktası %d)', idx));
    xlabel('Dedektör X Ekseni');
    ylabel('Dedektör Y Ekseni');
    zlabel('Yoğunluk');
    colormap jet;
    colorbar;
    grid on;
end

total_intensity = sum(ms_3d, 3);

figure;
surf(total_intensity, 'EdgeColor', 'none');
title('Toplam Yoğunluk Haritası (Tüm Dedektörlerden)');
xlabel('Dedektör X Ekseni');
ylabel('Dedektör Y Ekseni');
zlabel('Toplam Yoğunluk');
colormap jet;
colorbar;
grid on;

%%
% Görselleştirme
figure;
hold on;

% Görüntü sınırlarını çiz
rectangle('Position', [0, 0, image_width, image_height], ...
    'EdgeColor', 'k', 'LineWidth', 1.5, 'LineStyle', '--');
legend_labels = {'Görüntü Sınırları'};

% Seçilen grid sınırlarını çiz
x_start = max(1, source_pos(2) - selected_pixel_size(1) / 2); % Sütun
y_start = max(1, source_pos(1) - selected_pixel_size(2) / 2); % Satır
x_end = min(image_width, source_pos(2) + selected_pixel_size(1) / 2); % Sütun
y_end = min(image_height, source_pos(1) + selected_pixel_size(2) / 2); % Satır
rectangle('Position', [x_start, y_start, x_end - x_start, y_end - y_start], ...
    'EdgeColor', 'b', 'LineWidth', 2);
legend_labels{end+1} = 'Seçilen Grid';

% Dedektörleri çiz
for i = 1:size(detector_positions, 1)
    det_x = detector_positions(i, 1);
    det_y = detector_positions(i, 2);
    if det_x >= x_start && det_x <= x_end && det_y >= y_start && det_y <= y_end
        plot(det_x, det_y, 'go', 'MarkerFaceColor', 'g', 'MarkerSize', 8); % Grid içinde: Yeşil
        legend_labels{end+1} = 'Dedektör (Grid İçinde)';
    else
        plot(det_x, det_y, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 8); % Grid dışında: Kırmızı
        legend_labels{end+1} = 'Dedektör (Grid Dışında)';
    end
end

% Ayarları yap
title('Görüntü, Seçilen Grid ve Dedektör Pozisyonları');
xlabel('X Pozisyonu (piksel)');
ylabel('Y Pozisyonu (piksel)');
axis equal;
grid on;

% Tekrarlayan etiketleri kaldır
[unique_labels, ~, idx] = unique(legend_labels);
colors = {'k', 'b', 'r', 'g'};
h = arrayfun(@(i) plot(nan, nan, 'o', 'MarkerEdgeColor', 'none', ...
    'MarkerFaceColor', colors{i}), 1:numel(unique_labels));
legend(h, unique_labels, 'Location', 'best');
hold off;

%%
% Görüntüyü yükle
image_path = 'C:\TriggerCapturedImages\pos_1x1.png'; % Örnek görüntü yolu
img = imread(image_path);

if size(img, 3) == 3
    img = rgb2gray(img); % Gri tonlamaya çevir
end

% Görüntünün boyutlarını al
[image_height, image_width] = size(img);

% Seçilen piksel hacminin başlangıç ve bitiş noktalarını hesapla
crop_width = selected_pixel_size(1); % Seçilen grid genişliği
crop_height = selected_pixel_size(2); % Seçilen grid yüksekliği
x_start = round(source_pos(2) - crop_width / 2); % source_pos(2) = sütun
x_end = round(source_pos(2) + crop_width / 2 - 1);
y_start = round(source_pos(1) - crop_height / 2); % source_pos(1) = satır
y_end = round(source_pos(1) + crop_height / 2 - 1);

% Görüntü sınırlarını aşmaması için sınırlandır
x_start = max(1, x_start);
y_start = max(1, y_start);
x_end = min(image_width, x_end);
y_end = min(image_height, y_end);

% Dedektör gridini oluştur (kırpılmış hacmin içinde)
cropped_height = y_end - y_start + 1;
cropped_width = x_end - x_start + 1;

grid_x = linspace(1, cropped_width, detector_rows); % Dedektörlerin X pozisyonları
grid_y = linspace(1, cropped_height, detector_cols); % Dedektörlerin Y pozisyonları

[detector_x, detector_y] = meshgrid(grid_x + x_start - 1, grid_y + y_start - 1); % Dedektör merkezleri

% Görselleştirme
figure;
imshow(img, []);
hold on;

% Seçilen piksel hacmini çizin
rectangle('Position', [x_start, y_start, crop_width, crop_height], ...
          'EdgeColor', 'red', 'LineWidth', 2, 'LineStyle', '--');

% Dedektör pozisyonlarını çizin
plot(detector_x(:), detector_y(:), 'bo', 'MarkerSize', 8, 'LineWidth', 2);

% Etiketleme
for i = 1:numel(detector_x)
    text(detector_x(i), detector_y(i), sprintf('D%d', i), ...
         'Color', 'blue', 'FontSize', 10, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
end

title('Seçilen Piksel Hacmi ve Dedektör Pozisyonları');
xlabel('X (piksel)');
ylabel('Y (piksel)');
hold off;

%%
% Görüntüyü oluştur veya yükle
image_width = 180; % Örnek genişlik
image_height = 134; % Örnek yükseklik
img = ones(image_height, image_width); % Beyaz bir arka plan görüntüsü

% Görselleştirme
figure;
imshow(img, []);
hold on;

% Dedektör pozisyonlarını çiz
plot(detector_positions(:, 1), detector_positions(:, 2), 'ro', 'MarkerSize', 10, 'LineWidth', 2);

% Dedektör etiketleri
for i = 1:size(detector_positions, 1)
    text(detector_positions(i, 1), detector_positions(i, 2), sprintf('D%d', i), ...
         'Color', 'blue', 'FontSize', 10, 'HorizontalAlignment', 'center');
end

title('Dedektör Pozisyonları');
xlabel('X (piksel)');
ylabel('Y (piksel)');
hold off;
%%
% Selected pixel size'nin köşe koordinatlarını hesapla ve yazdır
disp('Selected Pixel Size Köşe Koordinatları:');
crop_width = selected_pixel_size(1);  % Seçilen grid genişliği
crop_height = selected_pixel_size(2); % Seçilen grid yüksekliği

% Grid başlangıç ve bitiş noktalarını hesapla
x_start = source_pos(2) - crop_width / 2; % Sol sütun
x_end = source_pos(2) + crop_width / 2 - 1; % Sağ sütun
y_start = source_pos(1) - crop_height / 2; % Üst satır3
y_end = source_pos(1) + crop_height / 2 - 1; % Alt satır

% Koordinatları yazdır
fprintf('Sol Üst Köşe: (%.2f, %.2f)\n', y_start, x_start);
fprintf('Sağ Üst Köşe: (%.2f, %.2f)\n', y_start, x_end);
fprintf('Sol Alt Köşe: (%.2f, %.2f)\n', y_end, x_start);
fprintf('Sağ Alt Köşe: (%.2f, %.2f)\n', y_end, x_end);

%%
% Hassasiyet matrisi boyutları
detectors = size(ms, 1); % Dedektör sayısı
scans = size(ms, 2); % Görüntü/tarama noktası sayısı

% Hassasiyet matrisini 3D olarak yeniden şekillendirme
if mod(sqrt(detectors), 1) == 0 % Dedektör sayısının karekökü tam sayı mı?
    ms_3d = reshape(ms, [sqrt(detectors), sqrt(detectors), scans]);
else
    error('Dedektör sayısı kare matris oluşturacak bir değer olmalıdır.');
end

% Her dedektör noktası için hassasiyet matrisi görselleştirme
for idx = 1:size(ms_3d, 3)
    figure;
    surf(ms_3d(:, :, idx), 'EdgeColor', 'none');
    title(sprintf('Hassasiyet Matrisi (Dedektör Noktası %d)', idx));
    xlabel('Dedektör X Ekseni');
    ylabel('Dedektör Y Ekseni');
    zlabel('Yoğunluk');
    colormap jet;
    colorbar;
    grid on;
end

% Tüm dedektörlerin toplam yoğunluk haritası
total_intensity = sum(ms_3d, 3);

figure;
surf(total_intensity, 'EdgeColor', 'none');
title('Toplam Yoğunluk Haritası (Tüm Dedektörlerden)');
xlabel('Dedektör X Ekseni');
ylabel('Dedektör Y Ekseni');
zlabel('Toplam Yoğunluk');
colormap jet;
colorbar;
grid on;
%%
%% Görselleştirme
% Daha önce hesaplanmış verileri kullanarak görselleştirme yapılıyor.

% Görüntüyü yükle (mevcut görüntü dosyası yolunuza göre ayarlayın)
image_path = fullfile(image_folder, 'pos_1x1.png'); % Örnek görüntü yolu
img = imread(image_path);

% Gri tonlama kontrolü
if size(img, 3) == 3
    img = rgb2gray(img); % Gri tonlamaya çevir
end

% Görselleştirme
figure;
imshow(img, []); % Görüntüyü göster
hold on;

% Seçilen piksel hacmini çizin (hesaplanmış x_start, y_start, crop_width, crop_height değerleri kullanılıyor)
rectangle('Position', [source_pos(2) - selected_pixel_size(2) / 2, source_pos(1) - selected_pixel_size(1) / 2, selected_pixel_size(2), selected_pixel_size(1)], ...
          'EdgeColor', 'red', 'LineWidth', 2, 'LineStyle', '--');

% Dedektör pozisyonlarını çizin (hesaplanmış detector_x ve detector_y değerleri kullanılıyor)
plot(detector_x(:), detector_y(:), 'bo', 'MarkerSize', 8, 'LineWidth', 2);

% Dedektör pozisyonlarına etiket ekleyin
for i = 1:numel(detector_x)
    text(detector_x(i), detector_y(i), sprintf('D%d', i), ...
         'Color', 'blue', 'FontSize', 10, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
end

% Başlık ve eksen etiketleri
title('Seçilen Piksel Hacmi ve Dedektör Pozisyonları');
xlabel('X (piksel)');
ylabel('Y (piksel)');
hold off;
