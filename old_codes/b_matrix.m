% Clear workspace


% Girdi Klasörünü Tanımla
image_folder = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\deneme_1'; 
grid_size = [11, 11]; % Görüntülerin grid boyutu

% `b` vektörünü oluştur (her pozisyon için bir yoğunluk değeri)
num_positions = grid_size(1) * grid_size(2);
b = zeros(num_positions, 1);

% Görüntüleri yükleyip `b` matrisini oluştur
for i = 1:num_positions
    try
        % Görüntüyü yükle
        filename = fullfile(image_folder, sprintf('pos_%dx%d.png', mod(i-1, grid_size(1)) + 1, floor((i-1) / grid_size(1)) + 1));
        img = imread(filename);
        
        % Normalize et ve yoğunluğu hesapla
        img_normalized = double(img) / 255;
        b(i) = sum(img_normalized(:));
    catch ME
        warning("Görüntü işlenirken hata oluştu: %s", ME.message);
        b(i) = NaN; % Hata durumunda `NaN` değeri ata
    end
end

% `b` matrisini kaydet
save('b_matrix.mat', 'b');
fprintf('b matrisi başarıyla oluşturuldu ve kaydedildi.\n');
