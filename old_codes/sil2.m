%% 1) Dosya adlarını oku ve gerçekten ilk 10’unu yazdır
files = dir(fullfile(image_folder,'pos_*.png'));
fileNames = {files.name}.';         % hücre dizisine çevir ve transpose et
disp('First 10 filenames:');
disp(fileNames(1:min(10,end)));

%% 2) coords matrisini oluşturduğun yere dikkat et, sonra sıralayıp ilk 10’u yazdır
% coords zaten daha önce şöyle doluyordu:
% coords = zeros(numel(files),2);
% for k = 1:numel(files)
%   tok = regexp(files(k).name,'pos_(\d+)x(\d+)\.png','tokens');
%   coords(k,1) = str2double(tok{1}{1});
%   coords(k,2) = str2double(tok{1}{2});
% end

[~, order] = sortrows(coords, [1 2]);
coords_sorted = coords(order,:);
disp('First 10 sorted coords:');
disp(coords_sorted(1:min(10,end),:));

%% 3) detpos matrisinin ilk 10 satırına bak
disp('First 10 detpos:');
disp(detpos(1:min(10,end),:));

%% 4) ms ve b matrisinin boyutlarını ve ilk birkaç elemanını kontrol et
[num_detectors, num_images] = size(ms);
fprintf('size(ms) = [%d  %d]\n', num_detectors, num_images);

disp('ms(1:5,1:5) =');
disp(ms(1:min(5,num_detectors), 1:min(5,num_images)));

b = reshape(ms, [], 1);
fprintf('length(b) = %d\n', numel(b));
disp('b(1:20) =');
disp(b(1:min(20,end)));
%%

% … dosyaları okudunuz, coords’u çıkardınız …
[~, order] = sortrows(coords,[1 2]);

% Bunu mutlaka yaptığınızdan emin olun:
coords = coords(order,:);
files  = files(order);

% Şimdi gerçekten sıralandı mı kontrol edelim:
sortedNames = {files.name}.';
fprintf('First 10 sorted filenames:\n');
disp(sortedNames(1:10));

fprintf('First 10 sorted coords:\n');
disp(coords(1:10,:));
%%
%% Test A: image_grid’in doğru dolup dolmadığını gör
% Örneğin pos_1x1.png içeriği image_grid{1,1} ile aynı mı?
fn_test = 'pos_1x1.png';
I_orig = imread(fullfile(image_folder,fn_test));
I_grid = image_grid{1,1};

figure; 
subplot(1,2,1), imshow(I_orig, []), title('Orijinal pos\_1x1.png');
subplot(1,2,2), imshow(I_grid, []),  title('image\_grid{1,1}');

% Test B: b vektörünün dedektör×frame haritası
num_detectors = size(ms,1);
num_frames    = size(ms,2);
B = reshape(b, num_detectors, num_frames);

figure;
imagesc(B);
colormap hot; colorbar;
xlabel('Frame index');
ylabel('Detector index');
title('b: Detector×Frame map');

% Test C: ms matrisinden bir orta frame’i göster
mid_frame = ceil(num_frames/2);
figure;
plot(ms(:,mid_frame), 'o-');
xlabel('Detector index');
ylabel('Signal');
title(sprintf('ms(:, %d) – orta frame sinyali', mid_frame));

%Test D: Reconstruction grid’in (vx×vx×nt) orta katmanını görüntüle
% Burada vx, nt reconstruction grid’in boyutları
nvox = numel(x_opt);
nt   = cfg.vol(3);
vx   = round(sqrt(nvox/nt));
Xvol = reshape(x_opt, vx, vx, nt);

mid_slice = ceil(nt/2);
figure;
imagesc(Xvol(:,:,mid_slice));
axis equal tight off;
colormap hot; colorbar;
title(sprintf('Reconstruction mid-slice (z = %d)', mid_slice));


%%

%% — sens sıralamasına göre b oluştur —
vx        = 30;                % sens fonksiyonundaki blok kenarı
scanX     = 30;                % tarama boyutu
scanY     = 30;
num_det   = size(detpos,1);    % dedektör sayısı
num_blocks= vx * vx;           % sens döngüsündeki toplam k (j,i kombinasyonu)

% orijinal ms: num_det x (scanX*scanY)
% şimdi b'yi sens sıralamasına göre boyutlandır
b2 = nan(num_blocks * num_det, 1);

k = 0;
for j = 1:vx                % sens fonksiyonundaki 'j' döngüsü
  for i = 1:vx              % sens fonksiyonundaki 'i' döngüsü
    k = k + 1;              % blok indeksi

    % bu bloğa karşılık gelen frame numarası (ind2sub sıralamasına uygun)
    frame_idx = i + (j-1)*scanX;  

    for d = 1:num_det
      % ms(d, frame_idx) zaten o detektörün o frame'deki okumaları
      row      = (d-1)*num_blocks + k;
      b2(row) = ms(d, frame_idx);
    end
  end
end

% Sonuç: A = sens(jac) ile tamamen örtüşen sıralamada b:
b = b2;
