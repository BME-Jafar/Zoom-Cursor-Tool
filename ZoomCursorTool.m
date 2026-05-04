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
        OriginalWindowButtonMotionFcn = [] % Previous mouse motion callback
        OriginalKeyPressFcn = []           % Previous key press callback
        OriginalWindowButtonDownFcn = []   % Previous mouse click callback
        MeasurementMode = false             % Toggle for measurement cursor placement in zoom window
        MeasurementPoints = zeros(0, 2)     % Up to two [x y] measurement cursor positions
        MaxMeasurementPoints = 2            % Number of measurement cursors used for dx/dy
        ZoomFrozenForMeasurement = false     % Freeze zoom view while placing measurement cursors
    end
    
    methods
        function obj = ZoomCursorTool(figHandle)
            % Constructor - Initialize the tool on an existing figure
            if nargin < 1 || isempty(figHandle)
                error('ZoomCursorTool requires a figure handle');
            end
            
            if ~ishandle(figHandle) || ~strcmp(get(figHandle, 'Type'), 'figure')
                error('ZoomCursorTool requires a valid MATLAB figure handle');
            end
            
            obj.MainFigure = figHandle;
            obj.MainAxes = get(figHandle, 'CurrentAxes');
            
            if isempty(obj.MainAxes) || ~ishandle(obj.MainAxes)
                axesList = findobj(figHandle, 'Type', 'axes');
                axesList = axesList(~strcmp(get(axesList, 'Tag'), 'legend'));
                if isempty(axesList)
                    error('No axes found in the figure');
                end
                obj.MainAxes = axesList(1);
            end
            
            % Extract data from ALL line plots
            obj.AllPlotLines = findobj(obj.MainAxes, 'Type', 'line');
            obj.AllPlotLines = flipud(obj.AllPlotLines(:));
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
            fprintf('Press M to toggle measurement cursors in zoom window and freeze current zoom view\n');
            fprintf('Press C to clear measurement cursors\n');
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
                'Color', [0.94 0.94 0.94], ...
                'WindowButtonDownFcn', @obj.onZoomMouseClick, ...
                'KeyPressFcn', @obj.onKeyPress);
            
            % Create axes in zoom figure
            obj.ZoomAxes = axes('Parent', obj.ZoomFigure, ...
                'Position', [0.12 0.15 0.82 0.75], ...
                'Box', 'on', ...
                'XGrid', 'on', ...
                'YGrid', 'on', ...
                'LineWidth', 1.5, ...
                'FontSize', 10);
            
            title(obj.ZoomAxes, 'Magnified View', 'FontWeight', 'bold', 'FontSize', 12, 'Color', [0 0 0]);
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
            % Save existing figure callbacks so they can be restored on deactivate.
            if isempty(obj.OriginalWindowButtonMotionFcn)
                obj.OriginalWindowButtonMotionFcn = get(obj.MainFigure, 'WindowButtonMotionFcn');
            end
            if isempty(obj.OriginalKeyPressFcn)
                obj.OriginalKeyPressFcn = get(obj.MainFigure, 'KeyPressFcn');
            end
            if isempty(obj.OriginalWindowButtonDownFcn)
                obj.OriginalWindowButtonDownFcn = get(obj.MainFigure, 'WindowButtonDownFcn');
            end
            
            set(obj.MainFigure, 'WindowButtonMotionFcn', @obj.onMouseMove);
            set(obj.MainFigure, 'KeyPressFcn', @obj.onKeyPress);
            set(obj.MainFigure, 'WindowButtonDownFcn', @obj.onMouseClick);
            
            % Also handle zoom figure close
            set(obj.ZoomFigure, 'CloseRequestFcn', @obj.onZoomFigureClose);
        end
        
        function onMouseMove(obj, ~, ~)
            % Callback for mouse movement
            if ~obj.IsActive || ~isgraphics(obj.ZoomFigure)
                return;
            end
            
            % When measurement mode is active, keep the current zoom view frozen
            % so the user can move to the zoom window and click measurement points.
            if obj.ZoomFrozenForMeasurement
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
                title(obj.ZoomAxes, 'Move cursor over main plot', 'FontSize', 11, 'Color', [0 0 0]);
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
                    allYData = [allYData; yZoom(:)];
                    
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
                title(obj.ZoomAxes, 'No data in zoom region', 'FontSize', 11, 'Color', [0 0 0]);
                return;
            end
            
            % Set Y limits based on mode
            if strcmp(obj.ZoomMode, 'xonly')
                % Auto-scale Y based on data in X range
                finiteYData = allYData(isfinite(allYData));
                if isempty(finiteYData)
                    finiteYData = yCursor;
                end
                yDataMin = min(finiteYData);
                yDataMax = max(finiteYData);
                yRange = yDataMax - yDataMin;
                if yRange < eps
                    yRange = 1;
                end
                yPadding = yRange * 0.1;
                yMin = yDataMin - yPadding;
                yMax = yDataMax + yPadding;
            end
            
            % Add live crosshair at cursor position. The tag allows it to be
            % hidden when measurement mode freezes the zoom view.
            plot(obj.ZoomAxes, [xCursor xCursor], [yMin yMax], 'r-', ...
                'LineWidth', 1.5, 'Tag', 'ZoomCursorToolLiveCursor');
            plot(obj.ZoomAxes, [xMin xMax], [yCursor yCursor], 'r-', ...
                'LineWidth', 1.5, 'Tag', 'ZoomCursorToolLiveCursor');
            
            % Mark the center point
            plot(obj.ZoomAxes, xCursor, yCursor, 'ro', 'MarkerSize', 8, ...
                'MarkerFaceColor', 'r', 'LineWidth', 2, ...
                'Tag', 'ZoomCursorToolLiveCursor');
            
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
                'FontWeight', 'bold', 'FontSize', 10, 'Color', [0 0 0]);
            
            grid(obj.ZoomAxes, 'on');
            obj.drawMeasurementCursors(xMin, xMax, yMin, yMax);
            
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
            elseif strcmp(event.Key, 'm') || strcmp(event.Key, 'M')
                obj.toggleMeasurementMode();
            elseif strcmp(event.Key, 'c') || strcmp(event.Key, 'C')
                obj.clearMeasurementCursors();
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
        

        function toggleMeasurementMode(obj)
            % Toggle measurement mode for placing two cursors in the zoom window.
            % When ON, freeze the current zoom view. This prevents the zoomed
            % content from changing while the user moves from the main figure
            % to the zoom figure to place measurement cursors.
            obj.MeasurementMode = ~obj.MeasurementMode;
            obj.ZoomFrozenForMeasurement = obj.MeasurementMode;
            
            if obj.MeasurementMode
                if isgraphics(obj.ZoomAxes)
                    % Hide the live red center crosshair while the frozen view is
                    % used for measurement, so it does not obstruct the signal.
                    delete(findobj(obj.ZoomAxes, 'Tag', 'ZoomCursorToolLiveCursor'));
                    xlims = xlim(obj.ZoomAxes);
                    ylims = ylim(obj.ZoomAxes);
                    obj.drawMeasurementCursors(xlims(1), xlims(2), ylims(1), ylims(2));
                    title(obj.ZoomAxes, 'Frozen Measurement View: click two points in this window', ...
                        'FontWeight', 'bold', 'FontSize', 10, 'Color', [0 0 0]);
                end
                fprintf('Measurement mode ON: zoom view frozen and live red cursor hidden. Click in the zoom window to place cursor 1 and cursor 2. Press M again to unfreeze, or C to clear.\n');
            else
                if isgraphics(obj.ZoomAxes)
                    delete(findobj(obj.ZoomAxes, 'Tag', 'ZoomCursorToolMeasurement'));
                end
                fprintf('Measurement mode OFF: live zoom resumed.\n');
            end
        end
        
        function clearMeasurementCursors(obj)
            % Clear measurement cursors and annotation
            obj.MeasurementPoints = zeros(0, 2);
            if isgraphics(obj.ZoomAxes)
                % Keep the currently plotted zoom view; the cursors will also be removed
                % on the next mouse-move update because the axes are redrawn.
                delete(findobj(obj.ZoomAxes, 'Tag', 'ZoomCursorToolMeasurement'));
            end
            if obj.MeasurementMode && isgraphics(obj.ZoomAxes)
                xlims = xlim(obj.ZoomAxes);
                ylims = ylim(obj.ZoomAxes);
                obj.drawMeasurementCursors(xlims(1), xlims(2), ylims(1), ylims(2));
            end
            fprintf('Measurement cursors cleared.\n');
        end
        
        function onZoomMouseClick(obj, ~, ~)
            % Place measurement cursors by clicking inside the zoomed axes
            if ~obj.IsActive || ~obj.MeasurementMode || ~isgraphics(obj.ZoomAxes)
                return;
            end
            
            pt = get(obj.ZoomAxes, 'CurrentPoint');
            xClick = pt(1, 1);
            yClick = pt(1, 2);
            
            xlims = xlim(obj.ZoomAxes);
            ylims = ylim(obj.ZoomAxes);
            if xClick < xlims(1) || xClick > xlims(2) || ...
               yClick < ylims(1) || yClick > ylims(2)
                return;
            end
            
            if size(obj.MeasurementPoints, 1) >= obj.MaxMeasurementPoints
                % Start a new two-point measurement after the previous pair is complete.
                obj.MeasurementPoints = zeros(0, 2);
            end
            obj.MeasurementPoints(end+1, :) = [xClick, yClick];
            
            fprintf('Measurement cursor %d: X = %.6g, Y = %.6g\n', ...
                size(obj.MeasurementPoints, 1), xClick, yClick);
            
            if size(obj.MeasurementPoints, 1) == 2
                dx = obj.MeasurementPoints(2, 1) - obj.MeasurementPoints(1, 1);
                dy = obj.MeasurementPoints(2, 2) - obj.MeasurementPoints(1, 2);
                dist = hypot(dx, dy);
                fprintf('Measurement: dx = %.6g, dy = %.6g, |dx| = %.6g, |dy| = %.6g, distance = %.6g\n', ...
                    dx, dy, abs(dx), abs(dy), dist);
            end
            
            obj.drawMeasurementCursors(xlims(1), xlims(2), ylims(1), ylims(2));
        end
        
        function drawMeasurementCursors(obj, xMin, xMax, yMin, yMax)
            % Draw persistent measurement cursors in the zoom axes
            if ~isgraphics(obj.ZoomAxes)
                return;
            end
            
            delete(findobj(obj.ZoomAxes, 'Tag', 'ZoomCursorToolMeasurement'));
            
            if isempty(obj.MeasurementPoints)
                if obj.MeasurementMode
                    text(obj.ZoomAxes, 0.02, 0.98, 'Measurement ON: click two points', ...
                        'Units', 'normalized', ...
                        'VerticalAlignment', 'top', ...
                        'Color', [0 0 0], ...
                        'BackgroundColor', [1 1 1], ...
                        'Margin', 4, ...
                        'FontSize', 9, ...
                        'Tag', 'ZoomCursorToolMeasurement');
                end
                return;
            end
            
            wasHold = ishold(obj.ZoomAxes);
            hold(obj.ZoomAxes, 'on');
            colors = [0 0.4470 0.7410; 0.4660 0.6740 0.1880];
            labels = {'1', '2'};
            
            for k = 1:size(obj.MeasurementPoints, 1)
                x = obj.MeasurementPoints(k, 1);
                y = obj.MeasurementPoints(k, 2);
                color = colors(min(k, size(colors,1)), :);
                
                plot(obj.ZoomAxes, [x x], [yMin yMax], '--', ...
                    'Color', color, 'LineWidth', 1.4, 'Tag', 'ZoomCursorToolMeasurement');
                plot(obj.ZoomAxes, [xMin xMax], [y y], '--', ...
                    'Color', color, 'LineWidth', 1.4, 'Tag', 'ZoomCursorToolMeasurement');
                plot(obj.ZoomAxes, x, y, 'o', ...
                    'Color', color, 'MarkerFaceColor', color, 'MarkerSize', 7, ...
                    'LineWidth', 1.2, 'Tag', 'ZoomCursorToolMeasurement');
                text(obj.ZoomAxes, x, y, ['  C' labels{k}], ...
                    'Color', color, 'FontWeight', 'bold', 'FontSize', 9, ...
                    'VerticalAlignment', 'bottom', 'Tag', 'ZoomCursorToolMeasurement');
            end
            
            if size(obj.MeasurementPoints, 1) == 1
                infoStr = sprintf('C1: X = %.6g, Y = %.6g\nClick second point for dx/dy', ...
                    obj.MeasurementPoints(1,1), obj.MeasurementPoints(1,2));
            else
                p1 = obj.MeasurementPoints(1, :);
                p2 = obj.MeasurementPoints(2, :);
                dx = p2(1) - p1(1);
                dy = p2(2) - p1(2);
                dist = hypot(dx, dy);
                infoStr = sprintf('dx = %.6g   dy = %.6g\n|dx| = %.6g   |dy| = %.6g\ndistance = %.6g', ...
                    dx, dy, abs(dx), abs(dy), dist);
            end
            
            text(obj.ZoomAxes, 0.02, 0.98, infoStr, ...
                'Units', 'normalized', ...
                'VerticalAlignment', 'top', ...
                'Color', [0 0 0], ...
                'BackgroundColor', [1 1 1], ...
                'EdgeColor', [0.2 0.2 0.2], ...
                'Margin', 5, ...
                'FontSize', 9, ...
                'Tag', 'ZoomCursorToolMeasurement');
            
            if ~wasHold
                hold(obj.ZoomAxes, 'off');
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
            if isgraphics(obj.ZoomFigure)
                delete(obj.ZoomFigure);
            end
        end
        
        function deactivate(obj)
            % Deactivate the tool
            obj.IsActive = false;
            obj.MeasurementMode = false;
            obj.ZoomFrozenForMeasurement = false;
            if isgraphics(obj.CursorBox)
                obj.CursorBox.Visible = 'off';
            end
            
            % Remove callbacks
            if isgraphics(obj.MainFigure)
                set(obj.MainFigure, 'WindowButtonMotionFcn', obj.OriginalWindowButtonMotionFcn);
                set(obj.MainFigure, 'KeyPressFcn', obj.OriginalKeyPressFcn);
                set(obj.MainFigure, 'WindowButtonDownFcn', obj.OriginalWindowButtonDownFcn);
            end
            
            %fprintf('\n=== Zoom Cursor Tool Deactivated ===\n');
        end
        
        function activate(obj)
            % Reactivate the tool
            if ~isgraphics(obj.ZoomFigure)
                obj.createZoomFigure();
            end
            obj.setupCallbacks();
            obj.IsActive = true;
            %fprintf('\n=== Zoom Cursor Tool Activated ===\n');
        end
        
        function delete(obj)
            % Destructor - clean up
            if isgraphics(obj.ZoomFigure)
                delete(obj.ZoomFigure);
            end
            if isgraphics(obj.CursorBox)
                delete(obj.CursorBox);
            end
        end
    end
end