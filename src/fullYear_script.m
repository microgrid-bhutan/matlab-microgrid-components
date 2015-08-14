%% This script is a mathemathical model of the simulink-version of the microgrid.
% It is very simplified, and is to give a fast simulation of the situation
% over the year, based on simple input-data
% a lot of the formulas used and approach presented is aquired from
% SAPV_buthan_01[...] by Stefoano Mandelli


%% Initialization
% Importing the (expected) available data
clear all
close all 

tic     % Start timer for the script

path_to_dataBase = 'C:\Users\MicrogridProject\Documents\MATLAB\Jeemijn\matlab-microgrid-components\dataBase\';
irr = importdata([path_to_dataBase,'solar_data_Phuntsholing_baseline.mat']);             % Input of solar data in [kW]
T_amb = importdata([path_to_dataBase,'surface_temp_phuent_2004_hour.mat']);              % Importing ambient temperature of site in [C]
Load = importdata([path_to_dataBase,'LoadCurve_normalized_single_3percent_100.mat']);    % Load data in kW, hourly resolution

% Declaration of variables
ELPV = zeros(1,length(irr));          % Energy loss PV (Energy not exploited)
LL = zeros(1,length(irr));            % Loss of Load for time period. If 0 power is delivered; if some negative number then this is the loss of load.
SoC = zeros(1,length(irr));           % State of Charge of the battery
batt_balance = zeros(1,length(irr));  % Powerflow in battery. Positive flow out from battery, negative flow is charging
E_batt = zeros(1,length(irr));        % Current energy stored in the battery

%% System components 
% System details and input-variables are as follows

% INPUT VALUES
P_syst_des = 295;         % INPUT Desired system capacity in [kW]   N.B. 'P_syst_des' is equivalent to 'PV_power_i' in the SAPV_buthan_01 script.
E_batt_nom = 1385;        % INPUT Capacity of the battery in [kWh]  N.B. 'E_batt_nom' is equivalent to 'Batt_cap_i' in the SAPV_buthan_01 script.

% PV panels
eta_BoS = 0.85;           % Balance Of System: account for such factors as soiling of the panels, wiring losses, shading, snow cover, aging, and so on
temp_degen = 0.004;       % Derating of panel's power due to temperature [ /  C]
T_ref = 25;               % Nominal ambient test-temperature of the panels [C]
T_nom = 47;               % Nominal operation temperature in [C]

% Battery 
SoC_min = 0.4;                    % Minimum allowed SoC for the battery
SoC(1) = 0.4;                     % Initial state of Charge of the battery
eta_char = 0.85;                  % Charge efficiency of the battery
eta_disch = 0.9;                  % Discharge efficiency of the battery
E_batt(1) = E_batt_nom * SoC(1);  % Current energy stored in the battery

% Inverter
eta_inv = 0.9;                    % Inverter efficiency

% Solar panels
% Here are the details for the solar panels, PER MODULE 
irr_nom = 0.8;                              % Irradiation at nominal operation [kW / m^2]

% info not being used:
% P_mod = 250;                                % Module power in [W]
% n_mod = ceil(P_syst_des * 1e3 / P_mod);     % Number of modules required for the system of given size
% a_module = 1.65;                            % Module area in [m^2]
% V_oc = 34.4;                                % Open circuit voltage [V]
% P_syst = n_mod * P_mod;                     % Actually installed capacity [W]

% PV-cell-temperature
T_cell = T_amb  +  irr .* (T_nom - T_ref) / irr_nom;    % Cell temperature as function of ambient temperature
eta_cell = 1 - temp_degen * (T_cell - T_ref);           % Cell efficiency as function of temperature
P_pv =  irr.* eta_cell.* P_syst_des * eta_BoS; % Power produced by the PV-installation. see p.191 of thesis Stefano Mandelli

%% Power balance
% Here follows the calculation of the power-balance of the system
batt_balance = Load / eta_inv - P_pv;                   % Array containing the power balance of the battery for each time step throughout the year (negative value is charging battery) [kWh]

