% BRIEF:
%   Controller function template. Input and output dimension MUST NOT be
%   modified.
% INPUT:
%   Q: State weighting matrix, dimension (3,3)
%   R: Input weighting matrix, dimension (3,3)
%   T: Measured system temperatures, dimension (3,1)
%   N: MPC horizon length, dimension (1,1)
%   d: Disturbance matrix, dimension (3,N)
% OUTPUT:
%   p: Heating and cooling power, dimension (3,1)

function p = controller_mpc_5(Q,R,T,N,d)
% controller variables
persistent param yalmip_optimizer

% initialize controller, if not done already
% if isempty(param)
%     [param, yalmip_optimizer] = init(Q,R,N);
% end

[param, yalmip_optimizer] = init(Q,R,N,d);

% evaluate control action by solving MPC problem
[u_mpc,errorcode] = yalmip_optimizer(T);
if (errorcode ~= 0)
    warning('MPC5 infeasible');
end
p = u_mpc + param.p_sp;
end

function [param, yalmip_optimizer] = init(Q,R,N,d)
% get basic controller parameters
param = compute_controller_base_parameters;

% implement your MPC using Yalmip here
nx = size(param.A,1);
nu = size(param.B,2);
U = sdpvar(repmat(nu,1,N-1),ones(1,N-1),'full');
X = sdpvar(repmat(nx,1,N),ones(1,N),'full');
T0 = sdpvar(nx,1,'full');
EPS = sdpvar(repmat(nx,1,N),ones(1,N),'full');

v = 1;
S = eye(3);

disp(d(:,1));
    
objective = 0;
constraints = [];
constraints = [constraints, X{1} == T0 - param.T_sp];
for k = 1:N-1
    constraints = [constraints, X{k+1} == param.A * X{k} + param.B * U{k} + param.Bd * d(:,k)];
    constraints = [constraints, param.Xcons(:,1) - EPS{k} <= X{k+1} <= param.Xcons(:,2) + EPS{k}];
    constraints = [constraints, param.Ucons(:,1) <= U{k} <= param.Ucons(:,2)];
    constraints = [constraints, EPS{k} >= 0];
    objective = objective + U{k}'*R*U{k} + X{k}'*Q*X{k} + v*norm(EPS{k},Inf) + EPS{k}'*S*EPS{k};
end

% get terminal cost
[~, P_inf, ~] = dlqr(param.A, param.B, Q, R);
objective = objective + X{N}'*P_inf*X{N} + v*norm(EPS{N},Inf) + EPS{N}'*S*EPS{N};

% terminal set constraint
[A_x, b_x] = compute_X_LQR(Q, R);
constraints = [constraints, A_x * X{N} <= b_x];

ops = sdpsettings('verbose', 0, 'solver', 'quadprog');
yalmip_optimizer = optimizer(constraints, objective, ops, T0, U{1});

end