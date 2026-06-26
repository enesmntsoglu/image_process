clc;
imaqreset;
% Kamerayı tanımla
vid = videoinput('gentl', 1, 'Mono12Packed'); % 'gentl' adaptörü ve 'Mono8' formatı  //info = imaqhwinfo('gentl'); disp(info.DeviceInfo.SupportedFormats); {'Mono10Packed'}    {'Mono12Packed'}    {'Mono16'}    {'Mono8'}
src = getselectedsource(vid);
%get(src)
% Donanım tetikleme yapılandırması
triggerconfig(vid, 'hardware', 'DeviceSpecific', 'DeviceSpecific');

try % Pozlama ayarları
    src.ExposureAuto = 'Off'; % Otomatik pozlama
%    src.ExposureTime = '100000' ;
    src.ExposureMode = 'TriggerWidth';        % Zamanlanmış pozlama modu
    disp('Pozlama ayarlandı.');
catch ME
    disp(['Pozlama yapılandırmasında hata: ', ME.message]);
end
    
try % Bit Ayarı
    src.AdcBitDepth = 'Bit12' ;
catch ME
    disp(['Bit ayarlanamadı.', ME.message]);
end

try %Tetikleme ayarları
    src.TriggerSelector = 'FrameStart'; % Tetikleme başlangıç noktası
    src.TriggerSource = 'Line0';        % Tetikleme kaynağı (GPIO hattı)
    src.TriggerActivation = 'LevelHigh' ;
    src.TriggerMode = 'On';               % Tetikleme modunu etkinleştir
    disp('Tetikleme başarıyla yapılandırıldı.');
catch ME
    disp(['Tetikleme yapılandırmasında hata: ', ME.message]);
end

% Temel görüntülerin kaydedileceği ana klasör
baseOutputFolder = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\24_09_25_\1_0_deep\cell3\17exp';

% Grid boyutları (örneğin 5x5)im
grid_size = [50, 50];

% Toplam kaç tarama yapılacağını belirleyin
numScans = 3; % İstediğiniz sayıya göre ayarlayabilirsiniz
t_start = tic;
for scanIndex = 1:numScans
    % Her tarama için ayrı bir klasör oluşturma
    outputFolder = fullfile(baseOutputFolder, sprintf('Scan_%d_%s', scanIndex, datestr(now, 'dd_mm_yy_HH_MM_SS')));
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    
    % Tarama öncesi kamera buffer'ını temizle ve trigger ayarını güncelle
    flushdata(vid); 
    vid.TriggerRepeat = grid_size(1) * grid_size(2) - 1;
    start(vid);
    
    disp(['Tarama ' num2str(scanIndex) ' başladı.']);
    
    for x = 1:grid_size(1)
        % Y ekseni sırası: tek sıra normal, çift sıra ters
        if mod(x, 2) == 1
            y_range = 1:grid_size(2);
        else
            y_range = grid_size(2):-1:1;
        end
        
        for y_idx = 1:length(y_range)
            y = y_range(y_idx);
            try
                disp(['Pozisyon: ', num2str(x), 'x', num2str(y), ' için tetikleme bekleniyor...']);
                
                % Tetikleme sinyali bekleniyor
                while vid.FramesAvailable == 0
                    % Bekleme (donma olmaz)
                end

                % Görüntüyü al
                img = getdata(vid, 1);
                
                % Görüntüyü yatayda ayna gibi çevir (gerekirse)
                mirrored_img = flip(img, 2);
                %mirrored_img = img;
                
                % İstenirse 90 derece sağa döndürebilirsiniz:
                rotated_img = imrotate(mirrored_img, 270);
                %rotated_img = mirrored_img; % Döndürme işlemi aktif değil
                
                % Dosya adını oluşturma (pozisyona göre)
                corrected_y = (x - 1) * grid_size(2) + y;
                image_name = sprintf('pos_%dx%d.png', ceil(corrected_y / grid_size(2)), mod(corrected_y - 1, grid_size(2)) + 1);
                save_path = fullfile(outputFolder, image_name);
                
                % Görüntüyü kaydet
                imwrite(rotated_img, save_path);
                fprintf('Görüntü kaydedildi: %s\n', save_path);
                
                % Buffer'ı temizle
                flushdata(vid);
                
            catch ME
                disp(['Hata oluştu: ', ME.message]);
            end
        end
    end
    
    
    disp(['Tarama ' num2str(scanIndex) ' tamamlandı.']);
    elapsed_time = toc(t_start);
    fprintf('Görüntü süresi: %.3f saniye\n', elapsed_time);
    
    % İki tarama arasında kısa bir bekleme süresi (opsiyonel)
    stop(vid);
    %pause(00.1);
end

% İşlem tamamlandığında kamerayı serbest bırak

delete(vid);
clear vid;
imaqreset;
disp('Tüm taramalar başarıyla tamamlandı.');


% % Pozlama ayarları
% try
%     src.ExposureAuto = 'Off'; % Otomatik pozlama
%     src.ExposureTime = '100000' ;
%     src.ExposureMode = 'Timed';        % Zamanlanmış pozlama modu
%     disp('Pozlama modu Continuous olarak ayarlandı.');
% catch ME
%     disp(['Pozlama yapılandırmasında hata: ', ME.message]);
% end

% Gain ayarları
% try
%     src.GainAuto = 'Off';  % Otomatik kazanç kapalı
%     disp('Gain başarıyla manuel olarak ayarlandı.');
% catch ME
%     disp(['Gain yapılandırmasında hata: ', ME.message]);
% end
% 
% % Gamma ayarları 
% try
%     src.GammaEnable = 'True';
%     src.Gamma = 1.0; % Varsayılan gamma değeri
%     disp('Gamma başarıyla ayarlandı.');
% catch ME
%     disp(['Gamma ayarlanamadı: ', ME.message]);
% end

% Tetikleme ayarları
% try
%     src.TriggerSelector = 'FrameStart'; % Tetikleme başlangıç noktası
%     src.TriggerSource = 'Line0';        % Tetikleme kaynağı (GPIO hattı)
%     %src.TriggerActivation = 'RisingEdge' ;
%     src.TriggerMode = 'On';               % Tetikleme modunu etkinleştir
%     disp('Tetikleme başarıyla yapılandırıldı.');
% catch ME
%     disp(['Tetikleme yapılandırmasında hata: ', ME.message]);
% end