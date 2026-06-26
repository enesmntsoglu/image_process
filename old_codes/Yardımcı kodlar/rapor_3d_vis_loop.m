%% Batch processing of recon files with figure & metrics saving (high-res)

% Eğer varsa phantom verinizi başta yükleyin:
% load('phantom.mat','vol_preX');

% İşlenecek SNR dosya adları (uzantısız):
snr_list = {'snr1','snr2','snr4','snr5','snr7','snr10'};

% Hata metrikleri hesaplayan yardımcı fonksiyonunuzun adı:
% [volErrVoxel, volErrMM, centErrVoxel, centErrMM] = quality_metrics(vol_preX, R, cfg.unitinmm);

for idx = 1:numel(snr_list)

    % 1) Önceki iterasyondaki değişkenleri temizle (vol_preX'i bırak):
    clearvars -except snr_list idx vol_preX

    % 2) Recon struct'ını yükle:
    currentFile = [snr_list{idx} '.mat'];
    D = load(currentFile);
    if ~isfield(D,'recon') || ~isstruct(D.recon)
        error('File "%s" does not contain a recon struct.', currentFile);
    end
    recon = D.recon;

    % 3) Struct içindeki alanları unpack et:
    flds = fieldnames(recon);
    for k = 1:numel(flds)
        eval([ flds{k} ' = recon.' flds{k} ';' ]);
    end

    % 4) Eşik değerlerini hesapla:
    th.LC       = 0.25 * max(Reconstructed_LC(:));
    th.GCV      = 0.25 * max(Reconstructed_GCV(:));
    th.Morozov  = 0.25 * max(Reconstructed_Morozov(:));
    th.Triangle = 0.25 * max(Reconstructed_Triangle(:));
    th.Corner   = 0.25 * max(Reconstructed_Corner(:));
    th.UC       = 0.25 * max(Reconstructed_UC(:));

    % 5) Görselleştirme dizilerini hazırla:
    vols   = {Reconstructed_LC, Reconstructed_GCV, Reconstructed_Morozov, ...
              Reconstructed_Triangle, Reconstructed_Corner, Reconstructed_UC};
    ths    = [th.LC, th.GCV, th.Morozov, th.Triangle, th.Corner, th.UC];
    cols   = {'red','green','magenta','cyan','yellow','cyan'};
    titles = {'LC','GCV','Morozov','Triangle','Corner','U-Curve'};

    % 6) Boyutları al ve figür oluştur (isosurface + projeksiyonlar):
    [Ny, Nx, Nz] = size(vol_preX);
    hFig1 = figure('Name', ['Recon: ' snr_list{idx}], 'Renderer','opengl');
    set(hFig1, 'Units','normalized', 'OuterPosition',[0 0 1 1]);

    % 6a) Orijinal Phantom
    subplot(2,4,1);
    p0 = patch(isosurface(vol_preX));
    set(p0, 'FaceColor','blue','EdgeColor','none');
    title('Orijinal Phantom');
    view(3); axis equal; xlim([1 Nx]); ylim([1 Ny]); zlim([1 Nz]);
    camlight; set(gca,'FontSize',20);
    % Projeksiyonlar
    [F0,V0] = isosurface(vol_preX);
    Vxy=V0; Vxy(:,3)=1; patch('Faces',F0,'Vertices',Vxy,'FaceColor','blue','EdgeColor','k','FaceAlpha',0.8,'LineWidth',1.5);
    Vxz=V0; Vxz(:,2)=1; patch('Faces',F0,'Vertices',Vxz,'FaceColor','blue','EdgeColor','k','FaceAlpha',0.8,'LineWidth',1.5);
    Vyz=V0; Vyz(:,1)=1; patch('Faces',F0,'Vertices',Vyz,'FaceColor','blue','EdgeColor','k','FaceAlpha',0.8,'LineWidth',1.5);

    % 6b) Her bir rekonstrüksiyon ve projeksiyon
    for i = 1:6
        subplot(2,4,i+1);
        [F,V] = isosurface(vols{i}, ths(i));
        p = patch('Faces',F,'Vertices',V,'FaceColor',cols{i},'EdgeColor','none');
        title([titles{i} ' Rekonstrüksiyon']);
        view(3); axis equal; xlim([1 Nx]); ylim([1 Ny]); zlim([1 Nz]);
        camlight; set(gca,'FontSize',20);
        Vxy=V; Vxy(:,3)=1; patch('Faces',F,'Vertices',Vxy,'FaceColor',cols{i},'EdgeColor','k','FaceAlpha',0.8,'LineWidth',1.5);
        Vxz=V; Vxz(:,2)=1; patch('Faces',F,'Vertices',Vxz,'FaceColor',cols{i},'EdgeColor','k','FaceAlpha',0.8,'LineWidth',1.5);
        Vyz=V; Vyz(:,1)=1; patch('Faces',F,'Vertices',Vyz,'FaceColor',cols{i},'EdgeColor','k','FaceAlpha',0.8,'LineWidth',1.5);
    end

    % 7) Yüksek çözünürlükle kaydet ve kapat
    set(hFig1,'PaperPositionMode','auto');
    print(hFig1, snr_list{idx}, '-dpng', '-r300');
    close(hFig1);

    % 8) Hata metriklerini hesapla
    methods = titles;
    num_methods = numel(methods);
    nssd_array = zeros(num_methods,1);
    nsad_array = zeros(num_methods,1);
    nr_array   = zeros(num_methods,1);
    volErrVoxel_array = zeros(num_methods,1);
    volErrMM_array    = zeros(num_methods,1);
    centErrVoxel_array = zeros(num_methods,1);
    centErrMM_array    = zeros(num_methods,1);

    for i = 1:num_methods
        R = vols{i};
        nssd_array(i) = sum((R(:)-vol_preX(:)).^2)/sum(vol_preX(:).^2);
        nsad_array(i) = sum(abs(R(:)-vol_preX(:)))/sum(abs(vol_preX(:)));
        nr_array(i)   = norm(R(:)-vol_preX(:))/norm(vol_preX(:));
        [vvV,vvM,ccV,ccM] = quality_metrics(vol_preX, R, 0.1);
        volErrVoxel_array(i)=vvV;
        volErrMM_array(i)   =vvM;
        centErrVoxel_array(i)=ccV;
        centErrMM_array(i)   =ccM;
    end

    % 9) Hata metrikleri grafiği ve kaydetme
    hFig2 = figure('Name','Hata Metrikleri','Units','normalized','OuterPosition',[0 0 1 1]);
    common_ylim = [min([nssd_array;nsad_array;nr_array])*0.95, max([nssd_array;nsad_array;nr_array])*1.05];
    yy = {nssd_array, nsad_array, nr_array, volErrMM_array, centErrMM_array, volErrVoxel_array, centErrVoxel_array};
    ylabels = {'NSSD','NSAD','NR','Volume Error (mm^3)','Centroid Error (mm)','Volume Error (vox)','Centroid Error (vox)'};
    for i = 1:7
        subplot(1,7,i);
        bar(yy{i});
        set(gca,'XTick',1:num_methods,'XTickLabel',methods,'FontSize',12);
        title(ylabels{i});
        grid on;
        if i<=3
            ylim(common_ylim);
        end
    end

    set(hFig2,'PaperPositionMode','auto');
    print(hFig2, [snr_list{idx} '_metrics'], '-dpng', '-r300');
    close(hFig2);

    fprintf('» %s : figürler ve metrikler kaydedildi.\n', snr_list{idx});

