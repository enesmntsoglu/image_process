% Only clear the 'cfg' variable to avoid clearing other data
% clear cfg cfgs
% clc

%% --- SİMÜLASYON VE HACİM AYARLARI ---
volume_size = [51, 51, 20];
cfg.nphoton   = 1e8;
cfg.vol       = uint8(ones(volume_size)); % Detector field of view (FOV)
cfg.srcpos    = [26, 26, 1];             % Kaynak pozisyonu (merkezde)
cfg.unitinmm  = 0.1;                     % Birim boyutu (mm)
cfg.srcdir    = [0, 0, 1];
cfg.gpuid     = 1;
cfg.autopilot = 1;
cfg.issrcfrom0 = 0;
cfg.prop      = [0 0 1 1; 0.02 1 0.81 1.34]; % [mua, mus, g, n]
cfg.tstart    = 0;
cfg.tend      = 100e-9;
cfg.tstep     = 100e-10;
cfg.seed      = 29012392; 

%% --- DEDEKTÖR GRID PARAMETRELERİ ---
grid_size       = [9, 9]; % [X dedektör sayısı, Y dedektör sayısı]
detector_radius = 1;        % Her dedektörün yarıçapı

% Manuel aralıklandırma kullanılsın mı?
use_manual_spacing = 1; % 1: Manuel, 0: Otomatik

center_det_pos = []; % Başlangıçta boş

if use_manual_spacing
    % Manuel aralık ayarları
    spacing_x_manual = 3;
    spacing_y_manual = 3;

    % Hacim sınırı kontrolü
    max_extent_x = cfg.srcpos(1) + (grid_size(1)-1)/2 * spacing_x_manual;
    max_extent_y = cfg.srcpos(2) + (grid_size(2)-1)/2 * spacing_y_manual;

    if max_extent_x > volume_size(1) || max_extent_y > volume_size(2)
        error('Manuel aralık hacim boyutunu aşıyor. Grid veya aralığı küçültün.');
    end

    % Dedektör pozisyonlarını oluştur (Merkez dahil tüm liste)
    [det_x_manual, det_y_manual] = meshgrid(-floor(grid_size(1)/2):floor(grid_size(1)/2), ...
                                            -floor(grid_size(2)/2):floor(grid_size(2)/2));
    det_x_manual = det_x_manual * spacing_x_manual + cfg.srcpos(1);
    det_y_manual = det_y_manual * spacing_y_manual + cfg.srcpos(2);

    detpos = [det_x_manual(:), det_y_manual(:), ...
              ones(numel(det_x_manual), 1), ... /zeros
              repmat(detector_radius, numel(det_x_manual), 1)];

else
    % Otomatik aralıklandırma
    spacing_x_auto = floor(volume_size(1) / (grid_size(1) + 1));
    spacing_y_auto = floor(volume_size(2) / (grid_size(2) + 1));

    % Dedektör pozisyonlarını oluştur
    [det_x_auto, det_y_auto] = meshgrid(-floor(grid_size(1)/2):floor(grid_size(1)/2), ...
                                        -floor(grid_size(2)/2):floor(grid_size(2)/2));
    det_x_auto = det_x_auto * spacing_x_auto + cfg.srcpos(1);
    det_y_auto = det_y_auto * spacing_y_auto + cfg.srcpos(2);

    detpos = [det_x_auto(:), det_y_auto(:), ...
              ones(numel(det_x_auto), 1), ...
              repmat(detector_radius, numel(det_x_auto), 1)];
end

%% --- MERKEZ DEDEKTÖRÜ TESPİT ETME (AMA LİSTEDEN ÇIKARMIYORUZ) ---
is_source_idx  = (detpos(:, 1) == cfg.srcpos(1)) & (detpos(:, 2) == cfg.srcpos(2));
center_det_pos = detpos(is_source_idx, :);      % merkez dedektör (kaynakla çakışan)
solver_detpos  = detpos(~is_source_idx, :);     % çevredeki dedektörler (sadece görselleştirme için)

disp(['Toplam dedektör sayısı      : ', num2str(size(detpos, 1))]);
disp(['Solver için kullanılacak yan dedektör sayısı: ', num2str(size(solver_detpos, 1))]);
if ~isempty(center_det_pos)
    disp('Merkez dedektör bulundu ve "center" hesapları için işaretlendi.');
else
    warning('Merkez dedektör bulunamadı (kaynakla çakışan dedektör yok).');
end
%%
% Görselleştirme
% Görselleştirme (merkez + kapsama dairesi)
figure; hold on;
theta = linspace(0,2*pi,100);

