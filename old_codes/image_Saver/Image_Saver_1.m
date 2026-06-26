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
    src.ExposureAuto = 'Off'; % Otomatik pozlamayı devre dışı bırak
    src.ExposureMode = 'Timed'; % Zamanlanmış pozlama modu
    src.ExposureTime = 15000; % Mikro-saniye cinsinden pozlama süresi
    disp('Pozlama başarıyla manuel olarak ayarlandı.');
catch ME
    disp(['Pozlama ayarlanamadı: ', ME.message]);
end

% Gain ayarları
try
    src.GainAuto = 'Off'; % Otomatik kazancı kapat
    src.Gain = 0.4; % Manuel kazanç
    disp('Gain başarıyla manuel olarak ayarlandı.');
catch ME
    disp(['Gain ayarlanamadı: ', ME.message]);
end

% Gamma ayarları
try
    src.GammaEnable = 'True'; % Gamma düzeltmesini etkinleştir
    src.Gamma = 0.8; % Gamma değeri
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

% Kamerayı başlat
start(vid);

disp('Harici tetikleme bekleniyor...');
frameCount = 0;
maxFrames = 20; % Maksimum kaydedilecek görüntü sayısı

% Görüntü yakalama döngüsü
while frameCount < maxFrames
    try
        % Görüntüyü al
        img = getdata(vid, 1); % Donanım tetiklemesi sonrası gelen görüntü

        % Görüntüyü kaydet
        fileName = sprintf('Image_%03d.png', frameCount + 1); % Örneğin, Image_001.png
        imwrite(img, fullfile(outputFolder, fileName));

        disp(['Görüntü kaydedildi: ', fileName]);
        frameCount = frameCount + 1;
    
    end
end

% Kamerayı durdur ve kaynakları serbest bırak
stop(vid);
delete(vid);
clear vid;

disp('Tüm görüntüler kaydedildi.');