function saveReconData(matFilename, excelFilename)
% saveReconData  Workspace'deki recon ile ilgili değişkenleri toplayıp kaydeder
%               ve Excel dosyasına aktarır.
%
%   saveReconData(matFilename, excelFilename)
%
%   matFilename   : Kaydedilecek MAT dosyasının adı (ör. 'recon_data.mat')
%   excelFilename : Oluşturulacak Excel dosyasının adı (ör. 'recon_data.xlsx')
%
% Bu fonksiyon, base workspace'de tanımlı olan aşağıdaki değişkenleri toplar:
%   tol, max_itr, noise_std, noise_level_dB, SNR_dB, lambda_range, num_lambda,
%   iso_value, X_lambda_ideal, X_lambda_noisy, res_norm_case1, reg_norm_case1,
%   res_norm_case2, reg_norm_case2, gcv_case1, gcv_case2, morozov_case2,
%   delta_est_case2, opt_lambda_LC_case1, opt_lambda_LC_case2,
%   opt_lambda_GCV_case1, opt_lambda_GCV_case2, opt_lambda_Morozov_case2,
%   opt_lambda_triangle_ideal, opt_lambda_triangle_noisy,
%   opt_lambda_corner_ideal, opt_lambda_corner_noisy,
%   opt_lambda_UC_ideal, opt_lambda_UC_noisy, Reconstructed_LC,
%   Reconstructed_GCV, Reconstructed_Morozov, Reconstructed_Triangle,
%   Reconstructed_Corner, Reconstructed_UC, nssd_array, nsad_array, nr_array,
%   volErrVoxel_array, volErrMM_array, centErrVoxel_array, centErrMM_array.
%
% Fonksiyon, öncelikle recon yapısını oluşturup kaydeder, sonra exportReconToExcel
% fonksiyonu ile Excel'e aktarır.

    % Base workspace'den gerekli değişkenleri topla:
    recon.tol = evalin('base','tol');
    recon.max_itr = evalin('base','max_itr');
    recon.noise_std = evalin('base','noise_std');
    recon.noise_rms = evalin('base','noise_rms');
    recon.SNR_dB = evalin('base','SNR_dB');
    recon.lambda_range = evalin('base','lambda_range');
    recon.num_lambda = evalin('base','num_lambda');
    recon.iso_value = evalin('base','iso_value');
    
    recon.x_lambda_case1 = evalin('base','X_lambda_ideal');
    recon.x_lambda_case2 = evalin('base','X_lambda_noisy');
    
    recon.res_norm_case1 = evalin('base','res_norm_case1');
    recon.reg_norm_case1 = evalin('base','reg_norm_case1');
    recon.res_norm_case2 = evalin('base','res_norm_case2');
    recon.reg_norm_case2 = evalin('base','reg_norm_case2');
    
    recon.gcv_case1 = evalin('base','gcv_case1');
    recon.gcv_case2 = evalin('base','gcv_case2');
    recon.morozov_case2 = evalin('base','morozov_case2');
    recon.delta_est_case2 = evalin('base','delta_est_case2');
    
    recon.opt_lambda_LC_case1 = evalin('base','opt_lambda_LC_case1');
    recon.opt_lambda_LC_case2 = evalin('base','opt_lambda_LC_case2');
    recon.opt_lambda_GCV_case1 = evalin('base','opt_lambda_GCV_case1');
    recon.opt_lambda_GCV_case2 = evalin('base','opt_lambda_GCV_case2');
    recon.opt_lambda_Morozov_case2 = evalin('base','opt_lambda_Morozov_case2');
    recon.opt_lambda_triangle_ideal = evalin('base','opt_lambda_triangle_ideal');
    recon.opt_lambda_triangle_noisy = evalin('base','opt_lambda_triangle_noisy');
    recon.opt_lambda_corner_ideal = evalin('base','opt_lambda_corner_ideal');
    recon.opt_lambda_corner_noisy = evalin('base','opt_lambda_corner_noisy');
    recon.opt_lambda_UC_ideal = evalin('base','opt_lambda_UC_ideal');
    recon.opt_lambda_UC_noisy = evalin('base','opt_lambda_UC_noisy');
    
    recon.Reconstructed_LC = evalin('base','Reconstructed_LC');
    recon.Reconstructed_GCV = evalin('base','Reconstructed_GCV');
    recon.Reconstructed_Morozov = evalin('base','Reconstructed_Morozov');
    recon.Reconstructed_Triangle = evalin('base','Reconstructed_Triangle');
    recon.Reconstructed_Corner = evalin('base','Reconstructed_Corner');
    recon.Reconstructed_UC = evalin('base','Reconstructed_UC');
    
    recon.nssd_array = evalin('base','nssd_array');
    recon.nsad_array = evalin('base','nsad_array');
    recon.nr_array = evalin('base','nr_array');
    recon.volErrVoxel_array = evalin('base','volErrVoxel_array');
    recon.volErrMM_array = evalin('base','volErrMM_array');
    recon.centErrVoxel_array = evalin('base','centErrVoxel_array');
    recon.centErrMM_array = evalin('base','centErrMM_array');
    
    % recon yapısını .mat dosyasına kaydet:
    save(matFilename, 'recon');
    fprintf('Recon yapısı "%s" dosyasına kaydedildi.\n', matFilename);
    
    % recon verilerini Excel'e aktar:
    exportReconToExcel(recon, excelFilename);
end
