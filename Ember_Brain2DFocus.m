%% 
%% OK, I have 2D time reversal focusing through the skull working. 
%% TODO: 
%% It would be good to compare to a non-time reversed version. 
%% 
%% 
%% Clear it. 
clear; clc;

% import the brain:  
brain_model = load('brain_model_skull.mat'); brain_model = brain_model.brain_model;
brain_model = brain_model(25:225, 35:274, 39:239); % reduce unnecessary space
% define properties of the signal to be emitted
focus_pressure      = 10;                 % [Pa]
focus_burst_cycles  = 2;

% define a slice
% model = squeeze(brain_model(85,:,:));
% 
model = squeeze(brain_model(80,:,:));
% model = squeeze(brain_model(:,80,:));
% view the model
figure;
imshow(model);

% define the sequence of points to be focused on with ultrasound.

%{
target_points = [[70, 80];...
                 [90, 110];...
                 [130, 90];...
                 [160, 140]]
%}
% target_points = [[80, 75]];
% target_points = [[100, 85]]; 
target_points = [[120, 100]]; 

% mask with the points that will be focused on
focus_points_mask = zeros(size(model));
for ipoint=1:size(target_points,1)
    focus_points_mask(target_points(ipoint,1), target_points(ipoint,2)) = 1;
end

%% Define the medium and its properties.

% create the 2D - computational grid
[Nx, Ny] = size(model);   % number of grid points in the X/Y direction
dx = 1e-3;                % grid point spacing in the X direction [m]
dy = 1e-3;                % grid point spacing in the Y direction [m]
dz = 1e-3;                % grid point spacing in the Z direction [m]
kgrid = kWaveGrid(Nx, dx, Ny, dy);
% 
% define the properties of the propagation medium
%tissue      speed[m/s]  density(Kg/m3)  absortion[dB/(MHz.cm)] img-pixel-values
%air          - 343.0      -  1.20        - 0.0004              - [0]*
%water        - 1475.0     -  1000        - 0.05?               - [0]*
%midbrain     - 1546.3     -  1000        - 0.6                 - [21-39] U [51-78]
%white matter - 1552.5     -  1050        - 0.6                 - [40-50]
%grey matter  - 1500.0     -  1100        - 0.6                 - [81-220]
%cSpinalFluid - 1475.0     -  1000        - 0.05                - [1-9]
%scalp        - 1540.0     -  1000        - 0.1                 - [10-20]
%skull        - 3476.0     -  1979        - 2.7                 - [221-255]
%* whether water or air is used as the external medium.

% speed [m/s]
medium.sound_speed = 1500 * ones(Nx, Ny);               % default
%medium.sound_speed(model==0)=343.0 ;                   % air
medium.sound_speed(model==0)=1504.0;                    % water
medium.sound_speed(model>=21 & model<=78)=1546.3;       % midbrain
medium.sound_speed(model>=40 & model<=50)=1552.5;       % white matter
medium.sound_speed(model>=81 & model<=220)=1500.0;      % grey matter
medium.sound_speed(model>=1  & model<=9)=1475.0;        % cerebroSpinalFluid
medium.sound_speed(model>=10 & model<=20)=1540.0;       % scalp
medium.sound_speed(model>=221)=3476.0;                  % skull
% density [Kg/m3]
medium.density = 1000 * ones(Nx, Ny);                   % default
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
medium.alpha_coeff = 0.75 * ones(Nx, Ny);               % default
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
n_elements = 32;                        % grid points - impar
sensor.mask = zeros(Nx, Ny);

source2use = 3;
% Source Position:
    % 1 - Array of sequential points glued to the top of the brain
    % 2 - Array of sequential points glued to the top and bottom of the brain.
    % 3 - Linear array on top of the brain
    % 4 - Random points on the top side of the brain
    % 5 - Completely random points
    % 
if source2use==1
    %%%%%%% Probe com varios elementos colados em cima do cerebro %%%%%%%%%
    array_step=6;
    array_center_pos_y = size(model,1)/2;
    for ypos=0:array_step:array_step*(n_elements-1)/2    % puts all aray elements in contact with the brain
        % lado positivo em relacao ao centro
        xpos = find(model(array_center_pos_y+ypos,:)>0,1,'last');
        sensor.mask(array_center_pos_y+ypos, xpos) = 1;
        % lado negativo em relacao ao centro
        xpos = find(model(array_center_pos_y-ypos,:)>0,1,'last');
        sensor.mask(array_center_pos_y-ypos, xpos) = 1;
    end
