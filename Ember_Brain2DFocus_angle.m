%% 
%% OK, I have 2D time reversal focusing through the skull working. 
%% TODO: 
%% It would be good to compare to a non-time reversed version. 
%% 
%% 
%% Clear it. 
clear; clc;
set(groot, 'DefaultFigureWindowStyle', 'normal');

% import the brain:  
brain_model = load('brain_model_skull.mat'); brain_model = brain_model.brain_model;
brain_model = brain_model(25:225, 35:274, 39:239); % reduce unnecessary space
% define properties of the signal to be emitted
focus_pressure      = 10;                 % [Pa]
focus_burst_cycles  = 2;

% define a slice
% model = squeeze(brain_model(:,80,:));
model = squeeze(brain_model(:,50,:));
% 


im = model;
P = [100;100];    % coordinates of point within the image size
alpha = 45;   % angle for rotation
RotatedIm = imrotate(im,alpha);   % rotation of the main image (im)
RotMatrix = [cosd(alpha) -sind(alpha); sind(alpha) cosd(alpha)]; 
ImCenterA = (size(im,1,2)/2)';         % Center of the main image
ImCenterB = (size(RotatedIm,1,2)/2)';  % Center of the transformed image
RotatedP = RotMatrix*(P-ImCenterA)+ImCenterB;

% figure('Name','Before Rotation','NumberTitle','off');
% ax1 = subplot(2,1,1); % Overlayed map of what is going on. 
% imshow(im);
% hold on
% plot(P(2),P(1),'r+', 'LineWidth', 20);
% plot(ImCenterA(2),ImCenterA(1),'k+', 'LineWidth', 20);
% 
% ax1 = subplot(2,1,2); % Overlayed map of what is going on. 
% imshow(RotatedIm);
% hold on
% plot(RotatedP(2),RotatedP(1),'r+', 'LineWidth', 20);
% plot(ImCenterB(2),ImCenterB(1),'k+', 'LineWidth', 20);

model = RotatedIm;
% RotatedP(1)
% RotatedP(2)
% 
target_points = [[141,143]];
% view the model
% figure;
% 3. Rotate the image 45 degrees clockwise
% model = imrotate(model, -45, 'bilinear', 'loose');
% fig = imshow(rotated_I_cw); % 
% saveas(fig,'brain.jpg');

% define the sequence of points to be focused on with ultrasound.
% target_points = [[100, 100]]; 
% target_points = [[0, 0]]; 
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
n_elements  = 28;                        % grid points - impar
sensor.mask = zeros(Nx, Ny);
source2use  = 3;
% Source Position:
% 1 - Array of sequential points glued to the top of the brain
% 2 - Array of sequential points glued to the top and bottom of the brain.
% 3 - Linear array on top of the brain
% 4 - Random points on the top side of the brain
% 5 - Completely random points
% 
if source2use==3
    %%%%%%%%%%%%%%%%%%%% Linear probe on top of the brain. %%%%%%%%%%%%%%%%%%%%%
    array_step=4;
    % This needs to be rounded. 
    % array_center_pos_x = round(size(model,1)/2);
    array_center_pos_y = round(size(model,1)/2);
    max_brain_x = 0;
    for ypos=0:array_step:array_step*(n_elements-1)/2  % find outer brain position for array
        max_brain_x = max(max_brain_x, find(model(array_center_pos_y+ypos,:)>0,1,'last'));
        max_brain_x = max(max_brain_x, find(model(array_center_pos_y-ypos,:)>0,1,'last'));
    end
    sensor.mask(array_center_pos_y-ypos:array_step:array_center_pos_y+ypos, max_brain_x)=1;
end

% 
startingX  = 100;
startingY  = 100;
Width      = 500;
Height     = 500;
% 
f1 = figure('Position',[startingX startingY Width Height]);
% set(f1,'Position',[40 40 500 500])
sensor.mask = im2double(sensor.mask);
focus_points_mask = im2double(focus_points_mask);

ax1 = subplot(1,1,1); % Overlayed map of what is going on. 
C = imfuse(focus_points_mask, sensor.mask, 'blend');
Total = im2double(imfuse(C, model, 'blend'));
% Adjust contrast to full range [0, 1] (black to white)
adjusted_img = imadjust(Total, [min(Total(:)), max(Total(:))], [0, 1]);
imshow(adjusted_img);
% ax1.FontSize  = 15;
% ax1.LineWidth = 2;
% figure('Renderer', 'painters', 'Position', [10 10 900 600])
saveas(f1,'brain.jpg');
hold on
close(f1)

