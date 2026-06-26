

% Girdi Klasörünü Tanımla
image_folder = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\deneme_1';
grid_size = [11, 11]; % Dedektörlerin grid boyutu
detector_frame_size = [10, 10]; % Dedektör başına düşen frame boyutu (örneğin: 10x10 piksel)

% `b` vektörünü oluştur (her dedektör pozisyonu için bir yoğunluk değeri)
num_positions = grid_size(1) * grid_size(2);
b = zeros(num_positions, 1);

% Görüntüleri yükleyip `b` matrisini oluştur
for i = 1:num_positions
    try
        % Görüntüyü yükle
        filename = fullfile(image_folder, sprintf('pos_%dx%d.png', mod(i-1, grid_size(1)) + 1, floor((i-1) / grid_size(1)) + 1));
        img = imread(filename);
        
        % Eğer görüntü renkli ise gri tonlamaya çevir
        if size(img, 3) == 3
            img = rgb2gray(img);
        end
        
        % Normalize et
        img_normalized = double(img) / 255;
        
        % Dedektör frame tekniği: dedektör pozisyonunu belirle
        [det_x, det_y] = ind2sub(grid_size, i); % Dedektör x, y pozisyonlarını bul
        x_start = (det_x - 1) * detector_frame_size(1) + 1;
        y_start = (det_y - 1) * detector_frame_size(2) + 1;
        
        % Frame alanını kontrol et, sınırlardan çıkmamalı
        x_end = min(x_start + detector_frame_size(1) - 1, size(img, 1));
        y_end = min(y_start + detector_frame_size(2) - 1, size(img, 2));
        
        % Dedektör frame alanındaki yoğunlukları topla
        detector_frame = img_normalized(x_start:x_end, y_start:y_end);
        b(i) = sum(detector_frame(:)); % Toplam yoğunluğu `b` matrisine ekle
        
        % Her adımı ekrana yazdır
        fprintf('Dedektör %d (%d, %d): Toplam yoğunluk = %f\n', i, det_x, det_y, b(i));
        
    catch ME
        warning("Görüntü işlenirken hata oluştu: %s", ME.message);
        b(i) = NaN; % Hata durumunda `NaN` değeri ata
    end
end

% `b` matrisini kaydet
save('b_matrix_with_detector_frame.mat', 'b');
fprintf('Dedektör frame tekniği ile b matrisi başarıyla oluşturuldu ve kaydedildi.\n');
