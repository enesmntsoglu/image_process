%% HEPSİ İÇİN SCALE AYARLA HOCA GÖRMEK İSTİYOR DATAYI AMA HESPİNDE COLOR BAR OLSUN
%% A_matrix ve deneme_9_vx kullanıytorum deneme9 b ve b2 olarak farkılığı var b2 vx'e koordine
%% —————— 7) A ve b normalize et ——————
A = cfg.ms;                    % duyarlılık matrisi
A_norm = A ./ max(A(:));
b_norm = b2 ./ max(b2(:));

%% —————— 8) Lp‐solver parametreleri ——————
p       = 1;               % L1 norm
tol     = 1e-3;            % iterasyon toleransı
max_itr = 1e5;             % maksimum iterasyon sayısı
nu      = 1e-4;            % adım büyüklüğü
eps0    = 1e-10;           % sıfıra bölmeyi önleyen küçük sabit
x0      = zeros(size(A,2),1);    % başlangıç tahmini

 % Derinlik‐bağımlı ağırlık vektörü
 D_diag = diag(A_norm' * A_norm);
 D = D_diag ;

%% —————— 9) L‐curve için λ taraması ve sonuçları saklama ——————
lambda_range = logspace(-1,1.4,5);
num_lambda   = numel(lambda_range);
res_norm     = zeros(num_lambda,1);
reg_norm     = zeros(num_lambda,1);
curvature    = zeros(num_lambda,1);
X_lambdas    = cell(num_lambda,1);   % her λ için x_lambda saklanacak

fprintf('Lambda tarama başlıyor...\n');
for i = 1:num_lambda
    lam = lambda_range(i);
    % x_lambda çözümünü al
    x_lambda = Lp_solver_depthver2( ...
        A_norm, b_norm, p, lam, tol, max_itr, nu, eps0, x0, D);
    % Normları kaydet
    res_norm(i) = norm(A_norm*x_lambda - b_norm,2); 
    reg_norm(i) = norm(x_lambda,1);
    % x_lambda’yı sakla
    X_lambdas{i} = x_lambda;
    fprintf('  λ = %.2e  →  res = %.3e, reg = %.3e\n', lam, res_norm(i), reg_norm(i));
end
fprintf('Tarama tamamlandı.\n\n');

%% —————— 10) Eğrilik hesapla ve optimal λ’yı bul ——————
[~,~,curv]   = compute_curvature(reg_norm, res_norm, lambda_range);
curvature    = curv;       % döngü dışı da sakla
[~,idx_LC]  = max(curvature);
opt_lambda  = lambda_range(idx_LC);
fprintf('Optimal λ (L-curve): %.3e (index %d)\n\n', opt_lambda, idx_LC);

%% —————— 10b) Eğrilik vs λ grafiği ——————
figure('Name','L-Curve Curvature','Color','white');
semilogx(lambda_range, curvature, '-o','MarkerSize',4);
hold on;
semilogx(opt_lambda, curvature(idx_LC), 'ro','MarkerSize',8,'LineWidth',1.5);
hold off;
xlabel('\lambda');
ylabel('Curvature');
title('L-Curve Eğrilik vs \lambda');
grid on;
legend('Eğrilik','Optimal \lambda','Location','best');

%% —————— 11) L-Curve grafiğini çiz ——————
figure('Name','L-Curve','Color','white');
loglog(res_norm, reg_norm, '-o','MarkerSize',4);
hold on;
loglog(res_norm(idx_LC), reg_norm(idx_LC), 'ro','MarkerSize',8,'LineWidth',1.5);
hold off;
xlabel('Residual norm ‖A x(\lambda) - b‖_2');
ylabel('Regularization norm ‖x(\lambda)‖_1');
title('L-Curve');
grid on;
legend('L-Curve','Optimal \lambda','Location','best');

%% —————— 12) Optimal X’i al ve ölçekle ——————
x_opt = X_lambdas{idx_LC};                % doğrudan sakladığımız
x_opt = x_opt * max(b) / max(A(:));       % orijinal ölçeğe geri döndür

% %% —————— 13) Manuel İnceleme İmkanı —————— BUNU DÜZELTTT.....
% % Artık X_lambdas hücresinde her λ için x var. 
% % Örneğin 10. lambda için:
% j = 1;  
% lam_j = lambda_range(j);
% xj    = X_lambdas{j} * max(b)/max(A(:));
% fprintf('\nManual inspect: λ(%d) = %.3e\n', j, lam_j);
% 
% % 2D/3D görselleştirme:
% Xj_vol = reshape(xj, vx, vx, nt);
% figure('Name',sprintf('Manual λ=%.2e Slice %d',lam_j,ceil(nt/2)),'Color','white');
% imagesc(Xj_vol(:,:,ceil(nt/2))); axis equal tight off;
% colormap hot; colorbar;
% title(sprintf('Slice %d for λ=%.2e',ceil(nt/2),lam_j));


