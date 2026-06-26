% Tek bir görüntü ile b ve X matrisini hesaplama ve X'in 3D Görselleştirilmesi

% Clear workspace and initialize environment
clear;
clc;

% Görüntü dosya yolunu tanımla
image_folder = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Final_Work_Space';
image_name = 'single_image.png'; % Tek bir görüntü kullanarak deneme yapmak için
image_path = fullfile(image_folder, image_name);

% A matrisini ve diğer konfigürasyon verilerini simule etmek için yapıyı tanımla
volume_size = [37, 37, 20]; % Örnek hacim boyutu
cfg.ms = rand(1, prod(volume_size)); % Tek satırlık A matrisi (örnek olarak rastgele değerler kullanıldı)

% b matrisini hesapla
try
    % Görüntüyü yükle
    img = imread(image_path);

    % Normalize et ve piksel yoğunluklarının toplamını hesapla
    img_normalized = double(img) / 255;
    b = sum(img_normalized(:)); % Tek bir değerden oluşan `b` matrisi

    % b matrisini göster
    fprintf('Tek görüntüden hesaplanan b matrisi:\n');
    disp(b);
catch ME
    error("Görüntü işlenirken hata oluştu: %s", ME.message);
end

% A ve b matrislerinden X değerini hesapla
try
    % Tek satırlık A matrisi
    A = cfg.ms; 

    % X değerini hesapla
    X = A \ b; % `X` tek bir değer olarak hesaplanır
    X_volume = reshape(X, volume_size); % X'i hacimsel yapıya yeniden şekillendir

    % Sonucu göster
    fprintf('Tek görüntü ile hesaplanan X değeri:\n');
    disp(X);

    % 3D Görselleştirme - Isosurface
    figure;
    p = patch(isosurface(X_volume, 0.5 * max(X_volume(:))));
    set(p, 'FaceColor', 'red', 'EdgeColor', 'none');
    camlight; lighting phong;
    title('3D Visualization of Reconstructed X Matrix (Isosurface)');
    xlabel('X'); ylabel('Y'); zlabel('Z');
    axis vis3d;
    grid on;

    % Orta katmanda dilim görüntüleme - Slice
    figure;
    slice(X_volume, size(X_volume, 2)/2, size(X_volume, 1)/2, size(X_volume, 3)/2);
    shading interp;
    colorbar;
    title('Reconstructed X Matrix - Middle Slice');
    xlabel('X'); ylabel('Y'); zlabel('Z');
catch ME
    warning("X matrisi hesaplama sırasında hata oluştu: %s", ME.message);
end
