function [tab, path] = Table_1D_Generator_R3(Rocket, Environment, H_target, drag_func, convert_func, phi_span, N_H, N_AB, ax)
% TABLE_1D_Generator_R2 computes the control table for a Rocket in given
% Environment aiming target altitude H_target.
% INPUTS:
% - Rocket      : Rocket structure
% - Environment : Environment structure
% - H_target    : Aimed altitude [m]
% - drag_func   : airbrake drag function, prototype: CD = ab_drag(Rocket, 
% phi, alpha, Uinf, nu)
% - convert_func: conversion function for AB_command in table, prototype
% phi_conv = f(phi)
% - phi_span    : airbrake opening angle span
% - N_H         : number of discretization points in altitude
% - N_AB        : number of discretization points in airbrake aperture
% - ax          : (opt) Define plot axes
    
% -------------------------------------------------------------------------
% Definitions
% -------------------------------------------------------------------------
 theta_AB = linspace(phi_span(1), phi_span(2), N_AB); % [deg]

% rail length
x_rail = Environment.Rail_Length;

% -------------------------------------------------------------------------
% Forward simulation; x1 and x2 for ±10% of thrust error
% -------------------------------------------------------------------------
tspan = [0, 30];
x0 = [0,0];
Option = odeset('Events', @myEvent);
[t,x,t1,x1,t2,x2] = Sim_1D_R3(Rocket, Environment, tspan, x0, drag_func, theta_AB(1),...
    'Velocity', 0, -1);
% get altitude and time value for beginning of burn phase
H_initial = interp1(t, x(:,1), Rocket.Burn_Time, 'linear');
V_rail = interp1(x(:,1), x(:,2), x_rail, 'linear');
display(['Velocity off rail: ' num2str(V_rail) ' m/s']);

if (nargin>8)
   plotAxes = ax; 
else
    figure; 
    plotAxes = gca;
end

hold(plotAxes, 'on');
set(plotAxes, 'Fontsize', 16); xlabel(plotAxes, 'h [m]'); ylabel(plotAxes, 'v [m/s]');
plot(plotAxes, x(:,1), x(:,2), 'k--', 'DisplayName', 'Nominal trajectory');
plot(plotAxes, x1(:,1), x1(:,2), 'k-', 'DisplayName', '+10% trajectory');
plot(plotAxes, x2(:,1), x2(:,2), 'k-', 'DisplayName', '-10% trajectory');
hold(plotAxes, 'on');
display('Sim: Boost OK ');

% -------------------------------------------------------------------------
% Backward simulation
% -------------------------------------------------------------------------
tspan = [100 0];
x0 = [H_target, 0];
Brake_Results = {};
for i = 1:N_AB
    [t,x,t1,x1,t2,x2] = Sim_1D_R3(Rocket, Environment, tspan, x0, drag_func, theta_AB(i), 'Altitude', H_initial, 0);
    if i==N_AB
        max(x1(:,2))-max(x(:,2))
        plot(plotAxes, x1(:,1), x1(:,2)-(max(x1(:,2))-max(x(:,2))), 'DisplayName', ['\phi +10% = ' num2str(convert_func(theta_AB(i))) '^\circ']);
    end
    if i==N_AB-1
        plot(plotAxes, x(:,1), x(:,2), 'DisplayName', ['\phi = ' num2str(convert_func(theta_AB(i))) '^\circ']);
    end
    display(['Sim: Angle ' num2str(theta_AB(i)) ' OK']);
    Brake_Results{i} = x; 
end

lgd = legend(plotAxes, 'show');  
title(plotAxes, 'Airbrake effect check');
set(lgd, 'Location', 'SouthWest');

figure;
plot(t,x(:,1));
% -------------------------------------------------------------------------
% Table generation
% -------------------------------------------------------------------------
% set table columns to 0
h_tab = zeros(N_H*N_AB,1); v_tab = h_tab; theta_tab = h_tab;
% determine discrete altitudes where table is generated
h_discret = linspace(H_initial, H_target, N_H);
% generate table
for i = 1:N_H
    for j = 1:N_AB
        h_tab((i-1)*N_AB+j) = h_discret(i);
        v_tab((i-1)*N_AB+j) = interp1(Brake_Results{j}(:,1), Brake_Results{j}(:,2), h_discret(i), 'linear');
        theta_tab((i-1)*N_AB+j) = theta_AB(j);
    end
end
tab = [h_tab, v_tab, convert_func(theta_tab)];
csvwrite(['1D_TAB_TARGET=' num2str(H_target)], tab);
[filepath, name, ext] = fileparts(['1D_TAB_TARGET=' num2str(H_target)]);
path = [filepath,name,ext];

% -------------------------------------------------------------------------
% Write .h file
% -------------------------------------------------------------------------
H_path = [filepath, 'lookup_table_shuriken.h'];
writeAirbrakeTable(H_path, N_H*N_AB, N_AB, tab);
end