end


%%
% 3B Rekonstrüksiyon (Gürültülü Veri) Görselleştirme
% -----------------------------------------------
% Varsayılan olarak workspace'te tanımlı:
%   vol_preX, Reconstructed_LC, Reconstructed_GCV,
%   Reconstructed_Morozov, Reconstructed_Triangle,
%   Reconstructed_Corner, Reconstructed_UC
%
% Boyutları al
Ny = size(vol_preX,1);
Nx = size(vol_preX,2);
Nz = size(vol_preX,3);

% Yeni figür
figure('Name','3B Rekonstrüksiyon (Gürültülü Veri)');
set(gcf,'Renderer','opengl');

% Alt şekilleri çiz
plotIso(1, vol_preX,              'cyan',    'Orijinal Phantom',       Nx, Ny, Nz);
plotIso(2, Reconstructed_LC,      'red',     'LC Rekonstrüksiyon',     Nx, Ny, Nz);
plotIso(3, Reconstructed_GCV,     'green',   'GCV Rekonstrüksiyon',    Nx, Ny, Nz);
plotIso(4, Reconstructed_Morozov, 'magenta', 'Morozov Rekonstrüksiyon',Nx, Ny, Nz);
plotIso(5, Reconstructed_Triangle,'cyan',    'Triangle Method',        Nx, Ny, Nz);
plotIso(6, Reconstructed_Corner,   'yellow',  'Corner Method',          Nx, Ny, Nz);
plotIso(7, Reconstructed_UC,       'cyan',    'U-Curve Rekonstrüksiyon',Nx, Ny, Nz);