if ~isempty(solver_detpos)
    hS = scatter(solver_detpos(:,1), solver_detpos(:,2), 'filled', 'b'); % Solver (Mavi)
    for i = 1:size(solver_detpos,1)
        plot(solver_detpos(i,1)+detector_radius*cos(theta), ...
             solver_detpos(i,2)+detector_radius*sin(theta), 'b');         % kapsama dairesi
    end
end

hK = scatter(cfg.srcpos(1), cfg.srcpos(2), 50, 'r', 'filled');            % Kaynak (Kırmızı)
plot(cfg.srcpos(1)+detector_radius*cos(theta), ...
     cfg.srcpos(2)+detector_radius*sin(theta), 'r');

if ~isempty(center_det_pos)
    hM = scatter(center_det_pos(1), center_det_pos(2), 80, 'g', 'filled'); % Merkez (Yeşil)
    plot(center_det_pos(1)+detector_radius*cos(theta), ...
         center_det_pos(2)+detector_radius*sin(theta), 'g');
end

title('Dedektör Yerleşimi'); xlabel('X'); ylabel('Y');
grid on; axis equal; axis([0 volume_size(1) 0 volume_size(2)]);

legH = hK; legL = {'Kaynak'};
if ~isempty(solver_detpos),  legH = [hS legH]; legL = ['Solver Dedektörleri' legL]; end
if ~isempty(center_det_pos), legH = [legH hM]; legL = [legL 'Merkez Dedektör'];     end
legend(legH, legL, 'Location', 'best');

%%

%% --- ANA SİMÜLASYON DÖNGÜSÜ (MS / A MATRİSİ + CENTER_DED BLOĞU) ---
d_p = size(detpos, 1);

ms              = double.empty(0, 26*26*20);   % yan dedektörler için A blokları
A_center_matrix = [];                          % merkez ded. için TAM blok (625 × 12500)

fprintf('--- Tüm Dedektörler İçin Simülasyon Başlıyor (%d adet) ---\n', d_p);
tic
for q = 1:d_p
    this_det   = detpos(q, :);
    cfg.detpos = this_det;

    % 1. İleri Simülasyon
    [flux, detp, vol, seeds] = mcxlab(cfg);

    % 2. Geri (Adjoint) Simülasyon -> Jacobian
    newcfg            = cfg;
    newcfg.seed       = seeds.data;
    newcfg.outputtype = 'jacobian';
    newcfg.detphotons = detp.data;
    [flux2, ~, ~, ~]  = mcxlab(newcfg);

    % Hassasiyet hesapla
    jac = sum(flux2.data, 4);    % 51 x 51 x 20

    % Bu dedektör için 625 frame’lik sensitivite matrisi (25x25 tarama)
    S = sens(jac);               % Boyut: [625, 12500]

    % Eğer bu dedektör kaynakla aynı yerdeyse → merkez dedektör
    if (this_det(1) == cfg.srcpos(1)) && (this_det(2) == cfg.srcpos(2))
        % Merkez dedektörün TAM A bloğu (625 x 12500)
        A_center_matrix = S;
    else
        % Diğer dedektörlerin tüm frame’lerini MS matrisine ekle
        ms = [ms; S];  
    end
end
toc

if isempty(A_center_matrix)
    warning('Merkez dedektör için A_center_matrix üretilemedi (kaynakla çakışan dedektör bulunamamış olabilir).');
else
    disp('>> "A_center_matrix" (625x12500) başarıyla oluşturuldu.');
end

% cfg içine kaydet
cfg.A_matrix         = ms;               % yan dedektörler A
cfg.A_matrix_center  = A_center_matrix;  % merkez dedektör A bloğu (625x12500)
cfg.ms = ms;
return

%% --- SONUÇLARI GÖRÜNTÜLE (MS Matrisi) ---
figure('Name', 'Solver Dedektörleri - Sensitivity Örneği');
z = 1;
if size(ms,1) >= z
    test = reshape(ms(z, :), 26, 26, 20);
    imagesc(log10(abs(squeeze(test(:, :, 1)))));
    colorbar
    title('Örnek Solver Dedektörü (İlk satır)');
    xlabel('y (sütun)'); ylabel('x (satır)');   % x=dim1=satır(dikey), y=dim2=sütun(yatay)
end


%%
% Display the results
figure; 
a_vx = 26 * 26; % FOV area

