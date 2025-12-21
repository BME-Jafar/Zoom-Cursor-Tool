# Zoom Cursor Tool for MATLAB

An interactive magnification tool for MATLAB figures that displays a real-time zoomed view of your signals as you move your cursor. Perfect for detailed signal inspection, data analysis, and exploratory visualization.

![image](imgs\3.png)

![MATLAB](https://img.shields.io/badge/MATLAB-R2016b%2B-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

## Features

✨ **Real-time Zoom Window** - Separate window shows magnified view of the region under your cursor

🎯 **Multiple Zoom Modes**
- **Box Mode**: Zoom both X and Y axes (magnifying glass effect)
- **X-Only Mode**: Zoom X axis while showing full Y range (perfect for time-series)

📐 **Adjustable Box Orientations**
- Square (1:1 aspect ratio)
- Landscape (2:1 - wide view)
- Portrait (1:2 - tall view)

🎨 **Multi-Signal Support** - Works seamlessly with multiple plotted lines, preserving colors and styles

⌨️ **Intuitive Keyboard Controls** - Easy-to-use shortcuts for all features

🔍 **Visual Feedback** - Red box indicator shows exactly what's being magnified

## Installation

### Option 1: Direct Download
1. Download `ZoomCursorTool.m`
2. Place it in your MATLAB path or working directory
3. Ready to use!

### Option 2: Clone Repository
```bash
git clone https://github.com/yourusername/zoom-cursor-tool.git
cd zoom-cursor-tool
```

### Option 3: Install as Toolbox
Double-click the `.mltbx` file or use:
```matlab
matlab.addons.install('ZoomCursorTool.mltbx')
```

## Quick Start

```matlab
% Create a plot
figure;
t = linspace(0, 10, 1000);
signal = sin(2*pi*t) + 0.5*sin(2*pi*5*t) + 0.2*randn(size(t));
plot(t, signal);
xlabel('Time (s)');
ylabel('Amplitude');
title('Signal with Noise');
grid on;

% Activate the zoom tool
tool = ZoomCursorTool(gcf);

% Move your mouse over the plot to see the zoomed view!
```

## Usage

### Basic Usage

```matlab
% On any existing figure with line plots
tool = ZoomCursorTool(gcf);
```

### Multiple Signals

```matlab
% Works with multiple signals
figure;
t = linspace(0, 10, 1000);
plot(t, sin(t), 'b-', 'LineWidth', 1.5);
hold on;
plot(t, cos(t), 'r--', 'LineWidth', 1.5);
plot(t, sin(2*t), 'g-.', 'LineWidth', 1.5);
hold off;
legend('sin(t)', 'cos(t)', 'sin(2t)');
grid on;

tool = ZoomCursorTool(gcf);
```

### Advanced: Custom Box Size

```matlab
tool = ZoomCursorTool(gcf);
tool.BoxSize = 1.0;  % Set initial box size in data units
```

## Keyboard Controls

| Key | Action |
|-----|--------|
| **↑** (Up Arrow) | Increase zoom box size |
| **↓** (Down Arrow) | Decrease zoom box size |
| **R** | Rotate box orientation (Square → Landscape → Portrait) |
| **X** | Toggle zoom mode (Box ↔ X-Only) |
| **ESC** | Deactivate the tool |
| **Click** | Print cursor coordinates to console |

## Zoom Modes

### Box Mode (Default)
Zooms both X and Y axes to show exactly what's inside the red box. Perfect for detailed inspection of specific regions.

![image](imgs\1.png)

### X-Only Mode
Zooms only the X axis while auto-scaling Y to show the full amplitude range. Ideal for time-series analysis.

![image](imgs\2.png)

## Box Orientations

- **Square** (1:1): Balanced view, true square on screen regardless of axis scales
- **Landscape** (2:1): Wide view, excellent for horizontal signal features
- **Portrait** (1:2): Tall view, great for examining amplitude variations

## Examples

### Example 1: ECG Signal Analysis
```matlab
% Load and plot ECG data
load('ecg.mat');
figure;
plot(ecg);
title('ECG Signal');
xlabel('Sample');
ylabel('Amplitude');
grid on;

% Activate zoom tool
tool = ZoomCursorTool(gcf);

% Press X for X-only mode to see full amplitude range
% Press R to switch to landscape for wider time view
```

### Example 2: Multiple Sensor Comparison
```matlab
% Simulate multiple sensor data
t = linspace(0, 100, 5000);
sensor1 = sin(0.1*t) + 0.1*randn(size(t));
sensor2 = cos(0.1*t) + 0.1*randn(size(t));
sensor3 = sin(0.2*t) + cos(0.15*t) + 0.1*randn(size(t));

figure;
plot(t, sensor1, 'b-', t, sensor2, 'r-', t, sensor3, 'g-');
legend('Sensor 1', 'Sensor 2', 'Sensor 3');
xlabel('Time (s)');
ylabel('Voltage (V)');
title('Multi-Sensor Data');
grid on;

% All three signals will appear in zoom window
tool = ZoomCursorTool(gcf);
```

### Example 3: Noisy Signal Detail Inspection
```matlab
% Generate signal with interesting features
t = linspace(0, 50, 10000);
clean = sin(t) + 0.5*sin(5*t);
noise = 0.2*randn(size(t));
signal = clean + noise;

figure;
plot(t, signal);
xlabel('Time');
ylabel('Signal');
title('Signal with Noise - Use Zoom to Find Features');
grid on;

tool = ZoomCursorTool(gcf);
% Try Box mode to zoom in on specific features
% Use arrow keys to adjust magnification level
```

## Methods

### Public Methods

```matlab
tool.activate()      % Reactivate the tool after deactivation
tool.deactivate()    % Deactivate the tool
tool.rotateBox()     % Programmatically rotate box orientation
tool.toggleZoomMode()% Programmatically toggle zoom mode
```

### Properties

```matlab
tool.BoxSize          % Get/set box size in data units
tool.BoxOrientation   % Current orientation: 'square', 'landscape', 'portrait'
tool.BoxAspectRatio   % Current aspect ratio (read-only)
tool.ZoomMode         % Current mode: 'box' or 'xonly'
tool.IsActive         % Tool activation state
```

## Requirements

- MATLAB R2016b or later
- Figure must contain at least one line plot
- Works with 2D line plots (does not support 3D, surface, or image plots)



## License

This project is licensed under the MIT License - see the LICENSE file for details.


## Acknowledgments

- This implementation was inspired by [Matlab Zoomed Axes](https://github.com/thom7660/matlab_zoomed_axes/) by [thom7660](https://github.com/thom7660).
No code from the original implementation was reused.
- Thanks to the MATLAB community for feedback and suggestions

## Citation

If you use this tool in your research, please cite:

```bibtex
@software{zoom_cursor_tool,
  author = {MHD Jafar Mortada},
  title = {Zoom Cursor Tool for MATLAB},
  year = {2025},
  url = {https://github.com/bme-jafar/zoom-cursor-tool}
}
```


⭐ **Star this repo** if you find it useful!