%--------------- Yerel Fonksiyonlar ----------------%
function plotIso(subIdx, dataVol, faceCol, titleStr, Nx, Ny, Nz)
    % Alt şekli seç
    subplot(2,4,subIdx);
    % İso-değeri hesapla
    isoVal = isovalue(dataVol);
    % İki argümanlı isosurface
    [F, V] = isosurface(dataVol, isoVal);
    patch('Faces', F, 'Vertices', V, 'FaceColor', faceCol, 'EdgeColor', 'none');
    % Görünüm ayarları
    view(3); axis equal;
    xlim([1 Nx]); ylim([1 Ny]); zlim([1 Nz]);
    camlight; lighting gouraud;
    set(gca,'FontSize',20);
    title(titleStr);

    % Projeksiyonlar
    Vxy = V; Vxy(:,3)=1;
    patch('Faces',F,'Vertices',Vxy,'FaceColor',faceCol,'EdgeColor','k','FaceAlpha',0.8,'LineWidth',1.5);
    Vxz = V; Vxz(:,2)=1;
    patch('Faces',F,'Vertices',Vxz,'FaceColor',faceCol,'EdgeColor','k','FaceAlpha',0.8,'LineWidth',1.5);
    Vyz = V; Vyz(:,1)=1;
    patch('Faces',F,'Vertices',Vyz,'FaceColor',faceCol,'EdgeColor','k','FaceAlpha',0.8,'LineWidth',1.5);

    % Eksen pozisyonunu al
    axPos = get(gca, 'Position');  % [left bottom width height]
    % Metin kutusu boyutu
    bw = 0.18; bh = 0.06;
    % Yatayda ortala
    xC = axPos(1) + axPos(3)/2;
    xStart = min(max(xC - bw/2, 0), 1-bw);
    % Biraz daha aşağı indir
    yStart = max(axPos(2) - bh - 0.03, 0.01);
    pos = [xStart, yStart, bw, bh];

    % Sabit konumlu, dönmeyen etiket
    annotation('textbox', pos, ...
               'String', sprintf('Iso-value: %.3f', isoVal), ...
               'FontSize', 16, 'FontWeight', 'bold', ...
               'HorizontalAlignment', 'center', ...
               'EdgeColor', 'none', ...
               'Color', 'white', ...
               'BackgroundColor', 'black', ...
               'FitBoxToText', 'on', ...
               'Units', 'normalized');
end

