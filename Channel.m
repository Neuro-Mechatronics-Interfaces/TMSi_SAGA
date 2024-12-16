classdef Channel < TMSiSAGA.HiddenHandle
    %CHANNEL Class that represents a single channel on a device.
    %
    %CHANNEL Properties:
    %   number - The number used by the device to identify the channel
    %   type - The channel type like ExG, Uni, etc.
    %   format - The format of the channel, float, int32, uin32, etc.
    %   divider - The sample rate of this channel, is "<base sample rate device> / 2^<divider>". If -1 the channel is disabled.
    %   impedance_divider - The sample rate when in impedance mode, is "<base sample rate device> / 2^<divider>". If -1 the channel is disabled.
    %   bandwidth - The bandwidth required for the data in this channel.
    %   exponent - The exponent to apply to the data.
    %   unit_name - The unit name of the retrieved data.
    %   name - The fixed name of the channel.
    %   alternative_name - The current alternative name set on this channel.
    %   sensor_channel - An optional sensor channel that is connected to this channel.
    %
    %CHANNEL Methods:
    %   Channel - Constructor for the Channel object.
    %   isActive - Is the current channel active in sample, or impedance mode.
    %   enable - Enable the channel.
    %   disable - Disable the channel.
    %   setUnitname - Set the unit for this channel.
    %   setExponent - Set the exponent value for this channel.
    %   setAlternativeName - Set the alternative name for this channel.
    %   isRef - (Added by MM): Check if this is a REF channel.
    %   isExG - Check if this an ExG channel.
    %   isBip - Check if this an Bip channel.
    %   isAux - Check if this an Aux channel.
    %   isDig - Check if this an Dig channel.
    %   isDigstat - Check if this an Digstat channel.
    %   isSaw - Check if this a saw channel.
    %   isCounter - Check if this is the counter channel.
    %   isStatus - Check if this is the status channel.
    %   setSAGA - (Added by MM): A function to set the `saga` property, which is the `tag` property of the Device this channel is associated with.
    %   fromSAGA - (Added by MM): Checks if `saga` for this Channel matches the tag in the argument.
    %   transform - A function that transform the raw sample data.
    %
    %CHANNEL Example:
    %   
    %   

    properties
        % The number used by the device to identify the channel
        number

        % The channel type like ExG, Uni, etc.
        type
            
        % The format of the channel, float, int32, uin32, etc.
        format
        
        % The sample rate of this channel, is "<base sample rate device> / 2^<divider>". If -1 the channel is disabled.
        divider
        
        % The sample rate when in impedance mode, is "<base sample rate device> / 2^<divider>". If -1 the channel is disabled.
        impedance_divider
        
        % The bandwidth required for the data in this channel.
        bandwidth
        
        % The exponent to apply to the data.
        exponent
        
        % he unit name of the retrieved data.
        unit_name
        
        % The fixed name of the channel.
        name
        
        % The current alternative name set on this channel.
        alternative_name
        
        % An optional sensor channel that is connected to this channel.
        sensor_channel

        % SAGA-DR serial number associated with this channel.
        sn (1,1) int64 = 0; % Serial number associated with SAGA
    end

    % Properties that must be set using class methods:
    properties (GetAccess = public, SetAccess = protected)
        % (Added MM) Which saga tag is this channel associated with?
        saga (1,1) string = "X";
    end

    properties (Access = private)
