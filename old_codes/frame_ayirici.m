% AVI dosyasını karelerine ayırıp ayrı resim dosyaları olarak kaydeden MATLAB script’i
% Kodu doğrudan kopyalayıp bir .m dosyasına yapıştırabilirsiniz.
% Çalışmadan önce inputAviPath ve outputFolder değişkenlerini kendinize göre düzenleyin.

clc;
clear;

%% 1. Giriş ve çıkış yollarını ayarlayın
% Düzenleyin: İşlem yapmak istediğiniz AVI dosyasının tam yolu
inputAviPath = "C:\Users\TUSEB\Videos\temp-06032025150856-0000.avi";

% Düzenleyin: Karelerin kaydedileceği klasör (var değilse otomatik oluşturulacak)
outputFolder = 'C:\Users\TUSEB\Videos\Captures';

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

%% 2. VideoReader nesnesi oluşturun
vidObj = VideoReader(inputAviPath);

%% 3. Kareleri okuyup kaydetme döngüsü
frameIndex = 1;
while hasFrame(vidObj)
    % Bir kare oku
    frameRGB = readFrame(vidObj);
    
    % Dosya adı örneği: frame_0001.png, frame_0002.png, vb.
    filename = fullfile(outputFolder, sprintf('frame_%04d.png', frameIndex));
    
    % Görüntüyü PNG olarak kaydet
    imwrite(frameRGB, filename);
    
    fprintf('Kaydedildi: %s\n', filename);
    frameIndex = frameIndex + 1;
end

fprintf('Tüm kareler başarıyla kaydedildi. Toplam kare sayısı: %d\n', frameIndex-1);
