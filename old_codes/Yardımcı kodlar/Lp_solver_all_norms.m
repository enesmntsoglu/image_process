function [x_L0, x_L1, x_L2] = Lp_solver_all_norms(J0, b0, lambda0, tol, max_itr, nu, eps, varargin)
% Lp_solver_all_norms solves the inverse problem for L0, L1, and L2 norms.
% Outputs: x_L0, x_L1, x_L2 - solutions for each norm.
% Inputs:
% J0: sensitivity matrix
% b0: measurement vector
% lambda0: regularization parameter (scalar)
% tol: tolerance for convergence
% max_itr: maximum number of iterations
% nu: gradient step size
% eps: small value to avoid division by zero
% varargin: optional inputs - (1) x0: initial guess, (2) D: depth-weighting matrix

%% Normalization
A = J0 ./ max(max(J0));
b = b0 ./ max(max(b0));

[~, n] = size(A);

% Initial guess
if nargin > 7
    x0 = varargin{1};
else
    x0 = zeros(n, 1);
end

% Depth weighting matrix
if nargin > 8
    D = varargin{2};
else
    D = eye(n);
end
D = nonzeros(D); % Convert diagonal matrix to vector for efficiency

%% Placeholder for solutions
x_L0 = x0;
x_L1 = x0;
x_L2 = x0;

%% Solve for each norm
% 1. L0-norm approximation (p ~ 0)
[x_L0, cost_L0] = solve_lp(A, b, 0.1, lambda0, tol, max_itr, nu, eps, x0, D);

% 2. L1-norm
[x_L1, cost_L1] = solve_lp(A, b, 1, lambda0, tol, max_itr, nu, eps, x0, D);

% 3. L2-norm
[x_L2, cost_L2] = solve_lp(A, b, 2, lambda0, tol, max_itr, nu, eps, x0, D);

%% Display results
fprintf("Final Costs:\nL0-norm: %.4e\nL1-norm: %.4e\nL2-norm: %.4e\n", cost_L0, cost_L1, cost_L2);
end

%% Subfunction to solve Lp problem
function [x, final_cost] = solve_lp(A, b, p, lambda0, tol, max_itr, nu, eps, x0, D)
    % Initialize variables
    [~, n] = size(A);
    lambda = repmat(lambda0, n, 1);
    cost = norm(A * x0 - b)^2 + lambda0 * sum(abs(D .* x0) ./ (abs(x0).^(1 - p) + eps));

    itr = 1;
    tol_x = 1;
    tol_x0 = 10;
    check = 1;

    while itr <= max_itr && tol_x > tol && abs(check) > tol * 1e-4 && cost ~= inf
        check = tol_x0 - tol_x;

        % Update x using gradient descent
        xt = x0 + 2 * nu .* (A' * (b - A * x0));

        % Update lambda for p < 1
        if p ~= 1 && p ~= 2
            lambda = lambda0 ./ (abs(x0).^(1 - p) + eps);
        end

        % Apply shrinkage operator (soft thresholding for sparsity)
        x = shrink(xt, nu * (D .* lambda));

        % Convergence check
        tol_x0 = tol_x;
        tol_x = norm(x - x0);

        % Update cost function
        if p == 2
            cost = norm(A * x - b)^2 + lambda0 * norm(D .* x, 2)^2;
        elseif p == 1
            cost = norm(A * x - b)^2 + lambda0 * sum(abs(D .* x));
        else
            cost = norm(A * x - b)^2 + sum(lambda .* abs(D .* x));
        end

        x0 = x; % Update x0 for next iteration
        itr = itr + 1;
    end

    final_cost = cost;
end

%% Shrinkage operator
function x = shrink(y, lambda)
    % Applies soft thresholding for sparsity
    x = sign(y) .* max(abs(y) - lambda, 0);
end