end

if source2use==2
    %%%%%%% Probe with various elements glued above and below the brain. %%%%%%%%%
    array_step=5;
    n_elements=(n_elements-1)/2;
    array_center_pos_y = size(model,1)/2;
    for ypos=0:array_step:array_step*(n_elements-1)/2    % puts all aray elements in contact with the brain
        % positive side in relation to the center
        xpos = find(model(array_center_pos_y+ypos,:)>0,1,'last');   % cima
        sensor.mask(array_center_pos_y+ypos, xpos) = 1;
        xpos = find(model(array_center_pos_y+ypos,:)>0,1,'first');  % baixo
        sensor.mask(array_center_pos_y+ypos, xpos) = 1;
        
        % negative side in relation to the center
        xpos = find(model(array_center_pos_y-ypos,:)>0,1,'last');   % cima
        sensor.mask(array_center_pos_y-ypos, xpos) = 1;
        xpos = find(model(array_center_pos_y-ypos,:)>0,1,'first');   % baixo
        sensor.mask(array_center_pos_y-ypos, xpos) = 1;
    end
end

if source2use==3
    %%%%%%%%%%%%%%%%%%%% Linear probe on top of the brain. %%%%%%%%%%%%%%%%%%%%%
    array_step=4;
    array_center_pos_y = size(model,1)/2;
    max_brain_x = 0;
    for ypos=0:array_step:array_step*(n_elements-1)/2  % find outer brain position for array
        max_brain_x = max(max_brain_x, find(model(array_center_pos_y+ypos,:)>0,1,'last'));
        max_brain_x = max(max_brain_x, find(model(array_center_pos_y-ypos,:)>0,1,'last'));
    end
    sensor.mask(array_center_pos_y-ypos:array_step:array_center_pos_y+ypos, max_brain_x)=1;
end


if source2use==4
    %%%%%%%%%%%% Random fonts on the side of the top of the brain %%%%%%%%%%%%%
    sensor_points = sort(randi(numel(model)/3,[n_elements,1])) + numel(model)*(2/3);
    vector_mask = zeros(prod([Nx,Ny]),1);
    vector_mask(sensor_points)=1;
    sensor.mask = reshape(vector_mask, [Nx,Ny]);
end

if source2use==5
    %%%%%%%%%%%% Random fonts in matrix %%%%%%%%%%%%%
    sensor_points = sort(randi(numel(model),[n_elements,1]));
    vector_mask = zeros(prod([Nx,Ny]),1);
    vector_mask(sensor_points)=1;
    sensor.mask = reshape(vector_mask, [Nx,Ny]);
end


%% Shows the entire layout (Density/Sound Speed/Fonts/Targets)
figure;
subplot(2,2,1); % Medium Density
imagesc(medium.density);
colormap(gray);
b=colorbar;
title('Density');
xlabel(b, '[Kg/L]');

subplot(2,2,3); % Speed of sound in the medium
imagesc(medium.sound_speed);
colormap(gray);
b=colorbar;
title('Speed');
xlabel(b, '[m/s]');

interfaces_mask = edge(medium.density.*medium.sound_speed);
subplot(2,2,[2 4]); % Interfaces US
imshow(interfaces_mask);
colormap(gray);
title('Significant US Interfaces');

figure;
subplot(1,2,1); % Targets US
imshow(focus_points_mask);
colormap(gray);
title('Targets US');

subplot(1,2,2); % US Sources
imshow(sensor.mask);
colormap(gray);
title('US Sources');
pause(0.5);

%% Define ping for ultrasound wave targets.

% target ping signal
ping_pressure = 20;                    % [Pa]
% signal_freq = 0.25e6;                % [Hz]
signal_freq = 0.5e6;                   % [Hz]
ping_burst_cycles = 2;
source.p = ping_pressure * toneBurst(1/kgrid.dt, signal_freq, ping_burst_cycles);

input_args = {'DataCast', 'single', ...
              'PlotSim', false};
% This is the time reversal part. 
% Calculate delays for each point. (by that we mean focus target)
for ipoint=1:size(target_points,1)
    % Define a target to ping.
    source.p_mask = zeros(Nx, Ny);
    source.p_mask(target_points(ipoint,1),target_points(ipoint,2))=1;
    
    % simulation
    sensor_data = kspaceFirstOrder2D(kgrid, medium, source, sensor, input_args{:});
    
    [~, max_pos] = max(sensor_data,[],2);
    sensor_delays(ipoint,:) = max(max_pos)-max_pos;
