function [x, itr] = Lp_solver_depthver2_gpu_2_double_v3_fast_console(J0, b0, p, lambda0, tol, max_itr, nu, eps0, varargin)
% Optimized GPU-only Lp solver (double precision, no CPU fallback).
% Based on Lp_solver_depthver2_gpu_2_double_v3.m.
%
% This version preserves CUDA forward compatibility checks for newer GPUs
% while using strided checks to minimize CPU-GPU sync, and supporting 
% direct gpuArray inputs to avoid redundant copies.
%
% x = Lp_solver_depthver2_gpu_2_double_v3_fast_console(J0, b0, p, lambda0, tol, max_itr, nu, eps0, [x0], [D], [resetGpuAtExit], [stride])

    %% 0) Input checks
    if ~isnumeric(J0) || ~isnumeric(b0)
        error('J0 and b0 must be numeric. class(J0)=%s, class(b0)=%s', class(J0), class(b0));
    end
    if isempty(J0) || isempty(b0)
        error('J0 or b0 is empty.');
    end
    if issparse(J0), J0 = full(J0); end
    if issparse(b0), b0 = full(b0); end
    if isvector(b0), b0 = b0(:); end

    [m, n] = size(J0);
    if size(b0, 1) ~= m
        error('Dimension mismatch: size(J0,1)=%d but size(b0,1)=%d', m, size(b0, 1));
    end
    if ~isfinite(p) || p <= 0 || p > 1
        error('p must satisfy 0 < p <= 1. p=%g', p);
    end
    if ~isscalar(lambda0) || ~isfinite(lambda0) || lambda0 < 0
        error('lambda0 must be a finite, nonnegative scalar. lambda0=%g', lambda0);
    end
    if nargin < 8 || isempty(eps0) || eps0 <= 0
        eps0 = 1e-10;
    end

    %% 1) GPU must be available (with v3 forward compatibility)
    if exist('gpuDeviceCount', 'file') ~= 2 || gpuDeviceCount < 1
        error('No GPU device found. Lp_solver_depthver2_gpu_2_double_v3_fast_console does not allow CPU fallback.');
    end

    try
        d = initialize_gpu_with_forward_compat();
        wait(d);
        testArr = gpuArray(ones(10, 1, 'double'));
        testSum = sum(testArr); %#ok<NASGU>
        clear testArr testSum;
        % fprintf('GPU in use (double): %s | CC=%s\n', d.Name, d.ComputeCapability);
    catch ME
        error('GPU initialization failed. No CPU fallback. Reason: %s', ME.message);
    end

    %% 2) Move data to GPU / Normalize
    if isa(J0, 'gpuArray')
        A = J0;
        maxJ = 1;
    else
        try
            J0g = gpuArray(double(J0));
            maxJ = max(J0g(:));
            if gather(maxJ) == 0, maxJ = 1; end
            A = J0g ./ maxJ;
        catch ME
            error('GPU transfer failed. No CPU fallback. Reason: %s', ME.message);
        end
    end
    
    if isa(b0, 'gpuArray')
        b = b0;
        maxB = 1;
    else
        try
            b0g = gpuArray(double(b0));
            maxB = max(b0g(:));
            if gather(maxB) == 0, maxB = 1; end
            b = b0g ./ maxB;
        catch ME
            error('GPU transfer failed. No CPU fallback. Reason: %s', ME.message);
        end
    end

    %% 3) x0
    if nargin > 8 && ~isempty(varargin{1})
        x0 = varargin{1};
        if isvector(x0), x0 = x0(:); end
        if ~isa(x0, 'gpuArray')
            x0 = gpuArray(double(x0));
        end
    else
        x0 = gpuArray.zeros(n, 1, 'double');
    end

    %% 4) D
    if nargin > 9 && numel(varargin) >= 2 && ~isempty(varargin{2})
        Dmat = varargin{2};
        if issparse(Dmat), Dmat = full(Dmat); end
        if isa(Dmat, 'gpuArray')
            D = Dmat;
        else
            D = nonzeros(Dmat);
            D = D(:);
            if numel(D) ~= n
                error('D length mismatch: numel(nonzeros(D))=%d, n=%d', numel(D), n);
            end
            D = gpuArray(double(D));
        end
    else
        D = gpuArray.ones(n, 1, 'double');
    end

    %% 5) Optional parameters
    resetGpuAtExit = false;
    if nargin > 10 && numel(varargin) >= 3 && ~isempty(varargin{3})
        resetGpuAtExit = logical(varargin{3});
    end
    
    stride = 10;
    if nargin > 11 && numel(varargin) >= 4 && ~isempty(varargin{4})
        stride = varargin{4};
    end

    %% 6) Lambda init
    lambda = gpuArray(repmat(double(lambda0), n, 1));

    %% 7) Iteration
    itr = 1;
    tol_x = 1;
    tol_x0 = 10;
    check = 1;
    x = x0;

    % Initial cost (GPU)
    cost = norm(A * x0 - b)^2 + lambda0 * sum(abs(D .* x0) ./ (abs(x0).^(1 - p) + eps0));
    cost_val = gather(cost);

    while itr <= max_itr && tol_x > tol && abs(check) > tol * 1e-4 && isfinite(cost_val)
        tol_x_old = tol_x;
        
        % Run 'stride' iterations entirely on GPU without CPU sync
        for s_idx = 1:stride
            if itr > max_itr, break; end
            
            x_prev_step = x0;
            
            % Gradient step
            r_vec = b - A * x0;
            xt = x0 + 2 * nu .* (A' * r_vec);
            
            % Update lambda if p ~= 1
            if p ~= 1
                lambda = lambda0 ./ (abs(x0).^(1 - p) + eps0);
            end
            
            % Shrinkage / Thresholding
            x = shrinkage(xt, nu * (D .* lambda));
            x0 = x;
            itr = itr + 1;
        end
        
        % Check convergence (gather scalar)
        tol_x = gather(norm(x - x_prev_step));
        check = tol_x_old - tol_x;
        
        % Cost computation (gather scalar)
        if p ~= 1
            cost = norm(A * x - b)^2 + sum(lambda .* abs(D .* x));
        else
            cost = norm(A * x - b)^2 + lambda0 * sum(abs(D .* x));
        end
        cost_val = gather(cost);
        
        % --- İterasyon bilgisini ekrana yazdırma ---
        if mod(itr-1, 100) < stride
            fprintf('İterasyon: %5d | Cost: %.6e | tol_x: %.6e\n', itr-1, cost_val, tol_x);
        end
    end

    %% 8) Rescale and gather/return
    x = x * (maxB / maxJ);
    if ~isa(J0, 'gpuArray')
        x = gather(x);
    end

    %% 9) Optional cleanup
    if resetGpuAtExit
        try
            reset(gpuDevice());
        catch
        end
    end
end

function d = initialize_gpu_with_forward_compat()
    try
        d = gpuDevice();
        return;
    catch ME
        if ~should_try_forward_compat(ME)
            rethrow(ME);
        end
    end

    if ~supports_forward_compat_toggle()
        rethrow(ME);
    end

    parallel.gpu.enableCUDAForwardCompatibility(true);
    d = gpuDevice();
    warning(['CUDA forward compatibility enabled for this MATLAB session. ' ...
             'On newer GPUs this may be slower and may show unexpected behavior.']);
end

function tf = should_try_forward_compat(ME)
    msg = string(ME.message);
    tf = contains(msg, "higher compute capability", 'IgnoreCase', true) || ...
         contains(msg, "forward compatibility", 'IgnoreCase', true) || ...
         contains(msg, "not supported", 'IgnoreCase', true);
end

function tf = supports_forward_compat_toggle()
    tf = exist('parallel.gpu.enableCUDAForwardCompatibility', 'file') == 2 || ...
         exist('parallel.gpu.enableCUDAForwardCompatibility', 'builtin') == 5;
end

function val = shrinkage(x, a)
    val = sign(x) .* max(abs(x) - a, 0);
end
