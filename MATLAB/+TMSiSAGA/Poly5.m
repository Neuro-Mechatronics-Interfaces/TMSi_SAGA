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
    %   device.updateDeviceConfig();
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
		% Name of the measurement.
		name

		% File name at which data is stored.
		filepath

		% The sample rate at which the data is stored.
		sample_rate

		% The channels stored (cell array of structs with atleast .name and .unit_name).
		%	channels{i}.name - Name of channel.
		%	channels{i}.unit_name - Unit of channel (e.g. uV).
		channels

		% The number of samples that should have been stored to disk.
		num_samples

		% A boolean whether or not the file is opened and can be streamed to.
		is_open

		% The date of creation of object.
        date 

        % The samplenr channel
        counter_channel

        % The digstat channel
        digstat_channel
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
		function obj = Poly5(filepath, name, sample_rate, channels)
			%POLY5 - Constructor for object that allows streaming of data to file.

			obj.filepath = filepath;
			obj.name = name;
			obj.sample_rate = sample_rate;
			obj.channels = channels;
			obj.samples = zeros(numel(channels), 0);
			obj.num_samples = 0;
            obj.date = clock;
            obj.num_samples_per_block = floor(2^13 / numel(channels));

			obj.handle = fopen(filepath, 'w', 'n', 'UTF-8');
			if obj.handle == -1
				throw(MException('Poly5:Poly5', ['Could not open file. ' filepath]));
			end
			
            for i=1:numel(obj.channels)
                if obj.channels{i}.type == TMSiSAGA.TMSiUtils.toChannelTypeNumber('digstat')
                    obj.digstat_channel = i;
                end

                if obj.channels{i}.type == TMSiSAGA.TMSiUtils.toChannelTypeNumber('counter')
                    obj.counter_channel = i;
                end 
            end

			TMSiSAGA.Poly5.writeHeader(obj.handle, obj, obj.num_samples_per_block);
			TMSiSAGA.Poly5.writeChannelDescriptions(obj.handle, obj);

			obj.is_open = true;
		end 

		function append(obj, samples)
			%APPEND - Append samples to file.
			%
			%	samples - Samples as a num_channels x num_samples.

			if ~obj.is_open
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

			if ~obj.is_open
				return;
			end

			fclose(obj.handle);

			obj.is_open = false;
		end

	end

	methods(Static)
		function data = read(filepath)
			%READ - A static function that allows opening and loading of a Poly5 file.
			%
			%	filepath - Path to a Poly5 file.
			%
			%	Returns a TMSiSAGA.Data.

			handle = fopen(filepath, 'r');
			if handle == -1
				throw(MException('Poly5:read', ['Could not open file, check if file is in use. ' filepath]));
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

            data = TMSiSAGA.Data(header.name, header.sample_rate, channels, samples);
		end

		function obj = write(filepath, data)
			%WRITE - A static function that allows saving of a TMSi.Data object to Poly5.
			%
			%	filepath - Path to a Poly5 file.
			%	data - A TMSi.Data object.

			handle = fopen(filepath, 'w');
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

	methods(Access = private, Static)
		function header = readHeader(handle)
			%READHEADER - Read header of a Poly5 file.

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
		end

		function channels = readChannelDescriptions(handle, num_channels)
			%READCHANNELDESCRIPTIONS - Read channel descriptions of Poly5 file.

			channels = {};
			channel_index = 1;
			for i=1:num_channels
				channel = struct();

                fread(handle, 1, 'uint8');
				channel.name = fread(handle, [1, 40], 'uint8');
                channel.name = deblank(native2unicode(channel.name, 'UTF-8'));
				fread(handle, 5, 'uint8');
				channel.unit_name = fread(handle, [1 10], 'uint8');
                channel.unit_name = deblank(native2unicode(channel.unit_name, 'UTF-8'));
                channel.unit_low = fread(handle, 1, 'uint32');
                channel.unit_high = fread(handle, 1, 'uint32');
                channel.adc_low = fread(handle, 1, 'uint32');
                channel.adc_high = fread(handle, 1, 'uint32');	
                channel.index = fread(handle, 1, 'uint16');
                channel.cache_offset = fread(handle, 1, 'uint16');
                fread(handle, 60, 'uint8');

				if ~strncmp('(Lo)', channel.name, 4) && ~strncmp('(Hi)', channel.name, 4)
					fclose(handle);
					throw(MException('Poly5:read', 'Does not support non 16 bit format.'));
				end

				if strncmp('(Lo)', channel.name, 4)
					if numel(channel.name) >= 6
						channels{channel_index}.alternative_name = channel.name(6:end);
					else
						channels{channel_index}.alternative_name = 'Unknown';
					end
					channels{channel_index}.unit_name = channel.unit_name;
					channel_index = channel_index + 1;
				end
            end			
		end

		function samples = readDataBlock(handle, num_channels, num_samples_per_block)
			%READDATABLOCK - Read a data block from a Poly5 file.

			index = fread(handle, 1, 'uint32');
            fread(handle, 4, 'uint8');
        	fread(handle, 7, 'uint16');
            fread(handle, 64, 'uint8');
        	samples = fread(handle, [num_channels num_samples_per_block], 'float32=>single');
		end

		function writeHeader(handle, data, num_samples_per_block)
			%WRITEHEADER - Write a header for a Poly5 file.

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
		end

		function writeChannelDescriptions(handle, data)
			%WRITECHANNELDESCRIPTION - Write channel descriptions for a Poly5 file.

			for i=1:numel(data.channels)
				unit_name = data.channels{i}.unit_name;

				for j=1:2
					if j == 1
						channel_name = ['(Lo) ' data.channels{i}.alternative_name];
					else 
						channel_name = ['(Hi) ' data.channels{i}.alternative_name];
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
		end
	

		function writeDataBlock(handle, num_samples_per_block, index, samples)
			%WRITEDATABLOCK - Write a data block for a Poly5 file. Is max 240 samples per block.

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
