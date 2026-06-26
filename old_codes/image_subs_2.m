%% --- Güvenli Fark Alma ve Aynı İsimle Kaydetme ---
folder1      = "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\24_09_25_\1_0_deep\cell3\17exp\avar";
folder2      = "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\24_09_25_\1_0_deep\noise\Scan_1_24_09_25_12_18_07";
outputFolder = "C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\24_09_25_\1_0_deep\cell3\no_bg";

if ~exist(outputFolder,'dir'); mkdir(outputFolder); end

% --- Klasör içeriklerini oku ---
L1 = dir(fullfile(folder1,'*.png'));
L2 = dir(fullfile(folder2,'*.png'));

% --- Ortak dosya isimlerini bul ---
names1 = string({L1.name});
names2 = string({L2.name});
commonNames = intersect(names1, names2);         % SADECE aynı isimdekiler işlenecek
only1 = setdiff(names1, names2);                 % folder1'de olup folder2'de olmayanlar
only2 = setdiff(names2, names1);                 % folder2'de olup folder1'de olmayanlar


% Bilgilendirme
if ~isempty(only1)
    fprintf('[Uyarı] Sadece folder1''de olan %d dosya atlandı.\n', numel(only1));
end
if ~isempty(only2)
    fprintf('[Uyarı] Sadece folder2''de olan %d dosya var (eşleşme yok).\n', numel(only2));
end
if isempty(commonNames)
    error('İşlenecek ortak isimli PNG bulunamadı.');
end

% --- Özet sayaçları / log ---
okCount = 0; skipCount = 0; errCount = 0;
logMsgs = strings(0,1);

for k = 1:numel(commonNames)
    baseName = commonNames(k);
    file1    = fullfile(folder1, baseName);
    file2    = fullfile(folder2, baseName);
    outPng   = fullfile(outputFolder, baseName);  % ÇIKTI AYNI İSİMLE

    try
        % 16-bit PNG bekleniyor ve 0–4095 aralığında 12-bit veri taşıdığı varsayımı
        [I1,info1] = read16as12(file1);
        [I2,info2] = read16as12(file2);

        % Güvenlik: boyut ve bit-derinliği eşleşmeleri
        if any(size(I1) ~= size(I2))
            skipCount = skipCount + 1;
            msg = sprintf('[Atlandı] Boyut uyuşmazlığı: %s (%dx%d) vs (%dx%d)', ...
                baseName, size(I1,2), size(I1,1), size(I2,2), size(I2,1));
            fprintf('%s\n', msg); logMsgs(end+1) = msg; %#ok<SAGROW>
            continue
        end
        if ~(info1.BitDepth == 16 && info2.BitDepth == 16)
            skipCount = skipCount + 1;
            msg = sprintf('[Atlandı] BitDepth 16 değil: %s (b1=%d, b2=%d)', ...
                baseName, info1.BitDepth, info2.BitDepth);
            fprintf('%s\n', msg); logMsgs(end+1) = msg; %#ok<SAGROW>
            continue
        end

        % Fark ve negatifleri bastırma
        Ddiff = double(I1) - double(I2);
        Ddiff(Ddiff < 0) = 0;

        % 0–4095 aralığına yuvarlayıp uint16 yap
        D16 = uint16(min(max(round(Ddiff),0),4095));

        % Güvenlik: NaN/Inf kontrolü
        if any(~isfinite(Ddiff(:)))
            skipCount = skipCount + 1;
            msg = sprintf('[Atlandı] NaN/Inf tespit edildi: %s', baseName);
            fprintf('%s\n', msg); logMsgs(end+1) = msg; %#ok<SAGROW>
            continue
        end

        % Çıkışı aynı isimle 16-bit PNG olarak yaz (içerik 0–4095)
        imwrite(D16, outPng, 'BitDepth', 16);
        okCount = okCount + 1;
        fprintf('[OK] %s (min=%d, max=%d)\n', baseName, min(D16(:)), max(D16(:)));

    catch ME
        errCount = errCount + 1;
        msg = sprintf('[Hata] %s -> %s', baseName, ME.message);
        fprintf('%s\n', msg); logMsgs(end+1) = msg; %#ok<SAGROW>
    end
end

% --- Özet ---
fprintf('\n--- ÖZET ---\n');
fprintf('İşlenen (OK): %d\n', okCount);
fprintf('Atlanan      : %d\n', skipCount);
fprintf('Hatalı       : %d\n', errCount);
fprintf('Sadece folder1''de: %d | Sadece folder2''de: %d\n', numel(only1), numel(only2));


% --- Log dosyası (opsiyonel) ---
if ~isempty(logMsgs)
    logPath = fullfile(outputFolder, 'fark_islem_log.txt');
    fid = fopen(logPath, 'w'); 
    if fid ~= -1
        fprintf(fid, '%s\n', strjoin(logMsgs, newline));
        fclose(fid);
        fprintf('Log yazıldı: %s\n', logPath);
    end
end

%% --- Yardımcı Fonksiyonlar ---
function [raw12,info] = read16as12(path)
    info = imfinfo(path);
    if info.BitDepth ~= 16
        error('Beklenen 16-bit PNG, bulundu: %d-bit', info.BitDepth);
    end
    A = imread(path);
    if ndims(A)==3
        A = rgb2gray(A);
    end
    % Burada 16-bit kap içinde 0–4095 (12-bit efektif) veri varsayılır
    raw12 = uint16(A);
    % İsteğe bağlı güvenlik: beklenen aralıkta mı?
    if any(raw12(:) > 4095)
        warning('>4095 değerler tespit edildi (%s). Yine de devam ediliyor.', path);
    end
end
