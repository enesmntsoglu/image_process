
varsToClear = { ...
  'tol','max_itr','noise_std','noise_rms','SNR_dB','lambda_range','num_lambda','iso_value', ...
  'x_lambda_case2','res_norm_case2','reg_norm_case2','gcv_case2','morozov_case2','delta_est_case2', ...
  'opt_lambda_LC_case2','opt_lambda_GCV_case2','opt_lambda_Morozov_case2', ...
  'opt_lambda_triangle_noisy','opt_lambda_corner_noisy','opt_lambda_UC_noisy', ...
  'Reconstructed_LC','Reconstructed_GCV','Reconstructed_Morozov','Reconstructed_Triangle', ...
  'Reconstructed_Corner','Reconstructed_UC', ...
  'nssd_array','nsad_array','nr_array', ...
  'volErrVoxel_array','volErrMM_array','centErrVoxel_array','centErrMM_array','recon' ...
};
clear(varsToClear{:});

clear Reconstructed_LC Reconstructed_GCV Reconstructed_Morozov ...
      Reconstructed_Triangle Reconstructed_Corner Reconstructed_UC


%%
% 1. Adım: Dosyayı yükle
S = load('recon_data.mat');    % S.recon olarak gelir

% 2. Adım: recon içindeki alanları workspace’e ata
recon = S.recon;
fn    = fieldnames(recon);
for k = 1:numel(fn)
    assignin('base', fn{k}, recon.(fn{k}));
end

disp('Recon struct içindeki tüm alanlar workspace’e atandı.');




%% DENEME ÇALIŞMADI
% --- workspace’teki recon struct’ını unpack et (dosya yüklemeden) ---

% 0) Eğer henüz yapmadıysanız bir kez dosyayı yükleyin:
%    >> load('recon.mat');

% 1) Önceki unpack’la gelen değişkenleri temizle:
if exist('prevReconFields','var')
    clear(prevReconFields{:});
end

% 2) workspace’te recon struct var mı kontrol et:
if ~exist('recon','var') || ~isstruct(recon)
    error('Workspace içinde ''recon'' struct bulunamadı. Önce load(''recon.mat'') yapın.');
end

% 3) recon içindeki tüm alan adlarını al ve workspace’e yaz:
flds = fieldnames(recon);
for k = 1:numel(flds)
    assignin('base', flds{k}, recon.(flds{k}));
end

% 4) Bir sonraki çalıştırmada silmek üzere isimleri sakla:
prevReconFields = flds;

fprintf('Recon unpacklandı: %d alan workspace’e atandı.\n', numel(flds));
