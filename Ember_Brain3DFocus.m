%% Load brain model and goal to focus on
clear; clc;

% load brain model
% brain_model = niftiread('brain_model.nii');
brain_model = load('brain_model_skull.mat'); brain_model = brain_model.brain_model;
model = brain_model(25:224,35:274,25:224); % reduce unnecessary space
% model = brain_model(66:161,96:191,120:215); % select small section
% 
pressure_output = 50; 
% 
% reduce the number of points in the simulation
undersample_rate = 0.4;
% undersample_rate = 1.0;
if undersample_rate~=1
    model = imresize3(model, undersample_rate);
    % It prevents some loss of information from the skull due to undersampling.
    model(model>=190 & model<=220)=190;
    model(model>190)=255;
end
% 
% volumeViewer(model); pause(2);
% 
% define the sequence of points to be focused on with ultrasound.
%{
target_points = [[100, 55, 70];...
                 [150, 80, 100];...
                 [50, 90, 140];...
                 [110, 95, 90];...
                 [90, 110, 110];...
                 [75, 120, 120];...
                 [130, 150, 130]]
%}
% This is a single point. 
target_points = [[100,120,130]];
target_points = round(target_points*undersample_rate);
% focus_points_mask = zeros(size(model));
% focus_points_mask(target_points(1,1)) = 1;
% mask with the points that will be focused on
focus_points_mask = zeros(size(model));
for ipoint=1:size(target_points,1)
    focus_points_mask(target_points(ipoint,1), target_points(ipoint,2), target_points(ipoint,3)) = 1;
end

%% Define the simulation medium and properties.
% 
% create the 2D - computational grid
[Nx, Ny, Nz] = size(model);   % number of grid points in the X/Y direction
dx = 1e-3 / undersample_rate;                % grid point spacing in the X direction [m]
dy = 1e-3 / undersample_rate;                % grid point spacing in the Y direction [m]
dz = 1e-3 / undersample_rate;                % grid point spacing in the Z direction [m]
kgrid = kWaveGrid(Nx, dx, Ny, dy, Nz, dz);
% 
% define the properties of the propagation medium
%tissue      speed[m/s]  density(Kg/m3)  absortion[dB/(MHz.cm)] img-pixel-values
%air          - 343.0      -  1.20        - 0.0004              - [0]*
%water        - 1475.0     -  1000        - 0.05?               - [0]*
%midbrain     - 1546.3     -  1000        - 0.6                 - [21-39] U [51-80]
%white matter - 1552.5     -  1050        - 0.6                 - [40-50]
%grey matter  - 1500.0     -  1100        - 0.6                 - [81-220]
%cSpinalFluid - 1475.0     -  1000        - 0.05                - [1-9]
%scalp        - 1540.0     -  1000        - 0.1                 - [10-20]
%skull        - 3476.0     -  1979        - 2.7                 - [221-255]
%* whether water or air is used as the external medium.

% speed [m/s]
medium.sound_speed = 1500 * ones(Nx, Ny, Nz);           % default
%medium.sound_speed(model==0)=343.0 ;                   % air
medium.sound_speed(model==0)=1504.0;                    % water
medium.sound_speed(model>=21 & model<=78)=1546.3;       % midbrain
medium.sound_speed(model>=40 & model<=50)=1552.5;       % white matter
medium.sound_speed(model>=81 & model<=220)=1500.0;      % grey matter
medium.sound_speed(model>=1  & model<=9)=1475.0;        % cerebroSpinalFluid
medium.sound_speed(model>=10 & model<=20)=1540.0;       % scalp
medium.sound_speed(model>=221)=3476.0;                  % skull
% density [Kg/m3]
medium.density = 1000 * ones(Nx, Ny, Nz);               % default
%medium.density(model==0)=1.20;                          % air
medium.density(model==0)=1000;                          % water
medium.density(model>=21 & model<=78)=1075;             % midbrain
medium.density(model>=40 & model<=50)=1050;             % white matter
medium.density(model>=81 & model<=220)=1100;            % grey matter
medium.density(model>=1  & model<=9)=1000.0;            % cerebroSpinalFluid
medium.density(model>=10 & model<=20)=1000.0;           % scalp
medium.density(model>=221)=1969.0;                      % skull
% absortion [dB/(MHz^y cm)]
medium.alpha_power = 1.5;                               % default
medium.alpha_coeff = 0.75 * ones(Nx, Ny, Nz);           % default
%medium.alpha_coeff(model==0)=1.6;                      % air
medium.alpha_coeff(model==0)=0.05;                      % water
medium.alpha_coeff(model>=21 & model<=78)=0.6;          % midbrain
medium.alpha_coeff(model>=40 & model<=50)=0.6;          % white matter
medium.alpha_coeff(model>=81 & model<=220)=0.6;         % grey matter
medium.alpha_coeff(model>=1  & model<=9)=0.05;          % cerebroSpinalFluid
medium.alpha_coeff(model>=10 & model<=20)=0.1;          % scalp
medium.alpha_coeff(model>=221)=2.7;                     % skull

