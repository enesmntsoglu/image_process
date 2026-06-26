%% En Yüksek Piksel Değerine Sahip PNG’yi ve Değerini Bulma

clc;

% İşlem yapılacak klasörü tanımlayın
imageFolder = "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Analiz\08_05\sw3\third_loop\sonuclar_average";

% Tüm PNG dosyalarını listeleyin
files = dir(fullfile(imageFolder, '*.png'));
if isempty(files)
    error('Bu klasörde hiç PNG dosyası bulunamadı.');
end

% Değişkenleri başlatın
globalMaxValue = -inf;
globalMaxFile  = '';

% Her dosya için en yüksek piksel değerini kontrol edin
for k = 1:numel(files)
    % Dosya yolunu oluştur
    filename = files(k).name;
    filepath = fullfile(imageFolder, filename);
    
    % 12-bit veriyi oku
    data12 = read12bitPng(filepath);
    
    % Bu görüntünün en yüksek piksel değeri
    thisMax = max(data12(:));
    
    % Karşılaştır ve gerekirse güncelle
    if thisMax > globalMaxValue
        globalMaxValue = thisMax;
        globalMaxFile  = filename;
    end
end

% Sonucu yazdır
fprintf('En yüksek piksel değerine sahip dosya: %s\n', globalMaxFile);
fprintf('En yüksek piksel değeri: %d\n', globalMaxValue);


%% Yardımcı Fonksiyon: 16-bit PNG içinden 12-bit ham veri al
function raw12 = read12bitPng(path)
    info = imfinfo(path);
    if info.BitDepth ~= 16
        error('Beklenen 16-bit PNG, bulundu: %d-bit (%s)', info.BitDepth, path);
    end
    A = imread(path);
    if ndims(A)==3
        A = rgb2gray(A);
    end
    raw12 = uint16(A);   % Üst 4 bit sıfır, alt 12 bit veri (0–4095)
end
