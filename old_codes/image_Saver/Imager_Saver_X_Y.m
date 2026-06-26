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
outputFolder = 'C:\TriggerCapturedImages';
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Grid boyutları
grid_size = [50, 1]; % 5x5 grid (örnek)

% Kamera başlatma
flushdata(vid); % Eski verileri temizle
start(vid); % Kamerayı başlat

disp('Harici tetikleme bekleniyor...');
for x = 1:grid_size(1)
    for y = 1:grid_size(2)
        try
            % Tetikleme sinyalini bekle
            disp(['Pozisyon: ', num2str(x), 'x', num2str(y), ' için tetikleme bekleniyor...']);
            while vid.FramesAvailable == 0
                % Tetikleme sinyali gelene kadar bekle
                pause(0.1); % 100 ms bekleme
            end

            % Görüntüyü al
            img = getdata(vid, 1);

            % Ayna görüntüsü al (Y ekseninde flip)
            mirrored_img = flip(img, 2);

            % 90 derece sağa döndür
            rotated_img = imrotate(mirrored_img, 90);

            % Dosya adını pozisyona göre ayarla
            image_name = sprintf('pos_%dx%d.png', x, y);

            % Görüntüyü kaydet
            save_path = fullfile(outputFolder, image_name);
            imwrite(rotated_img, save_path);
            fprintf('Görüntü kaydedildi: %s\n', save_path);

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