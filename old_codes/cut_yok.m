% Clear previous data               
clear;
clc;

disp('Adım 1: Parametreler yükleniyor...');

% Parametreler
source_pos = [270, 360]; % Kaynak pozisyonu (x, y)
scanX =50; % Tarama noktalarının X eksenindeki sayısı
scanY =50; % Tarama noktalarının Y eksenindeki sayısı

disp('Adım 2: Dedektör grid parametreleri alınıyor...');
% Dedektör parametreleri
detector_rows = input('Dedektör gridinde satır (X) sayısı: '); 
detector_cols = input('Dedektör gridinde sütun (Y) sayısı: '); 
detector_spacing = input('Dedektörler arasındaki mesafe (spacing): '); 

disp('Adım 3: Binning faktörü seçiliyor...');
% Binning faktörü seçimi
apply_binning = input('Binning yapmak istiyor musunuz? (Evet: 1, Hayır: 0): ');
if apply_binning
    binning_factor = input('Binning faktörünü seçin (2 veya 3): ');
    if ~ismember(binning_factor, [2, 3])
        error('Sadece 2x2 veya 3x3 binning faktörü seçilebilir.');
    end
else
    binning_factor = 1; % Binning yapılmıyorsa faktör 1 olarak ayarlanır
end

disp('Adım 4: Görüntü dosyaları kontrol ediliyor...');
% Görüntü dosyalarının bulunduğu klasör
image_folder = 'C:\Users\enesm\OneDrive\Desktop\Yeni klasör (2)\27_01_25'; % Görüntülerin olduğu klasör
image_files = dir(fullfile(image_folder, '*.png')); % Tüm PNG dosyalarını listele
num_images = length(image_files);

% Kontrol: Beklenen ve mevcut görüntü sayısı uyumlu mu?
expected_images = scanX * scanY;
if num_images ~= expected_images
    error(['Beklenen görüntü sayısı (', num2str(expected_images), ...
           ') ile klasördeki görüntü sayısı (', num2str(num_images), ') uyuşmuyor!']);
end

disp('Adım 5: Görüntü gridini yüklüyoruz...');
% Görüntü gridini yükle
image_grid = cell(scanX, scanY);
temp_img = [];

disp('Adım 5: Görüntü gridini yüklüyoruz...');
% Görüntü gridini yükle
image_grid = cell(scanX, scanY);
temp_img = [];

tic

for y = 1:scanY
    for x = 1:scanX
        % Beklenen dosya ismini oluştur
        image_name = sprintf('pos_%dx%d.png', x, y); % Örn: 'pos_1x1.png'
        image_path = fullfile(image_folder, image_name);
        
        disp(['İşleniyor: Görüntü [X: ', num2str(x), ', Y: ', num2str(y), '] (Dosya: ', image_name, ')']);
        
        if exist(image_path, 'file')
            img = imread(image_path);
            if size(img, 3) == 3 % Gri tonlamaya çevir (renkli ise)
                img = rgb2gray(img);
            end
            % Binning işlemi
            img = apply_binning_function(img, binning_factor);
            image_grid{x, y} = double(img); % Yoğunlukları kaydet
            if isempty(temp_img)
                temp_img = img; % Görüntü boyutunu belirlemek için bir örnek kaydet
            end
        else
            warning(['Beklenen görüntü bulunamadı: ', image_name]);
        end
    end
end

disp('Adım 6: Görüntü boyutları kontrol ediliyor...');
% Görüntü boyutlarını kontrol et
[image_height, image_width] = size(temp_img);

disp('Adım 7: Dedektör gridini oluşturuyoruz...');
% Dedektör gridini oluşturma
grid_x = linspace(-floor(detector_rows / 2), floor(detector_rows / 2), detector_rows) * detector_spacing + source_pos(1);
grid_y = linspace(-floor(detector_cols / 2), floor(detector_cols / 2), detector_cols) * detector_spacing + source_pos(2);

% Dedektör merkezlerini hesapla
[detector_x, detector_y] = meshgrid(grid_x, grid_y);
detector_positions = [detector_x(:), detector_y(:)];

disp('Adım 8: Dedektör yoğunlukları hesaplanıyor...');
% Dedektör yoğunluklarını hesaplama
ms = []; % Hassasiyet matrisi

for d = 1:size(detector_positions, 1) % Her dedektör için
    det_x = (detector_positions(d, 1));
    det_y = (detector_positions(d, 2));

    % Dedektörün her image'deki yoğunluklarını sırala
    intensity_values = zeros(1, num_images);
    for i = 1:num_images
        img = image_grid{i};

        % Yoğunluğu al
        if det_y > 0 && det_y <= size(img, 1) && det_x > 0 && det_x <= size(img, 2)
            intensity_values(i) = img(det_y, det_x);
        else
            % NaN yerine hata mesajı yazdır
            fprintf('Hata: Dedektör %d (X: %d, Y: %d), Görüntü %d sınır dışı!\n', d, det_x, det_y, i);
            intensity_values(i) = NaN; % NaN 
        end
    end
    ms = [ms; intensity_values]; % Hassasiyet matrisine ekle
end

disp('Adım 9: Dedektör pozisyonları ve yoğunlukları listeleniyor...');
% Dedektör pozisyonlarını ve yoğunlukları kaydet
for d = 1:size(detector_positions, 1)
    fprintf('Dedektör %d: (X: %.2f, Y: %.2f) -> Yoğunluklar: %s\n', d, detector_positions(d, 1), detector_positions(d, 2), mat2str(ms(d, :)));
end

toc

disp('Adım 10: B Matrisi oluşturuluyor...');
% B Matrisinin Oluşturulması
b_matrix = reshape(ms, [], 1); % B matrisini sütun vektöre dönüştür
disp('B Matrisi oluşturuldu.');

%% 
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
msb.source_pos= source_pos;
msb.scanX = scanX;
msb.scanY = scanY; 
msb.detector_rows = detector_rows;
msb.detector_cols = detector_cols;
msb.detector_spacing = detector_spacing;
msb.apply_binning = apply_binning ;
msb.ms = ms ;
msb.b_matrix = b_matrix ;
msb.ms_3d = ms_3d ;
% save('b_ms_matrix.mat', 'msb');
%%
% Fonksiyonlar sona taşındı
function binned_img = apply_binning_function(img, binning_factor)
    [height, width] = size(img);
    new_height = floor(height / binning_factor);
    new_width = floor(width / binning_factor);
    binned_img = zeros(new_height, new_width);
    for i = 1:new_height
        for j = 1:new_width
            row_start = (i - 1) * binning_factor + 1;
            col_start = (j - 1) * binning_factor + 1;
            block = img(row_start:row_start+binning_factor-1, col_start:col_start+binning_factor-1);
            binned_img(i, j) = mean(block(:));
        end
    end
end
