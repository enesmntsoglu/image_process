
% `A` matrisini ve `b` matrisini yükle
load('config_data.mat', 'cfg'); % Önceden hesaplanan `A` matrisi (cfg.ms)
load('b_matrix.mat', 'b');      % Önceden hesaplanan `b` matrisi

% `A` matrisini ve `b` vektörünü tanımla
A = cfg.ms;

% `X` çözümü için `A \ b` kullanarak lineer çözüm
try
    X = A \ b; % `X` değerini hesapla
    volume_size = [37, 37, 20]; % Hedef hacim boyutu
    X_volume = reshape(X, volume_size); % `X` sonucunu hacim boyutlarına göre yeniden şekillendir

    % Sonucu görüntüle
    figure;
    slice_view = squeeze(X_volume(:, :, 10)); % Orta katmandan örnek görüntü
    imagesc(slice_view);
    colorbar;
    title('Reconstructed X Matrix - Middle Slice');
catch ME
    warning("X matrisi hesaplama sırasında hata oluştu: %s", ME.message);
end
