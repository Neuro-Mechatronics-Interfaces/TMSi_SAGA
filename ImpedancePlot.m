classdef ImpedancePlot < TMSiSAGA.HiddenHandle
   %IMPEDANCEPLOT Provides a visualisation of the skin-electrode impedance of the subject
   %
   %IMPEDANCEPLOT properties:
   %
   %    is_visible - If plot is ready to be used (i.e. data appended to)
   %    name - Name of this GUI
   %    figure - The figure handle used
   %
   %IMPEDANCEPLOT methods:
   %
   %    ImpedancePlot - Constructor for this object
   %    show - Show the figure in which the data is going to be displayed
   %    hide - Destroy the current figure object associated with this object
   %    head_layout - Function that allows for making a topographic plot of the Impedance values
   %    grid_layout - Funtion that allows for making a gridded plot (as the HD EMG grid) of the Impedance values
   %
   %IMPEDANCEPLOT example:
   %
   % config = struct('setImpedance', true, ... 
   %                 'setReferenceMethod', 'common');
   %
   % channel_config = struct('uni', 1:32);
   %
   % lib = TMSiSAGA.Library();
   % 
   % lay_out = 'head';
   %
   % try
   %     device = lib.getFirstAvailableDevice('usb', 'electrical');   
   %     device.connect();
   %     device.getDeviceInfo();
   % 
   %     num_channels = length(channel_config.uni);
   %
   %     if strcmp(lay_out,'head')
   %         load(['EEGChannels' num2str(num_channels) 'TMSi.mat']);
   %     end
   %
   %     device.setDeviceConfig(config);
   %     device.setChannelConfig(channel_config);
   %
   %     for i=1:length(device.getActiveChannels())
   %         channel_names{i}=device.getActiveChannels{i}.alternative_name;
   %     end
   %
   %     iPlot = TMSiSAGA.ImpedancePlot('Grid plot Impedance', channel_config.uni, channel_names);
   %     iPlot.show();
   % 
   %     device.start();
   %     
   %     % As long as we do not press the X or 'q' keep on sampling from the
   %     % device.
   %     while iPlot.is_visible
   %         % Sample from device
   %         [samples, num_sets, type] = device.sample();
   %         
   %         % Append samples to the plot and redraw
   %         % need to divide by 10^6.
   %         if num_sets > 0
   %             s=samples ./ 10^6;
   %                    
   %             % Set the type of layout (head_layout or grid_layout) that is executed
   %             if strcmp(lay_out, 'head')
   %                 iPlot.head_layout(s, ChanLocs);
   %             elseif strcmp(lay_out, 'grid')
   %                 iPlot.grid_layout(s);
   %             end
   %         end
   %     end
   %     
   %     % Stop sampling on the device
   %     device.stop();
   %     
   %     % Disconnect from device
   %     device.disconnect();
   %  catch e
   %     % In case of an error close all still active devices and clean up
   %     % library itself
   %     lib.cleanUp();
   %     
   %     % Rethrow error to ensure you get a message in console
   %     rethrow(e)
   % end
   
   properties
       % If GUI is visible, not stopped
       is_visible
       
       % The figure handle used
       figure_handle
       
       % The axes handle used
       axes_handle
   end
    
    properties(Access = private)
        % Variables that track the size of added graphical objects to the
        % topoplot
        basic_children
        children
        previous_children
        
        % Colormap used for plotting impedances
        impedance_colormap
        
        % Names of the activated channels
        channel_names
        
        % Channels that are activated
        channels
        
        % Number of activated channels
        num_channels
    end
    
    methods
        function obj = ImpedancePlot(fig, enabled_channels, channel_names, SAGA_type)
            %IMPEDANCEPLOT - Constructor function for the ImpedancePlot Class
            %
            %   obj = ImpedancePlot(fig, name, enabled_channels, channel_names, SAGA_type)
            %
            %   obj [out] - ImpedancePlot object.
            %   fig [in] - Figure handle.
            %   enabled_channels [in] - Channels that have been enabled for the measurement
            %   channel_names [in] - Configured names for the impedance measurement
            %   SAGA_type [in] - Type of SAGA that is used (32+ or 64+).
            %
            % See also: Contents
            
            obj.channels = enabled_channels + 1; % skip the CREF channel
            obj.channel_names = channel_names;        
            obj.num_channels = SAGA_type;
            
            obj.figure_handle = fig;
            set(obj.figure_handle, 'CloseRequestFcn', @obj.figure_closed_cb);
            
            % Ensure that y-axis is reversed (lowest value in the top of
            % the figure
            obj.axes_handle = axes(obj.figure_handle, ...
                'NextPlot', 'add', 'YDir', 'reverse', ...
                'FontSize', 12, 'FontName', 'Tahoma', ...
                'XLim', [1 8], 'YLim', [1 SAGA_type/8]);
            axis equal
            axis off   
            
            obj.is_visible = true;
            
            obj.impedance_colormap = obj.CreateImpedanceMap();
            obj.basic_children = [];
        end
        
        function delete(obj)
            try
                delete(obj.figure_handle);
            catch
                disp('Figure handle was already deleted.'); 
            end
        end
        
        function figure_closed_cb(obj, src, ~)
            try
                obj.is_visible = false;
                set(src, 'CloseRequestFcn', closereq);
                close(src);
            catch
                disp('Impedance plot closed.');
            end
        end
        
        function head_layout(obj, impedance, ChanLocs)
            %HEAD_LAYOUT - Function that enables topographic plotting of 
            %   the EEG impedance measurement
            %
            %   head_layout(obj, impedance, ChanLocs)
            %
            %   Impedance values are plotted in a head layout using an EEG
            %   channel locations file. Disks are plotted that have a
            %   colour corresponding to a given impedance value that is
            %   retrieved from the device.
            %   
            %   obj [in] - ImpedancePlot object.
            %   impedance [in] - List of measured impedance values
            %   ChanLocs [in] - EEG ChannelLocation file containing information
            %       on where to plot the impedance disks.
            %
            
            % Find the color corresponding to the impedance value for
            % plotting.
            plot_impedance = obj.FindImpedanceColor(impedance);
            
            % Create legend entries
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',15,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(1,:),'DisplayName','1-5 k\Omega')
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',15,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(2,:),'DisplayName','5-10 k\Omega')
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',15,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(3,:),'DisplayName','10-30 k\Omega')          
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',15,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(4,:),'DisplayName','30-50 k\Omega')
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',15,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(5,:),'DisplayName','50-100 k\Omega')
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',15,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(6,:),'DisplayName','100-200 k\Omega')            
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',15,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(7,:),'DisplayName','200-400 k\Omega') 
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',15,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(8,:),'DisplayName','> 400 k\Omega')   
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',15,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(9,:),'DisplayName','Not connected')  
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',15,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(10,:),'DisplayName','Disabled')              
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',15,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(11,:),'DisplayName','Odd/Even error')  
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',15,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(12,:),'DisplayName','GND disconnected') 
            
            % Place the legend outside the plotted impedance values
            legend(obj.axes_handle, 'AutoUpdate','off','Location','northeastoutside')
            legend(obj.axes_handle, 'boxoff')
            
            % Plot a circle
            theta = 0:pi/50:2*pi;
            x_circle = 0.5*cos(theta);
            y_circle = 0.5*sin(theta);
            plot(obj.axes_handle, x_circle, y_circle, 'Color', [0.65 0.65 0.65],'LineWidth',5);

            % Plot a nose
            y_nose = [y_circle(3) 0 y_circle(end-2)];
            x_nose = [x_circle(3) 0.55 x_circle(end-2)];            
            plot(obj.axes_handle, y_nose,x_nose, 'Color', [0.65 0.65 0.65],'LineWidth',5);

            % Plot ears
            x_ear  = [0.49  0.51  0.52  0.53 0.54 0.54 0.55 0.53 0.51 0.485]; 
            y_ear  = [.10 .1175 .1185 .1145 .0955 -.0055 -.0930 -.1315 -.1385 -.12];                 
            plot(obj.axes_handle, x_ear, y_ear, 'Color', [0.65 0.65 0.65],'LineWidth',5);
            plot(obj.axes_handle, -x_ear, y_ear, 'Color', [0.65 0.65 0.65],'LineWidth',5);
            
            % Plot the impedances at the correct channel location. Skip the
            % first impedance value as this is the CREF channel.
            for i = 1:numel(ChanLocs)
                plot(obj.axes_handle, ChanLocs(i).radius * sind(ChanLocs(i).theta), ...
                    ChanLocs(i).radius * cosd(ChanLocs(i).theta), 'o', 'MarkerSize',15,...
                'MarkerEdgeColor','k','MarkerFaceColor', plot_impedance(i+1,:))
                if obj.num_channels == 32
                    text(obj.axes_handle, ChanLocs(i).radius  * sind(ChanLocs(i).theta) , ...
                    ChanLocs(i).radius * cosd(ChanLocs(i).theta) - 0.028, obj.channel_names(i+1), ...
                    'Color', 'k', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle')
                elseif obj.num_channels == 64
                    text(obj.axes_handle, ChanLocs(i).radius  * sind(ChanLocs(i).theta) , ... 
                        ChanLocs(i).radius * cosd(ChanLocs(i).theta) - 0.028, ...
                        obj.channel_names(i+1),  'Color', 'k', 'FontWeight', 'bold', ...
                        'FontSize', 9, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle')                    
                end
            end

            % Include the value of the PGND connection below the plot to
            % show the user this in the figure window
            text(obj.axes_handle, -0.075,-0.55,['PGND impedance: ' num2str(impedance(end,end)) 'k\Omega'], 'Color', 'k');
            text(obj.axes_handle, -0.075,-0.575,['CREF impedance: ' num2str(impedance(1,end)) 'k\Omega'], 'Color', 'k');
            
            % Find the impedance values for plotting a list next to the
            % figure
            obj.ImpedanceList(impedance, 'EEG');
            obj.CleanUpFigure();
            drawnow
        end
        
        function grid_layout(obj, impedance)
            %GRID_LAYOUT - Function that enables plotting of the HD EMG 
            %   impedance measurement in a grid layout
            %
            %   grid_layout(obj, impedance)
            %
            %   Impedance values are plotted in a grid layout. Disks are 
            %   plotted that have a colour corresponding to a given 
            %   impedance value that is retrieved from the device.
            %
            %   obj [in] - ImpedancePlot object.
            %   impedance [in] - List of measured impedance values.
            %            
            
            % Initialise the grid and the number of channels
            if obj.num_channels == 32
                grid_values = zeros(4,8);
            elseif obj.num_channels == 64
                grid_values = zeros(8,8);
            end
            
%             % Create a vector that ensures plotting is done appropriately
%             UNI_locations = [];
%             for i = 1:obj.num_channels/8:obj.num_channels, UNI_locations(end+1) = i; end
%             for i = 2:obj.num_channels/8:obj.num_channels, UNI_locations(end+1) = i; end
%             for i = 3:obj.num_channels/8:obj.num_channels, UNI_locations(end+1) = i; end
%             for i = 4:obj.num_channels/8:obj.num_channels, UNI_locations(end+1) = i; end
%             if obj.num_channels == 64
%                 for i = 5:obj.num_channels/8:obj.num_channels, UNI_locations(end+1) = i; end
%                 for i = 6:obj.num_channels/8:obj.num_channels, UNI_locations(end+1) = i; end
%                 for i = 7:obj.num_channels/8:obj.num_channels, UNI_locations(end+1) = i; end
%                 for i = 8:obj.num_channels/8:obj.num_channels, UNI_locations(end+1) = i; end                
%             end
            % Do the same thing but without arbitrarily complicated code:
            UNI_locations = reshape(1:obj.num_channels, 8, 8);
            UNI_locations = (UNI_locations(:))';
            
            % Ensure that the values in the grid are plotted in the right
            % locations
            grid_values(UNI_locations) = impedance(2:end-1,end);
            obj.CreateGridEMG(grid_values, impedance);
        end
        
        function hide(obj)
            %HIDE - Destroy the current figure object associated with this object.
            %
            %   hide(obj)
            %
            %   obj [in] - ImpedancePlot object.

            obj.figure_handle.Visible = 'off';            
            obj.is_visible = false;
        end
    end
    
    methods(Access = private)        
        function CleanUpFigure(obj)
            %CLEANUPFIGURE - Function that is used to clean up the figures
            %   that are created in the impedance plots
            %
            %   CleanUpFigure(obj)
            %
            %   obj [in] - ImpedancePlot object.
            %
            
            % Find the standard number of graphical objects that are added
            % to the plot (first iteration only)
            if isempty(obj.basic_children)
                obj.basic_children = allchild(obj.axes_handle);
            end
            
            % Get the current graphical objects
            obj.children = allchild(obj.axes_handle);
            
            % Check whether the current number of graphical
            % objects is more than the basic number of
            % graphical objects and delete the older graphical
            % objects from the current active axes
            if length(obj.children) > length(obj.basic_children)
                added_go = length(obj.children)-length(obj.previous_children);
                delete(obj.children(end-added_go+1:end))
            end
            % Save the number of current graphical objects in
            % the axes to ensure that they are properly deleted
            % in the next iteration.
            obj.previous_children = allchild(obj.axes_handle);
        end
        
        function impedance_color = FindImpedanceColor(obj, impedance)
            %FINDIMPEDANCECOLOR - Function that finds the color of the
            %   marker based on its impedance value
            %
            %   impedance_color = FindImpedanceColor(obj, impedance)
            %
            %   impedance_color [out] - RGB triplet corresponding to the
            %       impedance values.
            %   obj [in] - ImpedancePlot object.
            %   impedance [in] - List of measured impedance values.
            %
            
            % Pre-allocate the vector for speed-up
            impedance_color = nan(size(impedance,1),3);
            
            % Loop over all impedance values, find in what range the
            % impedance value lies and allocate the appropriate color to
            % the datapoint
            for ii = 1:numel(impedance)
                if impedance(ii) < 5
                    impedance_color(ii,:) = obj.impedance_colormap(1,:);
                elseif impedance(ii) >= 5 && impedance(ii) < 10
                    impedance_color(ii,:) = obj.impedance_colormap(2,:);
                elseif impedance(ii) >= 10 && impedance(ii) < 30
                    impedance_color(ii,:) = obj.impedance_colormap(3,:);
                elseif impedance(ii) >= 30 && impedance(ii) < 50
                    impedance_color(ii,:) = obj.impedance_colormap(4,:);
                elseif impedance(ii) >= 50 && impedance(ii) < 100
                    impedance_color(ii,:) = obj.impedance_colormap(5,:);
                elseif impedance(ii) >= 100 && impedance(ii) < 200
                    impedance_color(ii,:) = obj.impedance_colormap(6,:);
                elseif impedance(ii) >= 200 && impedance(ii) < 400
                    impedance_color(ii,:) = obj.impedance_colormap(7,:);
                elseif impedance(ii) >= 400 && impedance(ii) < 500
                    impedance_color(ii,:) = obj.impedance_colormap(8,:);
                elseif impedance(ii) == 500
                    impedance_color(ii,:) = obj.impedance_colormap(9,:);
                elseif impedance(ii) == 5000
                    impedance_color(ii,:) = obj.impedance_colormap(10,:);
                elseif impedance(ii) == 5100
                    impedance_color(ii,:) = obj.impedance_colormap(11,:);
                elseif impedance(ii) == 5200
                    impedance_color(ii,:) = obj.impedance_colormap(12,:);
                end
            end
        end
        
        function ImpedanceList(obj, impedance, flag)
            %IMPEDANCELIST - Function that creates a list with all
            %   impedance values next to the figure
            %
            %   ImpedanceList(obj, impedance, flag)
            %
            %   obj [in] - ImpedancePlot object.
            %   impedance [in] - List of measured impedance values.
            %   flag [in] - Contains whether the impedance plot is a head_layout
            %       or grid_layout plot.
            %
            
            % EEG setting
            if strcmp(flag,'EEG')
                % Loop over all impedance values except CREF and PGND                
                for ii = 2:size(impedance,1)-1
                    % Make two columns with impedance values if there are
                    % 64 channels used. Otherwise only one column is
                    % displayed.
                    if obj.num_channels == 64
                        if ii <= 33
                            text(obj.axes_handle, -0.96,0.55-ii/32,[obj.channel_names{ii} ...
                                ':  ' num2str(impedance(ii,end)) 'k\Omega']);                            
                        elseif ii> 33 
                            text(obj.axes_handle, -0.76,0.55-(ii-32)/32,[obj.channel_names{ii} ...
                                ':  ' num2str(impedance(ii,end)) 'k\Omega']);                            
                        end
                    elseif obj.num_channels == 32
                        text(obj.axes_handle, -0.76,0.55-ii/32,[obj.channel_names{ii} ...
                            ':  ' num2str(impedance(ii,end)) 'k\Omega']);
                    end
                end
            
            % HD EMG setting
            elseif strcmp(flag,'HDEMG')
                % Loop over all impedance values except CREF and PGND
                for ii = 2:size(impedance,1)-1
                    % Make two columns with impedance values if there are
                    % 64 channels used. Otherwise only one column is
                    % displayed. As the grid differs with 32 or 64
                    % channels, the text is plotted in a different
                    % location
                    if obj.num_channels == 64
                        if ii <= 33
                            text(obj.axes_handle, -2.3, 0.3 + ii/4,[obj.channel_names{ii} ...
                                ':  ' num2str(impedance(ii,end)) 'k\Omega']);
                        elseif ii > 33 && obj.num_channels > 32
                            text(obj.axes_handle, -0.9, 0.3 + (ii-32)/4,[obj.channel_names{ii} ...
                                ':  ' num2str(impedance(ii,end)) 'k\Omega']);
                        end
                    elseif obj.num_channels == 32
                        if ii <= 33
                            text(obj.axes_handle, 0, 0.25 + ii/8,[obj.channel_names{ii} ...
                                ':  ' num2str(impedance(ii,end)) 'k\Omega']);
                        end
                    end
                end
            end
        end
        
        function CreateGridEMG(obj, grid_values, impedance) 
            %CREATEGRIDEMG - Function that creates a gridded impedance plot 
            %   with indicated electrode locations for the HD EMG application
            %
            %   CreateGridEMG(obj, grid_values, impedance) 
            %
            %   obj [in] - ImpedancePlot object.
            %   grid_values [in] - List of impedance values assigned to 
            %       lay-out of the grid. 
            %   impedance [in] - List of all measured impedance values .
            %
              
            % Number of channels and columns
            channel_columns = 8;
            channel_rows = obj.num_channels/channel_columns;
            
            % Assign a z-value to the the grid points 
            channel_locs = ones(channel_rows,channel_columns)*2000;
            
            % Find the color for the different impedance values
            grid_value_color = obj.FindImpedanceColor(grid_values);
            
            % Make the grid 
            x = 1:channel_columns; y = 1:channel_rows;
            [X,Y] = meshgrid(x,y); 

            
            % Create legend entries
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',20,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(1,:),'DisplayName','1-5 k\Omega')
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',20,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(2,:),'DisplayName','5-10 k\Omega')
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',20,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(3,:),'DisplayName','10-30 k\Omega')          
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',20,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(4,:),'DisplayName','30-50 k\Omega')
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',20,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(5,:),'DisplayName','50-100 k\Omega')
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',20,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(6,:),'DisplayName','100-200 k\Omega')            
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',20,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(7,:),'DisplayName','200-400 k\Omega') 
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',20,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(8,:),'DisplayName','> 400 k\Omega')   
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',20,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(9,:),'DisplayName','Not connected')  
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',20,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(10,:),'DisplayName','Disabled')              
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',20,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(11,:),'DisplayName','Odd/Even error')  
            plot(obj.axes_handle, nan,nan,'o','MarkerSize',20,'MarkerEdgeColor','k','MarkerFaceColor',...
                obj.impedance_colormap(12,:),'DisplayName','GND disconnected') 
            
            % Place the legend outside the plotted impedance values
            legend(obj.axes_handle, 'AutoUpdate','off','Location','northeastoutside')
            legend(obj.axes_handle, 'boxoff')
            
            for ii = 1:size(grid_value_color,1)
                % Plotting electrode locations
                plot3(obj.axes_handle, X(ii),Y(ii),channel_locs(ii),...
                    'LineStyle','none','Marker','o','MarkerSize',20, ...
                    'MarkerEdgeColor','k','MarkerFaceColor',grid_value_color(ii,:));
            end
            
            
            % Include the value of the PGND connection below the plot to
            % show the user this in the figure window
            if obj.num_channels == 64
                text(obj.axes_handle, 0.9, 8.5, ['CREF impedance: ' num2str(impedance(1,end)) 'k\Omega']);
                text(obj.axes_handle, 7.0, 8.5, ['PGND impedance: ' num2str(impedance(end,end)) 'k\Omega']);
            elseif obj.num_channels == 32
                text(obj.axes_handle, 0.9, 4.7, ['CREF impedance: ' num2str(impedance(1,end)) 'k\Omega']);
                text(obj.axes_handle, 7.0, 4.7, ['PGND impedance: ' num2str(impedance(end,end)) 'k\Omega']);
            end
            
            % If the channel names have to be plotted, then print the text 
            % per channel in the figure
            r = 0.25; c = 1;
            for ii = 1:obj.num_channels
                if mod(ii,8) == 1; r = r+1; c = 1; 
                    text(obj.axes_handle, c,r,2000,[obj.channel_names{ii+1}],...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                else   
                    c = c+1; text(obj.axes_handle, c,r,2000,[obj.channel_names{ii+1}], ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');  
                end
            end
            
            % Plot the list with all impedance values
            obj.ImpedanceList(impedance, 'HDEMG');
            % Clean up the figure and draw all new graphical objects
            obj.CleanUpFigure();
            drawnow
        end
    end

    methods(Static, Access = private)        
        function impedance_map = CreateImpedanceMap()
            %CREATIMPEDANCEMAP - Creates an array that contains color 
            %   codings required for plotting of impedance values.
            %
            %   impedance_map = CreateImpedanceMap()
            %
            %   impedance_map [out] - List of RGB triples defined for the
            %       defined groups (12 in total) used in an impedance plot.
            
            impedance_map = nan(12,3);
            impedance_map(1,:) = [0,1,0];
            impedance_map(2,:) = [0,0.8,0];
            impedance_map(3,:) = [0,0.6,0];
            impedance_map(4,:) = [0,0.4,0];
            impedance_map(5,:) = [1,1,0];
            impedance_map(6,:) = [0.8,0.5,0];
            impedance_map(7,:) = [1,0,0];
            impedance_map(8,:) = [0.6,0,0];
            impedance_map(9,:) = [0.4,0.26,0.13];
            impedance_map(10,:) = [0.5,0.5,0.5];
            impedance_map(11,:) = [0.8,0,0.4];
            impedance_map(12,:) = [0,0,0.7];
        end    
    end
end