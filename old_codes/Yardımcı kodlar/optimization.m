% Define the objective function for your reconstruction problem
function result = reconstructionObjective(lambda, rootfact)
    % Your reconstruction logic here
    b_norm = b./max(b(:));
    sens_norm = ms./max(ms(:));
    [~, n] = size(sens_norm);

    % Calculate E matrix
    E = sens_norm' * sens_norm;

    % Calculate D matrix
    Dtmp = (eye(n) * diag(E)).^rootfact;
    D = Dtmp./max(Dtmp);

    % Run Lp_solver and calculate the objective result
    x_initial = zeros(n, 1);
    x_approxLp = Lp_solver_depthver2(sens_norm, b_norm, 1, lambda, 1e-6, 10000, 1e-3, 1e-10, x_initial, D);
    result = psnr(x_approxLp, X); % Change X with the actual reference image
end

% Set the ranges for the parameters
lambda_range = linspace(0, 50, 1000); % Adjust as needed
rootfact_range = linspace(0.1, 1, 10); % Adjust as needed

best_result = -inf;
best_lambda = 0;
best_rootfact = 0;

% Optimization Loop
for i = 1:length(lambda_range)
    for j = 1:length(rootfact_range)
        current_lambda = lambda_range(i);
        current_rootfact = rootfact_range(j);

        % Evaluate the objective function
        current_result = reconstructionObjective(current_lambda, current_rootfact);

        % Update best result if needed
        if current_result > best_result
            best_result = current_result;
            best_lambda = current_lambda;
            best_rootfact = current_rootfact;
        end
    end
end

% Display the best parameters and result
disp(['Best Lambda: ', num2str(best_lambda)]);
disp(['Best Rootfact: ', num2str(best_rootfact)]);
disp(['Best PSNR: ', num2str(best_result)]);
