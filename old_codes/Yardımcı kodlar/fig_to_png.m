
%%

% İşlem yapılacak klasörün yolu
folderPath = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Final_Work_Space\Sim_Recos_Codes\Tikhonov\Rapor Dosyası\11x11\Tikhonov_Data_Noise\1\1_fig'; % klasör yolunuzu buraya girin

% Klasördeki tüm .fig dosyalarını listele
figFiles = dir(fullfile(folderPath, '*.fig'));

% Her bir fig dosyası için döngü
for k = 1:length(figFiles)
    % Dosya adı ve tam yolunu al
    figName = figFiles(k).name;
    figFullPath = fullfile(folderPath, figName);
    
    % Figürü görünmeden aç
    hFig = openfig(figFullPath, 'invisible');
    
    % Dosya adından uzantıyı kaldır ve .png ekle
    [~, name, ~] = fileparts(figName);
    pngName = fullfile(folderPath, [name '.png']);
    
    % PNG olarak kaydet
    saveas(hFig, pngName);
    
    % Açılan figürü kapat
    close(hFig);
end
