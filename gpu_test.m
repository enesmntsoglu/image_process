parallel.gpu.enableCUDAForwardCompatibility(true);
gpuDevice
%%
% Tüm GPU memory'yi temizle
reset(gpuDevice());

% Kısa bekle
pause(2);

% Test et
gpuArray(ones(100));
disp('GPU çalışıyor!');
%%
%% GPU Tanılama (robust - her sürümde çalışır)
fprintf('=== GPU TANILAMA ===\n\n');

n = gpuDeviceCount;
fprintf('1) GPU sayısı: %d\n', n);

if n == 0
    fprintf('GPU bulunamadı (Parallel Computing Toolbox / driver kontrol edin).\n');
    return;
end

% Forward-compat varsa dene, yoksa geç
try
    if exist('parallel.gpu.enableCUDAForwardCompatibility','file') == 2
        parallel.gpu.enableCUDAForwardCompatibility(true);
    end
catch ME
    fprintf('[Uyarı] ForwardCompatibility açılamadı: %s\n', ME.message);
end

% GPU device al
d = gpuDevice;
fprintf('2) GPU Adı: %s\n', d.Name);

% Compute capability bazen char/string, bazen numeric gelebiliyor (sürüm farkı)
try
    cc = d.ComputeCapability;
    if isnumeric(cc)
        fprintf('   Compute Capability: %s\n', strjoin(string(cc), ', '));
    else
        fprintf('   Compute Capability: %s\n', string(cc));
    end
catch
    fprintf('   Compute Capability: (bilgi yok)\n');
end

fprintf('   Toplam Bellek: %.2f GB\n', d.TotalMemory/1e9);
fprintf('   Kullanılabilir Bellek: %.2f GB\n', d.AvailableMemory/1e9);

% CUDA Toolkit/Driver bilgisi: cudaVersion yoksa alternatifleri dene
printed = false;

% Bazı sürümlerde DriverVersion/ToolkitVersion property olabilir
try
    if isprop(d,'DriverVersion')
        fprintf('   NVIDIA Driver: %s\n', string(d.DriverVersion));
        printed = true;
    end
end
try
    if isprop(d,'ToolkitVersion')
        fprintf('   CUDA Toolkit: %s\n', string(d.ToolkitVersion));
        printed = true;
    end
end

% Hiçbiri yoksa en azından MATLAB sürümünü yaz
if ~printed
    fprintf('   CUDA Toolkit: (bu MATLAB sürümünde doğrudan alan yok)\n');
end

fprintf('\n3) MATLAB sürümü: %s\n', version);

% Basit GPU testi
fprintf('\n4) GPU Testi:\n');
try
    A = gpuArray.rand(1000,'single');
    B = gpuArray.rand(1000,'single');
    tic;
    C = A*B;
    wait(d);
    t = toc;
    fprintf('   ✓ 1000x1000 single matmul: %.4f s\n', t);
    clear A B C;
catch ME
    fprintf('   ✗ GPU testi hata: %s\n', ME.message);
end

fprintf('\n=== TANILAMA SONU ===\n');