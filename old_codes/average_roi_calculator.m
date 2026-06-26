% -----------------------------
% CSV (X,Y,Width,Height) OKUMA
% + AUTO CONTRAST (imadjust+stretchlim)
% + ROI’Yİ GÖSTERME
% + PİKSEL YOĞUNLUĞU ORT. + GRAFİK
% -----------------------------

% 0) Ayarlar
imageFolder = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Images\27_06_25\100_2';
coordsFile  = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\2.csv';

% 1) CSV’yi oku
T = readtable(coordsFile);
x = T.X(1);
y = T.Y(1);
w = T.Width(1);
h = T.Height(1);

% 2) Dosya listesini al
files = dir(fullfile(imageFolder,'*.tiff'));
if isempty(files)
    error('Resim bulunamadı.');
end

% 2.1) Tarihe göre sıralama
[~, sortIdx] = sort([files.datenum]);
files        = files(sortIdx);

% 2.2) Sıralamayı kontrol için ekrana yazdır
fprintf('--- Dosyalar tarihe göre sıralandı: ---\n');
for i = 1:numel(files)
    fprintf('%s    %s\n', files(i).name, datestr(files(i).datenum,'yyyy-mm-dd HH:MM:SS'));
end
fprintf('---------------------------------------\n');

% 3) İlk görüntüyü orijinal haliyle oku
firstFile = fullfile(imageFolder, files(1).name);
I0        = imread(firstFile);
if ndims(I0)==3, I0 = rgb2gray(I0); end

% 4) Sadece gösterim için Auto Contrast uygula (hesaplamayı etkilemez)
lims   = stretchlim(I0);
I0_vis = imadjust(I0, lims, []);

% 5) İlk görüntüyü göster, ROI çiz
figure('Name','Auto Contrast Görselleştirme','NumberTitle','off');
imshow(I0_vis); hold on;
rectangle('Position',[x y w h], 'EdgeColor','r','LineWidth',2);
title('ROI (Auto Contrast Görsel)');
hold off;

% 6) Hesaplama için mask oluştur (orijinal I0 kullanılır)
[H,W] = size(I0);
mask  = false(H,W);
mask(y:y+h-1, x:x+w-1) = true;

% 7) Tüm dizide ORİJİNAL piksellerle ortalama yoğunluğu hesapla
N = numel(files);
meanInt = zeros(N,1);
for k = 1:N
    I = imread(fullfile(imageFolder, files(k).name));
    if ndims(I)==3, I = rgb2gray(I); end
    meanInt(k) = mean( I(mask) );
end

% 8) Zaman serisi grafiği
figure('Name','ROI Ortalama Yoğunluğu Zaman Serisi','NumberTitle','off');
plot(1:N, meanInt, '-o','LineWidth',1.5);
xlabel('Resim Sırası (tarihe göre sıralı dosyalar)');
%xlabel('Her 10 saniyede bir görüntü dizisi');
ylabel('Ortalama Piksel Yoğunluğu');
title('Seçilen ROI Bölgesinin Ortalama Yoğunluğu');
grid on;