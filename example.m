% Demo script for ZoomCursorTool
clear; close all; clc;

fprintf('=== Zoom Cursor Tool Demo ===\n\n');

%% Example 1: Simple sine wave with noise
fprintf('Creating demo plot...\n');

figure('Name', 'Zoom Cursor Tool Demo', 'NumberTitle', 'off', ...
       'Position', [100 100 900 600]);

% Generate sample signal
t = linspace(0, 10, 1000);
signal = sin(2*pi*t) + 0.5*sin(2*pi*5*t) + 0.2*randn(size(t));
plot(t, signal);
xlabel('Time (s)');
ylabel('Amplitude');
title('Signal with Noise');
grid on;

% Activate the zoom tool
tool = ZoomCursorTool(gcf);