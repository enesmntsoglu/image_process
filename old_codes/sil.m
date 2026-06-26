%% Görselleştirme 1 (2D Heatmap Haline Getirilmiş Zaman Serisi)
disp('Görselleştirme 1: Bir dedektörün zaman serisini 2D olarak göster');
detector_idx = input(sprintf('1–%d arasında dedektör indeksi seçin: ', num_detectors));

% 1) Zaman serisini vektör halinde al
z = ms(detector_idx, :);

% 2) 2D ızgaraya çevir (scanX satır × scanY sütun)
Z = reshape(z, scanX, scanY);

% 3) Görselleştir
figure;
imagesc(Z, [min(z) max(z)]);
axis equal tight;
colormap hot;
colorbar;
title(sprintf('Dedektör %d – Zaman Serisi Heatmap', detector_idx));

% Ekseni kapatma yerine etiketleyelim
xlabel('Scan Y indeksi');
ylabel('Scan X indeksi');
%%
imagesc(Z);
colormap(hot);
colorbar;
set(gca,'Color','k'); 
%%
sum(isnan(Z),'all'), sum(Z(:)==0)
%%
detector_idx = 60;                     % istediğiniz detektör
z = ms(detector_idx, :);               % o detektörün tüm frame’leri
Z = reshape(z, scanX, scanY);          % 2D heatmap’e çevir
figure;
imagesc(Z, [min(z) max(z)]);           % otomatik değil, kendi min–max’inizi ayarlayın
axis equal tight;
colormap hot;
colorbar;
xlabel('Tarama Y İndeksi');
ylabel('Tarama X İndeksi');
title(sprintf('Dedektör %d — Frame Heatmap', detector_idx));
%%
%% Görselleştirme 2: Belirli Bir Frame için Dedektör Izgarası (Son fazlalık atlanarak)
disp('Görselleştirme 2: Dedektör ızgarası (fazlalık atlandı)');
frame_idx = input(sprintf('1–%d arasında frame indeksi seçin: ', num_images));
ints      = ms(:, frame_idx);

% 1) Boş bir nan-matris oluştur
intGrid = nan(detector_cols, detector_rows);

% 2) Satır/kolon indekslerini hesapla
dx     = (detpos(:,1) - source_pos(1)) / detector_spacing;
dy     = (detpos(:,2) - source_pos(2)) / detector_spacing;
rowIdx = round(dy + (detector_cols+1)/2);
colIdx = round(dx + (detector_rows+1)/2);

% 3) Yoğunluk değerlerini matrise yerleştir
for k = 1:length(ints)
    if rowIdx(k)>=1 && rowIdx(k)<=detector_cols && colIdx(k)>=1 && colIdx(k)<=detector_rows
        intGrid(rowIdx(k), colIdx(k)) = ints(k);
    end
end

% 4) “Fazlalık”  ölçütü: eğer tek sayıda ise son birimi bırak
effRows = detector_rows - mod(detector_rows,2);   % kaç sütun kullanılacak
effCols = detector_cols - mod(detector_cols,2);   % kaç satır kullanılacak

% 5) Çizim: yalnızca 1:effCols,1:effRows bloğunu göster
figure;
imagesc( intGrid(1:effCols, 1:effRows), [0 4095] );
axis equal tight off;
colormap hot;
colorbar;
xlabel('Dedektör Kolon İndeksi (1→effRows)');
ylabel('Dedektör Satır İndeksi (1→effCols)');
title(sprintf('Frame %d – %dx%d Izgara (Son Fazlalık Atlandı)', ...
               frame_idx, effCols, effRows));

% 6) Hücre ortasına değer yaz
for i = 1:effCols
    for j = 1:effRows
        v = intGrid(i,j);
        if ~isnan(v)
            text(j, i, sprintf('%.0f', v), ...
                 'HorizontalAlignment','center', ...
                 'VerticalAlignment','middle', ...
                 'Color','w', 'FontWeight','bold');
        end
    end
end
%%
% <<< Kodunuzu çalıştırdığınız dizinde çalıştırın >>>
% scanX, scanY, image_grid, ms, detpos zaten tanımlı olmalı

