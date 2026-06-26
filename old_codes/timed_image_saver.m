clc;
imaqreset;
%Kamera ve Format Ayarları
% Desteklenen formatları görüntülemek (isteğe bağlı):
% info = imaqhwinfo('gentl');
% disp(info.DeviceInfo.SupportedFormats);
% -> {'Mono10Packed'} {'Mono12Packed'} {'Mono16'} {'Mono8'}

vid = videoinput('gentl', 1, 'Mono12Packed');   % BF-U3-285M, 12-bit packed format
src = getselectedsource(vid);


try
    src.ExposureAuto = 'Off';           % Otomatik pozlamayı kapat
    src.ExposureMode = 'Timed';         % “Timed” modda çalışacak
    src.ExposureTime = uint32(1000000); % Pozlama süresi 1 000 000 µs = 1 s
    disp('Pozlama: 1 s (Timed mode) olarak ayarlandı.');
catch ME
    disp(['Pozlama yapılandırma hatası: ', ME.message]);
end

try
    src.AdcBitDepth = 'Bit12';
    disp('ADC Bit Depth: 12-bit olarak ayarlandı.');
catch ME
    disp(['Bit depth ayarlanamadı: ', ME.message]);
end


% 5. Gain / Gamma / Beyaz Dengesi (İsteğe bağlı)
% Aşağıdaki satırları açıp dilediğiniz değerleri girerek kazanç/gamma ayarlarını
% manuel yapabilirsiniz. Varsayılan olarak bu bölümü kapalı bırakabilirsiniz.
%
% try
%     src.GainAuto = 'Off';    % Otomatik kazancı kapat
%     src.Gain = 0.0;          % Örneğin 0 dB kazanç
%     disp('Gain manuel olarak ayarlandı.');
% catch ME
%     disp(['Gain ayarlanamadı: ', ME.message]);
% end
%
% try
%     src.GammaEnable = 'Off'; % Gamma düzeltmeyi devre dışı bırak
%     disp('Gamma devre dışı bırakıldı.');
% catch ME
%     disp(['Gamma ayarlanamadı: ', ME.message]);
% end
%
% try
%     src.BalanceWhiteAuto = 'Off';  % Otomatik beyaz dengesi kapalı
%     disp('Otomatik beyaz dengesi kapatıldı.');
% catch ME
%     disp(['Beyaz dengesi ayarlanamadı: ', ME.message]);
% end

% =========================
% 6. Çekilecek Kare Sayısı / Süre
% =========================
totalFramesToGrab = 60;       % 1 dakika boyunca, her biri 1 s exposure: ~60 kare


% Kendi bilgisayarınızdaki yolu aşağıdaki satırda belirtin:
baseOutputFolder = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\03_06_25';

if ~exist(baseOutputFolder, 'dir')
    mkdir(baseOutputFolder);
end

% “Timed” mod Free-Run’da çalışacak, tetik gerekmez ama FramesPerTrigger=1
% ve TriggerRepeat=0 ayarı güvenlik amaçlı eklenmiştir:
vid.FramesPerTrigger = 1;
vid.TriggerRepeat = 0;

flushdata(vid);  % Olası önbellekteki eski resimleri temizle
start(vid);      % Videoinput’u başlat

disp('Kayıt başladı: 1 s exposure ile ardışık 60 kare alınacak.');

for idx = 1:totalFramesToGrab
    % Bir sonraki kare gelene kadar bekle
    while vid.FramesAvailable < 1
        % Beklemede kal (pozlama süresi dolana kadar)
    end
    
    % Bir kare al
    img12 = getdata(vid, 1);
    
    % Dosya adını oluştur (frame_001.tif, frame_002.tif, …)
    filename = fullfile(baseOutputFolder, sprintf('frame_%03d.tif', idx));
    
    % Görüntüyü TIFF olarak kaydet (TIFF 16-bit konteyner kullandığından 12-bit veriyi içerir)
    imwrite(img12, filename);
    
    fprintf('Kaydedildi: %s\n', filename);
    
    % Buffer’ı temizle, bir sonraki kareyi beklemek için hazır ol
    flushdata(vid);
end


stop(vid);
delete(vid);
clear vid;
imaqreset();
disp('Kayıt tamamlandı ve kamera serbest bırakıldı.');
