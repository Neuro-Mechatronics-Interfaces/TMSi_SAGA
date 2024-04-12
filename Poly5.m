classdef Poly5 < TMSiSAGA.HiddenHandle
    %POLY5 Class can read/write/stream Poly5 (Polybench) files.
    %
    %	When appending data to a Poly5 file, make sure the function close is called. This will
    %	ensure that data that was written is committed to the disk and not cached somewhere
    %	by the Operating System.
    %
    %	Reading or writing with help of the static function returns or requires a TMSi.Data object.
    %
    %POLY5 Properties:
    %	name - Name of the measurement.
    %	filepath - File name at which data is stored.
    %	sample_rate - The sample rate at which the data is stored.
    %	channels - The channels stored (cell array of structs with atleast .type, .alternative_name and .unit_name).
    %	num_samples - The number of samples that should have been stored to disk.
    %	is_open - A boolean whether or not the file is opened and can be streamed to.
    %	date - The date of creation of object.
    %
    %POLY5 Methods:
    %	Poly5 - Constructor for object that allows streaming of data to file.
    %	append - Append samples to file.
    %	close - Close file.
    %	STATIC read - Read Poly5 and store it as a TMSiSAGA.Data object.
    %	STATIC write - Write a Data object to a Poly5 file.
    %
    %POLY5 Example 1:
    %	dataObject = TMSi.Poly5.read('filename.Poly5');
    %
    %POLY5 Example 2:
    %	TMSi.Poly5.write('filename.Poly5', dataObject);
    %
    %POLY5 Example 3:
    %   device = library.getFirstAvailableDevice('network', 'electrical');
    %
    %   device.connect();
    %   device.setDeviceConfig();
    %
    %   poly5 = TMSiSAGA.Poly5('Example', device.sample_rate, device.getActiveChannels());
    %
    %   device.start();
    %
    %   for i=1:10
    %       samples = device.sample();
    %       poly5.append(samples);
    %   end
    %
    %   device.stop();
    %   device.disconnect();
    %
    %   poly5.close();
    
    properties
        % File name at which data is stored.
        filepath
        folder
        name

        % Header information about the file
        header
        
        % The offset position in the file where channel descriptions start
        channels_offset

        % The offset position in the file where data actually starts
        data_offset
        
        % The sample rate at which the data is stored.
        sample_rate
        
        % The channels stored (cell array of structs with atleast .name and .unit_name).
        %	channels{i}.name - Name of channel.
        %	channels{i}.unit_name - Unit of channel (e.g. uV).
        channels
        num_channels % The number of actual channels
        
        % The number of samples that should have been stored to disk.
        num_samples
        
        % A boolean whether or not the file is opened and can be streamed to.
        is_open

        % A boolean whether or not the file is writable
        is_write_mode
        
        % The date of creation of object.
        date
        
        % The counter channel
        counter_channel
        
        % The digstat channel
        digstat_channel

        % The current block from sequential reading
        current_block = 1
    end
    
    properties(Access = private)
        % Handle to file.
        handle
        
        % A internal buffer used for samples.
        samples
        
        % Samples per block
        num_samples_per_block
    end
    
    methods
        function obj = Poly5(filepath, sample_rate, channels, permission)
            %POLY5 - Constructor for object that allows streaming of data to file.
            %
            %   obj = Poly5(filepath, name, sample_rate, channels)
            %
            %   obj [out] - Poly5 object.
            %   filepath [in] - Path to the Poly5 file.
            %   sample_rate [in] - Sample rate used to sample the data.
            %   channels [in] - Channels that are present in the Poly5 file.
            %   permission [in] - File access type of Poly5 file.

            if nargin < 4
                permission = 'a';
            else
                permission = char(permission);
                permission = permission(1);
            end

            filepath = string(filepath);
            if numel(filepath) > 1
                obj = repmat(obj, size(filepath));
                for ii = 1:numel(filepath)
                    obj(ii) = TMSiSAGA.Poly5(filepath(ii), sample_rate(ii), channels{ii});
                    pause(1);
                end
                return;
            end
            obj.filepath = filepath;
            [obj.folder, obj.name, ~] = fileparts(obj.filepath);
            if exist(obj.folder, 'dir') == 0
                mkdir(obj.folder);
            end
            obj.sample_rate = sample_rate;
            obj.num_samples = 0;
            obj.date = clock; %#ok<CLOCK>
            if isempty(channels) && ~strcmpi(permission, 'r')
                throw(MException('Poly5:Poly5', 'Channels must be specified if opening file for writing!'));
            end
            obj.channels = channels;
            obj.samples = zeros(numel(channels), 0);
            obj.num_samples_per_block = floor(2^13 / numel(channels));
            % Keep track of the STATUS and COUNTER channels
            for i=1:numel(obj.channels)
                if obj.channels(i).type == TMSiSAGA.TMSiUtils.toChannelTypeNumber('digstat')
                    obj.digstat_channel = i;
                end
                
                if obj.channels(i).type == TMSiSAGA.TMSiUtils.toChannelTypeNumber('counter')
                    obj.counter_channel = i;
                end
            end

            % Open a handle to the Poly5 file
            if (exist(filepath,"file")==0)||strcmpi(permission,'w')
                obj.handle = fopen(filepath, permission, 'n', 'UTF-8');
                if obj.handle == -1
                    throw(MException('Poly5:Poly5', sprintf('Could not open file (%s).', filepath)));
                end
                
                % Write the header and channel descriptions in the Poly5 file
                obj.channels_offset = TMSiSAGA.Poly5.writeHeader(obj.handle, obj, obj.num_samples_per_block);
                obj.data_offset = TMSiSAGA.Poly5.writeChannelDescriptions(obj.handle, obj);
                obj.is_write_mode = true;
            else
                obj.is_write_mode = ~strcmpi(permission, 'r');
                if ~obj.is_write_mode
                    permission = [permission, '+'];
                end
                obj.handle = fopen(filepath, permission, 'n', 'UTF-8');
                if obj.handle == -1
                    throw(MException('Poly5:Poly5', sprintf('Could not open file (%s).', filepath)));
                end
                % ===========================================
                %	HEADER
                % ===========================================
                [obj.header, obj.channels_offset] = TMSiSAGA.Poly5.readHeader(obj.handle);
    
                % ===========================================
                %	SIGNAL DESCRIPTION
                % ===========================================
                [obj.channels, obj.data_offset] = TMSiSAGA.Poly5.readChannelDescriptions(obj.handle, obj.header.num_channels);
                obj.num_channels = numel(obj.channels);
                obj.samples = zeros(obj.num_channels, 0);
                obj.num_samples_per_block = floor(2^13 / obj.num_channels);
            end
            obj.is_open = true;
        end
        
        function append(obj, samples)
            %APPEND - Append samples to file.
            %
            %   append(obj, samples)
            %
            %   obj [in] - Poly5 object.
            %	samples [in] - Samples as a num_channels x num_samples.
            %
            
            if numel(obj) > 1
                for ii = 1:numel(obj)
                    append(obj(ii), samples{ii});
                end
                return;
            end
            
            if size(samples, 2) == 0
                return;
            end
            
            if (~obj.is_open) || (~obj.is_write_mode)
                throw(MException('Poly5:append', 'Cannot append to this file'));
            end
            
            if numel(obj.channels) ~= size(samples, 1)
                throw(MException('Poly5:append', 'Unequal number of channels.'));
            end
            
            % Create a buffer that keeps the not yet written samples, and append the current samples to it
            obj.samples(:, size(obj.samples, 2) + size(samples, 2)) = 0;
            obj.samples(:, end-size(samples, 2) + 1:end) = samples;
            
            % Cycle the counter channel
            obj.samples(obj.counter_channel, :) = mod(obj.samples(obj.counter_channel, :), 2^23);
            
            % Write the samples in max blocks of max_samples_per_block
            while size(obj.samples, 2) >= obj.num_samples_per_block
                fseek(obj.handle, 0, 'eof');
                TMSiSAGA.Poly5.writeDataBlock(obj.handle, obj.num_samples_per_block, obj.num_samples / obj.num_samples_per_block, obj.samples(:, 1:obj.num_samples_per_block));
                
                obj.num_samples = obj.num_samples + obj.num_samples_per_block;
                fseek(obj.handle, 0, 'bof');
                TMSiSAGA.Poly5.writeHeader(obj.handle, obj, obj.num_samples_per_block);
                
                obj.samples = obj.samples(:, obj.num_samples_per_block+1:end);
            end
        end
        
        function close(obj)
            %CLOSE - Close the file and commit data to disk.
            %
            %   close(obj)
            %
            %   obj [in] - Poly5 object.
            %
            
            if numel(obj) > 1
                for ii = 1:numel(obj)
                    close(obj(ii));
                end
                return;
            end
            
            if ~obj.is_open
                return;
            end
            
            fclose(obj.handle);
            
            obj.is_open = false;
        end
        
        function delete(obj)
            try %#ok<TRYNC> 
                fclose(obj.handle);
            end
        end
        
        function prepare_for_writing(obj)
            if obj.is_open
                fclose(obj.handle);
            end
            obj.is_open = false;
            
            % Open a handle to the Poly5 file
            obj.handle = fopen(obj.filepath, 'a+', 'n', 'UTF-8');
            if obj.handle == -1
                throw(MException('Poly5:Poly5', sprintf('Could not open file (%s).', obj.filepath)));
            end
            obj.header = TMSiSAGA.Poly5.readHeader(obj.handle);
            obj.channels = TMSiSAGA.Poly5.readChannelDescriptions(obj.handle, obj.header.num_channels);
            obj.num_channels = numel(obj.channels);
            obj.samples = zeros(obj.num_channels, 0);
            obj.num_samples_per_block = floor(2^13 / obj.num_channels);
            obj.data_offset = ftell(obj.handle);
            obj.is_open = true;
            obj.is_write_mode = true;
            
        end

        function prepare_for_reading(obj)
            if obj.is_open
                fclose(obj.handle);
            end
            obj.is_open = false;
            
            % Open a handle to the Poly5 file
            obj.handle = fopen(obj.filepath, 'r', 'n', 'UTF-8');
            if obj.handle == -1
                throw(MException('Poly5:Poly5', sprintf('Could not open file (%s).', obj.filepath)));
            end
            obj.is_open = true;
            obj.is_write_mode = false;
            obj.current_block = 1;

            % ===========================================
            %	HEADER
            % ===========================================
            obj.header = TMSiSAGA.Poly5.readHeader(obj.handle);

            % ===========================================
            %	SIGNAL DESCRIPTION
            % ===========================================
            obj.channels = TMSiSAGA.Poly5.readChannelDescriptions(obj.handle, obj.header.num_channels);
            obj.num_channels = numel(obj.channels);
            obj.samples = zeros(obj.num_channels, 0);
            obj.num_samples_per_block = floor(2^13 / obj.num_channels);
            obj.data_offset = ftell(obj.handle);
        end

        function samples = read_next_n_blocks(obj, n)
            %READ_NEXT_N_BLOCKS  Read the next `n` data blocks and return `n` samples. Loops back to first samples if reaching end of file.
            %
            % Syntax:
            %   samples = read_next_n_blocks(obj, n);
            %
            % Example:
            %   % Open Poly5 file for reading:
            %   poly5 = TMSiSAGA.Poly5('MyData.poly5', sample_rate, channels, 'r');
            %   % Estimate how long to pause between each read iteration:
            %   sample_delay = max(poly5.header.num_samples_per_block*2/poly5.header.sample_rate-0.010, 0.030);
            %   % Create a GUI that lets you break the loop if needed:
            %   fig = figure('Color','w','Name','Sample Reader Interface');
            %   offset = 25; % microns
            %   ax = axes(fig,'NextPlot','add','YLim',[-0.5*offset, 63.5*offset]);
            %   title(ax, "MyData.poly5: UNI");
            %   h = gobjects(64,1);
            %   for iH = 1:64
            %       h(iH) = line(ax,1:poly5.header.sample_rate,nan(1,poly5.header.sample_rate));
            %   end
            %   past_samples = zeros(64,1);
            %   while isvalid(fig)
            %       samples = read_next_n_blocks(poly5, 2);
            %       iVec = rem(samples(end,:)-1,poly5.header.sample_rate)+1;
            %       plot_data = [past_samples, samples(2:65,:)];
            %       diff_data = plot_data(:,2:end) -plot_data(:,1:(end-1));
            %       for iH = 1:64
            %           h(iH).YData(iVec) = samples(iH+1,:)+offset*(iH-1);
            %       end
            %       drawnow();
            %       past_samples = samples(2:65,end);
            %       pause(sample_delay);
            %   end
            if ~obj.is_open || obj.is_write_mode
                throw(MException('Poly5:read_next_n_blocks', ['File is not opened in write mode: ' obj.filepath]));
            end
            samples = zeros(obj.num_channels, n);            
            k = 1;
            N = obj.header.num_samples_per_block;
            while (obj.current_block <= obj.header.num_data_blocks) && (k <= n)
                samples(:, (1+(k-1)*N):(k*N)) = TMSiSAGA.Poly5.readDataBlock(obj.handle, obj.num_channels, N);
                k = k + 1;
                obj.current_block = obj.current_block + 1;
            end
            if k <= n
                obj.current_block = 1;
                fseek(obj.handle, obj.data_offset, "bof");
                while k <= n
                    samples(:, (1+(k-1)*N):(k*N)) = TMSiSAGA.Poly5.readDataBlock(obj.handle, obj.num_channels, N);
                    k = k + 1;
                    obj.current_block = obj.current_block + 1;
                end
            end
        end

        function reset(obj)
            %RESET  Reset data to first sample point.
            if obj.is_open && ~obj.is_write_mode
                fseek(obj.handle, obj.data_offset, "bof");
            end
        end
    end
    
    methods(Static)
        function [data,header,channels] = read(filepath)
            %READ - A static function that allows opening and loading of a Poly5 file.
            %
            %   data = read(filepath)
            %
            %	Loads a Poly5 file and outputs the file as a TMSiSAGA.Data
            %	object.
            %
            %   data [out] - TMSiSAGA.Data object.
            %	filepath [in] - Path to a Poly5 file.
            %
            
            % Create a handle to the existing Poly5 file
            handle = fopen(filepath, 'r', 'n', 'US-ASCII');
            if handle == -1
                throw(MException('Poly5:read', sprintf('Could not open file, check if file is in use: %s', filepath)));
            end
            
            % ===========================================
            %	HEADER
            % ===========================================
            header = TMSiSAGA.Poly5.readHeader(handle);
            
            % ===========================================
            %	SIGNAL DESCRIPTION
            % ===========================================
            channels = TMSiSAGA.Poly5.readChannelDescriptions(handle, header.num_channels);
            
            % ===========================================
            %	DATA BLOCK
            % ===========================================
            samples = zeros(numel(channels), header.num_samples);
            for i=1:header.num_data_blocks
                i_start = (i - 1) * header.num_samples_per_block + 1;
                i_end = min(i * header.num_samples_per_block, header.num_samples);
                d =  TMSiSAGA.Poly5.readDataBlock(handle, numel(channels), i_end - i_start + 1);
                samples(:, i_start:i_end) = d;
            end
            
            if fclose(handle) == -1
                throw(MException('Poly5:read', ['Could not close file. ' filepath]));
            end
            
            % Create the Data object
            data = TMSiSAGA.Data(header.name, header.sample_rate, channels, samples);
        end
        
        function write(filepath, data)
            %WRITE - A static function that allows saving of a TMSi.Data object to Poly5.
            %
            %   write(filepath, data)
            %
            %	filepath [in] - Path to a Poly5 file.
            %	data [in] - A TMSi.Data object.
            %
            
            % Create a handle to write a Poly5 file
            handle = fopen(filepath, 'w', 'n', 'US-ASCII');
            if handle == -1
                throw(MException('Poly5:write', ['Could not open file, check if file is in use.' filepath]));
            end
            
            num_samples_per_block = floor(2^13 / numel(data.channels));
            
            % ===========================================
            %	HEADER
            % ===========================================
            TMSiSAGA.Poly5.writeHeader(handle, data, num_samples_per_block);
            
            % ===========================================
            %	SIGNAL DESCRIPTION
            % ===========================================
            TMSiSAGA.Poly5.writeChannelDescriptions(handle, data);

            % ===========================================
            %	DATA BLOCK
            % ===========================================
            for i=1:ceil(size(data.samples, 2) / num_samples_per_block)
                i_start = (i - 1) * num_samples_per_block + 1;
                i_end = min(i * num_samples_per_block, size(data.samples, 2));
                TMSiSAGA.Poly5.writeDataBlock(handle, num_samples_per_block, i - 1,  data.samples(:, i_start:i_end));
            end
            
            if fclose(handle) == -1
                throw(MException('Poly5:write', ['Could not close file. ' filepath]));
            end
        end
    end

    methods(Static,Access=public)
        function [header,channels_offset] = readHeader(handle)
            %READHEADER - Read header of a Poly5 file.
            %
            %   header = readHeader(handle);
            %   [header,channels_offset] = readHeader(handle);
            %
            %   header [out] - Header of Poly5 file
            %   channels_offset [out] - Byte position for start of 'channels' descriptions.
            %   handle [in] - Handle to Poly5 file
            %
            
            header = struct();
            
            header.magic_number = fread(handle, [1 31], 'char=>char');
            header.version_number = fread(handle, 1, 'uint16');
            fread(handle, 1, 'uint8');
            header.name = fread(handle, [1 80], 'uint8');
            header.name = deblank(native2unicode(header.name, 'UTF-8'));
            header.sample_rate = fread(handle, 1, 'uint16');
            header.storage_rate = fread(handle, 1, 'uint16');
            fread(handle, 1, 'uint8');
            header.num_channels = fread(handle, 1, 'uint16');
            header.num_samples = fread(handle, 1, 'uint32');
            fread(handle, 4, 'uint8');
            header.start_time = fread(handle, 7, 'uint16');
            header.num_data_blocks = fread(handle, 1, 'uint32');
            header.num_samples_per_block = fread(handle, 1, 'uint16');
            header.size_data_block = fread(handle, 1, 'uint16');
            header.compression_flag = fread(handle, 1, 'uint16');
            fread(handle, 64, 'uint8');
            
            if ~strcmp(header. magic_number, sprintf('POLY SAMPLE FILEversion 2.03\r\n\x1a'))
                fclose(handle);
                throw(MException('Poly5:read', 'This is not a Poly5 file.'));
            end
            
            if header.version_number ~= 203
                fclose(handle);
                throw(MException('Poly5:read', 'Version number of file is invalid.'));
            end
            channels_offset = ftell(handle);
        end
        
        function [channels, data_offset] = readChannelDescriptions(handle, num_channels)
            %READCHANNELDESCRIPTIONS - Read channel descriptions of Poly5 file.
            %
            %   channels = readChannelDescriptions(handle, num_channels)
            %   [channels,data_offset] = readChannelDescriptions(handle, num_channels);
            %
            %   channels [out] - Cell array with channel descriptions of Poly5 file.
            %   data_offset [out] - Byte position in file where data starts.
            %   handle [in] - Handle to Poly5 file.
            %   num_channels [in] - Number of channels in Poly5 file.
            %
            
            channels = struct('name', cell(num_channels,1), ...
                              'alternative_name', cell(num_channels,1), ...
                              'unit_name', cell(num_channels,1), ...
                              'unit_low', cell(num_channels,1), ...
                              'unit_high', cell(num_channels,1), ...
                              'adc_low', cell(num_channels,1), ...
                              'adc_high', cell(num_channels,1), ...
                              'index', cell(num_channels,1), ...
                              'cache_offset', cell(num_channels,1));
            keep_channel = false(num_channels,1);
            for i=1:num_channels
                fread(handle, 1, 'uint8');
                channels(i).name = fread(handle, [1, 40], 'uint8');
                channels(i).name = deblank(native2unicode(channels(i).name, 'UTF-8'));
                fread(handle, 5, 'uint8');
                channels(i).unit_name = fread(handle, [1 10], 'uint8');
                channels(i).unit_name = deblank(native2unicode(channels(i).unit_name, 'UTF-8'));
                channels(i).unit_low = fread(handle, 1, 'uint32');
                channels(i).unit_high = fread(handle, 1, 'uint32');
                channels(i).adc_low = fread(handle, 1, 'uint32');
                channels(i).adc_high = fread(handle, 1, 'uint32');
                channels(i).index = fread(handle, 1, 'uint16');
                channels(i).cache_offset = fread(handle, 1, 'uint16');
                if numel(channels(i).name) >= 6
                    channels(i).alternative_name = channels(i).name(6:end);
                else
                    channels(i).alternative_name = 'Unknown';
                end
                fread(handle, 60, 'uint8');
                
                if ~strncmp('(Lo)', channels(i).name, 4) && ~strncmp('(Hi)', channels(i).name, 4)
                    fclose(handle);
                    throw(MException('Poly5:read', 'Does not support non 16 bit format.'));
                end

                keep_channel(i) = strncmp('(Lo)', channels(i).name, 4);
            end
            channels = channels(keep_channel);
            data_offset = ftell(handle);
        end
        
        function samples = readDataBlock(handle, num_channels, num_samples_per_block)
            %READDATABLOCK - Read a data block from a Poly5 file.
            %
            %   samples = readDataBlock(handle, num_channels, num_samples_per_block)
            %
            %   samples [out] - Samples read from a Poly5 file.
            %   handle [in] - Handle to Poly5 file.
            %   num_channels [in] - Number of channels in the Poly5 file
            %   num_samples_per_block [in] - Number of samples that are
            %       read per call of this method
            %
            
            index = fread(handle, 1, 'uint32');
            if index > -1
                fread(handle, 4, 'uint8');
                fread(handle, 7, 'uint16');
                fread(handle, 64, 'uint8');
                samples = fread(handle, [num_channels num_samples_per_block], 'float32=>single');
            else
                samples = [];
            end
        end
        
        function channels_offset = writeHeader(handle, data, num_samples_per_block)
            %WRITEHEADER - Write a header for a Poly5 file.
            %
            %   writeHeader(handle, data, num_samples_per_block)
            %
            %   handle [in] - Handle to Poly5 file.
            %   data [in] - A TMSiSAGA.Data object.
            %   num_sample_per_block [in] - Number of samples that are
            %       written per call of this method
            %
            
            fwrite(handle, sprintf('POLY SAMPLE FILEversion 2.03\r\n\x1a'), 'char');
            fwrite(handle, 203, 'uint16');
            
            name_utf8 = unicode2native(deblank(data.name), 'UTF-8');
            fwrite(handle, min(80, numel(name_utf8)), 'uint8');
            fwrite(handle, name_utf8, 'uint8');
            fwrite(handle, zeros(1, 80 - min(80, numel(name_utf8))), 'uint8');
            
            fwrite(handle, data.sample_rate, 'uint16');
            fwrite(handle, data.sample_rate, 'uint16');
            
            fwrite(handle, 0, 'uint8');
            
            fwrite(handle, numel(data.channels) * 2, 'uint16');
            fwrite(handle, data.num_samples, 'uint32');
            
            fwrite(handle, zeros(1, 4), 'uint8');
            
            fwrite(handle, data.date(1), 'uint16');
            fwrite(handle, data.date(2), 'uint16');
            fwrite(handle, data.date(3), 'uint16');
            fwrite(handle, 1, 'uint16');
            fwrite(handle, data.date(4), 'uint16');
            fwrite(handle, data.date(5), 'uint16');
            fwrite(handle, data.date(6), 'uint16');
            
            fwrite(handle, ceil(data.num_samples / num_samples_per_block), 'uint32');
            fwrite(handle, num_samples_per_block, 'uint16');
            fwrite(handle, numel(data.channels) * num_samples_per_block * 4, 'uint16');
            fwrite(handle, 0, 'uint16');
            fwrite(handle, zeros(1, 64), 'uint8');

            channels_offset = ftell(handle);

        end
        
        function data_offset = writeChannelDescriptions(handle, data)
            %WRITECHANNELDESCRIPTION - Write channel descriptions for a Poly5 file.
            %
            %   writeChannelDescriptions(handle, data)
            %
            %   handle [in] - Handle to Poly5 file.
            %   data [in] - A TMSiSAGA.Data object
            %
            
            for i=1:numel(data.channels)
                unit_name = data.channels(i).unit_name;
                
                for j=1:2
                    if j == 1
                        channel_name = ['(Lo) ' data.channels(i).name];
                    else
                        channel_name = ['(Hi) ' data.channels(i).name];
                    end
                    
                    channel_name_utf8 = unicode2native(deblank(channel_name), 'UTF-8');
                    fwrite(handle, min(40, numel(channel_name_utf8)), 'uint8');
                    fwrite(handle, channel_name_utf8, 'uint8');
                    fwrite(handle, zeros(1, 40 - min(40, numel(channel_name_utf8))), 'uint8');
                    
                    fwrite(handle, ones(1, 4), 'uint8');
                    
                    unit_name_utf8 = unicode2native(deblank(unit_name), 'UTF-8');
                    fwrite(handle, min(10, numel(unit_name_utf8)), 'uint8');
                    fwrite(handle, unit_name_utf8, 'uint8');
                    fwrite(handle, zeros(1, 10 - min(10, numel(unit_name_utf8))), 'uint8');
                    
                    fwrite(handle, 0, 'uint32');
                    fwrite(handle, 1000, 'uint32');
                    fwrite(handle, 0, 'uint32');
                    fwrite(handle, 1000, 'uint32');
                    fwrite(handle, i, 'uint16');
                    fwrite(handle, zeros(1, 62), 'uint8');
                end
            end
            data_offset = ftell(handle);
        end
         
        function writeDataBlock(handle, num_samples_per_block, index, samples)
            %WRITEDATABLOCK - Write a data block for a Poly5 file. Is max 240 samples per block.
            %
            %   writeDataBlock(handle, num_samples_per_block, index, samples)
            %
            %   handle [in] - Handle to Poly5 file.
            %   num_samples_per_block [in] - Number of samples that are
            %       written per call of this method.
            %   index [in] - Indexing variable that determines where writing of
            %       the Poly5 file should start.
            %   samples [in] - Samples that are written to the Poly5 file.
            %
            
            fwrite(handle, index * num_samples_per_block, 'uint32');
            
            fwrite(handle, zeros(1, 4), 'uint8');
            
            fwrite(handle, 2016, 'uint16');
            fwrite(handle, 1, 'uint16');
            fwrite(handle, 1, 'uint16');
            fwrite(handle, 1, 'uint16');
            fwrite(handle, 1, 'uint16');
            fwrite(handle, 1, 'uint16');
            fwrite(handle, 1, 'uint16');
            
            fwrite(handle, zeros(1, 64), 'uint8');
            
            if size(samples, 2) < num_samples_per_block
                s = zeros(size(samples, 1), num_samples_per_block);
                s(:, 1:size(samples, 2)) = samples;
                fwrite(handle, s, 'float32');
            else
                fwrite(handle, samples, 'float32');
            end
            
        end
    end
end