% Hangi pozisyonlardan örnek isterseniz, ben ortayı ve sol-üstü seçtim:
sample1 = image_grid{ceil(scanX/2), ceil(scanY/2)};  % ortadaki hücre
sample2 = image_grid{1, 1};                           % sol-üst hücre

% ms ve detpos zaten bellekte; hepsini bir arada kaydediyoruz:
save('diagnostic_data.mat', 'ms', 'detpos', 'sample1', 'sample2', '-v7.3');


%%
% Adım 3: Görüntüleri Oku (12-bit ham veri olarak)
disp('Adım 3: Görüntü dosyaları yükleniyor...');

% <<< Burayı kendi klasör yolunuza göre güncelleyin >>>
image_folder = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Image_Saver\Analiz\24_04\sw_1\first_loop\average_minus_noise';

image_grid = cell(scanX, scanY);
temp_img   = [];
files      = dir(fullfile(image_folder,'pos_*.png'));
num_images = numel(files);

image_grid = cell(scanX, scanY);
for y = 1:scanY
    for x = 1:scanX
        name = sprintf('pos_%dx%d.png', x, y);
        path = fullfile(image_folder, name);
        if ~exist(path,'file')
            warning('Bulunamadı: %s', name);
            continue;
        end

        % --- burayı bu üç satırla değiştirin ---
        A = imread(path);
        if ndims(A)==3, A = rgb2gray(A); end
        raw = double(A);
        % ------------------------------------

        image_grid{x,y} = raw;
        if isempty(temp_img)
            temp_img = raw;
        end
    end
end

disp(['Yükleme tamamlandı (', num2str(toc),' s).']);
%%
% Mevcut oturumunuzda ms ve detpos olduğu varsayılıyor
% Çalışma dizininize bu iki CSV’yi yazın:
csvwrite('ms_debug.csv',      ms);
csvwrite('detpos_debug.csv',  detpos);

% Ayrıca örnek olması için bir adet ham 12-bit görüntüden küçük bir kesit de alın:
sample = image_grid{round(scanX/2), round(scanY/2)};  
csvwrite('sample_debug.csv', sample(1:100,1:100));  % 100×100’lük köşe
%%
% Örnek subset data oluşturma:
% (scanX, scanY önceden tanımlı; image_grid, ms, detpos hazır)
centerX = round(scanX/2);
centerY = round(scanY/2);

sample1 = image_grid{centerX, centerY};   % ortadan bir görüntü
sample2 = image_grid{1,1};                % köşeden bir görüntü

save('debug_subset.mat', 'ms', 'detpos', 'sample1', 'sample2', '-v7');
%%
% 1) Matris boyutları ve küçük bir preview:
fprintf('size(ms) = [%d %d]\n', size(ms));
disp('ms ilk 5×5 altküme:');
disp(ms(1:min(5,end), 1:min(5,end)));

fprintf('size(detpos) = [%d %d]\n', size(detpos));
disp('detpos ilk 5 koordinat:');
disp(detpos(1:min(5,end), :));

% 2) İki örnek alt-görüntü crop’u:
scanX = size(image_grid,1);
scanY = size(image_grid,2);
cx = round(scanX/2); cy = round(scanY/2);
cropSize = 2;  % merkez pikselin etrafında 5×5 crop

% Ortadaki görüntüden küçük bir crop:
I1 = image_grid{cx,cy};
xrng = max(1,cx-cropSize):min(size(I1,1),cx+cropSize);
yrng = max(1,cy-cropSize):min(size(I1,2),cy+cropSize);
crop1 = I1(xrng, yrng);
disp('Crop1 (ortadan 5×5):'); disp(crop1);

% Sol üstten bir crop:
I2 = image_grid{1,1};
xr2 = 1:1+2*cropSize; yr2 = 1:1+2*cropSize;
crop2 = I2(xr2, yr2);
disp('Crop2 (köşeden 5×5):'); disp(crop2);
%%
%% Diyelim ki workspace’inde zaten ms, detpos ve image_grid var
% scanX, scanY da tanımlı olmalı

% 1) Örnek görüntüleri seç
%    Orta noktadaki görüntü:
cx = round(scanX/2);
cy = round(scanY/2);
sample1 = image_grid{cx, cy};

%    Sol üst köşedeki görüntü:
sample2 = image_grid{1, 1};