%         % The source device of this channel.
%         device 

        % The type to which the has to be transformed before using.
        to_type
            
        % The stride that is required for the type conversion.
        to_stride
    end

    methods
        function obj = Channel(device, channel_info, tag, number)
            %CHANNEL - Constructor for the Channel object.
            %
            %   obj = Channel(device, channel_info)
            %   obj = Channel(device, channel_info, tag, number);
            %
            %   Constructor for the Channel object. Requires a device, and the raw channel info structure
            %   from the TMSi device. It is not recommended to create a channel directly.
            %
            %   obj [out] - Channel object.
            %   device [in] - The device for which the channel object is created.
            %   channel_info [in] - Basic channel information, should be gotten from the device.
            %   tag [in] - SAGA tag ("A" or "B"; default is "X")

            if nargin < 3
                tag = "X";
            end

            if nargin < 4
                obj = repmat(obj, size(channel_info));
                for ii = 1:numel(channel_info)
                    obj(ii) = TMSiSAGA.Channel(device, channel_info(ii), tag, ii - 1);
                end
                return;
            end
            obj.saga = tag;
            obj.sn = device.data_recorder.serial_number;
            obj.number = int64(number);
            obj.type = int64(channel_info.ChannelType);
            obj.format = int64(channel_info.ChannelFormat);
            obj.divider = int64(channel_info.ChanDivider);
            obj.impedance_divider = int64(channel_info.ImpDivider);
            obj.bandwidth = int64(channel_info.ChannelBandWidth);
            obj.exponent = int64(channel_info.Exp);
            obj.unit_name = channel_info.UnitName;
            obj.name = channel_info.DefChanName;
            obj.alternative_name = channel_info.AltChanName;
            if obj.alternative_name == ""
                obj.alternative_name = obj.name;
            end
            
            obj.sensor_channel = [];

            obj.to_type = 'double';
            obj.to_stride = 0;

            if bitand(obj.format, int64(hex2dec('FF00'))) == hex2dec('1100')
                obj.to_type = 'single';
                obj.to_stride = 0;
            elseif bitand(obj.format, int64(hex2dec('0100')))
                obj.to_type = ['int' num2str(bitand(obj.format, int64(hex2dec('00FF'))))];
                obj.to_stride = int32(4 / (bitand(obj.format, int64(hex2dec('00FF'))) / 8));
            else
                obj.to_type = ['uint' num2str(bitand(obj.format, int64(hex2dec('00FF'))))];
                obj.to_stride = int32(4 / (bitand(obj.format, int64(hex2dec('00FF'))) / 8));
            end
        end

        function name = getName(obj)
           %GET  Get 'name' value
           name = strings(size(obj));
           for ii = 1:numel(obj)
               name(ii) = string(sprintf('%s: %s', obj(ii).saga, obj(ii).name));
           end
        end
        
        function is_active = isActive(obj, impedance_mode)
            %ISACTIVE - A function that checks if the channel is active.
            %
            %   is_active = isActive(obj, impedance_mode)
            %
            %   This function checks if a channel is active in sampling mode or
            %   in impedance mode. Cannot check for both cases at a time.
            %
            %   is_active [out] - Boolean that states whether channel is
            %       active.
            %   obj [in] - Channel object.
            %   impedance_mode [in] - (Optional) Set to TRUE if you want to 
            %       check the active state of the channel when in impedance 
            %       mode. Is FALSE by default.
            
            if nargin < 2
                impedance_mode = false; 
            end
            
            if numel(obj) > 1
                is_active = false(size(obj));
                for ii = 1:numel(obj)
                    is_active(ii) = obj(ii).isActive(impedance_mode);
                end
                return;
            end
            if impedance_mode
                is_active = obj.impedance_divider >= 0;
            else
                is_active = obj.divider >= 0;
            end
        end

        function enable(obj)
            %ENABLE - A function to enable the channel.
            %
            %   enable(obj)
            %
            %   This function will enable the channel and set the divider to the current
            %   divider for this channel type gotten from device.
            %
            %   obj [in] - Channel object.
            %

            if numel(obj) > 1
                for ii = 1:numel(obj)
                    enable(obj(ii));
                end
                return;
            end
%             if obj.device.is_sampling
%                 throw(MException('Channel:enable', 'Cannot enable/disable channel while device is sampling.'));
%             end
            obj.divider = 0;
%             obj.divider = obj.device.dividers(obj.type);
%             obj.device.out_of_sync = true;
        end

        function disable(obj)
            %DISABLE - A function to disable the channel.
            %
            %   disable(obj)
            %
            %   This function will disable the channel and set the divider to -1.
            %
            %   obj [in] - Channel object.
            %
            
%             if obj.device.is_sampling
%                 throw(MException('Channel:disable', 'Cannot enable/disable channel while device is sampling.'));
%             end

            obj.divider = -1;
%             obj.device.out_of_sync = true;
        end

        function setDeviceTag(obj, saga)
            %SETDEVICETAG - Sets the device tag associated with this channel.
            %
            % setDeviceTag(obj, saga);
            %
            % saga - "A" or "B" (some identifier)
            for ii = 1:numel(obj)
                obj(ii).saga = saga;
            end
        end

        function setUnitName(obj, unit_name)
            %SETUNITNAME - A function to set the unit name for this channel.
            %
            %   setUnitName(obj, unit_name)
            %
            %   This function will set the unit name for this channel. Primary use
            %   is to set the unit name when it is a sensor channel.
            %
            %   obj [in] - Channel object.
            %   unit_name [in] - A string containing the unit name.
            %