%% —————— 12) Yeniden düzenle ve göster ——————
% x_opt → 3B hacme dök
vx   = 35;    % blok kenar uzunluğu
nt   = 20;    % z-katman sayısı
X_vol = reshape(x_opt, vx, vx, nt);

%% —————— 2D Dilimleri Tek Sayfada Göster (Yöntem 1) ——————
[~,~,nt] = size(X_vol);
nCols   = ceil(sqrt(nt));
nRows   = ceil(nt/nCols);

figure('Name','Rekonstrüksiyon Katmanları','Color','white');
tl = tiledlayout(nRows, nCols, ...
       'TileSpacing','compact', ...
       'Padding','compact');

for t = 1:nt
    ax = nexttile;
    imagesc(X_vol(:,:,t), [min(X_vol(:)) max(X_vol(:))]); 
    axis(ax,'off','equal');
    title(ax, sprintf('Slice %d', t), 'FontSize', 8);
end
colormap hot;
sgtitle('Rekonstrüksiyon Katmanları (2D Dilimler)','FontSize',14);

%% —————— 3B LC Rekonstrüksiyon ve Projeksiyonlar ——————
% LC sonucu 1D → 3D hacme (tekrar)
X_LC = X_vol;  
threshold_LC = max(X_LC(:)) * 0.75;

[faces, verts] = isosurface(X_LC, threshold_LC);

figure('Name','LC 3B & Projeksiyon','Color','white');
ax2 = axes('Position',[0.1 0.1 0.8 0.8]);
hold(ax2,'on');
daspect(ax2,[1 1 1]);
view(ax2,3);
grid(ax2,'on');

% 1) Ana 3D yüzey
patch(ax2, 'Faces',faces,'Vertices',verts, ...
    'FaceColor','red','EdgeColor','none','FaceAlpha',0.8);

% 2) XY-düzlemine projeksiyon (z=1)
pv = verts; pv(:,3)=1;
patch(ax2, 'Faces',faces,'Vertices',pv, ...
    'FaceColor','green','EdgeColor','none','FaceAlpha',0.2);

% 3) YZ-düzlemine projeksiyon (x=1)
pv = verts; pv(:,1)=1;
patch(ax2, 'Faces',faces,'Vertices',pv, ...
    'FaceColor','green','EdgeColor','none','FaceAlpha',0.2);

% 4) XZ-düzlemine projeksiyon (y=1)
pv = verts; pv(:,2)=1;
patch(ax2, 'Faces',faces,'Vertices',pv, ...
    'FaceColor','green','EdgeColor','none','FaceAlpha',0.2);

camlight(ax2,'headlight');
lighting(ax2,'gouraud');

xlim(ax2,[1 vx]);  ylim(ax2,[1 vx]);  zlim(ax2,[1 nt]);
xticks(ax2,0:5:vx); yticks(ax2,0:5:vx); zticks(ax2,0:5:nt);
xlabel(ax2,'X','FontSize',14);
ylabel(ax2,'Y','FontSize',14);
zlabel(ax2,'Z','FontSize',14);

title(ax2,'L-Curve (LC) Rekonstrüksiyon 3B + Projeksiyon','FontSize',18);

hold(ax2,'off');


%%
function [log_reg, log_res, curvature] = compute_curvature(reg_norm, res_norm, lambda_range)
    % compute_curvature  L-curve eğriliğini hesaplar
    %
    % [log_reg, log_res, curvature] = compute_curvature(reg_norm, res_norm, lambda_range)
    %
    % reg_norm: regularizasyon normları (||x(λ)||)
    % res_norm: artık normları (||A x(λ) − b||)
    % lambda_range: λ değerleri vektörü
    %
    % log_reg, log_res: logaritmik normlar
    % curvature: L-curve üzerindeki eğrilik değerleri

    log_reg = log(reg_norm(:));
    log_res = log(res_norm(:));
    t       = log(lambda_range(:));

    % Birinci türevler
    dlogr = gradient(log_reg, t);
    dlogR = gradient(log_res, t);

    % İkinci türevler
    d2logr = gradient(dlogr, t);
    d2logR = gradient(dlogR, t);

    % Eğrilik formülü
    curvature = abs(d2logR .* dlogr - dlogR .* d2logr) ...
                ./ ( (dlogR.^2 + dlogr.^2 + eps()).^(3/2) );
end