for z = 1:a_vx
    test = reshape(ms(z, :), 26, 26, 20);

    imagesc(log10(abs(squeeze(test(:, :, 1)))));
    colorbar

    % z (frame) -> tarama konumu.  k = x + (y-1)*26  (sens ile AYNI, vx=26)
    x = mod(z-1, 26) + 1;    % dim1 = X = satır
    y = floor((z-1)/26) + 1; % dim2 = Y = sütun

    title(sprintf('Tarama (frame) konumu: x(satır) = %d, y(sütun) = %d', x, y))
    xlabel('y (sütun)')   % yatay = dim2 = y
    ylabel('x (satır)')   % dikey = dim1 = x

   waitforbuttonpress
end


%% --- SONUÇLARI GÖRÜNTÜLE (Merkez Dedektör - Tek Frame) ---
if ~isempty(A_center_matrix)
    figure('Name', 'Center Detector Frame (Mid Scan)');
    
    % 625 satırın tam ortasındaki frame'i al (mid scan)
    mid_idx          = ceil(size(A_center_matrix, 1) / 2);  % 625 -> 313
    center_frame_vec = A_center_matrix(mid_idx, :);         % 1 x 12500
    
    % 1x12500 → 25x25x20 hacme çevir
    Center_Vol = reshape(center_frame_vec, 26, 26, 20);
    
    % Örnek olarak Z = 10 slice'ını göster
    imagesc(log10(abs(squeeze(Center_Vol(:, :, 1)))));
    colorbar;
    title('Center Detector Sensitivity (Mid Scan) - Slice Z=10');
    xlabel('y (sütun)'); ylabel('x (satır)');   % dikey=dim1=x, yatay=dim2=y
    axis equal tight;
else
    warning('A_center_matrix boş, merkez dedektör görselleştirilemedi.');
end
%%
%%
% Create a numerical phantom and calculate the b matrix
% vol_preX = zeros(25, 25, 20);
% q_Y = 0.15; % 0.15
%  vol_preX(12:14, 12:14, 4:6) = q_Y; % Cube with different quantum yield inside
% 
%  vol_preX(6:10,10:12,7:7)= q_Y; %
%  vol_preX(6:6,10:12,3:7)= q_Y;  % 
%  vol_preX(8:8,10:12,3:7)= q_Y;  % 
%  vol_preX(10:10,10:12,3:7)= q_Y; % 
% % 
% vol_preX(15:23, 15:15, 2:4) = q_Y; 
% vol_preX(15:23, 18:18, 2:4) = q_Y; 
% vol_preX(15:15, 15:18, 2:4) = q_Y; 
% vol_preX(19:19, 15:18, 2:4) = q_Y; 
% 
% 
% X = reshape(vol_preX, [], 1); % X vector
% b = ms * X; % Create the detector readvving matrix
% 
% cfg.X= X;
cfg.ms = ms;
% cfg.b = b;

% Save the configuration data
% save('config_data.mat', 'cfg');
return
%%
% Görselleştirme
figure;
if ~isempty(solver_detpos)
    scatter(solver_detpos(:, 1), solver_detpos(:, 2), 'filled', 'b'); % Solver (Mavi)
    hold on;
    
    % --- DEDEKTÖR NUMARALARINI YAZDIRMA ---
    for i = 1:size(solver_detpos, 1)
        text(solver_detpos(i, 1) + 0.5, solver_detpos(i, 2) + 0.5, num2str(i), ...
            'FontSize', 8, 'FontWeight', 'bold', 'Color', 'k');
    end
else
    hold on;
end

scatter(cfg.srcpos(1), cfg.srcpos(2), 50, 'r', 'filled'); % Kaynak (Kırmızı)
text(cfg.srcpos(1) - 1.5, cfg.srcpos(2) - 1.5, 'Source', 'FontSize', 8, 'Color', 'r');

if ~isempty(center_det_pos)
    scatter(center_det_pos(1), center_det_pos(2), 80, 'g', 'filled'); % Merkez (Yeşil)
end

title('Dedektör Yerleşimi'); xlabel('X'); ylabel('Y');
grid on; axis([0 volume_size(1) 0 volume_size(2)]);

% === EKSENİ TERS ÇEVİRİP (0,0) NOKTASINI SOL ÜSTE ALMA ===
set(gca, 'YDir', 'reverse'); 
% =========================================================

legend_entries = {};
if ~isempty(solver_detpos), legend_entries{end+1} = 'Solver Dedektörleri'; end
legend_entries{end+1} = 'Kaynak';
if ~isempty(center_det_pos), legend_entries{end+1} = 'Merkez Dedektör'; end
legend(legend_entries, 'Location', 'best');
%%


