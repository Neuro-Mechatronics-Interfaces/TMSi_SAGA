classdef Visualisation < TMSiSAGA.HiddenHandle
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
        % Name of the figure handle
        name
        
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
        X
        Y
        Xq
        Yq
        
        % Conditions filter delay (high-pass)
        z_h
        
        % Filter coefficients (high-pass)
        b_high
        
        % Filter coefficients (high-pass)
        a_high
        
        % Connector orientation
        connector_orientation
        
        % Do normalisation?
        normalisation
        
        % Vector containing the normalisation constants in the EMG signal
        norm_factor
        
        % Channel name display for the HD EMG grid
        chan_name
        
        % Handle to the figure of the HD EMG grid
        figure_handle
        
        % Handle to the axes that goes in figure
        axes_handle
        
        % Handle to the plot of the HD EMG grid
        surface_handle = []
        
        % Handle to plotted channel locations
        plt_chans = []
        
        % Handle to plotted channel locations that are not connected
        plt_chans_nc = []
    end
    
    methods
        function obj = Visualisation(fig, sample_rate, channels, window_samples, normalisation, connector_orientation)
            %VISUALISATION - Constructor for the Visualisation object
            %
            %   obj = Visualisation(sample_rate, channels, window_samples)
            %
            %   obj [out] - Visualisation object.
            %   sample_rate [in] - Sample rate of the device.
            %   channels [in] - Activated channels. 
            %   window_samples [in] - Number of samples that are processed in a data window.
            %   normalisation [in] - 0 (no normalization) or 1 (normalize)
            %   connector_orientation [in] - 'up' | 'left' | 'down' | 'right'
            %
            if numel(fig) > 1
                obj = repmat(obj, size(fig));
                for ii = 1:numel(fig)
                    obj(ii) = TMSiSAGA.Visualisation(fig(ii), ...
                        sample_rate(ii), ...
                        channels(ii), ...
                        window_samples(ii), ...
                        normalisation(ii), ...
                        connector_orientation{ii}); 
                end
                return;
            end
            obj.sample_rate = double(sample_rate);
            obj.channels = channels;
            obj.window_samples = double(window_samples);
            obj.normalisation = normalisation;
            obj.connector_orientation = connector_orientation;
            obj.norm_factor = ones(numel(obj.channels)-3, 1);
            obj.chan_name = 0;
            obj.figure_handle = fig;
            set(obj.figure_handle, 'NumberTitle', 'off');
            obj.name = get(fig, 'Name');
            obj.axes_handle = axes(obj.figure_handle, ...
                'NextPlot', 'add', 'YDir', 'reverse', ...
                'FontSize', 12, 'FontName', 'Tahoma', ...
                'XLim', [1 8], 'YLim', [1 8]);
            xlabel(obj.axes_handle, 'HD EMG Grid Columns');
            ylabel(obj.axes_handle, 'HD EMG Grid Rows')
            title(obj.axes_handle, {'Anterior view of the HD EMG grid in the frontal plane',' '})
            obj.is_visible = true;
            set(obj.figure_handle, 'CloseRequestFcn', @obj.figure_closed_cb); 
            % Set the colorbar settings
            c = colorbar(obj.axes_handle);
            colormap(obj.axes_handle,'jet');
            c.FontSize = 12;
            c.FontName = 'Tahoma';

            if ~obj.normalisation
                % In microVolts
                caxis([0 1000])
                c.Label.String = 'Muscle activation (\muV)';
            else
                % Percentage
                caxis([0 100])
                c.Label.String = 'Muscle activation (% of MVC)';
            end
            
            % % % Create graphics objects % % %
            % Values in grid
            [obj.X, obj.Y] = meshgrid(1:8, 1:8);
            channel_locs = ones(8, 8) .* 4000;
            
            % Settings used in making the plot.
            interpolation_step = 0.2;  % With respect to grid spacing for channels
            
            % Interpolation
            xq = 1:interpolation_step:8;
            yq = 1:interpolation_step:8;
            [obj.Xq, obj.Yq] = meshgrid(xq, yq);
            Vq = nan(size(obj.Xq));
            
            obj.surface_handle = surf(obj.axes_handle, obj.Xq, obj.Yq, Vq);
            obj.surface_handle.EdgeColor = 'none';
            
            % Ensure that the grid points are visible by giving them a
            % larger value than the calculated RMS values of a data window
            obj.add_labels(obj.axes_handle, false, obj.connector_orientation);
            obj.plt_chans_nc = scatter3(obj.axes_handle, ...
                obj.X(:), obj.Y(:), channel_locs(:), ...
                'MarkerEdgeColor', 'r', ...
                'MarkerFaceColor', 'r', ...
                'SizeData', ones(1, 64).*20, ...
                'Marker', 'x', ...
                'AlphaDataMapping', 'direct', ...
                'AlphaData', ones(1, 64));
            obj.plt_chans = scatter3(obj.axes_handle, ...
                obj.X(:), obj.Y(:), channel_locs(:), ...
                'MarkerEdgeColor', 'k', ...
                'MarkerFaceColor', 'k', ...
                'SizeData', ones(1, 64).*20, ...
                'Marker', '.', ...
                'AlphaDataMapping', 'direct', ...
                'AlphaData', zeros(1, 64)); 
        end
        
        function tf = visible(obj)
             tf = all([obj.is_visible]);
        end
        
        function delete(obj)
           %DELETE - Overload delete to ensure figure destruction
           try
               delete(obj.figure_handle)
           catch
               disp('Figure handle already deleted.'); 
           end
        end
        
        function figure_closed_cb(obj, src, ~)
            try
                obj.is_visible = false;
                set(src, 'CloseRequestFcn', closereq);
                close(src);
                fprintf('%s closed.\n', obj.name);
            catch
                try
                    fprintf('%s closed.\n', obj.name);
                catch
                    disp('Closed data visualization.'); 
                end
            end
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
        
        function EMG_Visualisation(obj, sample_buffer, data_plot)
            %EMG_VISUALISATION - Function that enables Real Time plotting of an HD EMG grid.
            %
            %   obj [in] - Visualisation object.
            %   sample_buffer [in] - A buffer with unprocessed sampled data.
            %   data_plot [in] - Array with RMS values to be plotted.
            
            grid_values = zeros(8, 8);             
            
            % If normalisation of the data is done, check whether MVC is
            % already set or if it has to be initialised
            if obj.normalisation
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
            
            % Do the same thing but without arbitrarily complicated code:
            UNI_locations = reshape(1:64, 8, 8);
            UNI_locations = (UNI_locations(:))';
            
            
            % Enter the values to be plotted in the grid. To fill the grid
            % properly, the UNI_locations file is used.
            grid_values(UNI_locations) = data_plot;
            obj.CreateGridEMG(grid_values)
            
            % Remove all the old graphical objects from the figure
            drawnow;
        end       
               
        function hide(obj)
            %HIDE - Destroy the current figure object associated with this object.
            %
            %   hide(obj)
            %
            %   obj [in] - Visualisation object.
            try
                obj.is_visible = false;
                set(src, 'CloseRequestFcn', closereq);
                close(src);
            catch
                disp('Impedance plot closed.');
            end
        end
    end
    
    methods(Access = private)               
       
        function CreateGridEMG(obj, grid_values)
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

            % Interpolate the data over the redefined grid
            Vq = interp2(obj.X, obj.Y, grid_values, obj.Xq, obj.Yq, 'linear');
        
            % Update data on the surface plot
            set(obj.surface_handle, 'ZData', Vq, 'CData', Vq);

            % Mark not connected channels so that this is clear to a user
            is_connected = abs(grid_values) ~= 0;

            % Plotting connected and non-connected electrode locations
            set(obj.plt_chans_nc, 'AlphaData', double(~is_connected(:)));
            set(obj.plt_chans, 'AlphaData', double(is_connected(:)));
            drawnow;
        end     
    end
    
    methods (Static, Access=protected)
        function add_labels(ax, add_names, connector_orientation)
           % List of plotted labels based on the orientation of the
            % connector (from an anterior view of the frontal plane)
            if strcmp(connector_orientation, 'up')
                view(ax, 90,90)
            elseif strcmp(connector_orientation, 'down')
                view(ax, 270,90)
            elseif strcmp(connector_orientation, 'right')
                view(ax, 180,90)
            elseif strcmp(connector_orientation, 'left')
                view(ax, 0,90)
            end

            % If the channel names have to be plotted, print the text
            % per channel in the figure. All text is centered below the
            % plotted electrode marker.
            if add_names
                r = 0; c = 1.25;
                for ii = 1:64
                    if mod(ii,8) == 1 
                        r = r+1; c = 1.25; 
                        text(ax, c,r,2000,['UNI ' num2str(ii)],...
                            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                    else
                        c = c+1; 
                        text(ax, c,r,2000,['UNI ' num2str(ii)],...
                            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');  
                    end
                end
            else
                % Always print the four electrodes on the corners of
                % the grid so that the orientation of the plot is
                % clear.
                text(ax, 0.92, 0.9 ,2000, 'UNI 01',...
                            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                text(ax, 8.12, 0.9, 2000, 'UNI 08',...
                            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                text(ax, 0.92, 8.1, 2000, 'UNI 57',...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                text(ax, 8.12, 8.1, 2000, 'UNI 64',...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');

            end            
        end
    end
end