%             if obj.device.is_sampling
%                 throw(MException('Channel:setUnitName', 'Cannot change unit name while device is sampling.'));
%             end

            obj.unit_name = unit_name;
        end

        function setExponent(obj, exponent)
            %SETEXPONENT - A function to set the exponent value for this channel.
            %
            %   setExponent(obj, exponent)
            %
            %   This function will set the exponent for this channel. The raw data is 
            %   divided by 10^exponent.
            %
            %   obj [in] - Channel object.
            %   exponent [in] - A value containing the exponent.
            %
            
%             if obj.device.is_sampling
%                 throw(MException('Channel:setExponent', 'Cannot change exponent while device is sampling.'));
%             end

            obj.exponent = exponent;
        end

        function setAlternativeName(obj, alternative_name)
            %SETALTERNATIVENAME - A function to set the alternative name of this channel.
            %
            %   setAlternativeName(obj, alternative_name)
            %
            %   This function will set the alternative name for this channel. By default
            %   the regular channel name is used.
            %
            %   obj [in] - Channel object.
            %   alternative_name [in] - A string to be used as alternative name.
            %
        
%             if obj.device.is_sampling
%                 throw(MException('Channel:setAlternativeName', 'Cannot change alternative name while device is sampling.'));
%             end

            obj.alternative_name = alternative_name;

