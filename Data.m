classdef Data < TMSiSAGA.HiddenHandle
    %DATA Class that will store data that we sampled from a TMSi device.
    %
    %DATA Properties:
    %   name - Name for this data object.
    %   sample_rate - Rate this data was sampled at.
    %   channels - A cell array containing channel structures (see TMSi.Device).
    %   data - A matrix containing the sample data order as num_channels x num_samples.
    %   num_samples - Number of samples in this data object.
    %   time - The total time of data (num_samples / sample_rate).
    %   date - Date of objects creation.
    %
    %DATA Methods:
    %   Data - Constructor for the Data object.
    %   append - Append samples to this data object.
    %   trim - Trim the internal data matrix to exact propertions.
    %   toEEGLab - Transform information to EEG EEGLAB object.
    %
    %DATA Example:
    %   device = library.getFirstAvailableDevice('network', 'electrical');
    %
    %   device.connect();
    %   device.updateDeviceConfig();
    %
    %   data = TMSiSAGA.Data('Example', device.sample_rate, device.getActiveChannels());
    %   
    %   device.start();
    %
    %   for i=1:10
    %       samples = device.sample();
    %       data.append(samples);
    %   end
    %
    %   device.stop();
    %   device.disconnect();
    %   
    %   data.trim();
    %   eeglab(data.toEEGLab());

    properties
        % Name for this data object.
        name

        % Rate this data was sampled at.
        sample_rate

        % A cell array containing channel structures (see TMSi.Device).
        channels

        % A matrix containing the sample data order as num_channels x num_samples.
        samples

        % Number of samples in this data object.
        num_samples

        % The total time of data (num_samples / sample_rate).
        time

        % Date of objects creation.
        date
    end

    methods
        function obj = Data(name, sample_rate, channels, samples)
            %DATA - Constructor for the Data object.
            %
            %   obj = Data(name, sample_rate, channels, samples)
            %
            %   Constructor for the data object. Requires a name, sample rate and
            %   channel information as part of the Device object.
            %
            %   obj [out] - Data object.
            %   name [in] - Name of the Data object.
            %   sample_rate [in] - Sample rate of this data in Hz.
            %   channels [in] - Cell structure with channel structure (see TMSiSaga.Channel)
            %       Minimum elements need to be .alternative_name and .unit_name.
            %   samples [in] - Samples that are placed in the Data object.
            %   

            if ~exist('samples', 'var')
                samples = single(zeros(numel(channels), 0));
            end

            obj.name = name;
            obj.sample_rate = sample_rate;
            obj.channels = channels;
            obj.samples = samples;
            obj.num_samples = 0;
            obj.time = 0;
            obj.date = clock;

            if size(samples, 2) > 0
                obj.samples = samples;
                obj.num_samples = size(samples, 2);
                obj.time = size(samples, 2) / obj.sample_rate;
            end

        end

        function setSamples(obj, samples)
            %SETSAMPLES - Set the samples for this object.
            %
            %   setSamples(obj, samples)
            %
            %   Replace the current samples in this data object with the samples in 
            %   referenced samples parameter. Make sure the size of the samples array
            %   has atleast numel(channels).
            %
            %   obj [in] - Data object.
            %   samples [in] - A matrix with samples of the form numel(channels) x num_samples.

            if size(samples, 1) ~= numel(obj.channels)
                throw(MException('Data:setSamples', 'Samples should have atleast numel(channels) rows.'));
            end

            obj.samples = samples;
            obj.num_samples = size(samples, 2);
            obj.time = size(samples, 2) / obj.sample_rate;
        end

        function append(obj, samples)
            %APPEND - Append samples to this data object.
            %
            %   append(obj, samples)
            %
            %   Append samples as retrieved from a Sampler object to the current
            %   data. If a subset of channels are selected, make sure you also only
            %   add the samples from the channels you want stored.
            %
            %   obj [in] - Data object.
            %   samples [in] - A matrix with samples of the form numel(channels) x num_samples.
            
            index_start = obj.num_samples + 1;
            index_end = obj.num_samples + size(samples, 2);

            if index_end > size(obj.samples, 2)
                obj.samples(:, size(obj.samples, 2) + obj.sample_rate * 10) = 0;
            end

            obj.samples(:, index_start:index_end) = samples(:, :);

            obj.num_samples = obj.num_samples + size(samples, 2);
            obj.time = obj.num_samples / obj.sample_rate;
        end

        function trim(obj)
            %TRIM - Trim the internal data matrix to exact propertions.
            %
            %   trim(obj)
            %
            %   This function will trim the data variable to precise size. If you
            %   do not do this the samples variable will have more samples than you 
            %   appended.
            %
            %   obj [in] - Data object.
            %

            obj.samples = obj.samples(:, 1:obj.num_samples);
        end

        function eeg = toEEGLab(obj, ChanLocs)
            %TOEEGLAB - Transform information to EEG EEGLAB object.
            %
            %   eeg = toEEGLab(obj, ChanLocs)
            %
            %   This function will transform the data contained in this object, into
            %   an EEGLAB compatible object. You can use the returned object as follows:
            %       eeglab(data.toEEGLab());
            %
            %   eeg [out] - Struct compatible with EEGLAB. 
            %   obj [in] - Data object.
            %   ChanLocs [in] - Channel locations file.
            %
            
            if obj.num_samples ~= size(obj.samples, 2)
                warning('You forgot to trim the data, call obj.trim() before calling this function.');
            end
            
            eeg = eeg_emptyset;
            % Recording information
            eeg.setname = ['Continuous Data TMSi Name: ' obj.name];
            eeg.pnts = obj.num_samples;
            eeg.nbchan = size(obj.samples, 1);
            eeg.trials = 1;
            eeg.srate = obj.sample_rate;
            % Total recording time
            eeg.xmax = (obj.num_samples - 1) / obj.sample_rate;
            % Time vector
            eeg.times = (0:obj.num_samples-1) / obj.sample_rate;
            % Reshaping data into eeglab structure
            eeg.data = reshape(obj.samples, size(obj.samples, 1), size(obj.samples, 2), 1);
            
            % Determine the index of the triggers channel
            for i = 1:size(eeg.data,1)
                if strcmp(obj.channels{i}.alternative_name, 'TRIGGERS')
                    index_of_triggers = i;
                    % Number of trigger channels in SAGA
                    num_triggers = 16;
                end
            end
            
            % Retrieve individual trigger channel data
            if exist('index_of_triggers', 'var')
                % Convert the triggers channel to binary numbers
                stacked_triggers = dec2bin(obj.samples(index_of_triggers,:),num_triggers);
                triggers = nan(num_triggers,size(obj.samples, 2));
                % Convert binary string to channel-specific numbers
                for i = size(triggers, 1):-1:1
                    triggers(end-i+1,:) = str2num(stacked_triggers(:,i));
                end
                % Update channel info for all trigger channels
                triggers_channel_info = cell(1,num_triggers);
                for i = 1:size(triggers_channel_info,2)
                    triggers_channel_info{i} = obj.channels{index_of_triggers};
                    triggers_channel_info{i}.alternative_name = [triggers_channel_info{i}.alternative_name num2str(i)];
                end
                
                % Replace the TRIGGERS channel with the 16 split trigger
                % channels in both the channels object and the data object.
                eeg.data = [eeg.data(1:index_of_triggers-1,:); triggers; eeg.data(index_of_triggers+1:end,:)];  
                obj.channels = {{obj.channels{1:index_of_triggers-1}} ...
                    triggers_channel_info ...
                    {obj.channels{index_of_triggers+1:end}}};
                obj.channels = horzcat(obj.channels{:});
                
                % Update the channel number counter
                eeg.nbchan = size(eeg.data,1);
            end
            
            % Determine reference method 
            if strcmp('CREF', obj.channels{1}.alternative_name)
                eeg.ref = 'common';
                chanlocs_offset = 1;
            else
                eeg.ref = 'averef';
                chanlocs_offset = 0;
            end
            
            % Check whether name of channel corresponds to channel
            % locations file. This is done to ensure correct topographic
            % plotting of the channels. Furthermore, channel names are both
            % checked for the EEG convention and the SAGA default
            % convention.
            idx_ChanLocs = [];
            for i = 1+chanlocs_offset:numel(obj.channels)
                for j = 1:numel(ChanLocs)
                    if strcmp(obj.channels{i}.alternative_name, ChanLocs(j).labels) || ...
                            strcmp(obj.channels{i}.alternative_name, ['UNI ' sprintf('%02d',j)])
                        idx_ChanLocs(end+1) = j;
                    end
                end
            end        
            
            % Assign channel locations information, based on type of
            % reference method. 
            for i=1:numel(obj.channels)
                % Place common reference channel in middle of head plot
                if strcmp('CREF', obj.channels{i}.alternative_name)
                    eeg.chanlocs(i).theta = 0;
                    eeg.chanlocs(i).radius = 0.3525;
                    eeg.chanlocs(i).labels = obj.channels{i}.alternative_name;
                    eeg.chanlocs(i).sph_theta = 0;
                    eeg.chanlocs(i).sph_phi = 26.55;
                    eeg.chanlocs(i).sph_radius= 0.3525;
                    eeg.chanlocs(i).X = 0.8333;
                    eeg.chanlocs(i).Y = 0;
                    eeg.chanlocs(i).Z = 0.4164;
                    eeg.chanlocs(i).ref = 'common';
                % Ensure non-unipolar channels are not plotted in the
                % topographic plot.
                elseif ~strcmp('µVolt', obj.channels{i}.unit_name) || ...
                        contains(obj.channels{i}.alternative_name,'BIP') || ...
                        contains(obj.channels{i}.alternative_name,'AUX')
                    eeg.chanlocs(i).theta = nan;
                    eeg.chanlocs(i).radius = nan;
                    eeg.chanlocs(i).labels = obj.channels{i}.alternative_name;
                    eeg.chanlocs(i).sph_theta = nan;
                    eeg.chanlocs(i).sph_phi = nan;
                    eeg.chanlocs(i).sph_radius= nan;
                    eeg.chanlocs(i).X = nan;
                    eeg.chanlocs(i).Y = nan;
                    eeg.chanlocs(i).Z = nan;           
                    % Save reference method in channel locations
                    % information.  
                    if chanlocs_offset
                        eeg.chanlocs(i).ref = 'common';
                    else
                        eeg.chanlocs(i).ref = 'averef';
                    end
                else
                    eeg.chanlocs(i).theta = ChanLocs(idx_ChanLocs(i-chanlocs_offset)).theta;
                    eeg.chanlocs(i).radius = ChanLocs(idx_ChanLocs(i-chanlocs_offset)).radius;
                    eeg.chanlocs(i).labels = obj.channels{i}.alternative_name;
                    eeg.chanlocs(i).sph_theta = ChanLocs(idx_ChanLocs(i-chanlocs_offset)).sph_theta;
                    eeg.chanlocs(i).sph_phi = ChanLocs(idx_ChanLocs(i-chanlocs_offset)).sph_phi;
                    eeg.chanlocs(i).sph_radius= ChanLocs(idx_ChanLocs(i-chanlocs_offset)).radius;
                    eeg.chanlocs(i).X = ChanLocs(idx_ChanLocs(i-chanlocs_offset)).X;
                    eeg.chanlocs(i).Y = ChanLocs(idx_ChanLocs(i-chanlocs_offset)).Y;
                    eeg.chanlocs(i).Z = ChanLocs(idx_ChanLocs(i-chanlocs_offset)).Z;
                    % Save reference method in channel locations
                    % information.
                    if chanlocs_offset
                        eeg.chanlocs(i).ref = 'common';
                    else
                        eeg.chanlocs(i).ref = 'averef';
                    end
                end
            end
            % Check the consistency of the assigned data structure for
            % EEGlab compatibility. 
            eeg = eeg_checkset(eeg);
        end
    end
end
