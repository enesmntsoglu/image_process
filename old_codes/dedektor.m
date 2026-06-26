%% Dedektör Yoğunluk Gösterme
% Hassasiyet matrisi boyutları
detectors = size(ms, 1); % Dedektör sayısı
scans = size(ms, 2); % Görüntü/tarama noktası sayısı

% Dedektör grid boyutları
detector_grid_size = sqrt(detectors);

% Hassasiyet matrisini 3D olarak yeniden şekillendirme
if mod(detector_grid_size, 1) == 0 % Dedektör sayısının karekökü tam sayı mı?
    ms_3d = reshape(ms, [detector_grid_size, detector_grid_size, scans]);
else
    error('Dedektör sayısı kare matris oluşturacak bir değer olmalıdır.');
end
%%
% Her dedektör noktası için hassasiyet matrisi görselleştirme
for idx = 89:91%size(ms_3d, 3)
    figure;
    surf(ms_3d(:, :, idx), 'EdgeColor', 'none');
    title(sprintf('Hassasiyet Matrisi (Dedektör Noktası %d) - Dedektör Grid: %dx%d', idx, detector_grid_size, detector_grid_size));
    xlabel('Dedektör X Ekseni');
    ylabel('Dedektör Y Ekseni');
    zlabel('Yoğunluk');
    colormap jet;
    colorbar;
    grid on;
end

%% Tüm dedektörlerin toplam yoğunluk haritası

total_intensity = sum(ms_3d, 3);

figure;
surf(total_intensity, 'EdgeColor', 'none');
title(sprintf('Toplam Yoğunluk Haritası (Tüm Dedektörlerden) - Dedektör Grid: %dx%d', detector_grid_size, detector_grid_size));
xlabel('Dedektör X Ekseni');
ylabel('Dedektör Y Ekseni');
zlabel('Toplam Yoğunluk');
colormap jet;
colorbar;
grid on;


%% % Dedektör koordinatlarını ekrana yazdır

disp('Dedektör Koordinatları:');
for i = 1:size(detector_positions, 1)
    fprintf('Dedektör %d: (X: %.2f, Y: %.2f)\n', i, detector_positions(i, 1), detector_positions(i, 2));
end


%% Selecterd pixel size
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
%% B matrisini görselleştir
disp('B Matrisi:');
disp(b_matrix);

%% DEDEKTÖR LOKASYON
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

% Dedektör pozisyonlarını çizin (hesaplanmış detector_x ve detector_y değerleri kullanılıyor)
plot(detector_x(:), detector_y(:), 'bo', 'MarkerSize', 8, 'LineWidth', 2);

% Dedektör pozisyonlarına etiket ekleyin
for i = 1:numel(detector_x)
    text(detector_x(i), detector_y(i), sprintf('D%d', i), ...
         'Color', 'blue', 'FontSize', 10, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
end

% Başlık ve eksen etiketleri
title('Dedektör Pozisyonları');
xlabel('X (piksel)');
ylabel('Y (piksel)');
hold off;
%% dedektör görselleştirme koordinat
% Display the number of detectors generated
disp(['Number of detectors: ', num2str(size(detector_positions, 1))]);

% Plot detector positions
figure;
scatter(detector_positions(:, 1), detector_positions(:, 2), 'filled', 'b'); % Detectors in blue
hold on;
scatter(source_pos(1), source_pos(2), 'filled', 'r'); % Source in red
title('Detector and Source Positions');
xlabel('X Position');
ylabel('Y Position');
grid on;
legend('Detectors', 'Source', 'Location', 'best');