for i = 2:length(irr)
    
    % Charging the battery
    if batt_balance(i) < 0                                              % PV production is larger than Load. Battery will be charged
        EB_flow = batt_balance(i) * eta_char;                           % energy flow that will be stored in the battery i.e. including losses in charging. Equivalent to flow_from_batt in SAPV script.
        if (SoC(i - 1) - batt_balance(i) / E_batt_nom) > 1              % SoC at n-1  +  power charging will exceed battery capacity limit
            ELPV(i) = E_batt(i - 1) - batt_balance(i) - E_batt_nom;     % Power not being utilized is the amount of power not charged to the battery, and must be dumped
            batt_balance(i) = E_batt(i - 1) - E_batt_nom;               % Updating batt_balance to actual amount charged
            E_batt(i) = E_batt_nom;                                     % Battery is full, thus energy stored = max energy in batt
            SoC(i) = E_batt(i) / E_batt_nom;                            % SoC will be 1
        else                                                            % Sufficient room in battery
            E_batt(i) = E_batt(i - 1) - EB_flow;
            SoC(i) = E_batt(i) / E_batt_nom;
        end
    end
    % Discharging the battery
    if batt_balance(i) > 0                                              % PV production is lower than Load consumption
        EB_flow = batt_balance(i) / eta_disch;                          % Energy flow from the battery, including losses in discharging
        if (SoC(i - 1) - EB_flow / E_batt_nom) >= SoC_min              % Sufficient power in battery
            E_batt(i) = E_batt(i - 1) - batt_balance(i);
            SoC(i) = E_batt(i) / E_batt_nom;
        else                                                            % Not enough power in battery
            E_batt(i) = E_batt(i - 1) - EB_flow;                        % Energy in battery without SoC limit (only for calculation purpose)
            SoC(i) = E_batt(i) / E_batt_nom;                            % SoC in battery without limit (only for calculation purpose)
            LL(i) = E_batt(i) - E_batt_nom * SoC_min;                   % Lost power, power not delivered to the Load
            E_batt(i) = E_batt_nom * SoC_min;                           % Updating to real energy in battery
            SoC(i) = SoC_min;                                           % Updating to real SoC in battery
            batt_balance(i) = (SoC(i - 1) - SoC(i)) * E_batt_nom;
        end
    end
    if batt_balance(i) == 0;            % No power exchanged with the battery
        E_batt(i) = E_batt(i - 1);      % Energy stored in battery remains the same
        SoC(i) = SoC(i - 1);            % State of Charge remains the same
    end
end
    
toc % End timer

batt_balance_pos = subplus(batt_balance);         % batt_balance_pos becomes a vector only containing positive values in batt_balance i.e. only interested in when discharging. Negative values = 0
abs(sum(LL) / sum(Load))                          % Finds percentage of Load not served (w.r.t. kWh)
length(LL(find(LL<0))) / length(LL)               % System Average Interruption Frequency Index (SAIFI), how many hours are without power  (w.r.t. hours)

%% Plots

figure(1)
plot(Load,'Color',[72 122 255] / 255)
hold on
plot(P_pv,'Color',[255 192 33] / 255)
hold on
plot(batt_balance_pos,'Color',[178 147 68] / 255)
hold off
xlabel('Time over the year [hour]')
ylabel('Energy [kWh]')
title('Energy produced and estimated load profile over the year')
legend('Load profile','Energy from PV', 'Energy flow in battery')


figure(2)
plot(SoC,'Color',[64 127 255] / 255)
hold on
plot(LL ./ E_batt_nom + SoC_min,'Color',[255 91 60] / 255)
hold on
plot(ELPV ./ E_batt_nom + 1,'Color',[142 178 68] / 255)
hold off
xlabel('Time over the year [hour]')
ylabel('Power refered to State of Charge of the battery')
legend('State of charge', 'Loss of power', 'Overproduction, not utilized')
path = '/Users/hakon/Dropbox/Master_i_skyen/Thesis/Figures/Chap3';
saveas(gca, fullfile(path,'batt_year.eps'),'epsc')      % Saves figure to path, as eps in colours
