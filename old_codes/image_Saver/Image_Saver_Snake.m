% Çalışma alanını temizle
clear;
clc;

% Kamerayı tanımla
vid = videoinput('gentl', 1, 'Mono8'); % 'gentl' adaptörü ve 'Mono8' formatı
src = getselectedsource(vid);

% Tetikleme ayarları
try
    src.TriggerSelector = 'FrameStart'; % Tetikleme başlangıç noktası
    src.TriggerSource = 'Line0'; % Tetikleme kaynağı (GPIO hattı)
    src.TriggerActivation = 'RisingEdge'; % Yükselen kenar tetikleme
    src.TriggerMode = 'On'; % Tetikleme modunu etkinleştir
    disp('Tetikleme başarıyla yapılandırıldı.');
catch ME
    disp(['Tetikleme yapılandırmasında hata: ', ME.message]);
end

% Pozlama ayarları
try
    src.ExposureAuto = 'Continuous'; % Otomatik pozlama
    src.ExposureMode = 'Timed'; % Zamanlanmış pozlama modu
    disp('Pozlama modu Continuous olarak ayarlandı.');
catch ME
    disp(['Pozlama yapılandırmasında hata: ', ME.message]);
end

% Gain ayarları
try
    src.GainAuto = 'Off'; % Otomatik kazanç
    disp('Gain başarıyla manuel olarak ayarlandı.');
catch ME
    disp(['Gain yapılandırmasında hata: ', ME.message]);
end

% Gamma ayarları 
try
    src.GammaEnable = 'True';
    src.Gamma = 1.0; % Varsayılan gamma değeri
    disp('Gamma başarıyla ayarlandı.');
catch ME
    disp(['Gamma ayarlanamadı: ', ME.message]);
end

% Donanım tetikleme yapılandırması
triggerconfig(vid, 'hardware', 'DeviceSpecific', 'DeviceSpecific');

% Görüntülerin kaydedileceği klasör
outputFolder = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Final_Work_Space\Images\27_01_25';
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Grid boyutları
grid_size = [5, 5]; % X ve Y çekim sayısı

% Kamera başlatma
flushdata(vid); % Eski verileri temizle
vid.TriggerRepeat = grid_size(1) * grid_size(2) - 1; % Tetikleme tekrar sayısı
start(vid); % Kamerayı başlat

disp('Harici tetikleme bekleniyor...');
for x = 1:grid_size(1)
    % Y ekseni sırasını kontrol et
    if mod(x, 2) == 1
        y_range = 1:grid_size(2); % Normal sıra
    else
        y_range = grid_size(2):-1:1; % Ters sıra
    end

    for y_idx = 1:length(y_range)
        y = y_range(y_idx);
        try
            % Tetikleme sinyalini bekle
            disp(['Pozisyon: ', num2str(x), 'x', num2str(y), ' için tetikleme bekleniyor...']);
            
            % Tetikleme sinyalini bekle
            while vid.FramesAvailable == 0
                % Bekleme süresinde işlem yapılmaz, sinyal beklenir
            end

            % Görüntüyü al
            img = getdata(vid, 1);

            % Ayna görüntüsü al (Y ekseninde flip)
            mirrored_img = flip(img, 2);

            % 90 derece sağa döndür
            rotated_img = mirrored_img ;%imrotate(mirrored_img, 90);

            % Eski düzene göre dosya adını pozisyona göre ayarla
            corrected_y = (x - 1) * grid_size(2) + y;
            image_name = sprintf('pos_%dx%d.png', ceil(corrected_y / grid_size(2)), mod(corrected_y - 1, grid_size(2)) + 1);

            % Görüntüyü kaydet
            save_path = fullfile(outputFolder, image_name);
            imwrite(rotated_img, save_path);
            fprintf('Görüntü kaydedildi: %s\n', save_path);

            % Buffer temizle
            flushdata(vid);

        catch ME
            disp(['Hata oluştu: ', ME.message]);
        end
    end
end

% Kamerayı durdur ve temizle
stop(vid);
delete(vid);
clear vid;
imaqreset;
disp('Tüm görüntüler başarıyla kaydedildi.');
