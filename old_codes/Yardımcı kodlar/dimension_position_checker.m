%% Test için Bilinen Değerlerle Jac Matrisi Oluşturma
vx = 25;               % Tarama çözünürlüğü (hem x hem y)
num_voxels = vx * vx * 20;  
% jac matrisinin boyutu: [(vx+vx-1) x (vx+vx-1) x 20 x 1] = [49 x 49 x 20 x 1]
jac = zeros(49, 49, 20, 1);
for idx = 1:numel(jac)
    jac(idx) = idx;    % Her eleman benzersiz bir değer alır
end

%% Sens Fonksiyonunu Kullanarak A Matrisini Oluşturma
A = sens(jac);  % A'nın boyutu: [vx*vx x (25*25*20)] = [625 x 12500]

%% b Vektörünü Aynı Mantıkla Oluşturma
b_expected = zeros(vx*vx, 1);
k = 0;
for j = 1:vx
    for i = 1:vx
        k = k + 1;
        % sens fonksiyonundaki blok seçimine uygun alt-matris:
        block = jac(i : vx+i-1, j : vx+j-1, 1:20, 1);
        b_expected(k) = sum(block, 'all'); % Örneğin bloktaki toplam değeri alıyoruz
    end
end

%% Test: A Matrisindeki Her Satırın Toplamı b Vektöründeki Karşılık Gelen Değere Eşit Olmalı
consistent = true;
for row = 1:size(A, 1)
    if abs(sum(A(row, :)) - b_expected(row)) > 1e-10
         fprintf('Frame %d uyumsuz: sum(A(%d,:)) = %f, b_expected(%d) = %f\n', ...
                 row, row, sum(A(row, :)), row, b_expected(row));
         consistent = false;
    end
end

if consistent
    disp('Test başarılı: A matrisi ve b vektörü aynı dedektör frame sıralamasını kullanıyor.');
else
    disp('Test başarısız: A matrisi ve b vektöründe sıralama uyumsuzluğu var.');
end

%% Sensitivity Matrix Oluşturma Fonksiyonu (sens)
function m3 = sens(jac)
    vx = 25; % Tarama çözünürlüğü (hem x hem y)
    k = 0;
    for j = 1:vx
        for i = 1:vx
            m1 = jac(i : vx+i-1, j : vx+j-1, 1:20, 1);
            volm1 = numel(m1);  % Blok hacmi
            m2 = reshape(m1, 1, volm1);  % Bloğu tek satırlık vektöre çeviriyoruz
            k = k + 1;
            m3(k, :) = m2;  % Her bloğu m3 matrisine satır olarak ekliyoruz
        end
    end
end
