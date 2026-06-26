% Kamera ile otomatik görüntü çekme, isimlendirme ve kaydetme kodu

% Kamerayı başlat (önceki adımlarda kameranın tanımlandığını varsayıyorum)
try
    % Kamera bağlantısını kontrol et
    camera = videoinput("gentl", 1); % "gentl" arayüzü ve ilk cihaz (kamera aygıtı bağlı olmalı)
catch
    error("Kamera başlatılamadı. Bağlantı ayarlarını kontrol edin.");
end

% Grid boyutu ve kaydetme klasörünü ayarla
grid_size = [5 , 5]; % 7x7 grid
save_folder = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\deneme_1';

% Kaydetme klasörü yoksa oluştur
if ~exist(save_folder, 'dir')
    mkdir(save_folder);
end

% Kamera tetikleme modunu ayarla
triggerconfig(camera, 'manual'); % Kamera için manuel tetikleme modu
set(camera, 'FramesPerTrigger', 1); % Her tetiklemede tek bir kare çekilecek

% Görüntüleri grid pozisyonuna göre çekip kaydetme
for x = 1:grid_size(1)
    for y = 1:grid_size(2)
        try
            % Kamerayı başlat ve tetikleme öncesinde çalıştır
            start(camera); % Kamera başlatılıyor
            trigger(camera); % Kamerayı tetikle

            % Çekilen görüntüyü al
            img = getdata(camera, 1); % İlk görüntüyü al

            % Dosya adını pozisyona göre ayarla
            image_name = sprintf('pos_%dx%d.png', x, y);
            % Tam dosya yolunu oluştur
            save_path = fullfile(save_folder, image_name);

            % Görüntüyü kaydet
            imwrite(img, save_path);
            fprintf('Görüntü kaydedildi: %s\n', save_path);

            % İsteğe bağlı olarak her çekim arasında bekleme süresi
           % pause(0.1); % Bekleme süresi 0.5 saniyeye düşürüldü

        catch ME
            % Hata oluşursa kullanıcıyı bilgilendir ve devam et
            warning("Görüntü çekme veya kaydetme sırasında hata oluştu: %s", ME.message);
        end

        % Kamerayı durdur
        stop(camera);
    end
end

% Kamerayı serbest bırakma
delete(camera); % Kamera bağlantısını kes
clear camera; % Kamera nesnesini temizle
