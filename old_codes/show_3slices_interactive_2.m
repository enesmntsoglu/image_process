function show_3slices_interactive_2(volume3D, methodName)
% SHOW_3SLICES_INTERACTIVE
%   volume3D  : 3B hacim (örneğin, Reconstructed_Triangle)
%   methodName: Görselleştirme başlığında görünecek isim/etiket

    % Hacmin boyutlarını al
    [Nx, Ny, Nz] = size(volume3D);

    % Figure penceresini oluştur (daha geniş bir pencere)
    figure('Name', [methodName ' - Interactive Slices & IsoSurface'], ...
           'Units','normalized','Position',[0.1 0.1 0.8 0.8]);

    %% Üst Kısım: Slice Görselleştirmesi
    % Dilimlerin başlangıç indeksleri (ortadan başlatıyoruz)
    z_init = round(Nz/2);
    x_init = round(Nx/2);
    y_init = round(Ny/2);

    % XY Slice (Z sabit)
    hAx1 = axes('Position',[0.05 0.55 0.27 0.35]);
    hXY = imagesc(volume3D(:,:,z_init), 'Parent', hAx1);
    axis(hAx1, 'image'); axis(hAx1, 'off');
    colormap(hAx1, jet); colorbar(hAx1);
    title(hAx1, sprintf('XY Slice (Z = %d)', z_init), 'FontSize',12);

    % YZ Slice (X sabit)
    hAx2 = axes('Position',[0.36 0.55 0.27 0.35]);
    hYZ = imagesc(squeeze(volume3D(x_init,:,:)), 'Parent', hAx2);
    axis(hAx2, 'image'); axis(hAx2, 'off');
    colormap(hAx2, jet); colorbar(hAx2);
    title(hAx2, sprintf('YZ Slice (X = %d)', x_init), 'FontSize',12);

    % XZ Slice (Y sabit)
    hAx3 = axes('Position',[0.67 0.55 0.27 0.35]);
    hXZ = imagesc(squeeze(volume3D(:,y_init,:)), 'Parent', hAx3);
    axis(hAx3, 'image'); axis(hAx3, 'off');
    colormap(hAx3, jet); colorbar(hAx3);
    title(hAx3, sprintf('XZ Slice (Y = %d)', y_init), 'FontSize',12);

    % Slice sliderları (üst kısımda, dilimleri kontrol etmek için)
    sldZ = uicontrol('Style','slider', ...
        'Min',1, 'Max', Nz, 'Value', z_init, ...
        'SliderStep',[1/(Nz-1) , 10/(Nz-1)], ...
        'Units','normalized', 'Position',[0.1 0.5 0.25 0.03], ...
        'Callback',@(src,evt) updateSlices);
    sldX = uicontrol('Style','slider', ...
        'Min',1, 'Max', Nx, 'Value', x_init, ...
        'SliderStep',[1/(Nx-1) , 10/(Nx-1)], ...
        'Units','normalized', 'Position',[0.4 0.5 0.25 0.03], ...
        'Callback',@(src,evt) updateSlices);
    sldY = uicontrol('Style','slider', ...
        'Min',1, 'Max', Ny, 'Value', y_init, ...
        'SliderStep',[1/(Ny-1) , 10/(Ny-1)], ...
        'Units','normalized', 'Position',[0.7 0.5 0.25 0.03], ...
        'Callback',@(src,evt) updateSlices);

    %% Alt Kısım: IsoSurface Görselleştirmesi
    % Meshgrid oluştur (MATLAB'da X: sütunlar, Y: satırlar)
    [X, Y, Z] = meshgrid(1:Ny, 1:Nx, 1:Nz);
    % Iso değer: örnek olarak, maksimumun yarısı
    iso_val = 0.5 * max(volume3D(:));
    isoStruct = isosurface(X, Y, Z, volume3D, iso_val);

    % IsoSurface için axes oluştur
    hIsoAx = axes('Position',[0.05 0.1 0.90 0.5]);
    hIso = patch(hIsoAx, isoStruct);
    set(hIso, 'FaceColor', 'red', 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    camlight(hIsoAx); lighting(hIsoAx, 'gouraud');
    axis(hIsoAx, 'vis3d'); axis(hIsoAx, 'equal'); axis(hIsoAx, 'off');
    title(hIsoAx, sprintf('IsoSurface (Iso = %.2f)', iso_val), 'FontSize',12);

    % Orijinal vertices bilgisini saklayalım (dönüşümün referansı olarak)
    origVertices = get(hIso, 'Vertices');

    % IsoSurface rotasyon sliderları (alt kısımda, 3 adet)
    sldAz = uicontrol('Style','slider', ...
        'Min',0, 'Max',360, 'Value',0, ...
        'Units','normalized', 'Position',[0.05 0.02 0.25 0.03], ...
        'Callback',@(src,evt) updateIsoRotation);
    sldEl = uicontrol('Style','slider', ...
        'Min',0, 'Max',360, 'Value',0, ...
        'Units','normalized', 'Position',[0.37 0.02 0.25 0.03], ...
        'Callback',@(src,evt) updateIsoRotation);
    sldRoll = uicontrol('Style','slider', ...
        'Min',0, 'Max',360, 'Value',0, ...
        'Units','normalized', 'Position',[0.69 0.02 0.25 0.03], ...
        'Callback',@(src,evt) updateIsoRotation);

    %% Callback Fonksiyonları

    % Slice sliderları değiştikçe çalışır
    function updateSlices
        % Güncel dilim slider değerleri
        zVal = round(sldZ.Value);
        xVal = round(sldX.Value);
        yVal = round(sldY.Value);
        
        % XY dilimi
        set(hXY, 'CData', volume3D(:,:,zVal));
        title(hAx1, sprintf('XY Slice (Z = %d)', zVal), 'FontSize',12);
        
        % YZ dilimi
        set(hYZ, 'CData', squeeze(volume3D(xVal,:,:)));
        title(hAx2, sprintf('YZ Slice (X = %d)', xVal), 'FontSize',12);
        
        % XZ dilimi
        set(hXZ, 'CData', squeeze(volume3D(:,yVal,:)));
        title(hAx3, sprintf('XZ Slice (Y = %d)', yVal), 'FontSize',12);
    end

    % IsoSurface için rotasyon sliderları değiştikçe çalışır
    function updateIsoRotation
        % Rotasyon sliderlarından gelen açı değerleri (derece cinsinden)
        az = sldAz.Value;
        el = sldEl.Value;
        roll = sldRoll.Value;
        
        % X, Y, Z eksenleri etrafında dönüş matrisleri
        Rx = [1 0 0; 0 cosd(az) -sind(az); 0 sind(az) cosd(az)];
        Ry = [cosd(el) 0 sind(el); 0 1 0; -sind(el) 0 cosd(el)];
        Rz = [cosd(roll) -sind(roll) 0; sind(roll) cosd(roll) 0; 0 0 1];
        
        % Dönüş sırası: önce X, sonra Y, sonra Z ekseni etrafında dönüş
        R = Rz * Ry * Rx;
        
        % Orijinal vertices'e dönüşümü uygula
        newVertices = (R * origVertices')';
        set(hIso, 'Vertices', newVertices);
        drawnow;
    end

end
