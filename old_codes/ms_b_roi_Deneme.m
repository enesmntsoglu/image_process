%% ms oluştur (dedektör x frame)
num_images = scanX * scanY;
num_det    = size(detpos, 1);

ms = nan(num_det, num_images);   % her satır: dedektör, her sütun: frame
for idx = 1:num_images
    [x_img, y_img] = ind2sub([scanX, scanY], idx);
    I = image_grid{x_img, y_img};                % ilgili frame'in görüntüsü

    for d = 1:num_det
        xi = round(detpos(d,1));
        yi = round(detpos(d,2));
        if xi>=1 && xi<=size(I,2) && yi>=1 && yi<=size(I,1)
            ms(d, idx) = I(yi, xi);              % o dedektörün o frame'deki ölçümü
        else
            ms(d, idx) = NaN;
        end
    end
end

% opsiyonel: NaN'leri 0'a çek (ya da bırak)
ms(isnan(ms)) = 0;

fprintf('ms boyutu: %dx%d | min=%g max=%g\n', size(ms,1), size(ms,2), min(ms(:)), max(ms(:)));

%% b vektörü (sens sırası ile, i hızlı j yavaş; ROI = 25x25)
vx         = 25;                  % sens penceresi
num_blocks = vx * vx;             % 625
assert(size(ms,2) >= scanX*scanY, 'ms sütun sayısı yetersiz.');

% --- ROI başlangıcı: sol-üst (1,1). Ortalamak istersen 13,13 yap.
roi_x0 = 1;     % veya 13
roi_y0 = 1;     % veya 13

% güvenlik: ROI görüntü ızgarasının içinde mi?
assert(roi_x0>=1 && roi_x0+vx-1<=scanX && roi_y0>=1 && roi_y0+vx-1<=scanY, ...
    'ROI (roi_x0, roi_y0) 25x25 pencere ile scan ızgarasının dışında kalıyor.');

% sens sırasındaki 625 frame indeksini hazırla (i hızlı, j yavaş)
[ig, jg] = ndgrid(roi_x0:(roi_x0+vx-1), roi_y0:(roi_y0+vx-1));
frames   = ig + (jg-1)*scanX;     % 25x25
frames   = frames(:).';           % 1x625

% --- Vektörize ve A ile bire bir aynı sıra: önce d=1'in 625'i, sonra d=2'nin 625'i, ...
b = reshape(ms(:, frames).', [], 1);   % boyut: (num_det*625) x 1

% (isteğe bağlı) döngü ile üretip kontrol etmek istersen:
% b_loop = nan(num_det*num_blocks, 1);
% k = 0;
% for j = 1:vx
%   for i = 1:vx
%     k = k + 1;
%     frame_idx = (roi_x0 + i - 1) + (roi_y0 + j - 1)*scanX;
%     for d = 1:num_det
%       row = (d-1)*num_blocks + k;
%       b_loop(row) = ms(d, frame_idx);
%     end
%   end
% end
% assert(isequal(b, b_loop), 'b sırası sens ile uyumlu değil!');