%    İstersen daha fazla örnek ekleyebilirsin:
% sample3 = image_grid{scanX, scanY};

% 2) ms’in ilk 5×5’lik altkümesini de debug için görmek istersen:
ms_sub5 = ms(1:5, 1:5);
detpos_sub5 = detpos(1:5,:);

% 3) Hepsini tek dosyada kaydet
save('data.mat', 'ms', 'detpos', 'sample1', 'sample2', 'ms_sub5', 'detpos_sub5','scanX', 'scanY','detector_rows', 'detector_cols', 'detector_spacing', 'detector_radius','source_pos','detector_idx','Z', '-v7.3');

fprintf('subset_data.mat oluşturuldu: içinde ms, detpos, sample1, sample2, ms_sub5, detpos_sub5 var.\n');



%%% diyelim frame_idx = zaman serisinde tepe yaptığı indekse yakın
frame_idx = 1100;  

% ms: [num_detectors × num_images] matrix
ints = ms(:, frame_idx);   

% dedektör pozisyonlarınız detpos (num_detectors × 2)
% buradan her bir detektörü 2D hücreye:
detMap = nan(detector_rows, detector_cols);
dx = (detpos(:,1)-source_pos(1))/detector_spacing;
dy = (detpos(:,2)-source_pos(2))/detector_spacing;
rowIdx = round(dy + (detector_cols+1)/2);
colIdx = round(dx + (detector_rows+1)/2);

for k = 1:numel(ints)
  detMap(rowIdx(k), colIdx(k)) = ints(k);
end

figure;
imagesc(detMap, [0 4095]);
axis equal tight off;
colormap hot; colorbar;
title(sprintf('Frame %d – Tüm Dedektörlerin Okuması', frame_idx));

%%
% 1) Zaman serisini vektör halinde al
z = ms(detector_idx, :);

% 2) 2D ızgaraya çevir ve transpoze et
Z = reshape(z, scanY, scanX)';

% 3) Görselleştir
figure;
imagesc(Z, [min(z) max(z)]);  % istersen [0 4095] sabit aralık da kullanabilirsin
axis equal tight off;
colormap hot;
colorbar;
title(sprintf('Dedektör %d – Dedektor Frame Heatmap', detector_idx));
xlabel('Scan Y indeksi');
ylabel('Scan X indeksi');
%%
slice = X_vol(:,:,t);      % örneğin bir 2D slice

mn = min(slice(:));
mx = max(slice(:));
if mn == mx
    disp('Tüm değerler aynı');
else
    disp('Değerler farklı');
end

%%
% vx, nt zaten tanımlı olduğunu varsayıyoruz
% 1) detektör sayısını bulun (A’nın satır sayısıyla aynı):
num_detectors = size(A,1);   % örn. 48

% 2) frame sayısını hesaplayın
num_frames    = numel(b) / num_detectors;  % 43200/48 = 900

% 3) reshape ile ölçümleri matris haline getirin:
B = reshape(b, num_detectors, num_frames);

% 4) Görselleştirme (frame’i y ekseni, detektörü x ekseni):
figure('Name','b measurements','Color','white');
imagesc(B');              % B' ile frame’leri satır, detektörleri sütun olarak göster
colormap hot; colorbar;
xlabel('Detector index');
ylabel('Frame index');
title('Measurement b as Detector×Frame map');




%%
 %Doğru oryantasyon için:
imagesc(b);           % rows=detektör, cols=frame
xlabel('Frame index');
ylabel('Detector index');
title('Measurement b as Detector×Frame');
colorbar;

%%
%%
%%
%%%%
%%
%%
%%
%%
%%
%% —————— 11b) Manuel λ Keşfi ——————
% Kullanılabilir tüm λ değerlerini yazdır
fprintf('\nManual λ exploration:\n');
for i = 1:num_lambda
    fprintf('  %2d: λ = %.3e\n', i, lambda_range(i));
end

% Kullanıcıdan bir indeks al
sel = input('Görselleştirmek için λ indeksi seçin (1–num_lambda): ');
sel = max(1,min(num_lambda,round(sel)));
lam_sel = lambda_range(sel);
fprintf('Seçilen λ = %.3e (index %d)\n', lam_sel, sel);

