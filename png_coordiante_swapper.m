% Kaynak klasör (bulunduğun klasör)
srcFolder = "D:\Images\24_09_25_\0_5_deep\cell_no bg";  
% srcFolder = 'C:\veri\resimler';  % istersen elle yaz

% Hedef klasör (aynı klasörün içinde)
dstFolder = fullfile(srcFolder, 'renamed_swapped');

% Klasör yoksa oluştur
if ~exist(dstFolder, 'dir')
    mkdir(dstFolder);
end

% Dosyaları bul
files = dir(fullfile(srcFolder, 'pos_*x*.png'));

% Yalnızca "pos_<sayı>x<sayı>.png" formatını eşle
expr = '^pos_(\d+)x(\d+)\.png$';

for i = 1:numel(files)
    fname = files(i).name;
    tokens = regexp(fname, expr, 'tokens');

    if isempty(tokens)
        continue; % uymayanları geç
    end

    k = tokens{1}{1};
    m = tokens{1}{2};

    newName = sprintf('pos_%sx%s.png', m, k);

    srcPath = fullfile(srcFolder, fname);
    dstPath = fullfile(dstFolder, newName);

    % Çakışma varsa üzerine yazma
    if isfile(dstPath)
        fprintf('Atlandı (hedefte var): %s\n', newName);
        continue;
    end

    % Görüntüyü oku
    img = imread(srcPath);
    
    % 90 derece sola döndür (counterclockwise)
    img_rotated = imrotate(img, 90);
    
    % Kaydet (orijinal bozulmaz)
    try
        imwrite(img_rotated, dstPath);
        fprintf('Döndürüldü ve kaydedildi: %s  -->  %s\\%s\n', fname, 'renamed_swapped', newName);
    catch ME
        fprintf('HATA: %s kaydedilemedi: %s\n', fname, ME.message);
    end
end