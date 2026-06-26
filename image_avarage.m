%% Birden Fazla Klasördeki PNG’leri Ortalayıp 12-bit Veri İçeren 16-bit PNG Olarak Kaydetme

clc

%% Adım 0: Girdi Klasörlerini ve Çıktı Klasörünü Tanımlayın
folders = {
    "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\30_01_26\sw3\Scan_1_03_02_26_16_25_55" ;
    "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\30_01_26\sw3\Scan_2_03_02_26_16_33_39" ;
    "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\30_01_26\sw3\Scan_3_03_02_26_16_41_26" ;
   
    
    
    
};
outputFolder = "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\30_01_26\sw3\avrg";
%outputFolder = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Analiz\08_05\besiyer_bg_avrg';

if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

%% Adım 1: Ortak PNG İsimlerini Bulun
commonNames = {};
for i = 1:numel(folders)
    files = dir(fullfile(folders{i}, '*.png'));
    names = {files.name}';
    if i == 1
        commonNames = names;
    else
        commonNames = intersect(commonNames, names);
    end
end
if isempty(commonNames)
    error('Klasörler arasında ortak PNG dosyası bulunamadı.');
end

%% Adım 2: Ortalama Hesapla ve 16-bit PNG Olarak Kaydet
for k = 1:numel(commonNames)
    name   = commonNames{k};
    sumImg = [];
    
    % Tüm klasörlerden oku
    for i = 1:numel(folders)
        path  = fullfile(folders{i}, name);
        raw12 = read12bitPng(path);       % 16-bit PNG içinden 12-bit veriyi al
        if isempty(sumImg)
            sumImg = double(raw12);
        else
            sumImg = sumImg + double(raw12);
        end
    end
    
    avgImg = sumImg / numel(folders);    % Ortalama (double)
    avg12  = uint16(round(avgImg));      % 0–4095 aralığında uint16

    % Çıktı dosya
    outPng = fullfile(outputFolder, name);

    % 16-bit PNG olarak kaydet (içeride 12-bit veri)
    imwrite(avg12, outPng, 'BitDepth', 16);
    fprintf('Kaydedildi: %s  (min=%d, max=%d)\n', ...
        outPng, min(avg12(:)), max(avg12(:)));
end

%% Yardımcı Fonksiyon: 16-bit PNG içinden 12-bit ham veri al
function raw12 = read12bitPng(path)
    info = imfinfo(path);
    if info.BitDepth ~= 16
        error('Beklenen 16-bit PNG, bulundu: %d-bit', info.BitDepth);
    end
    A = imread(path);
    if ndims(A)==3
        A = rgb2gray(A);
    end
    raw12 = uint16(A);  % 0–4095 aralığında gerçek 12-bit veri
end