% Görselleştirme
figure;
if ~isempty(solver_detpos)
    scatter(solver_detpos(:, 1), solver_detpos(:, 2), 'filled', 'b'); % Solver (Mavi)
    hold on;
    
    % --- DEDEKTÖR NUMARALARINI YAZDIRMA ---
    for i = 1:size(solver_detpos, 1)
        text(solver_detpos(i, 1) + 0.5, solver_detpos(i, 2) + 0.5, num2str(i), ...
            'FontSize', 8, 'FontWeight', 'bold', 'Color', 'k');
    end
else
    hold on;
end

scatter(cfg.srcpos(1), cfg.srcpos(2), 50, 'r', 'filled'); % Kaynak (Kırmızı)
text(cfg.srcpos(1) - 1.5, cfg.srcpos(2) - 1.5, 'Source', 'FontSize', 8, 'Color', 'r');

if ~isempty(center_det_pos)
    scatter(center_det_pos(1), center_det_pos(2), 80, 'g', 'filled'); % Merkez (Yeşil)
end

title('Dedektör Yerleşimi'); xlabel('X'); ylabel('Y');
grid on; axis([0 volume_size(1) 0 volume_size(2)]);

% === EKSENİ TERS ÇEVİRİP (0,0) NOKTASINI SOL ÜSTE ALMA ===
set(gca, 'YDir', 'reverse'); 
% =========================================================

legend_entries = {};
if ~isempty(solver_detpos), legend_entries{end+1} = 'Solver Dedektörleri'; end
legend_entries{end+1} = 'Kaynak';
if ~isempty(center_det_pos), legend_entries{end+1} = 'Merkez Dedektör'; end
legend(legend_entries, 'Location', 'best');
% SİMÜLASYON İÇİN 25x25 DEDEKTÖR GÖRSELLEŞTİRME KODU (PHANTOM DESTEKLİ)
% A_matrix kodunuz çalıştıktan sonra bu dosyayı çalıştırabilirsiniz.

if ~exist('b', 'var') || ~exist('ms', 'var')
    error('Önce b vektörünü ve ms matrisini oluşturan kodu çalıştırın.');
end

vx = 25; 
if exist('solver_detpos', 'var')
    num_detectors = size(solver_detpos, 1);
elseif exist('detpos_filtered', 'var')
    num_detectors = size(detpos_filtered, 1);
else
    num_detectors = size(ms, 1) / (vx*vx);
end

% --- Düzen Ayarları ---
n     = num_detectors;                
nTile = n + 1;                        
nc = ceil(sqrt(nTile)); if mod(nc,2)==0, nc = nc+1; end
nr = ceil(nTile/nc);    if mod(nr,2)==0, nr = nr+1; end
while nr*nc < nTile
    if nr <= nc, nr = nr+2; else, nc = nc+2; end
end
r0 = (nr+1)/2;  c0 = (nc+1)/2;        

% --- Global Renk Ölçeği (b vektörü için) ---
vals = b(:);
vals = vals(~isnan(vals));
if isempty(vals)
    globalMin = 0; globalMax = 1;
else
    globalMin = min(vals); globalMax = max(vals);
    if globalMax <= globalMin, globalMin = 0; globalMax = 1; end
end

fig = figure('Name','Simülasyon 25x25 Dedektör Frameleri ve Phantom','NumberTitle','off', ...
             'Units','normalized','Position',[0 0.05 1 0.9], 'Color',[0.97 0.97 0.95]);

tl  = tiledlayout(nr, nc, 'Padding','none', 'TileSpacing','none', 'TileIndexing','columnmajor');
colormap(fig,'hot');

ringColors = [0.00 0.00 0.00; 0.20 0.20 0.80; 0.80 0.20 0.20; 0.20 0.60 0.20; 0.50 0.00 0.50];
frameLW = 2.0;

d = 1;

