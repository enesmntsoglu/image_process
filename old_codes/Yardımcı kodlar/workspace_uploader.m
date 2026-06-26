%% === [1] Hazırlık ve Ayarlar ===
clear; clc;

% .mat dosyasının tam yolunu girin
matFilePath = 'C:\Users\TUSEB\Desktop\MCXStudio-win64-v2023\MCXStudio\MATLAB\mcxlab\enes\Final_Work_Space\workspace.mat';

% Bellek durumunu görmek için
feature('memstats');

% Büyük matrisler için satır başına okuma boyutu
chunkSize = 5000;

% Yüklenen verileri tutacak yapı
loadedData = struct();

%% === [2] Dosya ve Değişken İsimlerini Al ===
if ~isfile(matFilePath)
    error('MATLAB:FileNotFound', 'Hata: Dosya bulunamadı!\nYol: %s', matFilePath);
end

% Dosyadaki TÜM değişken adlarını alıyoruz
allVars = who('-file', matFilePath);
fprintf('Dosyada toplam %d değişken bulundu.\n', length(allVars));

%% === [3] Her Bir Değişkeni Tek Tek Yükleme Denemesi ===
for iVar = 1:length(allVars)
    varName = allVars{iVar};
    fprintf('\n=== Değişken yükleniyor: %s ===\n', varName);
    
    % Dosyada var mı ve boyutu nedir -> whos
    varInfo = whos('-file', matFilePath, varName);
    if isempty(varInfo)
        warning('Değişken %s dosyada görünmüyor, atlanıyor.', varName);
        continue;
    end
    
    try
        %% [A] Küçükse (örn. < 50 MB) -> load ile yükle
        if varInfo.bytes < 5e7
            fprintf(' > Standart LOAD ile deneniyor (%.2f MB)...\n', varInfo.bytes/1e6);
            
            temp = load(matFilePath, varName);
            loadedData.(varName) = temp.(varName);
            
            fprintf('   > %s başarıyla LOAD edildi.\n', varName);
            
        else
            %% [B] Büyükse -> matfile ile yükle
            fprintf(' > Değişken büyük (~%.2f MB). matfile ile deneniyor...\n', varInfo.bytes/1e6);
            mObj = matfile(matFilePath);
            
            % Numeric mi, değil mi kontrol edelim
            if any(strcmp(varInfo.class, {'double','single','logical','uint8','int8','uint16','int16','uint32','int32','uint64','int64'}))
                % === [B.1] Büyük ve Numeric -> Parça parça yükle ===
                dims = varInfo.size;
                nDims = numel(dims);
                
                if nDims == 2
                    % İki boyutlu matris
                    nRows = dims(1);
                    nCols = dims(2);
                    bigMatrix = zeros(dims, varInfo.class);  % Tüm veriyi saklayacaksak
                    
                    rowStart = 1;
                    while rowStart <= nRows
                        rowEnd = min(rowStart + chunkSize - 1, nRows);
                        
                        partData = mObj.(varName)(rowStart:rowEnd, :);
                        bigMatrix(rowStart:rowEnd, :) = partData;
                        
                        fprintf('   > %s: %d-%d satırları yüklendi.\n', varName, rowStart, rowEnd);
                        rowStart = rowEnd + 1;
                    end
                    
                    loadedData.(varName) = bigMatrix;
                    fprintf('   > %s parça parça başarıyla yüklendi.\n', varName);
                    
                else
                    % Çok boyutlu (3D veya 4D) bir array ise:
                    % Burada row-slice değil, dilim (ör: 3D = [X Y Z]) bazında okumalıyız.
                    % Örnek olarak 3. boyuta göre chunk yapalım:
                    
                    fprintf('   > %s değişkeni %d boyutlu. 3D chunk örneği...\n', varName, nDims);
                    % Siz kendi ihtiyacınıza göre boyutlu chunk yapabilirsiniz.
                    
                    % Burada basitçe tek seferde okumayı deneyelim:
                    data = mObj.(varName);
                    loadedData.(varName) = data;
                    fprintf('   > %s tümüyle yüklendi (3D+ array).\n', varName);
                end
                
            else
                % === [B.2] Büyük ama numeric olmayan değişken (cell, struct, vb.) ===
                fprintf('   > Değişken "%s" numeric değil. matfile ile tek seferde okunmaya çalışılıyor...\n', varName);
                
                try
                    data = mObj.(varName);
                    
                    % Eğer cell ise içeriğini çıkarmak isteyebilirsiniz
                    if iscell(data)
                        data = data{:};
                    end
                    
                    % Eğer struct ise fieldnames() ile alt alanları gezebilirsiniz
                    if isstruct(data)
                        disp('   > Bu bir struct, alt alanlar fieldnames() ile incelenebilir.');
                    end
                    
                    % function_handle ise genelde matfile ile açılamaz
                    if isa(data, 'function_handle')
                        warning('   > Function handle türü matfile ile açılamayabilir. LOAD ile deneyeceğiz.');
                        temp = load(matFilePath, varName);
                        loadedData.(varName) = temp.(varName);
                    else
                        loadedData.(varName) = data;
                    end
                    
                    fprintf('   > %s matfile ile okundu (non-numeric).\n', varName);
                    
                catch errNonNumeric
                    warning('   > Non-numeric değişkeni matfile ile okuyamadık: %s\n   > Standart LOAD deneniyor...', errNonNumeric.message);
                    
                    temp = load(matFilePath, varName);
                    loadedData.(varName) = temp.(varName);
                    fprintf('   > %s standart LOAD ile okundu (non-numeric).\n', varName);
                end
            end
        end
        
    catch ME
        % Hem load hem matfile hatası burada yakalanır
        warning('   > Değişken %s yüklenirken hata oluştu: %s', varName, ME.message);
    end
end

%% === [4] Sonuçları İnceleme ===
disp('========================================');
disp('Yükleme işlemi tamamlandı. Elde edilen değişkenler (loadedData):');
disp(fieldnames(loadedData));

disp('Bellek durumu:');
feature('memstats');

% Artık loadedData.varName şeklinde her şeye erişebilirsiniz.
% Örneğin: loadedData.ms, loadedData.max_extent_x, vb.
%%
% struct içindeki alan (değişken) isimlerini al
varNames = fieldnames(loadedData);

% Her bir alanı tek tek ana workspace'e aktar
for i = 1:length(varNames)
    thisName = varNames{i};
    thisValue = loadedData.(thisName);
    
    % Bu değişkeni "base workspace"e atayalım
    assignin('base', thisName, thisValue);
end