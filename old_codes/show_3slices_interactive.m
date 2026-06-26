function show_3slices_interactive(volume3D, methodName)
% SHOW_3SLICES_INTERACTIVE
%   volume3D  : 3B hacim (ör. Reconstructed_Triangle)
%   methodName: Görselleştirme başlığında görünecek isim/etiket
% % Tüm yöntem isimlerini ve verilerini hücre dizilerinde toplayalım:
% methodNames = { ...
%     'LC', ...
%     'GCV', ...
%     'Morozov', ...
%     'Triangle', ...
%     'Corner', ...
%     'UC' ...
% };
% 
% reconstructedVolumes = { ...
%     Reconstructed_LC, ...
%     Reconstructed_GCV, ...
%     Reconstructed_Morozov, ...
%     Reconstructed_Triangle, ...
%     Reconstructed_Corner, ...
%     Reconstructed_UC ...
% };
% 
% % Şimdi bu listeler üzerinden bir döngü kurarak hepsini çizdirelim
% for i = 1:length(methodNames)
%     show_3slices(reconstructedVolumes{i}, methodNames{i});
% end
%vol_preX, 'Original Phantom (vol_preX)'


    % Hacmin boyutlarını al
    [Nx, Ny, Nz] = size(volume3D);

    % Bir figure penceresi oluştur
    figure('Name', [methodName ' - Interactive Slices'], ...
           'Units','normalized','Position',[0.1 0.1 0.8 0.6]); %%[x y genişlik yükseklik]

    %--------------------------------------------------
    % 1) Başlangıçta ortadaki kesitleri görüntüle
    %--------------------------------------------------
    % Başlangıç kesitleri
    z_init = round(Nz/2);
    x_init = round(Nx/2);
    y_init = round(Ny/2);

    % XY Slice (Z sabit)
    hAx1 = subplot(1,3,1);
    % Axes konumunu güncelle (normalized: [x y width height])
    set(hAx1, 'Position', [0.05 0.25 0.27 0.65]);
    hXY = imagesc(volume3D(:,:,z_init));
    axis(hAx1, 'image'); axis(hAx1, 'off');
    colormap(hAx1, jet); colorbar;
    title(hAx1, sprintf('XY Slice (Z = %d)', z_init), 'FontSize',12);

    % YZ Slice (X sabit)
    hAx2 = subplot(1,3,2);
    set(hAx2, 'Position', [0.36 0.25 0.27 0.65]);
    hYZ = imagesc(squeeze(volume3D(x_init,:,:)));
    axis(hAx2, 'image'); axis(hAx2, 'off');
    colormap(hAx2, jet); colorbar;
    title(hAx2, sprintf('YZ Slice (X = %d)', x_init), 'FontSize',12);

    % XZ Slice (Y sabit)
    hAx3 = subplot(1,3,3);
    set(hAx3, 'Position', [0.67 0.25 0.27 0.65]);
    hXZ = imagesc(squeeze(volume3D(:,y_init,:)));
    axis(hAx3, 'image'); axis(hAx3, 'off');
    colormap(hAx3, jet); colorbar;
    title(hAx3, sprintf('XZ Slice (Y = %d)', y_init), 'FontSize',12);

    %--------------------------------------------------
    % 2) Slider Kontrollerini Oluştur
    %--------------------------------------------------
    % Z dilimi seçimi (XY görüntüsünü değiştirir)
    sldZ = uicontrol('Style','slider', ...
        'Min',1, 'Max', Nz, 'Value', z_init, ...
        'SliderStep',[1/(Nz-1) , 10/(Nz-1)], ...
        'Units','normalized', 'Position',[0.1 0.03 0.25 0.03], ...
        'Callback',@(src,evt) updateSlices);

    % X dilimi seçimi (YZ görüntüsünü değiştirir)
    sldX = uicontrol('Style','slider', ...
        'Min',1, 'Max', Nx, 'Value', x_init, ...
        'SliderStep',[1/(Nx-1) , 10/(Nx-1)], ...
        'Units','normalized', 'Position',[0.4 0.03 0.25 0.03], ...
        'Callback',@(src,evt) updateSlices);

    % Y dilimi seçimi (XZ görüntüsünü değiştirir)
    sldY = uicontrol('Style','slider', ...
        'Min',1, 'Max', Ny, 'Value', y_init, ...
        'SliderStep',[1/(Ny-1) , 10/(Ny-1)], ...
        'Units','normalized', 'Position',[0.7 0.03 0.25 0.03], ...
        'Callback',@(src,evt) updateSlices);

    %--------------------------------------------------
    % 3) Slider Değiştikçe Dilimleri Güncelleyen Fonksiyon
    %--------------------------------------------------
    function updateSlices
        % Sliderlardan güncel değerleri al
        zVal = round(sldZ.Value);
        xVal = round(sldX.Value);
        yVal = round(sldY.Value);

        % XY dilimi güncelleme
        sliceXY = volume3D(:,:,zVal);
        set(hXY, 'CData', sliceXY);
        title(hAx1, sprintf('XY Slice (Z = %d)', zVal), 'FontSize',12);

        % YZ dilimi güncelleme
        sliceYZ = squeeze(volume3D(xVal,:,:));
        set(hYZ, 'CData', sliceYZ);
        title(hAx2, sprintf('YZ Slice (X = %d)', xVal), 'FontSize',12);

        % XZ dilimi güncelleme
        sliceXZ = squeeze(volume3D(:,yVal,:));
        set(hXZ, 'CData', sliceXZ);
        title(hAx3, sprintf('XZ Slice (Y = %d)', yVal), 'FontSize',12);
    end

end


%%
