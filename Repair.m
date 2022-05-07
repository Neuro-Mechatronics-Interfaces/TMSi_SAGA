classdef Repair < TMSiSAGA.HiddenHandle
    %REPAIR - Class with functions that allow for repair of sample data.
    %
    %   This class contains two function that will fill in the missing samples
    %   with the missing samples retrieved from the device. Either directly from 
    %   a Poly5 file, or indirectly via the Data object.
    %
    %REPAIR - Methods
    %   repair - Repair missing samples in a Data object with missing samples.
    %   repairPoly5 - Repair missing samples in a Poly5 file.
    %
    %REPAIR - Example 1
    %   data = TMSiSAGA.Data('Example', device.sample_rate, device.getActiveChannels());
    %
    %   % sampled data
    %   
    %   missing_samples = device.getMissingSamples();
    %   TMSiSAGA.Repair.repair(data, missing_samples);
    %
    %REPAIR - Example 2
    %   missing_samples = device.getMissingSamples();
    %   TMSiSAGA.Repair.repair('./example.poly5', missing_samples);
    %

    methods (Static = true)
        function data = repair(data, missing_samples, index_of_counter, reset_counter_on)
            %REPAIR - Repair a Data object with missing samples.
            %
            %   data = repair(data, missing_samples, index_of_counter, reset_counter_on)
            %
            %   Repair a Data object with missing samples. Counter channel is by default the last channel
            %   in the data object, can be changed with index_of_counter. The counter channel can be mod
            %   by the reset_counter_on.
            %   
            %   data [out/in] - Data object that has to be repaired.
            %   missing_samples [in] - An array of samples containing the missing samples.
            %   index_of_counter [in] - (Optional) Index that specifies the counter channel.
            %   reset_counter_on [in] - (Optional) Reset the counter value every reset_counter_on (mod reset_counter_on).
            %

            if ~exist('index_of_counter', 'var')
                index_of_counter = size(data, 1);
            end

            if ~exist('reset_counter_on', 'var')
                reset_counter_on = 0;
            end
            
            if numel(missing_samples) == 0
                return
            end
            
            % Determine the index of the triggers channel (DR does not
            % contain trigger data).
            active_channels = data.channels;            
            for i = 1:numel(active_channels)
                if strcmp(active_channels{i}.alternative_name, 'TRIGGERS') 
                    index_of_triggers = i;
                end
            end

            samples = data.samples;
            
            current_sample_counter = 1;
            offset_missing_samples = 1;
            for i=1:size(data.samples, 2)
                if data.samples(index_of_counter) == 0
                    current_sample_counter = current_sample_counter + reset_counter_on;
                end
                
                while size(missing_samples, 2) > offset_missing_samples && missing_samples(index_of_counter, offset_missing_samples) < current_sample_counter
                    offset_missing_samples = offset_missing_samples + 1;
                end
                
                if missing_samples(index_of_counter, offset_missing_samples) == current_sample_counter
                    % Overwrite samples except for the TRIGGERS channel (if
                    % present)
                    if exist('index_of_triggers', 'var')
                        samples([1:index_of_triggers-1, index_of_triggers+1:end], i) = missing_samples([1:index_of_triggers-1, index_of_triggers+1:end], offset_missing_samples);
                    else
                        samples(:, i) = missing_samples(:, offset_missing_samples);
                    end
                        
                end

                current_sample_counter = current_sample_counter + 1;
            end

            samples(index_of_counter, :) = mod(samples(index_of_counter, :), reset_counter_on);

            data.setSamples(samples);
        end

        function [data] = repairPoly5(src_file, missing_samples, index_of_counter)
            %REPAIRPOLY5 - Repair a Poly5 file with missing samples.
            %
            %   [data] = repairPoly5(src_file, missing_samples, index_of_counter)
            %
            %   Repair a Poly5 file with missing samples. Counter channel is by default the last channel
            %   in the poly5 file, can be changed with index_of_counter.
            % 
            %   data [out] - Data object.
            %   src_file [in] - Poly5 file that has to be repaired.
            %   missing_samples [in] - An array of samples containing the missing samples.
            %   index_of_counter [in] - Index that specifies the counter channel.

            data = TMSiSAGA.Poly5.read(src_file);
            data = TMSiSAGA.Repair.repair(data, missing_samples, index_of_counter, 2^23);
            TMSiSAGA.Poly5.write([src_file '.repaired.poly5'], data);
        end

    end

end