% Klasör yollarını belirleyin
folder1 = 'C:\Klasor1';
folder2 = 'C:\Klasor2';
folder3 = 'C:\Klasor3';
outputFolder = 'C:\OrtalamaGoruntu';

% Çıktı klasörü yoksa oluşturun
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% İlk klasördeki tüm png dosyalarını alıyoruz (dosya isimleri diğer klasörlerle aynı olmalı)
files = dir(fullfile(folder1, '*.png'));

for k = 1:length(files)
    % Dosya ismini al
    fileName = files(k).name;
    
    % Üç klasördeki dosya tam yollarını oluşturun
    filePath1 = fullfile(folder1, fileName);
    filePath2 = fullfile(folder2, fileName);
    filePath3 = fullfile(folder3, fileName);
    
    % Dosyaların var olup olmadığını kontrol edin
    if exist(filePath2, 'file') && exist(filePath3, 'file')
        % Görüntüleri okuyun ve double formatına çevirin (ortalama alma için)
        img1 = double(imread(filePath1));
        img2 = double(imread(filePath2));
        img3 = double(imread(filePath3));
        
        % Ortalama görüntüyü hesaplayın
        avgImg = (img1 + img2 + img3) / 3;
        
        % Tekrar uint8 formatına çevirin (görüntü formatı için)
        avgImg = uint8(avgImg);
        
        % Ortaya çıkan görüntüyü çıktı klasörüne kaydedin
        imwrite(avgImg, fullfile(outputFolder, fileName));
    else
        fprintf('Dosya %s klasör2 veya klasör3 de bulunamadı.\n', fileName);
    end
end