% Seçilen λ ile yeniden çöz
x_manual = Lp_solver_depthver2( ...
    A_norm, b_norm, p, lam_sel, tol, max_itr, nu, eps0, x0, D);
x_manual = x_manual * max(b) / max(A(:));   % orijinal ölçeğe dönüş

% 1D → 3D hacme dök
X_man = reshape(x_manual, vx, vx, nt);

%%% —————— 11b) Manuel λ Keşfi ve Görselleştirme ——————
fprintf('\nManual λ exploration:\n');
for i = 1:num_lambda
    fprintf('  %2d: λ = %.3e\n', i, lambda_range(i));
end
sel = input('Görselleştirmek için λ indeksi seçin (1–num_lambda): ');
sel = max(1,min(num_lambda,round(sel)));
lam_sel = lambda_range(sel);
fprintf('Seçilen λ = %.3e (index %d)\n', lam_sel, sel);

% Seçilen λ ile yeniden çözüm
x_manual = Lp_solver_depthver2( ...
    A_norm, b_norm, p, lam_sel, tol, max_itr, nu, eps0, x0, D);
x_manual = x_manual * max(b) / max(A(:));  % orijinal ölçeğe dönüş

% 1D → 3D hacme dök
X_man = reshape(x_manual, vx, vx, nt);

%% —————— 11c) Rekonstrüksiyon Diagnostikleri ——————
fprintf('\n*** Reconstruction Diagnostics ***\n');
nNaN    = sum(isnan(x_manual));
nInf    = sum(isinf(x_manual));
nNeg    = sum(x_manual < 0);
minVal  = min(x_manual);
maxVal  = max(x_manual);
meanVal = mean(x_manual);

fprintf(' NaN count   : %d\n', nNaN);
fprintf(' Inf count   : %d\n', nInf);
fprintf(' Neg count   : %d\n', nNeg);
fprintf(' Min / Max   : %.2e  /  %.2e\n', minVal, maxVal);
fprintf(' Mean        : %.2e\n', meanVal);

if nNaN>0 || nInf>0
    warning('Reconstructed x contains NaN or Inf values. Solver parametrelerini gözden geçirin.');
end

% Değer dağılımı için histogram
figure('Name','x\_manual Histogram','Color','white');
histogram(x_manual, 50);
xlabel('x values'); ylabel('Frequency');
title(sprintf('Histogram of x\\_manual for λ = %.2e', lam_sel));

%% —————— 11d) 2D Dilimleri Göster ——————
figure('Name',sprintf('All 2D Slices for λ=%.2e',lam_sel),'Color','white');
tl2 = tiledlayout(ceil(sqrt(nt)),ceil(sqrt(nt)), ...
                 'TileSpacing','compact','Padding','compact');
for t = 1:nt
    ax = nexttile;
    imagesc(X_man(:,:,t));    % otomatik renk skalası
    axis(ax,'off','equal');
    title(ax,sprintf('Slice %d',t),'FontSize',8);
end
colormap hot;
sgtitle(sprintf('Manual λ Slices (λ=%.2e)',lam_sel),'FontSize',14);

%% —————— 11e) 3D Isosurface Görselleştirme ——————
thm = max(X_man(:)) * 0.1;
[faces_m, verts_m] = isosurface(X_man, thm);

figure('Name',sprintf('3D Manual λ=%.2e',lam_sel),'Color','white');
ax3 = axes('Position',[0.1 0.1 0.8 0.8]); hold(ax3,'on');
daspect(ax3,[1 1 1]); view(ax3,3); grid(ax3,'on');

% Ana yüzey
patch(ax3,'Faces',faces_m,'Vertices',verts_m, ...
      'FaceColor','blue','EdgeColor','none','FaceAlpha',0.8);
% XY projeksiyonu (z=1)
proj_m = verts_m; proj_m(:,3)=1;
patch(ax3,'Faces',faces_m,'Vertices',proj_m, ...
      'FaceColor','blue','EdgeColor','none','FaceAlpha',0.2);

camlight(ax3,'headlight'); lighting(ax3,'gouraud');
xlabel(ax3,'X'); ylabel(ax3,'Y'); zlabel(ax3,'Z');
title(ax3,sprintf('3D Manual Reconstruction (th=%.2e)',thm),'FontSize',16);
hold(ax3,'off');