end
% 
% plot the time series recorded at each array element
% figure;
% stackedPlot(kgrid.t_array * 1e6, sensor_data);
% xlabel('Time [\mus]');
% ylabel('Time Series Recorded At Each Element');
% title('US Sources');
% pause(0.5);
% % 
%% END TIME REVERSAL SECTION. 
%%  Free - field estimation section
% sensor_delays is a 1 x 31 double. 
% Make free field field focusing option. 
% use geometric beam forming to calculate the tone burst offsets for each
% create an element index relative to the centre element of the transducer
% element_index   = -(n_elements - 1)/2:(n_elements - 1)/2
% element_pitch   = array_step * dx;      %  [m]
% source_focus    = 72e-3;    % focal length [m]
% c0              = 1500;     % sound speed [m/s]
% steering_angle  = 45;
% % set indices for each element
% if rem(n_elements, 2)
%     ids = (1:n_elements) - ceil(n_elements/2);
% else
%     ids = (1:n_elements) - (n_elements + 1)/2;
% end
% % % set time delays for each element to focus at source_focus
% time_delays = -(sqrt((ids .* element_pitch).^2 + source_focus.^2) - source_focus) ./ c0;
% time_delays = time_delays - min(time_delays);
% time_delays = round(time_delays / kgrid.dt);
% time_delays = time_delays(1:31);
% sensor_delays(1,:) = time_delays;
% % % Make the time series. 
% source_test.p = ping_pressure * toneBurst(1/kgrid.dt, signal_freq, ping_burst_cycles, 'SignalOffset', time_delays);
% num_source_time_points = length(source_test.p(1,:));
% figure; % plot the input time series
% stackedPlot(kgrid.t_array(1:num_source_time_points) * 1e6, source_test.p);
% xlabel('Time [\mus]');
% ylabel('Time Series for free-field focusing');
% pause(0.5);

% % 
% 
%% Simulate wave focusing on multiple targets sequentialy

% swap sensor to source and monitor pressure on all grid
source.p_mask   = sensor.mask;
sensor.mask     = ones(Nx,Ny);
sensor.record   = {'p', 'p_max'};

total_sensor_max_pressure = zeros(Nx*Ny,1);

for ipoint=1:size(target_points,1)
    % Creates a signal to emit for focusing (with delays).
    source.p = focus_pressure*toneBurst(1/kgrid.dt, signal_freq, focus_burst_cycles, ...
                                   'SignalOffset', sensor_delays(ipoint,:));
    % simular                    
    input_args = {'PlotLayout', false, ... 
                  'PlotPML', false, ...
                  'DisplayMask', source.p_mask | focus_points_mask | model==255,...
                  'RecordMovie', false, 'MovieName', strcat('FocusTarget',num2str(ipoint)),...
                  'DataCast', 'single'};
          
    sensor_data = kspaceFirstOrder2D(kgrid, medium, source, sensor, input_args{:});
    
    if size(target_points,1)>1
        figure;
        p_max = reshape(sensor_data.p_max, Nx, Ny);     
        p_max(model<21 | model>221) = 0;           % ignores points outside the skull
        imagesc(kgrid.y_vec * 1e3, kgrid.x_vec * 1e3, p_max);
        h = colorbar; xlabel(h, '[Pa]');
        title(strcat('Max Acoustic Pressure - Point (', num2str(target_points(ipoint,1)), ', ', num2str(target_points(ipoint,2)), ')'));
    end
    
    % add new sensor data to overal pressure data
    total_sensor_max_pressure = max(total_sensor_max_pressure,sensor_data.p_max);   % max
end
% 
% 
figure;
p_max = reshape(total_sensor_max_pressure, Nx, Ny);     
p_max(model<21 | model>221) = 0;           % ignores points outside the skull
imagesc(kgrid.y_vec * 1e3, kgrid.x_vec * 1e3, p_max);
% imshow(focus_points_mask);
% plot(120, 100)
hold on
plot(120, 100,'k*', 'MarkerSize', 30, 'LineWidth', 2)
hold off
h = colorbar; xlabel(h, '[Pa]');
title('Max Acoustic Pressure');
% 
% Now do a comparative cross-section. 
% 
figure;
subplot(2,1,1); % Medium Density
plot(p_max(120,:)) 
hold on
subplot(2,1,2); % Medium Density
plot(p_max(:,100)) 
hold on
% 
% 