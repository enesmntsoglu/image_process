%% TEK BİR REFERANS GÖRÜNTÜ ÇIKARMA (REF FOLDER) + FOLDER1’DEKİ TÜM TIFF’LERİ SIRALA VE ÇIKAR
clc; clear;

%% 0) Parametreler
folder1        = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images_biolum\27_06_25_\1_sw\flor1\Scan_1_27_06_25_20_03_31';
referenceFolder= 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images_biolum\27_06_25_\1_sw\flor1\bg';  
outputFolder   = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images_biolum\27_06_25_\1_sw\flor1\minus_bg';


% Çıktı klasörünü hazırla
if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

%% 1) referenceFolder içindeki tek TIFF dosyasını bul ve oku
refList = dir(fullfile(referenceFolder,'*.png*'));
if isempty(refList)
    error('referenceFolder içinde hiç TIFF bulunamadı.');
end
% Birden fazla varsa ilkini kullan
referenceImageFile = fullfile(referenceFolder, refList(1).name);
Iref = imread(referenceImageFile);
if ndims(Iref)==3, Iref = rgb2gray(Iref); end

%% 2) folder1 içindeki tüm TIFF dosyalarını tarihi göre sırala
files1 = dir(fullfile(folder1,'*.png*'));
if isempty(files1)
    error('folder1 içinde hiç TIFF bulunamadı.');
end
[~, idx] = sort([files1.datenum]);
files1   = files1(idx);

%% 3) Her dosyadan referansı çıkar ve aynı isimle kaydet
for k = 1:numel(files1)
    fname    = files1(k).name;
    thisFile = fullfile(folder1, fname);
    
    % Orijinal görüntüyü oku
    I1 = imread(thisFile);
    if ndims(I1)==3, I1 = rgb2gray(I1); end
    
    % Çıkarma işlemi ve negatifleri sıfırla
    D = double(I1) - double(Iref);
    D(D < 0) = 0;
    
    % Orijinal sınıfa döndür
    Dout = cast(D, class(I1));
    
    % Aynı isimle çıktı dosyasını oluştur
    outFile = fullfile(outputFolder, fname);
    imwrite(Dout, outFile);
    
    fprintf('Kaydedildi: %s\n', outFile);
end