%             obj.device.out_of_sync = true;
        end

        function is_true = isRef(obj)
            %ISREF - A function to check if this channel is a REF channel.
            %
            %   is_true = isRef(obj);
            %
            %   is_true [out] - Boolean that states whether channel type is
            %                   REF.
            %   obj [in] - Channel object.
            %
            % (2022-11-15 - added by MM)
            
            is_true = false(size(obj));
            for ii = 1:numel(obj)
                is_true(ii) = contains(upper(obj(ii).name), 'REF');
            end
        end

        function is_true = isExG(obj)
            %ISEXG - A function to check if this channel is an ExG channel.
            %
            %   is_true = isExG(obj)
            %
            %   This function will check if the channel type is ExG (1). 
            %
            %   is_true [out] - Boolean that states whether channel type is
            %   	ExG.
            %   obj [in] - Channel object.
            %
            
            is_true = [obj.type] == 1;
        end

        function is_true = isBip(obj)
            %ISBIP - A function to check if this channel is an Bip channel.
            %
            %   is_true = isBip(obj)
            %
            %   This function will check if the channel type is Bip (2). 
            %
            %   is_true [out] - Boolean that states whether channel type is
            %   	Bip.
            %   obj [in] - Channel object.
            %            
            
            is_true = [obj.type] == 2;
        end

        function is_true = isAux(obj)
            %ISAUX - A function to check if this channel is an Aux channel.
            %
            %   is_true = isAux(obj)
            %
            %   This function will check if the channel type is Aux (3). 
            %
            %   is_true [out] - Boolean that states whether channel type is
            %   	Aux.
            %   obj [in] - Channel object.
            %      
            
            is_true = [obj.type] == 3;
        end

        function is_true = isDig(obj)
            %ISDIG - A function to check if this channel is an Dig channel.
            %
            %   is_true = isDig(obj)
            %
            %   This function will check if the channel type is Dig (4). 
            %
            %   is_true [out] - Boolean that states whether channel type is
            %   	Dig.
            %   obj [in] - Channel object.
            %      
                        
            is_true = [obj.type] == 4;
        end

        function is_true = isDigstat(obj)
            %ISDIGSTAT - A function to check if this channel is an Digstat channel.
            %
            %   is_true = isDigstat(obj)
            %
            %   This function will check if the channel type is Digstat (5). 
            %
            %   is_true [out] - Boolean that states whether channel type is
            %   	Digstat.
            %   obj [in] - Channel object.
            %      
                        
            is_true = [obj.type] == 5;
        end

        function is_true = isSaw(obj)
            %ISSAW - A function to check if this channel is an Saw channel.
            %
            %   is_true = isSaw(obj)
            %
            %   This function will check if the channel type is Saw (6). 
            %
            %   is_true [out] - Boolean that states whether channel type is
            %   	Saw.
            %   obj [in] - Channel object.
            %      
                        
            is_true = [obj.type] == 6;
        end

        function is_true = isCounter(obj)
            %ISCOUNTER - A function to check if this channel is the counter channel.
            %
            %   is_true = isCounter(obj)
            %
            %   This function checks if the name of the channel is COUNTER.
            %
            %   is_true [out] - Boolean that states whether channel type is
            %   	COUNTER.
            %   obj [in] - Channel object.
            %      
            
            is_true = strcmp({obj.name}, 'COUNTER');
        end

        function is_true = isStatus(obj)
            %ISSTATUS - A function to check if this channel is the status channel.
            %
            %   is_true = isStatus(obj)
            %
            %   This function checks if the name of the channel is STATUS.
            %
            %   is_true [out] - Boolean that states whether channel type is
            %   	STATUS.
            %   obj [in] - Channel object.
            %      
            
            is_true = strcmp({obj.name}, 'STATUS');
        end
        
        function is_true = isTrigger(obj)
            %ISTRIGGER - A function to check if this channel is the TRIGGER channel.
            %
            %   is_true = isTrigger(obj)
            %
            %   This function checks if the name of the channel is TRIGGER.
            %
            %   is_true [out] - Boolean that states whether channel type is
            %   	TRIGGER.
            %   obj [in] - Channel object.
            %      
            
            is_true = contains({obj.name}, 'TRIGGER');
        end

        function setSAGA(obj, saga_tag)
            %SETSAGA - A function to set the `saga` property, which is the `tag` property of the Device this channel is associated with.
            %
            %   setSAGA(obj, saga_tag);
            %
            % Should set saga_tag as "A" or "B". Can assign to array of
            % Channel objects, and if saga_tag is a string array each
            % element corresponds to matched element of `obj`.
            if nargin < 1
                me = MException('MATLAB:notEnoughInputs', 'Not enough input arguments.');
                aac = matlab.lang.correction.AppendArgumentsCorrection('"A"');
                me = me.addCorrection(aac);
                throw(me);
            end
            saga_tag = string(saga_tag);
            if isscalar(saga_tag)
                saga_tag = repmat(saga_tag, size(obj));
            end
            for ii = 1:numel(obj)
                obj(ii).saga = saga_tag(ii);
            end
        end

        function is_true = fromSAGA(obj, saga_tag)
            %FROMSAGA - A function to check the `saga` property against the provided tag.
            %
            %   fromSAGA(obj, saga_tag);
            %
            % Example:
            %   idx = channels.fromSAGA("A"); % Get mask for channels from
            %                                 % "A" SAGA (useful if running
            %                                 % acquisition from two SAGA
            %                                 % devices on same host PC).
            if nargin < 1
                me = MException('MATLAB:notEnoughInputs', 'Not enough input arguments.');
                aac = matlab.lang.correction.AppendArgumentsCorrection('"A"');
                me = me.addCorrection(aac);
                throw(me);
            end
            saga_tag = string(saga_tag);
            if isscalar(saga_tag)
                saga_tag = repmat(saga_tag, size(obj));
            end
            is_true = false(size(obj));
            for ii = 1:numel(obj)
                is_true(ii) = strcmpi(obj(ii).saga, saga_tag(ii));
            end
        end

        function result = transform(obj, samples)
            %TRANSFORM - A function that transforms samples, based on channel settings.
            %
            %   result = transform(obj, samples)
            %
            %   This function will transform the raw samples from the device, into the
            %   right types and applies either sensor transform or the default exponent
            %   transform.
            %   
            %   result [out] - Transformed samples.
            %   obj [in] - Channel object.
            %   samples [in] - Raw samples obtained from the device.
            %
            
            if strcmp(obj.to_type, 'single')
                result = double(samples);
            else
                result = typecast(samples, obj.to_type);
                result = double(result(1:obj.to_stride:end));
            end

            if numel(obj.sensor_channel) ~= 0
                result = obj.sensor_channel.transform(result);
            else
                result = result ./ (10^double(obj.exponent));
            end
        end
    
        function channels = toCell(obj)
            %TOCELL  Returns cell array of channels from array of Channel objects.
            %
            % Syntax:
            %   channels = toCell(channelObjArray);
            %
            % Output:
            %   channels - Cell array with same size as input array. If
            %               input is a scalar Channel object, then the
            %               returned output is a 1x1 cell with that object
            %               in it. Corresponding elements of the returned
            %               cell array match to the original elements of
            %               the Channel object array.
            %
            % See also: Contents
            channels = cell(size(obj));
            for iCh = 1:numel(obj)
                channels{iCh} = obj(iCh);
            end
        end

        function channels = toStruct(obj, chan_nr_offset)
            %TOSTRUCT  Returns as a struct array 
            if nargin < 2
                chan_nr_offset = 0;
            end
            channels = struct();
            for i=1:numel(obj)
                channels(i).ChanNr = obj(i).number + chan_nr_offset;
                channels(i).ChanDivider = obj(i).divider;                
                channels(i).AltChanName = obj(i).alternative_name;
                channels(i).name = obj(i).name;
                channels(i).type = obj(i).type;
                channels(i).sn = obj(i).sn;
                channels(i).tag = obj(i).saga;
                channels(i).unit_name = obj(i).unit_name;
            end
        end
    end

    methods (Static)
        function channels = DefaultSet(setType, varargin)
            %DEFAULTSET  Returns default cell array of channels
            %
            % Syntax:
            %   channels = TMSiSAGA.Channel.DefaultSet();
            %   channels = TMSiSAGA.Channel.DefaultSet(setType);
            %   channels = TMSiSAGA.Channel.DefaultSet(setType,'Name',value,...);
            %
            % Inputs:
            %   setType - The channel-set type. See options in
            %               `enum.TMSiChannelSet`. If not given, then the
            %               default value of this is
            %                   enum.TMSiChannelSet.NHP_EMG
            %   'Name',value pairs:
            %       + 'ChannelSetsFolder' - Default is the package folder
            %                               with sub-folder 'ChannelSets'
            %
            % See also: Contents, enum, enum.TMSiChannelSet
            
            % For file i/o
            base_file_folder = fileparts(mfilename('fullpath'));
            ChannelSetsDefault = fullfile(base_file_folder, 'ChannelSets');

            % Validation functions
            setTypeValidator = @(in)isa(in, 'enum.TMSiChannelSet');
            ChannelSetsFolderParamValidator = @(in)((isstring(in)||ischar(in)) && (exist(in,'dir')~=0) && (~isempty(dir(fullfile(in, '*.mat')))));
            if (nargin < 2) || ~ismember('ChannelSetsFolder', varargin(1:3:end))
                assert(ChannelSetsFolderParamValidator(ChannelSetsDefault), ...
                    'TMSiSAGA:Channel:EmptyChannelSetsFolder', ...
                    'No *.mat files found in default ChannelSetsFolder (%s).', ...
                    ChannelSetsDefault);
            end
            TagParamValidator = @(in)((isstring(in) || ischar(in)) && ismember(char(in), {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'}));

            % Handle default
            if (nargin < 1) || isempty(setType)
                setType = enum.TMSiChannelSet.NHP_EMG;
            elseif ischar(setType) || isstring(setType)
                if ~ismember(char(setType), {'NHP_EMG', 'NHP'})
                    firstParam = char(setType);
                    setType = enum.TMSiChannelSet.NHP_EMG;
                    varargin = [firstParam, varargin];
                else
                    setType = enum.TMSiChannelSet.(setType);
                end
            end

            % Parse inputs
            p = inputParser();
            p.addRequired('setType', setTypeValidator);
            p.addParameter('ChannelSetsFolder', ChannelSetsDefault, ChannelSetsFolderParamValidator);
            p.addParameter('Tag', 'X', TagParamValidator);
            p.parse(enum.TMSiChannelSet(setType), varargin{:});
            pname = p.Results.ChannelSetsFolder;
            switch p.Results.setType
                case enum.TMSiChannelSet.NHP_EMG
                    ch = getfield(load(fullfile(pname, 'NHP_EMG.mat'), 'channels'), 'channels');
                otherwise
                    error("Unhandled TMSiChannelSet enumeration: %s", string(p.Results.setType));
            end
            setSAGA(ch, p.Results.Tag);
            channels = toCell(ch);
        end
    end
end