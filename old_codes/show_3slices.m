function show_3slices(volume3D, methodName)
    % volume3D  : 3B matris (ör. Reconstructed_LC)
    % methodName: Bu hacmin hangi yönteme ait olduğunu belirten isim (string)
    
    % Hacmin boyutlarını al
    [Nx, Ny, Nz] = size(volume3D);
    
    % Orta kesit indekslerini belirle (küsurat çıkarsa round kullanabilirsin)
    x_center = floor(Nx/2);  
    y_center = floor(Ny/2);  
    z_center = floor(Nz/2);  
    
    % 1) XY Düzlemi: Z = z_center
    sliceXY = volume3D(:, :, z_center);
    
    % 2) YZ Düzlemi: X = x_center
    sliceYZ = squeeze(volume3D(x_center, :, :));
    
    % 3) XZ Düzlemi: Y = y_center
    sliceXZ = squeeze(volume3D(:, y_center, :));
    
    % Yeni bir figür oluştur, ismini methodName ile ilişkilendir
    figure('Name', ['3 Slices - ' methodName], ...
           'Units','normalized','Position',[0.1 0.1 0.8 0.4]);
    
    % -- XY slice --
    subplot(1,3,1);
    imagesc(sliceXY);
    colormap(jet); 
    axis image; axis off;
    title(sprintf('XY Slice (Z = %d) | %s', z_center, methodName), 'FontSize', 12);
    colorbar;
    
    % -- YZ slice --
    subplot(1,3,2);
    imagesc(sliceYZ);
    colormap(jet);
    axis image; axis off;
    title(sprintf('YZ Slice (X = %d) | %s', x_center, methodName), 'FontSize', 12);
    colorbar;
    
    % -- XZ slice --
    subplot(1,3,3);
    imagesc(sliceXZ);
    colormap(jet);
    axis image; axis off;
    title(sprintf('XZ Slice (Y = %d) | %s', y_center, methodName), 'FontSize', 12);
    colorbar;
end