%% Define ping for ultrasound wave targets.

% target ping signal
ping_pressure       = 20;                    % [Pa]
signal_freq         = 0.5e6;                   % [Hz]
ping_burst_cycles   = 2;
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
% time_series = kgrid.t_array; 

% plot the time series recorded at each array element
% figure;
% stackedPlot(kgrid.t_array * 1e6, sensor_data);
% xlabel('Time [\mus]');
% ylabel('Time Series TRM focusing');
% title('US Sources');
% save Ember_time_series_TR.mat sensor_data time_series
% pause(0.5);

% % 
%% END TIME REVERSAL SECTION. 
%%  Free - field estimation section
% sensor_delays is a 1 x 31 double. 
% Make free field field focusing option. 
% use geometric beam forming to calculate the tone burst offsets for each
% create an element index relative to the centre element of the transducer
element_index   = -(n_elements - 1)/2:(n_elements - 1)/2
element_pitch   = array_step * dx;      %  [m]
% source_focus    = 72e-3;    % focal length [m]
source_focus    = 55e-3;    % focal length [m]
c0              = 1500;     % sound speed [m/s]
steering_angle  = 45;
% set indices for each element
if rem(n_elements, 2)
    ids = (1:n_elements) - ceil(n_elements/2);
else
    ids = (1:n_elements) - (n_elements + 1)/2;
end
% % set time delays for each element to focus at source_focus
time_delays = -(sqrt((ids .* element_pitch).^2 + source_focus.^2) - source_focus) ./ c0;
time_delays = time_delays - min(time_delays);
time_delays = round(time_delays / kgrid.dt);
time_delays = time_delays(1:(n_elements-1) );
sensor_delays(1,:) = time_delays;
% % Make the time series. 
source_test.p = ping_pressure * toneBurst(1/kgrid.dt, signal_freq, ping_burst_cycles, 'SignalOffset', time_delays);
num_source_time_points = length(source_test.p(1,:));
figure; % plot the input time series
stackedPlot(kgrid.t_array(1:num_source_time_points) * 1e6, source_test.p);
xlabel('Time [\mus]');
ylabel('Time Series for free-field focusing');
pause(0.5);
time_series = kgrid.t_array(1:num_source_time_points); 
sensor_data = source_test.p;
save Ember_time_series_FF.mat sensor_data time_series
% %
% 
% 
%% Simulate wave focusing on multiple targets sequentialy
% 
% swap sensor to source and monitor pressure on all grid
source.p_mask   = sensor.mask;
sensor.mask     = ones(Nx,Ny);
sensor.record   = {'p', 'p_max'};

total_sensor_max_pressure = zeros(Nx*Ny,1);

for ipoint=1:size(target_points,1)
    % Creates a signal to emit for focusing (with delays).
    source.p = focus_pressure*toneBurst(1/kgrid.dt, signal_freq, focus_burst_cycles, ...
                                   'SignalOffset', sensor_delays(ipoint,:));
    % simulation                   
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
startingX  = 100;
startingY  = 100;
Width      = 500;
Height     = 500;
% Figure arrangement. 
lowerxvalue = -70;
upperxvalue = 50;
loweryvalue = -60;
upperyvalue = 70;

f2 = figure('Position',[startingX startingY Width Height]);
ax1 = subplot(1,1,1); % Overlayed map of what is going on. 
p_max = reshape(total_sensor_max_pressure, Nx, Ny);     
p_max(model<21 | model>221) = 0;           % ignores points outside the skull
imagesc(kgrid.y_vec * 1e3, kgrid.x_vec * 1e3, p_max);
ax1 = gca;
ax1.XLim = [lowerxvalue upperxvalue];
ax1.YLim = [loweryvalue upperyvalue];
clim([0 5]);
% h = colorbar; xlabel(h, '[Pa]');
% title('Max Acoustic Pressure');
% ax1.FontSize = 15;
saveas(f2,'max_pressure.jpg');
hold on
close(f2)
% 
% Now do a comparative cross-section. 
figure;
subplot(1,1,1); % 
plot(p_max(:,143)) 
xlabel('cross-section [mm]');
ylabel('P [Pa]');
hold on

save Ember_focus_FF_XY.mat p_max

% figure;
% subplot(2,1,1); % 
% plot(p_max(100,:)) 
% xlabel('cross-section [mm]');
% ylabel('P [Pa]');
% hold on
% subplot(2,1,2); % 
% plot(p_max(:,100)) 
% xlabel('X [mm]');
% ylabel('P [Pa]');
% hold on
% % 
% 