% simulation time and step
kgrid.makeTime(medium.sound_speed);

%% Define the source of ultrasound waves.
n_elements = 19;                        % grid points - impar
sensor.mask = zeros(Nx, Ny, Nz);

source2use = 6;
% Source Position:
% 1 - Array of sequential points glued to the top of the brain
% 2 - Array of sequential points glued to the top and bottom of the brain.
% 5 - Completely random points

if source2use==1
    %%%%%%% Probe with various elements glued on top of the brain. %%%%%%%%%
    array_step=1;
    array_center_pos_y = round(size(model,2)/2);
    array_center_pos_z = round(size(model,1)/2);
    for zpos=0:array_step:array_step*(n_elements-1)/2
        for ypos=0:array_step:array_step*(n_elements-1)/2
            % Quadrante +Y e +Z
            xpos = find(model(array_center_pos_z+zpos,array_center_pos_y+ypos,:)>0,1,'last');
            sensor.mask(array_center_pos_z+zpos, array_center_pos_y+ypos, xpos) = 1;
            % Quadrante -Y e +Z
            xpos = find(model(array_center_pos_z+zpos,array_center_pos_y-ypos,:)>0,1,'last');
            sensor.mask(array_center_pos_z+zpos, array_center_pos_y-ypos, xpos) = 1;
            % Quadrante +Y e -Z
            xpos = find(model(array_center_pos_z-zpos,array_center_pos_y+ypos,:)>0,1,'last');
            sensor.mask(array_center_pos_z-zpos, array_center_pos_y+ypos, xpos) = 1;
            % Quadrante -Y e -Z
            xpos = find(model(array_center_pos_z-zpos,array_center_pos_y-ypos,:)>0,1,'last');
            sensor.mask(array_center_pos_z-zpos, array_center_pos_y-ypos, xpos) = 1;
        end
    end
end

if source2use==2
    %%%%%%% Probe with various elements glued above and below the brain. %%%%%%%%%
    array_step=6;
    n_elements=round((n_elements-1)/2);
    array_center_pos_y = round(size(model,2)/2);
    array_center_pos_z = round(size(model,1)/2);
    for zpos=0:array_step:array_step*(n_elements-1)/2
        for ypos=0:array_step:array_step*(n_elements-1)/2
            % above the brain
            % Quadrante +Y e +Z
            xpos = find(model(array_center_pos_z+zpos,array_center_pos_y+ypos,:)>0,1,'last');
            sensor.mask(array_center_pos_z+zpos, array_center_pos_y+ypos, xpos) = 1;
            % Quadrante -Y e +Z
            xpos = find(model(array_center_pos_z+zpos,array_center_pos_y-ypos,:)>0,1,'last');
            sensor.mask(array_center_pos_z+zpos, array_center_pos_y-ypos, xpos) = 1;
            % Quadrante +Y e -Z
            xpos = find(model(array_center_pos_z-zpos,array_center_pos_y+ypos,:)>0,1,'last');
            sensor.mask(array_center_pos_z-zpos, array_center_pos_y+ypos, xpos) = 1;
            % Quadrante -Y e -Z
            xpos = find(model(array_center_pos_z-zpos,array_center_pos_y-ypos,:)>0,1,'last');
            sensor.mask(array_center_pos_z-zpos, array_center_pos_y-ypos, xpos) = 1;
            
            % below the brain
            % Quadrante +Y e +Z
            xpos = find(model(array_center_pos_z+zpos,array_center_pos_y+ypos,:)>0,1,'first');
            sensor.mask(array_center_pos_z+zpos, array_center_pos_y+ypos, xpos) = 1;
            % Quadrante -Y e +Z
            xpos = find(model(array_center_pos_z+zpos,array_center_pos_y-ypos,:)>0,1,'first');
            sensor.mask(array_center_pos_z+zpos, array_center_pos_y-ypos, xpos) = 1;
            % Quadrante +Y e -Z
            xpos = find(model(array_center_pos_z-zpos,array_center_pos_y+ypos,:)>0,1,'first');
            sensor.mask(array_center_pos_z-zpos, array_center_pos_y+ypos, xpos) = 1;
            % Quadrante -Y e -Z
            xpos = find(model(array_center_pos_z-zpos,array_center_pos_y-ypos,:)>0,1,'first');
            sensor.mask(array_center_pos_z-zpos, array_center_pos_y-ypos, xpos) = 1;
        end
    end
end

if source2use==5
    %%%%%%%%%%%% Random fonts on the side of the top of the brain %%%%%%%%%%%%%
    sensor_points = sort(randi(numel(model),[n_elements,1]));
    vector_mask = zeros(prod([Nx,Ny,Nz]),1);
    vector_mask(sensor_points)=1;
    sensor.mask = reshape(vector_mask, [Nx,Ny,Nz]);
