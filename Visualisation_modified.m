classdef Visualisation_modified < TMSiSAGA.HiddenHandle
    %VISUALISATION Class provides a method to visualise HD EMG measurements
    %
    %   Online processing by means of a visualisation is provided by the
    %   class. An HD EMG visualisation (heat map of the muscle activation) 
    %   can be generated.
    %
    %VISUALISATION properties:
    %
    %   channels - A list of numbers representing the channels that are sampled from
    %   sample_rate - The sample rate of the sampled data
    %   window_samples - The number of samples in a window
    %   MVC - Vector containing the maximal values during a Maximum Voluntary Contraction
    %   is_visible - Parameter that states whether the plot is visible
    %
    %VISUALISATION methods:
    %
    %   Visualisation - Constructor function for this object
    %   HPfilter - Function that allows for high-pass filtering of the data stream
    %   RMSEnvelope - Function that computes the RMS value of a high-pass filtered and rectified data window
    %   MaximumVoluntaryContraction - Function that finds the maximal values during a MVC that are used for normalisation
    %   EMG_visualisation - Function that visualises the activation measured by the HD EMG grid
    %
    %VISUALISATION example:
    %
    %     device = lib.getFirstAvailableDevice('usb', 'electrical');
    %     device.connect();
    %
    %     device.updateDeviceConfig();
    %
    %     sample_buffer = zeros(numel(device.getActiveChannels()), 0);
    %     window_seconds = 0.5;
    %     window_samples = window_seconds*device.sample_rate;
    %
    %     Fc = 10; order = 2;
    %
    %     vPlot = TMSiSAGA.Visualisation(device.sample_rate, device.getActiveChannels(), window_samples);
    %
    %     device.start();
    %
    %     for ii = 1:1000
    %         % Sample from device
    %         [samples, num_sets, type] = device.sample();
    %
    %         % Append samples to the plot and redraw
    %         if num_sets > 0
    %             sample_buffer(:, size(sample_buffer, 2) + size(samples, 2)) = 0;
    %             sample_buffer(:, end-size(samples, 2) + 1:end) = samples;
    %
    %             while size(sample_buffer, 2) >= window_samples
    %                 data_plot = vPlot.RMSEnvelope(sample_buffer(:,1:window_samples), Fc, order);
    %                 vPlot.EMG_Visualisation(sample_buffer, data_plot, ...
    %                   normalisation, 'Example HD EMG plot', 'up')
    %
    %                 sample_buffer = sample_buffer(:, window_samples + 1:end);
    %             end
    %         end
    %     end
    %
    %     device.stop();
    %     device.disconnect();
    %
    
    properties
        % A list of numbers representing the channels that are sampled from
        channels
        
        % The sample rate of the sampled data
        sample_rate
        
        % The number of samples in a window
        window_samples
               
        % Maximal values during a Maximum Voluntary Contraction in the EMG
        % signal
        MVC
        
        % Parameter that states visibility of the figure window
        is_visible
    end
    
    properties(Access = private)       
        % Conditions filter delay (high-pass)
        z_h
        
        % Filter coefficients (high-pass)
        b_high
        
        % Filter coefficients (high-pass)
        a_high
        
        % Vector containing the normalisation constants in the EMG signal
        norm_factor
        
        % Channel name display for the HD EMG grid
        chan_name
        
        % Handle to the figure of the HD EMG grid
        figure_handle
        
        % Handle to the plot of the HD EMG grid
        surface_handle
        
        % Handle to plotted channel locations
        plt_chans
        
        % Handle to plotted channel locations that are not connected
        plt_chans_nc
    end
    
    methods
        function obj = Visualisation(sample_rate, channels, window_samples)
            %VISUALISATION - Constructor for the Visualisation object
            %
            %   obj = Visualisation(sample_rate, channels, window_samples)
            %
            %   obj [out] - Visualisation object.
            %   sample_rate [in] - Sample rate of the device.
            %   channels [in] - Activated channels. 
            %   window_samples [in] - Number of samples that are processed in a data window.
            %
            
            obj.sample_rate = double(sample_rate);
            obj.channels = channels;
            obj.window_samples = double(window_samples);
            
            obj.norm_factor = ones(numel(obj.channels)-3, 1);
            obj.chan_name = 0;
            obj.figure_handle = [];
            obj.is_visible = true;

        end
              
        function filtered_samples = HPfilter(obj, samples, Fc, order)
            %HPFILTER - Function that allows for real-time high-pass
            %   filtering.
            %
            %   filtered_samples = HPfilter(obj, samples, Fc, order)
            %
            %   This function requires the signal-processing toolbox, as
            %   butter() is used to find the filter coefficients
            %
            %   filtered_samples [out] - Sampled data that has been filtered.
            %   obj [in] - Visualisation object.
            %   samples [in] - Sampled data to be filtered.
            %   Fc [in] - Cut-off frequency of the filter (Hz).
            %   order [in] - Order of the filter.
            %
            
            % Check whether the filter coefficients were already set.
            if isempty(obj.b_high) && isempty(obj.a_high)
                [obj.b_high, obj.a_high] = butter(order, Fc/(obj.sample_rate/2), 'high');
            end
            if isempty(obj.z_h)
                obj.z_h = zeros(1,order);
            end
            
            % Filter data and append the status and counter channel again.
            [filtered_samples, obj.z_h] = filter(obj.b_high, obj.a_high,....
                samples(1:end-2,:), obj.z_h, 2);
            filtered_samples = [filtered_samples; samples(end-1:end,:)];
        end
        
        function RMS_value = RMSEnvelope(obj, sample_buffer, Fc, order)
            %RMSENVELOPE - Function that calculates the RMS value of a 
            %   signal window of an HD EMG measurement. 
            %
            %   RMS_value = RMSEnvelope(obj, sample_buffer, Fc, order)
            %
            %   RMS values are calculated for all connected channels Prior 
            %   to calculation of the RMS, a high-pass filter is applied 
            %   (Butterworth). 
            %
            %   RMS_value [out] - List containing RMS values for all channels.
            %   obj [in] - Visualisation object.
            %   sample_buffer [in] - A buffer with unprocessed sampled data.
            %   Fc [in] - Cut-off frequency of the filter (Hz).
            %   order [in] - Order of the filter.
            %
            
            % High-pass filter the data
            filtered_samples = obj.HPfilter(sample_buffer(:,1:obj.window_samples), Fc, order);
                    
            % The first channel and last two channels are not plotted in 
            % the HD EMG heat map, because these are the CREF, STATUS and 
            % COUNTER channels
            RMS_value = rms(filtered_samples(2:end-2,:), 2);            
        end
        
        function MaximumVoluntaryContraction(obj, RMS_value)
            %MAXIMUMVOLUNTARYCONTRACTION - Function that finds the
            %   normalisation constants during a Maximum Voluntary 
            %   Contraction.
            %
            %   MaximumVoluntaryContraction(obj, RMS_value)
            %
            %   obj [in] - Visulisation object.
            %   RMS_value [in] - Array with RMS values obtained from the buffered data. 
            %       For each channel, a single RMS value is present.
            %
            
            % Notify user that MVC has to be performed
            disp('Maximally contract the muscle')
            % Find MVC values for every channel
            obj.norm_factor = max(obj.norm_factor,RMS_value);
            obj.MVC = obj.norm_factor;
        end
        
        function EMG_Visualisation(obj, sample_buffer, data_plot, ...
                normalisation, figurename, connector_orientation)
            %EMG_VISUALISATION - Function that enables Real Time plotting
            %   of an HD EMG grid.
            %
            %   EMG_Visualisation(obj, sample_buffer, data_plot, ...
            %    normalisation, figurename, connector_orientation)
            %
            %   obj [in] - Visualisation object.
            %   sample_buffer [in] - A buffer with unprocessed sampled data.
            %   data_plot [in] - Array with RMS values to be plotted.
            %   normalisation [in] - Boolean that determines whether normalisation should be done.
            %   figurename [in] - User-defined name for the figure window.
            %   connector_orientation [in] - Direction in which the HD EMG connnector points when observed from the 
            %       user's point of view.
            %
            
            % Initialise the grid and the number of channels.
            % num_channels also contains the channels: CREF, STATUS and
            % COUNTER which are not plotted in the figure
            num_columns = 8; num_channels = numel(obj.channels)-3;
            num_rows = num_channels/num_columns;
            grid_values = zeros(num_rows,num_columns);
            
            % If normalisation of the data is done, check whether MVC is
            % already set or if it has to be initialised
            if normalisation
                if sample_buffer(end, 1) / obj.sample_rate >= 5 && ...
                        sample_buffer(end, 1) / obj.sample_rate <= 10
                    
                    % Remove old print messages
                    if sample_buffer(end,1) / obj.sample_rate > (5 + obj.window_samples/obj.sample_rate)
                        old_print_message = 'Maximally contract the muscle';
                        disp(repmat(char(8),1,length(old_print_message)+2))
                    elseif sample_buffer(end,1) / obj.sample_rate >= 5 && ...
                           sample_buffer(end,1) / obj.sample_rate < (5 + obj.window_samples/obj.sample_rate) 
                       old_print_message = 'Normalisation procedure not yet started';
                       disp(repmat(char(8),1,length(old_print_message)+2))
                    end
                    
                    % Find MVC value
                    obj.MaximumVoluntaryContraction(data_plot);                    
                    return
                    
                elseif sample_buffer(end,1) / double(obj.sample_rate) > 10
                    
                    % Remove old print message
                    if sample_buffer(end,1) / obj.sample_rate >= 10 && ...
                       sample_buffer(end,1) / obj.sample_rate < (10 + obj.window_samples/obj.sample_rate)                     
                        old_print_message = 'Maximally contract the muscle';
                        disp(repmat(char(8),1,length(old_print_message)+2))
                    end

                    % Find percentage of MVC
                    data_plot = data_plot ./ obj.norm_factor * 100;
                else
                    if sample_buffer(end,1) == 1
                        disp('Normalisation procedure not yet started')
                    end
                    return
                end
            end
            
            % Create a figure object, only during the first iteration
            if isempty(obj.figure_handle)
                obj.figure_handle = figure('Name', figurename);
                set(obj.figure_handle, 'CloseRequestFcn', @obj.closeRequestEvent);  
                set(obj.figure_handle, 'Units', 'Normalized', 'OuterPosition', [0, 0, 1, 1]);                
            end
            
            % Create a vector that ensures plotting is done appropriately
            UNI_locations = [];
            for i = 1:num_channels/8:num_channels, UNI_locations(end+1) = i; end
            for i = 2:num_channels/8:num_channels, UNI_locations(end+1) = i; end
            for i = 3:num_channels/8:num_channels, UNI_locations(end+1) = i; end
            for i = 4:num_channels/8:num_channels, UNI_locations(end+1) = i; end    
            if num_channels == 64
                for i = 5:num_channels/8:num_channels, UNI_locations(end+1) = i; end
                for i = 6:num_channels/8:num_channels, UNI_locations(end+1) = i; end
                for i = 7:num_channels/8:num_channels, UNI_locations(end+1) = i; end
                for i = 8:num_channels/8:num_channels, UNI_locations(end+1) = i; end
            end
            
            % Enter the values to be plotted in the grid. To fill the grid
            % properly, the UNI_locations file is used.
            grid_values(UNI_locations) = data_plot;
            obj.CreateGridEMG(grid_values, normalisation, connector_orientation)
            
            % Remove all the old graphical objects from the figure
            drawnow
        end       
               
        function hide(obj)
            %HIDE - Destroy the current figure object associated with this object.
            %
            %   hide(obj)
            %
            %   obj [in] - Visualisation object.
            %
            
            if ~obj.is_visible
                return;
            end
            
            delete(obj.figure_handle);
            obj.figure_handle = 0;
            
            obj.is_visible = false;
        end
    end
    
    methods(Access = private)               
       
        function CreateGridEMG(obj, grid_values, normalisation, connector_orientation)
            %CREATEGRIDEMG - Function that creates a heatmap plot with
            %   indicated electrode locations for the HD EMG application
            %
            %   CreateGridEMG(obj, grid_values, normalisation, connector_orientation)
            %
            %   obj [in] - Visualisation object.
            %   grid_values [in] - List of RMS values assigned to lay-out of the grid. 
            %   normalisation [in] - Boolean that determines whether normalisation should be done.
            %   connector_orientation [in] - Direction in which the HD EMG connnector points when observed from the 
            %       user's point of view.
            
            % Determine whether this is the first iteration of the plot
            if isempty(obj.surface_handle)
                % Create a logical that controls whether labels have to be
                % plotted
                plot_labels = true;
            else
                plot_labels = false;
            end
            
            % Settings used in making the plot.
            obj.chan_name = 0;
            interpolation_step = 0.2;
            
            % Number of columns and rows on the grid
            channel_columns = 8;
            num_channels = numel(obj.channels) - 3;
            channel_rows = num_channels / channel_columns;
            
            % Ensure that the grid points are visible by giving them a
            % larger value than the calculated RMS values of a data window
            channel_locs = ones(channel_rows, channel_columns) * 4000;
            
            % Values in grid
            x = 1:channel_columns; y = 1:channel_rows;
            [X, Y] = meshgrid(x, y);
            
            % Interpolation
            xq = 1:interpolation_step:channel_columns;
            yq = 1:interpolation_step:channel_rows;
            [Xq, Yq] = meshgrid(xq, yq);
            % Interpolate the data over the redefined grid
            Vq = interp2(X, Y, grid_values, Xq, Yq, 'linear');
            
            if plot_labels
                % Create the figure object
                set(gcf,'NumberTitle','off')
            end
            
            % Get the current axes and enable plotting of multiple
            % graphical objects
            h = gca;
            hold on
            
            % Delete the previous plotted heat map and channel locations
            delete(obj.surface_handle);
            delete(obj.plt_chans);
            delete(obj.plt_chans_nc);
                        
            % Create the surface plot and set the axis to reverse style
            % plotting
            obj.surface_handle = surf(Xq, Yq, Vq); obj.surface_handle.EdgeColor = 'none';
            
            % During the first iteration, plot the axis information next to
            % heat map
            if plot_labels
                axis ij
                xlabel('HD EMG Grid Columns'),ylabel('HD EMG Grid Rows')
                set(gca,'xticklabel',[]); set(gca,'yticklabel',[]);
                title({'Anterior view of the HD EMG grid in the frontal plane',' '})
                axis equal
                
                % List of plotted labels based on the orientation of the
                % connector (from an anterior view of the frontal plane)
                if strcmp(connector_orientation, 'up')
                    view(90,90)
                elseif strcmp(connector_orientation, 'down')
                    view(270,90)
                elseif strcmp(connector_orientation, 'right')
                    view(180,90)
                elseif strcmp(connector_orientation, 'left')
                    view(0,90)
                end
                
                % Create an equidistant grid, with set limits on the number of
                % rows and channels
                xlim([1 channel_columns]), ylim([1 channel_rows])
                
                % Set the colorbar settings
                c = colorbar;
                colormap jet
                c.FontSize = 12;
                
                if ~normalisation
                    % In microVolts
                    caxis([0 1000])
                    c.Label.String = 'Muscle activation (\muV)';
                else
                    % Percentage
                    caxis([0 100])
                    c.Label.String = 'Muscle activation (% of MVC)';
                end
                
                % If the channel names have to be plotted, print the text
                % per channel in the figure. All text is centered below the
                % plotted electrode marker.
                if obj.chan_name
                    r = 0; c = 1.25;
                    for ii = 1:num_channels
                        if mod(ii,8) == 1 
                            r = r+1; c = 1.25; 
                            txt_locs = text(c,r,2000,['UNI ' num2str(ii)],...
                                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                        else
                            c = c+1; 
                            txt_locs = text(c,r,2000,['UNI ' num2str(ii)],...
                                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');  
                        end
                    end
                else
                    % Always print the four electrodes on the corners of
                    % the grid so that the orientation of the plot is
                    % clear.
                    txt_locs = text(0.92, 0.9 ,2000, 'UNI 01',...
                                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                    txt_locs = text(8.12, 0.9, 2000, 'UNI 08',...
                                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                    if num_channels == 32
                        txt_locs = text(0.92, 4.1, 2000, 'UNI 25',...
                                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                        txt_locs = text(8.12, 4.1, 2000, 'UNI 32',...
                                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                    elseif num_channels == 64
                        txt_locs = text(0.92, 8.1, 2000, 'UNI 57',...
                                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                        txt_locs = text(8.12, 8.1, 2000, 'UNI 64',...
                                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                    end
                end
                
                % Set the font size
                set(gca,'FontSize',12)                
            end

            % Mark not connected channels so that this is clear to a user
            ind_not_connected = find(grid_values == 0);            
            obj.plt_chans_nc = plot3(X(ind_not_connected), Y(ind_not_connected), channel_locs(ind_not_connected),...
                'LineStyle', 'none', 'Marker', '.', 'MarkerSize', 20, 'Color', 'r');
            X(ind_not_connected) = []; Y(ind_not_connected) = []; 
            channel_locs(ind_not_connected) = [];
            
            % Plotting electrode locations
            obj.plt_chans = plot3(X, Y, channel_locs,...
                'LineStyle', 'none', 'Marker', '.', 'MarkerSize', 20, 'Color', 'k');            

            hold off
        end     
                
        function closeRequestEvent(obj, ~, ~)
            %CLOSEREQUESTEVENT - A callback function used to identify the quit event
            %
            %   closeRequestEvent(obj, ~, ~)
            %
            %   obj [in] - Visualisation object.
            %
            
            obj.hide();
        end
    end
end