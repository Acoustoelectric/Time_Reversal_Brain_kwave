clear; clc;
set(groot, 'DefaultFigureWindowStyle', 'normal');

load Ember_focus_TR_XY.mat
p_max_TR = p_max;

load Ember_focus_FF_XY.mat
p_max_FF = p_max;

% Calculate the full-width half maximum. 
max_TR = max(p_max_TR(:,143))
P_half = 0.5 * max_TR;
idxs = find (p_max_TR(:,143) > P_half);
dx = 1e-3; 
TR_FWHM = dx * length(idxs)

max_FF = max(p_max_FF(:,143))
P_FF_half = 0.5 * max_FF;
FF_idxs = find (p_max_FF(:,143) > P_FF_half);
FF_FWHM = dx * length(FF_idxs)



startingX  = 100;
startingY  = 100;
Width  = 500;
Height = 500;
% Now do a comparative cross-section. 
f1 = figure('Position',[startingX startingY Width Height]);
ax1 = subplot(1,1,1); 
plot(p_max_TR(:,143),'r','LineWidth', 3) 
hold on
plot(p_max_FF(:,143),'k','LineWidth', 3) 
ax1.XLim = [100 200];
ax1.YLim = [0 5];
ax1.FontSize = 25;
box off;
H=gca;
H.LineWidth=2; %change to the desired value
% xlabel('cross-section [mm]');
% ylabel('P [Pa]');
hold on
saveas(f1,'max_pressure_cross-sections.jpg');
hold on
close(f1)

% load Ember_time_series_TR.mat
% load Ember_time_series_FF.mat


