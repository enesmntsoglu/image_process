% Görüntülerin bulunduğu klasör
image_folder = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Final_Work_Space\Finalin_Finali\Images\Error'; % Görüntülerin olduğu klasör
image_files = dir(fullfile(image_folder, '*.png'));
num_images = length(image_files);

% Motor ve kamera parametreleri
motor_step_size = 100; % Motor adım boyu (mikron)
pixel_size_x = 6.9; % Piksel boyutu X (mikron)
pixel_size_y = 6.9; % Piksel boyutu Y (mikron)
resolution_x = 540; % Kamera çözünürlüğü (X ekseni, piksel)
resolution_y = 720; % Kamera çözünürlüğü (Y ekseni, piksel)

% Grid parametreleri
grid_size = [25, 1]; % Grid boyutları
step_size_x = motor_step_size / pixel_size_x; % X yönündeki teorik adım büyüklüğü (piksel)
step_size_y = motor_step_size / pixel_size_y; % Y yönündeki teorik adım büyüklüğü (piksel)
theoretical_positions = zeros(num_images, 2);
counter = 1;

% Teorik pozisyonları hesapla
for y = 1:grid_size(2)
    for x = 1:grid_size(1)
        theoretical_positions(counter, :) = [(x-1)*step_size_x, (y-1)*step_size_y];
        counter = counter + 1;
    end
end

% Gerçek pozisyonları tespit et (örnek: merkez tespiti)
real_positions = zeros(num_images, 2);
for i = 1:num_images
    img = imread(fullfile(image_folder, image_files(i).name));
    
    % Görüntü işleme: Görüntüde merkez veya özellik tespiti
    if size(img, 3) == 3 % Görüntü renkli mi?
        img = rgb2gray(img); % Gri tonlamaya çevir
    end
    
    binary_img = imbinarize(img); % İkili görüntüye çevir
    stats = regionprops(binary_img, 'Centroid'); % Merkez tespiti
    if ~isempty(stats)
        real_positions(i, :) = stats(1).Centroid; % İlk bölgenin merkezi
    else
        warning(['Görüntüde özellik bulunamadı: ', image_files(i).name]);
        real_positions(i, :) = [NaN, NaN];
    end
end

% Hata hesaplama
errors = real_positions - theoretical_positions;
distance_errors = sqrt(errors(:, 1).^2 + errors(:, 2).^2); % Öklid uzaklığı
distance_errors_micron = distance_errors * pixel_size_x; % Mikron cinsine dönüştür

% Hata istatistikleri
mean_error = mean(distance_errors_micron, 'omitnan');
std_error = std(distance_errors_micron, 'omitnan');

% Sonuçları göster
disp('Step Motor Hata Analizi:');
disp(['Ortalama Hata (mikron): ', num2str(mean_error)]);
disp(['Standart Sapma (mikron): ', num2str(std_error)]);
