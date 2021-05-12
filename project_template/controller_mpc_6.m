% BRIEF:
%   Controller function template. Input and output dimension MUST NOT be
%   modified.
% INPUT:
%   Q: State weighting matrix, dimension (3,3)
%   R: Input weighting matrix, dimension (3,3)
%   T: Measured system temperatures, dimension (3,1)
%   N: MPC horizon length, dimension (1,1)
% OUTPUT:
%   p: Heating and cooling power, dimension (3,1)

function p = controller_mpc_6(Q,R,T,N,~)
% controller variables
persistent param yalmip_optimizer

% initialize controller, if not done already
if isempty(param)
    [param, yalmip_optimizer] = init(Q,R,T,N);
end

% evaluate control action by solving MPC problem
[u_mpc,errorcode] = yalmip_optimizer(T);
if (errorcode ~= 0)
    warning('MPC6 infeasible');
end
p = u_mpc; % p_sp has changed

% observer update
% ...

% set point update
% ...
end

function [param, yalmip_optimizer] = init(Q,R,T,N)
% get basic controller parameters
param = compute_controller_base_parameters;
% get terminal cost
% ...
% get terminal set
% ...
% design disturbance observer
A_aug = [param.A, param.Bd; zeros(3), eye(3)];
B_aug = [param.B; zeros(3)];
C_aug = [eye(3), zeros(3)];
P = [0, 0, 0, 0.5, 0.5, 0.5];
L = -place(A_aug', C_aug', P)';

% init state and disturbance estimate variables
% ...
% implement your MPC using Yalmip here
nx = size(param.A,1);
nu = size(param.B,2);
U = sdpvar(repmat(nu,1,N-1),ones(1,N-1),'full');
X = sdpvar(repmat(nx,1,N),ones(1,N),'full');
T0 = sdpvar(nx,1,'full');
d0 = sdpvar(nx,1,'full');
T_sp = sdpvar(nx,1,'full');
p_sp = sdpvar(nu,1,'full');



objective = 0;
constraints = [];
constraints = [constraints, X{1} == T0 - T_sp];
constraints = [constraints, T_sp == param.A*T_sp + param.B*p_sp + param.Bd*d0];
for k = 1:N-1
    constraints = [constraints, X{k+1} == param.A * X{k} + param.B * U{k} + d0];
    constraints = [constraints, param.Xcons(:,1)+param.T_sp <= X{k+1} <= param.Xcons(:,2)+param.T_sp];
    constraints = [constraints, param.Ucons(:,1)+param.p_sp <= U{k} <= param.Ucons(:,2)+param.p_sp];
%     objective = objective + U{k}'*R*U{k} + X{k}'*Q*X{k};
    objective = objective + (U{k}-p_sp)'*R*(U{k}-p_sp) + (X{k}-T_sp)'*Q*(X{k}-T_sp);
end


% get terminal cost
[~, P_inf, ~] = dlqr(param.A, param.B, Q, R);
objective = objective + (X{N}-T_sp)'*P_inf*(X{N}-T_sp);

% terminal set constraint
[A_x, b_x] = compute_X_LQR(Q, R);
constraints = [constraints, A_x * X{N} <= b_x];

ops = sdpsettings('verbose',0,'solver','quadprog');
yalmip_optimizer = optimizer(constraints,objective,ops,T0,U{1});
end