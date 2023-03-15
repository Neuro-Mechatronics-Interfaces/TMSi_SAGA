classdef Playback < TMSiSAGA.HiddenHandle
    %PLAYBACK  Playback "wrapper" class for TMSi recordings.
    %
    % Syntax:
    %   device = Playback(fname);
    %   device = Playback(fname, 'Name', value, ...);
    %
    % Example 1:
    %   device = TMSiSAGA.Playback('test.poly5');
    % 
    % Example 2:
    %   device = TMSiSAGA.Playback(["test_A.poly5"; "test_B.poly5"]);
    %
    % Example 3:
    %   device = TMSiSAGA.Playback(["test_A.mat"; "test_B.mat"], ...
    %                              'max_buffer_samples', 16000);
    %
    % Inputs:
    %   fname - char array or string, or array of strings or cell array of
    %               char arrays. This corresponds to either .poly5 files 
    %               or .mat files, which automatically determine the
    %               'Type' property for this object. The returned `device`
    %               is of the same dimensions as the input array.
    %   varargin - (Optional) 'Name', value input argument pairs,
    %               corresponding to publically settable properties of this
    %               class.
    %
    % Output:
    %   device - Scalar or array of TMSiSAGA.Playback objects, which should
    %               accept most of the same methods as TMSiSAGA.Device
    %               objects without causing errors and don't need a SAGA
    %               device hooked up to your machine to try and get code
    %               working for example.
    %
    % Note: This utility was developed by Max Murphy at the NML (Carnegie
    %   Mellon University; 2022). Code re-use is welcome, just please 
    %   this acknowledgment somewhere in the documentation. Thank you.
    %
    % See also: Contents, TMSiSAGA.Device, TMSiSAGA.Poly5, io.load_tmsi

    properties
        name (1,1) string
        fname (1,1) string
        channels
        tag (1,1) string = "X"
        is_connected (1,1) logical = false;
        is_sampling (1,1) logical = false;
        is_recording (1,1) logical = false;
        verbose (1,1) logical = true;
    end

    properties (Hidden)
        cur_index (1,1) double = 1;
        index_step_size (1,1) double
    end

    properties (GetAccess = public, SetAccess = protected)
        sample_rate (1,1) double = 4000.0;
    end

    properties (Access = protected)
        impedance_mode (1,1) logical = false;
        type
        samples
        serial_number (1,1) double = 42;
        timer
        max_buffer_samples (1,1) double = 8000
        queue_update_rate (1,1) double = 250; % Hz
        num_samples
    end

    methods
        function self = Playback(fname,varargin)
            %PLAYBACK Construct an instance of this class
            %
            % Syntax:
            %   device = Playback(fname);
            %   device = Playback(fname, 'Name', value, ...);
            %
            % Example 1:
            %   device = TMSiSAGA.Playback('test.poly5');
            % 
            % Example 2:
            %   device = TMSiSAGA.Playback(["test_A.poly5"; "test_B.poly5"]);
            %
            % Example 3:
            %   device = TMSiSAGA.Playback(["test_A.mat"; "test_B.mat"], ...
            %                              'Max_Buffer_Samples', 16000);
            %
            % Inputs:
            %   fname - char array or string, or array of strings or cell array of
            %               char arrays. This corresponds to either .poly5 files 
            %               or .mat files, which automatically determine the
            %               'Type' property for this object. The returned `device`
            %               is of the same dimensions as the input array.
            %   varargin - (Optional) 'Name', value input argument pairs,
            %               corresponding to publically settable properties of this
            %               class.
            %
            % Output:
            %   device - Scalar or array of TMSiSAGA.Playback objects, which should
            %               accept most of the same methods as TMSiSAGA.Device
            %               objects without causing errors and don't need a SAGA
            %               device hooked up to your machine to try and get code
            %               working for example.
            %
            % Note: This utility was developed by Max Murphy at the NML (Carnegie
            %   Mellon University; 2022). Code re-use is welcome, just please 
            %   this acknowledgment somewhere in the documentation. Thank you.
            %
            % See also: Contents, TMSiSAGA.Device, TMSiSAGA.Poly5, io.load_tmsi
            fname = string(fname);
            if numel(fname) > 1
                self = repmat(self, size(fname));
                for ii = 1:numel(self)
                    self(ii) = TMSiSAGA.Playback(fname(ii), varargin{:});
                end
                return;
            end
            for iV = 1:2:numel(varargin)
                self.(varargin{iV}) = varargin{iV+1};
            end
            self.fname = fname;
            [p,f,e] = fileparts(fname);
            if isempty(e)
                expr = fullfile(p, strcat(f, '*'));
                F = dir(expr);
                if isempty(F)
                    error("[TMSiSAGA]::[Playback]\tNo files matched expression: %s", expr);
                end
                if F(1).isdir
                    e = ".poly5";
                    f = fullfile(f, F(1).name);
                else
                    e = ".mat";
                end
            end
            self.type = e;
            switch e
                case ".poly5"
                    self.name = fullfile(p, strcat(f, e));
                    x = TMSiSAGA.Poly5.read(self.name);
                    self.num_samples = x.num_samples;
                    self.samples = x.samples;
                    self.channels = vertcat(x.channels{:});
                    self.sample_rate = x.sample_rate;
                    self.num_samples = x.num_samples;
                case ".mat"
                    self.name = string(fullfile(p, strcat(f, e)));
                    x = load(self.name);
                    self.num_samples = size(x.samples, 2);
                    self.samples = x.samples;
                    if ~isfield(x, 'sample_rate')
                        self.sample_rate = 4000;
                    else
                        self.sample_rate = x.sample_rate;
                    end
                    self.channels = vertcat(x.channels{:});
                otherwise
                    error("[TMSiSAGA]::[Playback]\tUnsupported format: %s (should be '.mat' or '.poly5')", e);
            end
            finfo = strsplit(f, '_');
            if numel(finfo) >= 6
                self.tag = string(finfo{5});
            end

            self.index_step_size = round(self.sample_rate/self.queue_update_rate);
            T = 1/self.queue_update_rate;
            self.timer = timer(...
                'ExecutionMode', 'singleShot', ...
                'BusyMode', 'queue', ...
                'StartDelay', T, ...
                'UserData', struct('sample_queue', [], 'cur_index', self.cur_index), ...
                'TimerFcn', @self.connected_timer_cb, ...
                'Tag', sprintf('TMSiSAGA.Playback.%s.timer', self.tag));
            self.is_connected = true;
        end

        function load_new(self, fname)
            %LOAD_NEW  Load new file for the playback device.
            if numel(self) > 1
                for ii = 1:numel(self)
                    if nargin < 2
                        self(ii).load_new();
                    else
                        self(ii).load_new(fname(ii));
                    end
                end
                return;
            end
            if nargin < 2
                fname = self.fname;
            end
            [p,f,e] = fileparts(fname);
            if isempty(e)
                expr = fullfile(p, strcat(f, '*'));
                F = dir(expr);
                if isempty(F)
                    error("[TMSiSAGA]::[Playback]\tNo files matched expression: %s", expr);
                end
                if F(1).isdir
                    e = ".poly5";
                    f = fullfile(f, F(1).name);
                else
                    e = ".mat";
                end
            end
            self.type = e;
            switch e
                case ".poly5"
                    self.name = fullfile(p, strcat(f, e));
                    x = TMSiSAGA.Poly5.read(self.name);
                    self.num_samples = x.num_samples;
                    self.samples = x.samples;
                    self.channels = vertcat(x.channels{:});
                    self.sample_rate = x.sample_rate;
                    self.num_samples = x.num_samples;
                case ".mat"
                    self.name = string(fullfile(p, strcat(f, e)));
                    x = load(self.name);
                    self.num_samples = size(x.samples, 2);
                    self.samples = x.samples;
                    if ~isfield(x, 'sample_rate')
                        self.sample_rate = 4000;
                    else
                        self.sample_rate = x.sample_rate;
                    end
                    self.channels = vertcat(x.channels{:});
                otherwise
                    error("[TMSiSAGA]::[Playback]\tUnsupported format: %s (should be '.mat' or '.poly5')", e);
            end
            finfo = strsplit(f, '_');
            if numel(finfo) >= 6
                self.tag = string(finfo{5});
            end
        end

        function delete(self)
            for ii = 1:numel(self)
                try %#ok<TRYNC> 
                    delete(self(ii).timer);
                end
            end
        end

        function connect(self)
            %CONNECT  Emulates `Device` object `connect` -- sets TimerFcn
            if numel(self) > 1
                for ii = 1:numel(self)
                    connect(self(ii));
                end
                return;
            end
            if self.is_connected
                if self.verbose
                    fprintf(1,'[TMSiSAGA]::[Playback]\tTMSiSAGA.Playback-%s is already connected.\n', self.tag);
                end
                return;
            end
            self.load_new(self.fname);
            T = 1/self.queue_update_rate;
            self.timer.Period = T;
            self.timer.TimerFcn = @self.connected_timer_cb;
            self.is_connected = true;
            if self.verbose
                fprintf(1,'[TMSiSAGA]::[Playback]\tConnected to TMSiSAGA.Playback-%s (%s)\n', self.tag, self.name);
            end

        end

        function disconnect(self)
            %DISCONNECT Does mostly nothing, just to emulate `Device` object
            if numel(self) > 1
                for ii = 1:numel(self)
                    disconnect(self(ii));
                end
                return;
            end
            self.timer.Period = 1;
            self.timer.TimerFcn = @self.disconnected_timer_cb;
            self.is_connected = false;
            if self.verbose
                fprintf(1,'[TMSiSAGA]::[Playback]\tDisconnected from TMSiSAGA.Playback-%s (%s)\n', self.tag, self.name);
            end

        end

        function [data, num_sets, data_type] = sample(self)
            %SAMPLE - Retrieves samples from the device and does some basic processing.
            %
            %   [data, num_sets, data_type] = sample(self)
            %
            %   Retrieves samples from the device and does some basic processing on them. The
            %   returned samples are in double format, but have been converted from float, int32
            %   or other types. 
            %
            %   data [out] - Transformed data retrieved from the device.
            %   num_sets [out] - Number of samples per channel present in
            %       data block
            %   data_type [out] - Type of data:
            %       (1 - Sample data, 2 - Impedance data)
            %   self [in] - TMSiSAGA.Playback object.
            %
            %   Can be called when:
            %   - Device is connected.
            %   - Device is sampling.
            if numel(self) > 1
                data = cell(size(self));
                num_sets = nan(size(self));
                data_type = nan(size(self));
                for ii = 1:numel(self)
                    [data{ii}, num_sets(ii), data_type(ii)] = sample(self(ii));
                end
                return;
            end

            num_sets = numel(self.timer.UserData.sample_queue);
            data = self.samples(:, self.timer.UserData.sample_queue);
            self.timer.UserData.sample_queue = [];
            if self.impedance_mode
                data_type = 2;
            else
                data_type = 1;
            end
        end

        function start(self)
            %START  Starts the timer callback which loops dumping samples into the queue from which they are then drawn with the "sample" method.
            for ii = 1:numel(self)
                start(self(ii).timer);
                self(ii).is_sampling = true;
                if self(ii).verbose
                    fprintf(1,'[TMSiSAGA]::[Playback]\tStarted TMSi.Playback-%s (%s)\n', self(ii).tag, self(ii).name);
                end
            end
        end

        function stop(self)
            %START  Stop the timer dumping samples into the sampling queue.
            for ii = 1:numel(self)
                stop(self(ii).timer);
                self(ii).is_sampling = false;
                self(ii).is_recording = false;
                if self(ii).verbose
                    fprintf(1,'[TMSiSAGA]::[Playback]\tStopped TMSi.Playback-%s (%s)\n', self(ii).tag, self(ii).name);
                end
            end
        end

        function setDeviceTag(self, SN, TAG)
            %SETDEVICETAG  Set the serial_number and tag properties
            TAG = string(TAG);
            if numel(TAG) > 1
                for ii = numel(TAG)
                    self(ii).setDeviceTag(SN(ii), TAG(ii));
                end
                return;
            end
            self.serial_number = SN;
            self.tag = TAG;
        end

        function info = getDeviceInfo(self)
            %GETDEVICEINFO  Returns information about device
            if numel(self) > 1
                info = cell(size(self));
                for ii = 1:numel(self)
                    info{ii} = getDeviceInfo(self(ii));
                end
                return;
            end
            info = struct(...
                'serial_number',self.serial_number, ...
                'channels', self.channels, ...
                'tag', self.tag, ...
                'sample_mode', 'dummy', ...
                'sample_rate', self.sample_rate, ...
                'num_samples', self.num_samples, ...
                'max_buffer_samples', self.max_buffer_samples);
        end

        function channels = getActiveChannels(self)
            %GETACTIVECHANNELS - Get a cell array of active channels.
            %
            %   channels = getActiveChannels(self)
            %
            %   This function will return a cell array of Channels object of all channels that
            %   are active. A channel is active when the divider of the channel does not equal
            %   -1. When impedance mode is on it will return all channels that are active in
            %   impedance mode.
            %
            %   channels [out] - Cell array with all active channels
            %   obj [in] - Device object.
            %
            if numel(self) > 1
                channels = cell(size(self));
                for ii = 1:numel(self)
                    channels{ii} = getActiveChannels(self(ii));
                end
                return;
            end
            channels = self.channels(isActive(self.channels, self.impedance_mode));
        end

        function enableChannels(self, channels)
            %ENABLECHANNELS  Enable channels (either as config struct or as logical array)
            for ij = 1:numel(self)
                for ii=1:numel(channels)
                    if isa(channels, 'double')
                        self.channels(channels(ii)).enable();
                    elseif isa(channels, 'logical')
                        if channels(ii)
                            self.channels(ii).enable();
                        end
                    else
                        idx = self.channels == channels(ii);
                        self.channels(idx).enable();
                    end
                end
            end
        end

        function updateDeviceConfig(self)
            %UPDATEDEVICECONFIG  This literally does nothing
            for ii = 1:numel(self)
                if self(ii).verbose
                    fprintf(1,'[TMSiSAGA]::[Playback]\tUpdated config for TMSiSAGA.Playback-%s (%s)\n', self(ii).tag, self(ii).name);
                end
            end
        end

        function setChannelConfig(self, ~)
            %SETCHANNELCONFIG  Does nothing, just for `Device` compatibility
            for ii = 1:numel(self)
                if self(ii).verbose
                    fprintf(1,'[TMSiSAGA]::[Playback]\tSet channel configs for TMSiSAGA.Playback-%s (%s)\n', self(ii).tag, self(ii).name);
                end
            end
        end

        function setDeviceConfig(self, config)
            %SETDEVICECONFIG  Does nearly nothing, just for `Device` compatibility
            if isscalar(config)
                config = repmat(config,size(self));
            end
            for ii = 1:numel(self)
                % Set the ImpedanceMode
                if isfield(config(ii), 'ImpedanceMode')
                    if ~isa(config(ii).ImpedanceMode,'logical')
                        throw(MException('Device:SetImpedanceMode', 'ImpedanceMode argument type should be a boolean.'));
                    end
                    
                    self(ii).impedance_mode = config(ii).ImpedanceMode;
                end
                if self(ii).verbose
                    fprintf(1,'[TMSiSAGA]::[Playback]\tSet device configs for TMSiSAGA.Playback-%s (%s)\n', self(ii).tag, self(ii).name);
                end
            end
        end
    end

    methods (Hidden,Access=public)
        function disconnected_timer_cb(self, ~, ~)
            %DISCONNECTED_TIMER_CB  Callback for TimerFcn when "disconnected."
            fprintf(1,"[TMSiSAGA]::[Playback]\tTMSiSAGA.Playback.%s :: Sampling but not connected?", self.tag);
        end

        function connected_timer_cb(self,src,~)
            %CONNECTED_TIMER_CB  Callback for TimerFcn when "connected" (actually core running the playback class).
            stop(src);
            next_samples = mod((src.UserData.cur_index:(src.UserData.cur_index+self.index_step_size-1))-1, self.num_samples)+1;
            src.UserData.sample_queue = horzcat(src.UserData.sample_queue, next_samples);
            if numel(src.UserData.sample_queue) > self.max_buffer_samples
                src.UserData.sample_queue = src.UserData.sample_queue((end-(self.max_buffer_samples+1)):end);
            end
            src.UserData.cur_index = mod(src.UserData.cur_index+self.index_step_size-1, self.num_samples)+1;
            start(src);
        end
    end
end