end
% 
%%% LINEAR ARRAY ATTEMPT
if source2use==6
    %%%%%%% Probe with various elements glued on top of the brain. %%%%%%%%%
    array_step=2;
    offset = 70;
    array_center_pos_y = round(size(model,2)/2);
    array_center_pos_z = round(size(model,1)/2);
    for ypos=0:array_step:array_step*(n_elements-1)/2
        % Quadrante +Y e +Z
        % xpos = find(model(array_center_pos_z,array_center_pos_y+ypos,:)>0,1,'last');
        % sensor.mask(array_center_pos_z, array_center_pos_y+ypos, xpos) = 1;
        sensor.mask(array_center_pos_z, array_center_pos_y+ypos, offset) = 1;
        % Quadrante -Y e +Z
        % xpos = find(model(array_center_pos_z,array_center_pos_y-ypos,:)>0,1,'last');
        sensor.mask(array_center_pos_z, array_center_pos_y-ypos, offset) = 1;
    end
end
% 
% 
% 
%% Shows the entire assembly layout.
visualization_mask = zeros(Nx, Ny, Nz);
visualization_mask(focus_points_mask==1)=1;                 % focal points
visualization_mask(sensor.mask==1)=0.5;                     % transducors
visualization_mask(model>220)=0.022;                        % skull
volumeViewer(visualization_mask);

% mostra interfaces
if true
    for i = 1:size(model,3) interfaces_mask_x(:,:,i) = edge(model(:,:,i), 'Sobel', 0.2); end
    for i = 1:size(model,2) interfaces_mask_y(:,i,:) = edge(squeeze(model(:,i,:)), 'Sobel', 0.4); end
    for i = 1:size(model,1) interfaces_mask_z(i,:,:) = edge(squeeze(model(i,:,:)), 'Sobel', 0.4); end
    interfaces_mask = max(max(interfaces_mask_x, interfaces_mask_y),interfaces_mask_z);
    %volumeViewer(interfaces_mask);
else
    interfaces_mask = zeros(Nx,Ny,Nz);
end

pause(5);
%% Define ping for ultrasound wave targets.

% target ping signal
% ping_pressure = 25;                       % [Pa]
ping_pressure = pressure_output;                        % [Pa]
signal_freq = 0.25e6;                        % [Hz]
ping_burst_cycles = 2;
source.p = ping_pressure * toneBurst(1/kgrid.dt, signal_freq, ping_burst_cycles);

input_args = {'DataCast', 'single', ...
              'PlotSim', false};
          
% calcular delays para cada ponto
for ipoint=1:size(target_points,1)
    % definir target para fazer ping
    source.p_mask = zeros(Nx, Ny, Nz);
    source.p_mask(target_points(ipoint,1), target_points(ipoint,2), target_points(ipoint,3))=1;
    % simular
    sensor_data = kspaceFirstOrder3D(kgrid, medium, source, sensor, input_args{:});
    
    [~, max_pos] = max(sensor_data,[],2);
    sensor_delays(ipoint,:) = max(max_pos)-max_pos;
end

figure;
stackedPlot(kgrid.t_array * 1e6, sensor_data);
xlabel('Time [\mus]');
ylabel('Time Series Recorded At Each Element');


%% Simulate wave focusing on multiple targets sequentialy

% swap sensor to source and monitor pressure on all grid
source.p_mask = sensor.mask;
sensor.mask = ones(Nx,Ny,Nz);
sensor.record = {'p', 'p_max'};

% define properties of the signal to be emitted
focus_pressure = pressure_output;                %  [Pa]
focus_burst_cycles = 2;

total_sensor_max_pressure = zeros(Nx*Ny*Nz,1);

for ipoint=1:size(target_points,1)
    % Creates a signal to emit for focusing (with delays).
    source.p = focus_pressure*toneBurst(1/kgrid.dt, signal_freq, focus_burst_cycles, ...
                                   'SignalOffset', sensor_delays(ipoint,:));
    % simulation
    input_args = {'PlotLayout', false, ... 
                  'PlotPML', false, ...
                  'DisplayMask', visualization_mask | interfaces_mask,...
                  'RecordMovie', false, 'MovieName', strcat('FocusTarget',num2str(ipoint)),...
                  'DataCast', 'single'...
                  };
          
    sensor_data = kspaceFirstOrder3D(kgrid, medium, source, sensor, input_args{:});
    
    % add new sensor data to overal pressure data
    total_sensor_max_pressure = max(total_sensor_max_pressure,sensor_data.p_max);   % max
end


% Open VolumeViewer to see p_max correctly.
p_max = reshape(total_sensor_max_pressure, Nx, Ny, Nz);
p_max(model==0) = 0;           % Ignores outer points (doesn't work well with undersamples)
volumeViewer(p_max)


