% Çalışma alanını temizle
clear;
clc;

% Grid boyutları
grid_size = [10, 10]; % X ve Y çekim sayısı (örnek: 10x10 grid)

% Mevcut ve çıkış klasörleri
inputFolder = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Final_Work_Space\Finalin_Finali\Images\11_12_24x2'; % Cihazın verdiği görüntülerin olduğu klasör
outputFolder = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Final_Work_Space\Finalin_Finali\Images\11_12_24x2\rename'; % Yeniden isimlendirilen görüntülerin kaydedileceği klasör

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Mevcut dosyaları yükle
image_files = dir(fullfile(inputFolder, 'pos_*.png'));
num_images = length(image_files);

% Kontrol: Grid boyutuna göre görüntü sayısı doğru mu?
expected_images = grid_size(1) * grid_size(2);
if num_images ~= expected_images
    error(['Beklenen görüntü sayısı (', num2str(expected_images), ...
           ') ile klasördeki görüntü sayısı (', num2str(num_images), ') uyuşmuyor!']);
end

% Cihaz tarama sırasına göre numaraları belirleme
snake_order = zeros(grid_size); % Yılan sıralamasını tutacak matris
counter = 1;
for col = 1:grid_size(2)
    if mod(col, 2) == 1
        % Tek sütunlarda normal sıra
        snake_order(:, col) = counter:counter+grid_size(1)-1;
    else
        % Çift sütunlarda ters sıra
        snake_order(:, col) = counter+grid_size(1)-1:-1:counter;
    end
    counter = counter + grid_size(1);
end

% Eski düzene uygun sıra
correct_order = reshape(1:expected_images, grid_size(1), grid_size(2));

% Yeniden sıralama ve kaydetme
for row = 1:grid_size(1)
    for col = 1:grid_size(2)
        try
            % Mevcut sıralamadan görüntüyü bulun
            snake_idx = snake_order(row, col); % Yılan hareketindeki sıra
            current_image_name = sprintf('pos_%dx%d.png', ceil(snake_idx / grid_size(2)), mod(snake_idx - 1, grid_size(2)) + 1);
            current_image_path = fullfile(inputFolder, current_image_name);

            % Görüntüyü yükleyin
            img = imread(current_image_path);

            % Eski sıraya uygun dosya adı oluştur
            correct_idx = correct_order(row, col);
            new_image_name = sprintf('pos_%dx%d.png', row, col); % Eski düzene uygun isim
            save_path = fullfile(outputFolder, new_image_name);

            % Yeniden isimlendirilen görüntüyü kaydet
            imwrite(img, save_path);
            fprintf('Görüntü yeniden isimlendirildi ve kaydedildi: %s\n', save_path);

        catch ME
            warning(['Görüntü işlenirken hata oluştu: ', ME.message]);
        end
    end
end

disp('Görüntüler başarıyla yeniden isimlendirildi ve eski düzene göre kaydedildi.');
