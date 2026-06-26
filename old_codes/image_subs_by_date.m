%% Birden Fazla Klasördeki PNG’leri Tarihe Göre Sırala, Ortala ve 16-bit PNG Olarak Kaydetme
clc

%% Adım 0: Girdi Klasörlerini ve Çıktı Klasörünü Tanımlayın
folders = {
    "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\18_08_25_\opak_2\birinci_sefer\Scan_1_18_08_25_13_27_13" ;
    "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\18_08_25_\opak_2\birinci_sefer\Scan_2_18_08_25_13_35_22" ;
    "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\18_08_25_\opak_2\birinci_sefer\Scan_3_18_08_25_13_43_43" ;
   
    
    
    
};
outputFolder = "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\18_08_25_\opak_2\birinci_sefer\sonuclar_average";

if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

%% Adım 1: Klasörler Arasındaki Ortak PNG İsimlerini Bulun
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

%% Adım 1.5: commonNames’ı Oluşturma Tarihine Göre Sırala
% 1. klasördeki dosyaların datenum değerlerini okuyup, commonNames’ı tarihe göre diziyoruz
files0   = dir(fullfile(folders{1}, '*.png'));
dateNums = nan(numel(commonNames),1);
for k = 1:numel(commonNames)
    idx = find(strcmp({files0.name}, commonNames{k}), 1);
    if ~isempty(idx)
        dateNums(k) = files0(idx).datenum;
    end
end
[~, order]     = sort(dateNums);
commonNames    = commonNames(order);

%% Adım 2: Ortalama Hesapla ve 16-bit PNG Olarak Kaydet
for k = 1:numel(commonNames)
    name   = commonNames{k};
    sumImg = [];
    
    % Tüm klasörlerden aynı adlı dosyaları oku ve topla
    for i = 1:numel(folders)
        path  = fullfile(folders{i}, name);
        raw12 = read12bitPng(path);       % 16-bit PNG içinden 12-bit ham veri al
        if isempty(sumImg)
            sumImg = double(raw12);
        else
            sumImg = sumImg + double(raw12);
        end
    end
    
    % Ortalama al ve uint16’ye yuvarla
    avgImg = sumImg / numel(folders);
    avg12  = uint16(round(avgImg));      % 0–4095 aralığında uint16
    
    % Çıktıyı kaydet
    outPng = fullfile(outputFolder, name);
    imwrite(avg12, outPng, 'BitDepth', 16);
    fprintf('Kaydedildi: %s  (min=%d, max=%d)\n', ...
        outPng, min(avg12(:)), max(avg12(:)));
end

%% Yardımcı Fonksiyon: 16-bit PNG İçinden 12-bit Ham Veri Al
function raw12 = read12bitPng(path)
    info = imfinfo(path);
    if info.BitDepth ~= 16
        error('Beklenen 16-bit PNG, bulundu: %d-bit', info.BitDepth);
    end
    A = imread(path);
    if ndims(A) == 3
        A = rgb2gray(A);
    end
    raw12 = uint16(A);  % 0–4095 aralığında gerçek 12-bit veri
end
