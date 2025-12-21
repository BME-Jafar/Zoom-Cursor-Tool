classdef ZoomCursorTool < handle
    % ZoomCursorTool - Interactive zoom tool for MATLAB figures
    % Displays a magnified view of the signal under the cursor
    % you can activate it after creating a figure with a 2D plot 
    % tool = ZoomCursorTool(gcf);
    
    properties
        MainFigure          % Main figure handle
        MainAxes            % Main axes handle
        ZoomFigure          % Separate zoom figure window
        ZoomAxes            % Zoom axes handle
        CursorBox           % Rectangle showing cursor area
        CrosshairV          % Vertical crosshair line
        CrosshairH          % Horizontal crosshair line
        AllPlotLines        % Array of all line handles
        XData               % Cell array of X data for each plot
        YData               % Cell array of Y data for each plot
        BoxSize = 0.5       % Size of cursor box in data units
        BoxOrientation = 'square'  % 'square', 'landscape', or 'portrait'
        BoxAspectRatio = 1  % Width/Height ratio (1 = square, >1 = landscape, <1 = portrait)
        ZoomMode = 'box'    % 'box' (zoom X and Y) or 'xonly' (zoom X, show all Y)
        IsActive = false    % Tool activation state
    end
    
    methods
        function obj = ZoomCursorTool(figHandle)
            % Constructor - Initialize the tool on an existing figure
            if nargin < 1 || isempty(figHandle)
                error('ZoomCursorTool requires a figure handle');
            end
            
            obj.MainFigure = figHandle;
            obj.MainAxes = gca(figHandle);
            
            % Extract data from ALL line plots
            obj.AllPlotLines = findobj(obj.MainAxes, 'Type', 'line');
            if isempty(obj.AllPlotLines)
                error('No line plots found in the figure');
            end
            
            % Store data from all lines
            numLines = length(obj.AllPlotLines);
            obj.XData = cell(numLines, 1);
            obj.YData = cell(numLines, 1);
            
            for i = 1:numLines
                obj.XData{i} = get(obj.AllPlotLines(i), 'XData');
                obj.YData{i} = get(obj.AllPlotLines(i), 'YData');
            end
            
            %fprintf('Data extracted: %d line(s) found\n', numLines);
            
            % Create separate zoom figure
            obj.createZoomFigure();
            
            % Create cursor box
            obj.createCursorBox();
            
            % Set up callbacks
            obj.setupCallbacks();
            
            % Activate the tool
            obj.IsActive = true;
            
            fprintf('\n=== Zoom Cursor Tool Activated! ===\n');
            fprintf('Move your mouse over the main plot\n');
            fprintf('The zoom window will show magnified view\n');
            fprintf('Press UP/DOWN arrows to adjust box size\n');
            fprintf('Press R to rotate box (square/landscape/portrait)\n');
            fprintf('Press X to toggle zoom mode (box/X-only)\n');
            fprintf('Press ESC to deactivate\n\n');
        end
        
        function createZoomFigure(obj)
            % Create separate figure for zoom view
            mainPos = get(obj.MainFigure, 'Position');
            
            % Position zoom figure to the right of main figure
            zoomWidth = 400;
            zoomHeight = 350;
            zoomX = mainPos(1) + mainPos(3) + 20;
            zoomY = mainPos(2) + mainPos(4) - zoomHeight;
            
            obj.ZoomFigure = figure('Name', 'Zoomed View', ...
                'NumberTitle', 'off', ...
                'Position', [zoomX, zoomY, zoomWidth, zoomHeight], ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'Color', [0.94 0.94 0.94]);
            
            % Create axes in zoom figure
            obj.ZoomAxes = axes('Parent', obj.ZoomFigure, ...
                'Position', [0.12 0.15 0.82 0.75], ...
                'Box', 'on', ...
                'XGrid', 'on', ...
                'YGrid', 'on', ...
                'LineWidth', 1.5, ...
                'FontSize', 10);
            
            title(obj.ZoomAxes, 'Magnified View', 'FontWeight', 'bold', 'FontSize', 12);
            xlabel(obj.ZoomAxes, 'X', 'FontSize', 10);
            ylabel(obj.ZoomAxes, 'Y', 'FontSize', 10);
            
            % Plot empty data initially
            hold(obj.ZoomAxes, 'on');
            plot(obj.ZoomAxes, NaN, NaN, 'b-', 'LineWidth', 2);
            obj.CrosshairV = plot(obj.ZoomAxes, [NaN NaN], [NaN NaN], 'r-', 'LineWidth', 1.5);
            obj.CrosshairH = plot(obj.ZoomAxes, [NaN NaN], [NaN NaN], 'r-', 'LineWidth', 1.5);
            hold(obj.ZoomAxes, 'off');
            
            %fprintf('Zoom window created and positioned\n');
        end
        
        function createCursorBox(obj)
            % Create rectangle to show cursor area on main plot
            obj.CursorBox = rectangle('Parent', obj.MainAxes, ...
                'Position', [0 0 0 0], ...
                'EdgeColor', [1 0 0], ...
                'LineWidth', 2.5, ...
                'LineStyle', '-', ...
                'Visible', 'off');
            
            %fprintf('Cursor box created\n');
        end
        
        function setupCallbacks(obj)
            % Set up mouse motion and key press callbacks
            set(obj.MainFigure, 'WindowButtonMotionFcn', @obj.onMouseMove);
            set(obj.MainFigure, 'KeyPressFcn', @obj.onKeyPress);
            set(obj.MainFigure, 'WindowButtonDownFcn', @obj.onMouseClick);
            
            % Also handle zoom figure close
            set(obj.ZoomFigure, 'CloseRequestFcn', @obj.onZoomFigureClose);
        end
        
        function onMouseMove(obj, ~, ~)
            % Callback for mouse movement
            if ~obj.IsActive || ~isvalid(obj.ZoomFigure)
                return;
            end
            
            % Get cursor position in main axes
            pt = get(obj.MainAxes, 'CurrentPoint');
            xCursor = pt(1, 1);
            yCursor = pt(1, 2);
            
            % Check if cursor is within axes limits
            xlims = xlim(obj.MainAxes);
            ylims = ylim(obj.MainAxes);
            
            if xCursor < xlims(1) || xCursor > xlims(2) || ...
               yCursor < ylims(1) || yCursor > ylims(2)
                % Hide cursor box when outside
                obj.CursorBox.Visible = 'off';
                cla(obj.ZoomAxes);
                title(obj.ZoomAxes, 'Move cursor over main plot', 'FontSize', 11);
                return;
            end
            
            % Show and update cursor box
            obj.CursorBox.Visible = 'on';
            obj.updateCursorBox(xCursor, yCursor);
            
            % Update zoom view
            obj.updateZoomView(xCursor, yCursor);
        end
        
        function updateCursorBox(obj, xCursor, yCursor)
            % Update the position of the cursor box with orientation
            
            % Get current axes limits to calculate aspect ratio
            xlims = xlim(obj.MainAxes);
            ylims = ylim(obj.MainAxes);
            axPos = get(obj.MainAxes, 'Position');
            
            % Calculate data units per screen unit
            xDataPerScreen = (xlims(2) - xlims(1)) / axPos(3);
            yDataPerScreen = (ylims(2) - ylims(1)) / axPos(4);
            
            % Adjust aspect ratio to make squares actually square on screen
            screenAspectCorrection = xDataPerScreen / yDataPerScreen;
            
            % Apply orientation with screen correction
            halfBoxX = (obj.BoxSize * obj.BoxAspectRatio * screenAspectCorrection) / 2;
            halfBoxY = obj.BoxSize / 2;
            
            % Calculate box position (center it on cursor)
            boxX = xCursor - halfBoxX;
            boxY = yCursor - halfBoxY;
            boxWidth = obj.BoxSize * obj.BoxAspectRatio * screenAspectCorrection;
            boxHeight = obj.BoxSize;
            
            % Update rectangle
            set(obj.CursorBox, 'Position', [boxX, boxY, boxWidth, boxHeight]);
        end
        
        function updateZoomView(obj, xCursor, yCursor)
            % Update the zoomed view in separate figure
            
            % Get current axes limits to calculate aspect ratio
            xlims = xlim(obj.MainAxes);
            ylims = ylim(obj.MainAxes);
            axPos = get(obj.MainAxes, 'Position');
            
            % Calculate data units per screen unit
            xDataPerScreen = (xlims(2) - xlims(1)) / axPos(3);
            yDataPerScreen = (ylims(2) - ylims(1)) / axPos(4);
            
            % Adjust aspect ratio to make squares actually square on screen
            screenAspectCorrection = xDataPerScreen / yDataPerScreen;
            
            halfBoxX = (obj.BoxSize * obj.BoxAspectRatio * screenAspectCorrection) / 2;
            halfBoxY = obj.BoxSize / 2;
            
            % Define zoom region - X based on box
            xMin = xCursor - halfBoxX;
            xMax = xCursor + halfBoxX;
            
            % Y limits depend on zoom mode
            if strcmp(obj.ZoomMode, 'box')
                % Box mode: zoom both X and Y
                yMin = yCursor - halfBoxY;
                yMax = yCursor + halfBoxY;
            else
                % X-only mode: show full Y range
                yMin = -inf;
                yMax = inf;
            end
            
            % Clear and prepare to replot
            cla(obj.ZoomAxes);
            hold(obj.ZoomAxes, 'on');
            
            % Plot ALL lines in the zoom window
            hasData = false;
            allYData = [];  % Collect all Y data for auto-scaling in X-only mode
            
            for i = 1:length(obj.AllPlotLines)
                % Find data points within the X zoom region for this line
                xData = obj.XData{i};
                yData = obj.YData{i};
                
                idx = find(xData >= xMin & xData <= xMax);
                
                if length(idx) >= 2
                    % Extract zoom data
                    xZoom = xData(idx);
                    yZoom = yData(idx);
                    
                    % Collect Y data for auto-scaling
                    allYData = [allYData, yZoom];
                    
                    % Get original line properties
                    lineColor = get(obj.AllPlotLines(i), 'Color');
                    lineStyle = get(obj.AllPlotLines(i), 'LineStyle');
                    lineWidth = get(obj.AllPlotLines(i), 'LineWidth');
                    marker = get(obj.AllPlotLines(i), 'Marker');
                    
                    % Plot the zoomed signal with original properties
                    plot(obj.ZoomAxes, xZoom, yZoom, ...
                        'Color', lineColor, ...
                        'LineStyle', lineStyle, ...
                        'LineWidth', lineWidth, ...
                        'Marker', marker);
                    
                    hasData = true;
                end
            end
            
            if ~hasData
                % No data in zoom region
                hold(obj.ZoomAxes, 'off');
                title(obj.ZoomAxes, 'No data in zoom region', 'FontSize', 11);
                return;
            end
            
            % Set Y limits based on mode
            if strcmp(obj.ZoomMode, 'xonly')
                % Auto-scale Y based on data in X range
                yDataMin = min(allYData);
                yDataMax = max(allYData);
                yRange = yDataMax - yDataMin;
                if yRange < eps
                    yRange = 1;
                end
                yPadding = yRange * 0.1;
                yMin = yDataMin - yPadding;
                yMax = yDataMax + yPadding;
            end
            
            % Add crosshair at cursor position
            % Vertical line at cursor X
            plot(obj.ZoomAxes, [xCursor xCursor], [yMin yMax], 'r-', 'LineWidth', 1.5);
            % Horizontal line at cursor Y
            plot(obj.ZoomAxes, [xMin xMax], [yCursor yCursor], 'r-', 'LineWidth', 1.5);
            
            % Mark the center point
            plot(obj.ZoomAxes, xCursor, yCursor, 'ro', 'MarkerSize', 8, ...
                'MarkerFaceColor', 'r', 'LineWidth', 2);
            
            hold(obj.ZoomAxes, 'off');
            
            % Set limits
            xlim(obj.ZoomAxes, [xMin, xMax]);
            ylim(obj.ZoomAxes, [yMin, yMax]);
            
            % Make zoom axes square for square mode in box zoom
            if obj.BoxAspectRatio == 1.0 && strcmp(obj.ZoomMode, 'box')
                axis(obj.ZoomAxes, 'square');
            else
                axis(obj.ZoomAxes, 'normal');
            end
            
            % Update title with info including orientation and mode
            modeStr = upper(obj.ZoomMode);
            title(obj.ZoomAxes, sprintf('X: %.3f, Y: %.3f | %s | %s (%.3f)', ...
                xCursor, yCursor, modeStr, obj.BoxOrientation, obj.BoxSize), ...
                'FontWeight', 'bold', 'FontSize', 10);
            
            grid(obj.ZoomAxes, 'on');
            
            % Force update
            drawnow limitrate;
        end
        
        function onKeyPress(obj, ~, event)
            % Callback for key press
            if strcmp(event.Key, 'escape')
                obj.deactivate();
            elseif strcmp(event.Key, 'uparrow')
                xRange = range(xlim(obj.MainAxes));
                obj.BoxSize = min(obj.BoxSize * 1.3, xRange/2);
                %fprintf('Box size increased to %.4f\n', obj.BoxSize);
            elseif strcmp(event.Key, 'downarrow')
                xRange = range(xlim(obj.MainAxes));
                obj.BoxSize = max(obj.BoxSize / 1.3, xRange/200);
                %fprintf('Box size decreased to %.4f\n', obj.BoxSize);
            elseif strcmp(event.Key, 'r') || strcmp(event.Key, 'R')
                obj.rotateBox();
            elseif strcmp(event.Key, 'x') || strcmp(event.Key, 'X')
                obj.toggleZoomMode();
            end
        end
        
        function rotateBox(obj)
            % Rotate box orientation: square -> landscape -> portrait -> square
            switch obj.BoxOrientation
                case 'square'
                    obj.BoxOrientation = 'landscape';
                    obj.BoxAspectRatio = 2.0;  % Width is 2x height
                    %fprintf('Box orientation: LANDSCAPE (wide)\n');
                case 'landscape'
                    obj.BoxOrientation = 'portrait';
                    obj.BoxAspectRatio = 0.5;  % Width is 0.5x height (tall)
                    %fprintf('Box orientation: PORTRAIT (tall)\n');
                case 'portrait'
                    obj.BoxOrientation = 'square';
                    obj.BoxAspectRatio = 1.0;  % Equal width and height
                    %fprintf('Box orientation: SQUARE\n');
            end
        end
        
        function toggleZoomMode(obj)
            % Toggle between box zoom and X-only zoom
            if strcmp(obj.ZoomMode, 'box')
                obj.ZoomMode = 'xonly';
                %fprintf('Zoom mode: X-ONLY (zoom X axis, show full Y range)\n');
            else
                obj.ZoomMode = 'box';
                %fprintf('Zoom mode: BOX (zoom both X and Y axes)\n');
            end
        end
        
        function onMouseClick(obj, ~, ~)
            % Print cursor position on click
            if ~obj.IsActive
                return;
            end
            
            pt = get(obj.MainAxes, 'CurrentPoint');
            xlims = xlim(obj.MainAxes);
            ylims = ylim(obj.MainAxes);
            
            xCursor = pt(1,1);
            yCursor = pt(1,2);
            
            if xCursor >= xlims(1) && xCursor <= xlims(2) && ...
               yCursor >= ylims(1) && yCursor <= ylims(2)
                fprintf('>>> Clicked at: X = %.4f, Y = %.4f\n', xCursor, yCursor);
            end
        end
        
        function onZoomFigureClose(obj, ~, ~)
            % Handle zoom figure being closed
            obj.deactivate();
            if isvalid(obj.ZoomFigure)
                delete(obj.ZoomFigure);
            end
        end
        
        function deactivate(obj)
            % Deactivate the tool
            obj.IsActive = false;
            if isvalid(obj.CursorBox)
                obj.CursorBox.Visible = 'off';
            end
            
            % Remove callbacks
            if isvalid(obj.MainFigure)
                set(obj.MainFigure, 'WindowButtonMotionFcn', '');
                set(obj.MainFigure, 'KeyPressFcn', '');
            end
            
            %fprintf('\n=== Zoom Cursor Tool Deactivated ===\n');
        end
        
        function activate(obj)
            % Reactivate the tool
            if ~isvalid(obj.ZoomFigure)
                obj.createZoomFigure();
            end
            obj.IsActive = true;
            obj.setupCallbacks();
            %fprintf('\n=== Zoom Cursor Tool Activated ===\n');
        end
        
        function delete(obj)
            % Destructor - clean up
            if isvalid(obj.ZoomFigure)
                delete(obj.ZoomFigure);
            end
            if isvalid(obj.CursorBox)
                delete(obj.CursorBox);
            end
        end
    end
end