for c = 1:nc
    for r = 1:nr
        ax = nexttile(tl);

        % --- MERKEZ: PHANTOM (TÜMÖR) PROJEKSİYONU ---
        if r==r0 && c==c0
            if exist('vol_preX', 'var')
                Zs = rot90(sum(vol_preX, 3)', 2); 
            else
                Zs = zeros(vx, vx);
            end
            
            hIm = imagesc(ax, Zs);
            axis(ax,'image');
            % ORİJİN SOL ÜSTE ALINDI
            set(ax,'YDir','reverse');
            
            set(ax,'Box','on','LineWidth',frameLW, ...
                'XTick',[],'YTick',[],'Layer','top','Color','none', ...
                'XColor',[0.3 0.3 0.3],'YColor',[0.3 0.3 0.3]);

            text(ax, 0.02, 0.98, 'Phantom', 'Units','normalized', ...
                'HorizontalAlignment','left','VerticalAlignment','top', ...
                'FontSize',8, 'FontWeight','bold', 'Color',[0.95 0.95 0.95], ...
                'BackgroundColor',[0 0 0], 'Margin',1, 'Clipping','on');
            
            setappdata(hIm,'Zdata', Zs); 
            setappdata(hIm,'detIdx', 'Phantom');
            hIm.ButtonDownFcn = @openCloseLocal;
            
            continue
        end

        % Boş kutular
        if d>n
            axis(ax,'image');
            set(ax,'Box','on','LineWidth',1, ...
                'XTick',[],'YTick',[],'Layer','top','Color','none', ...
                'XColor',[0.85 0.85 0.85],'YColor',[0.85 0.85 0.85]);
            continue
        end

        % --- DEDEKTÖR ---
        start_idx = (d-1)*(vx*vx) + 1;
        end_idx   = d*(vx*vx);
        Z = reshape(b(start_idx:end_idx), vx, vx)';
        
        hIm = imagesc(ax, Z, [globalMin, globalMax]);
        axis(ax,'image');
        % ORİJİN SOL ÜSTE ALINDI
        set(ax,'YDir','reverse');

        ringIdx  = max(abs(r - r0), abs(c - c0));
        frameCol = ringColors(mod(ringIdx, size(ringColors,1)) + 1, :);
        set(ax,'Box','on','LineWidth',frameLW, ...
            'XTick',[],'YTick',[],'Layer','top','Color','none', ...
            'XColor',frameCol,'YColor',frameCol);

        text(ax, 0.02, 0.98, sprintf('Det %d', d), 'Units','normalized', ...
            'HorizontalAlignment','left','VerticalAlignment','top', ...
            'FontSize',7, 'FontWeight','bold', 'Color',[0.95 0.95 0.95], ...
            'BackgroundColor',[0 0 0], 'Margin',1, 'Clipping','on');

        setappdata(hIm,'Zdata', Z); 
        setappdata(hIm,'detIdx', d);
        hIm.ButtonDownFcn = @openCloseLocal;

        d = d + 1;
    end
end

cb = colorbar('Location','southoutside');
cb.Limits = [globalMin, globalMax];
cb.Label.String = 'Ölçüm Şiddeti (Simülasyon B Vektörü)';
cb.Layout.Tile = 'south';
%%
% =========================================================================
% TIKLAMA (LOCAL) FONKSİYONU
% =========================================================================
function openCloseLocal(src, ~)
    oldFig = getappdata(src,'FullFig');
    if ~isempty(oldFig) && isvalid(oldFig)
        close(oldFig); rmappdata(src,'FullFig'); return;
    end
    Z   = getappdata(src,'Zdata');
    idx = getappdata(src,'detIdx');

    zVals = Z(:); zVals = zVals(~isnan(zVals));
    if isempty(zVals) || any(~isfinite([min(zVals),max(zVals)]))
        locMin = 0; locMax = 1;
    else
        locMin = min(zVals); locMax = max(zVals);
        if locMax <= locMin, locMin = 0; locMax = 1; end
    end

    if isnumeric(idx), ttl = sprintf('Det %d', idx); else, ttl = char(idx); end
    hF = figure('Name', sprintf('%s – Büyütülmüş (Lokal)', ttl), ...
                'NumberTitle','off', 'Color','w');
    h2 = imagesc(Z, [locMin, locMax]); axis image off; colormap(hot); colorbar;
    % ORİJİN SOL ÜSTE ALINDI
    set(gca,'YDir','reverse');
    title(ttl, 'FontWeight','normal');
    h2.ButtonDownFcn = @(~,~) close(hF);
    setappdata(src,'FullFig', hF);
end

% --- Sensitivity Matrix Fonksiyonu ---
function m3 = sens(jac)
    vx = 26; 
    k  = 0;

   
    num_frames        = vx * vx;          
    elements_per_frame = vx * vx * 20;    
    m3               = zeros(num_frames, elements_per_frame);

    for j = 1:vx
        for i = 1:vx
            m1 = jac(i:vx+i-1, j:vx+j-1, 1:20, 1); 
            
            m2 = reshape(m1, 1, []);  
            k  = k + 1;
            m3(k, :) = m2;
        end
    end
end