function val = isovalue(data)
    %ISOVALUE  Isovalue calculator (from MATLAB internal)
    r = 1; num = numel(data);
    if num > 20000
        r = floor(num/10000);
    end
    [n, ctrs] = hist(data(1:r:end), 100);
    pos = find(n == max(n), 1);
    q = max(n(1:min(2,end)));
    if pos <= 2 && q/mean(n) > 10
        n = n(3:end); ctrs = ctrs(3:end);
    end
    smallBins = n < max(n)/50;
    if sum(smallBins) < 90
        ctrs(smallBins) = []; n(smallBins) = [];
    end
    if sum(n == 0) == 99
        val = data(1);
    else
        val = ctrs(floor(numel(ctrs)/2));
    end
end
%%
function [log_reg, log_res, curvature] = compute_curvature(reg_norm, res_norm, lambda_range)
    log_reg = log(reg_norm(:));
    log_res = log(res_norm(:));
    t = log(lambda_range(:));
    
    % Birinci türevler (gradyan ile boyut korunarak)
    dlogr = gradient(log_reg, t); % log_reg'in t'ye göre türevi
    dlogR = gradient(log_res, t); % log_res'in t'ye göre türevi
    
    % İkinci türevler (gradyan ile boyut korunarak)
    d2logr = gradient(dlogr, t);  % dlogr'ın t'ye göre türevi
    d2logR = gradient(dlogR, t);  % dlogR'ın t'ye göre türevi
    
    % Eğrilik formülü (NaN korumalı)
    curvature = abs(d2logR .* dlogr - dlogR .* d2logr) ./ (dlogR.^2 + dlogr.^2 + eps()).^(3/2);
end

function [idx_corner, distances] = corner_by_triangle(xvals, yvals)
    % xvals, yvals : L-curve noktaları (log(||x_lambda||), log(||Ax_lambda - b||))
    % idx_corner   : Üçgen yöntemine göre köşe noktasının indeksi
    % distances    : Her noktaya ait dik uzaklıklar
    
    % İlk ve son noktalar:
    x1 = xvals(1);  y1 = yvals(1);
    xN = xvals(end); yN = yvals(end);
    
    % İki nokta arasındaki doğru uzunluğu:
    denom = sqrt((yN - y1)^2 + (xN - x1)^2);
    
    n = length(xvals);
    distances = zeros(n,1);
    for i = 1:n
        % Nokta ile chord arasındaki dik mesafe:
        distances(i) = abs((yN - y1)*xvals(i) - (xN - x1)*yvals(i) + xN*y1 - yN*x1) / denom;
    end
    
    [~, idx_corner] = max(distances);
end

function [volErrVoxel, volErrMM, centErrVoxel, centErrMM] = quality_metrics(original_volume, reconstructed_volume, unitInMM)
    % Volume Error Calculation (Voxel cinsinden)
    volErrVoxel = abs(nnz(original_volume) - nnz(reconstructed_volume));
    % Volume Error (mm^3): Her voxelün hacmi (unitInMM)^3
    volErrMM = volErrVoxel * unitInMM^3;
    
    % Centroid Error Calculation (Voxel cinsinden)
    origCentroid = centroid(original_volume);
    reconCentroid = centroid(reconstructed_volume);
    centErrVoxel = norm(origCentroid - reconCentroid);
    % Centroid Error (mm): Voxel cinsinden hatayı unitInMM ile çarpıyoruz.
    centErrMM = centErrVoxel * unitInMM;
end

function c = centroid(volume)
    % 3B hacmin centroidini hesaplar (voxel cinsinden)
    [x, y, z] = ndgrid(1:size(volume, 1), 1:size(volume, 2), 1:size(volume, 3));
    totalMass = sum(volume(:));
    c = [sum(x(:) .* volume(:)) / totalMass, ...
         sum(y(:) .* volume(:)) / totalMass, ...
         sum(z(:) .* volume(:)) / totalMass];
end


