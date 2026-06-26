function x = Lp_solver_depthver2(J0, b0, p, lambda0, tol, max_itr, nu, eps, varargin)
% Created by Lingling Zhao & Wenxiang Cong
% Modified by Ruoyang Yao
% Reference: Lp regularization for early gate fluorescence molecular tomography
% x = Lp_solver( J0, b0, p, lambda0, tol, max_itr, nu, varargin )
% J0: sensitivity matrix
% b0: measurement value
% p: norm value, 0<p<=1
% lambda0: initial value for regularization parameter, chosen from L-curve
% tolerance: desired cost function value
% max_itr: maximum iteration number
% nu: gradient step size, should be smaller than 1/norm(A'*A)
% optional:
%          (1) x0, initial guess for x from other solvers
%          (2) D, a diagonal depth-dependent matrix,whose diagonal entries
%          propotional to diagnal entries of A'*A

%% initialization
A=J0./max(max(J0));
b=b0./max(max(b0));

[~,n]=size(A);
%eps = 1e-10;

if nargin>8
    x0 = varargin{1};
else
    x0 = zeros(n,1);
end

if nargin>9
    D = varargin{2};
else
    D = eye(n);
end
D = nonzeros(D);  % modify the diagonal matrix to a vector to make computation faster

cost = norm(A*x0-b)^2 + lambda0*sum(abs(D.*x0)./(abs(x0).^(1-p)+eps)); % cost function

%% iteration

disp(sprintf('%5s       %9s         %9s                 %9s','iter','cost','tol','check'));
lambda = repmat(lambda0, n, 1); 

tic;

itr = 1;
tol_x = 1;
tol_x0 = 10;
check  = 1;
while itr<=max_itr && tol_x>tol && abs(check)>tol*1e-4 && cost ~= inf
    check = tol_x0-tol_x;
    % update x based on gradient
    xt = x0 + 2*nu.*(A'*(b-A*x0));
    
    % update lambda
    if p~=1
        lambda = lambda0./(abs(x0).^(1-p)+eps);
    end
    
    % x shrinkage
    tol_x0 = tol_x;
    x = shrink(xt,nu*(D.*lambda));
    tol_x = norm(x-x0); %norm(A*x-b)/norm(b); %norm(x-x0)/norm(x0);
    
   
    % update cost function value
    if p~=1
        cost = norm(A*x-b)^2 + sum(lambda.*abs(D.*x));
    else
        cost = norm(A*x-b)^2 + lambda0*sum(abs(D.*x));
    end
    
    % print info
    if mod(itr,10)==0
        disp(sprintf('%4d  %12.3e %12.3e %12.3e',itr,cost,tol_x,check));
    end
    
    x0 = x;
    itr = itr+1;
    
end

timeLp=toc;
timedisp(timeLp);

x = x*max(max(b0))/max(max(J0));
disp(sprintf('%4d  %12.3e %12.3e %12.3e',itr,cost,tol_x,check));

end