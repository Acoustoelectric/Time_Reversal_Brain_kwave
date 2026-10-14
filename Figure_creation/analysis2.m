clear; clc;
set(groot, 'DefaultFigureWindowStyle', 'normal');
startingX   = 100;
startingY   = 100;
Width       = 500;
Height      = 300;


load Ember_time_series_TR.mat

TR_sensor_data = sensor_data;
TR_time_series = time_series;

% f1 = figure('Position',[startingX startingY Width Height]); % plot the input time series
% ax1 = subplot(1,1,1); 
% stackedPlot(TR_time_series* 1e6-35, TR_sensor_data);
% ax1.XLim = [0 20];
% set(gca,'YTick',[])
% % set(gca,'XTick',[])
% % xlabel('Time [\mus]');
% % ylabel('Time Series for free-field focusing');
% % pause(0.5);
% saveas(f1,'TR_stacked_time_series.jpg');

load Ember_time_series_FF.mat

FF_sensor_data = sensor_data;
FF_time_series = time_series;

% f1 = figure('Position',[startingX startingY Width Height]); % plot the input time series
% ax1 = subplot(1,1,1); 
% stackedPlot(FF_time_series* 1e6, FF_sensor_data);
% % ax1.XLim = [1 21];
% % xlabel('Time [\mus]');
% % ylabel('Time Series for free-field focusing');
% hold on;
% set(gca,'YTick',[])
% % set(gca,'XTick',[])
% saveas(f1,'FF_stacked_time_series.jpg');
% 
startingX   = 100;
startingY   = 100;
Width       = 500;
Height      = 500;

% def normalize_amplitude(data):
%     min_val = np.min(data);
%     max_val = np.max(data);
%     return (data - min_val) / (max_val - min_val)

% start_TR_index = find(TR_time_series*1e6 == 35)

transducer_number = 14; 

pressure_TR = TR_sensor_data(transducer_number,:);
pressure_FF = FF_sensor_data(transducer_number,:);

% pressure_TR = normalize(pressure_TR);
% pressure_FF = normalize(pressure_FF);

index = find(TR_time_series* 1e6 >= 35);
index(1)
endpt = index(1) + length(pressure_FF)
length(pressure_FF)
TR_new_time_series = TR_time_series(index(1):endpt)* 1e6 -35;
TR_new_pressure = pressure_TR(index(1):endpt);

% Now do a comparative cross-section. 
f1 = figure('Position',[startingX startingY Width Height]);
ax1 = subplot(1,1,1); 
% plot(TR_time_series* 1e6, pressure_TR,'r','LineWidth', 3) 
plot(FF_time_series* 1e6, 0.5*pressure_FF,'k','LineWidth', 3) 
hold on
plot(TR_new_time_series, TR_new_pressure,'r','LineWidth', 3) 
ax1.XLim = [0 20];
% ax1.YLim = [0 5];
ax1.FontSize = 25;
box off;
H=gca;
H.LineWidth=2; %change to the desired value
% xlabel('cross-section [mm]');
% ylabel('P [Pa]');
hold on
saveas(f1,'time_series.jpg');
%close(f1)


startingX   = 100;
startingY   = 100;
Width       = 250;
Height      = 250;
f1 = figure('Position',[startingX startingY Width Height]);
ax1 = subplot(1,1,1); 
% plot(TR_time_series* 1e6, pressure_TR,'r','LineWidth', 3) 
plot(TR_new_time_series, TR_new_pressure,'r','LineWidth', 3) 
ax1.XLim = [0 20];
% ax1.YLim = [0 5];
ax1.FontSize = 25;
box off;
H=gca;
H.LineWidth=2; %change to the desired value
% xlabel('cross-section [mm]');
% ylabel('P [Pa]');
hold on
saveas(f1,'zoom_time_series.jpg');