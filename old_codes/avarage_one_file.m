%% TIFF DİZİSİNDE PİKSEL ORTALAMASI ALMA VE KAYDETME
clc; clear;

%% 1) Ayarlar
inputFolder  = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\biolum_2\only_medium_sephoroid';
outputFolder = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\biolum_2_analiz\bg';

% Klasör yoksa oluştur
if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

% Kaydedilecek dosya adı
outputFile = fullfile(outputFolder, 'average_image.tiff');

%% 2) Klasördeki .tif/.tiff dosyalarını bul
fileList = dir(fullfile(inputFolder,'*.tif*'));
if isempty(fileList)
    error('Belirtilen klasörde hiç TIF dosyası bulunamadı.');
end

% (İsteğe bağlı) Tarihe göre sıralama
[~, idxDate] = sort([fileList.datenum]);
fileList = fileList(idxDate);

%% 3) Tüm görüntüleri topla
sumImg = [];
for k = 1:numel(fileList)
    I = imread(fullfile(inputFolder, fileList(k).name));
    if ndims(I)==3
        I = rgb2gray(I);
    end
    if k == 1
        sumImg = double(I);
    else
        sumImg = sumImg + double(I);
    end
end

%% 4) Ortalama görüntüyü hesapla ve orijinal sınıfa dönüştür
avgImg     = sumImg / numel(fileList);
firstImage = imread(fullfile(inputFolder, fileList(1).name));
origClass  = class(firstImage);
avgImgCast = cast(round(avgImg), origClass);

%% 5) TIFF olarak kaydet
imwrite(avgImgCast, outputFile, 'TIFF', 'Compression','none');
fprintf('Ort. görüntü kaydedildi: %s\n', outputFile);
