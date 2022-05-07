classdef Sensor < TMSiSAGA.HiddenHandle
    %SENSOR - A class that represents a TMSi Sensor.
    %
    %   A class that represents one of the TMSi sensors. It keeps track of all sensors
    %   that are retrieved from the TMSi device. This class is not directly correlated
    %   to a sensor channel. Is for internal use.
    %
    %SENSOR Properties:
    %   device - Device
    %   channel_number - Channel Number
    %   io_mode - IO Mode
    %   sensor_id - Sensor ID
    %   sensor_meta_data - Sensor meta data
    %   manufacturer_id - Manufacturer identification number
    %   serial_number - Sensor Serial Number
    %   product_identifier - Product identifier
    %   num_channels - Sensor Channels
    %   num_additional_structs - Additional structs
    %   channels - Channels
    %
    %SENSOR Methods:
    %   Sensor - Constructor for the Sensor object.
    
    properties
        % Device
        device

        % Channel Number
        channel_number

        % IO Mode
        io_mode

        % Sensor ID
        sensor_id
        
        % Sensor meta data
        sensor_meta_data

        % Manufacturer identification number
        manufacturer_id

        % Sensor Serial Number
        serial_number

        % Product identifier
        product_identifier

        % Sensor Channels
        num_channels

        % Additional structs
        num_additional_structs

        % Channels
        channels
    end

    methods
        function obj = Sensor(device, sensor_info) 
            %SENSOR - Constructor for the Sensor object.
            %
            %   obj = Sensor(device, sensor_info) 
            %
            %   obj [out] - Sensor object.
            %   device [in] - Device object.
            %   sensor_info [in] - List with sensor information obtained from the device.
            %
            
            if numel(sensor_info) > 1
                obj = repmat(obj, size(sensor_info));
                for ii = 1:numel(sensor_info)
                    obj(ii) = TMSiSAGA.Sensor(device, sensor_info(ii));
                end
                return;
            end
            
            obj.device = device;
            obj.channel_number = sensor_info.ChanNr;
            obj.io_mode = sensor_info.IOMode;
            obj.sensor_meta_data = uint8(sensor_info.SensorMetaData);
            obj.sensor_id = sensor_info.SensorID;
            obj.manufacturer_id = typecast(obj.sensor_meta_data(1:2), 'uint16');
            obj.serial_number = typecast(obj.sensor_meta_data(3:6), 'uint32');
            obj.product_identifier = typecast(obj.sensor_meta_data(7:14), 'uint64');
            obj.num_channels = typecast(obj.sensor_meta_data(15:15), 'uint8');
            obj.num_additional_structs = typecast(obj.sensor_meta_data(16:16), 'uint8');
%             obj.channels = TMSiSAGA.SensorChannelDummy.empty;
            channels = {};

            meta_data_start = 17;
            for i=1:obj.num_channels
                % Check whether recognised sensor is a Type0 or Dummy
                % sensor type. Only link sensors that are Type0 sensors. 
                if typecast(obj.sensor_meta_data(meta_data_start:meta_data_start+1), 'uint16') == hex2dec('0000')
                    channels{i} = obj.createChannel(double(obj.channel_number) + i - 1, obj.sensor_meta_data(meta_data_start:end)); %#ok<AGROW>
                    channels{i}.linkChannel(device.channels(double(obj.channel_number) + i));                    
                end
                meta_data_start = meta_data_start + channels{end}.size();
            end
            obj.channels = vertcat(channels{:});
        end
    end

    methods(Access = private)
        function sensor_channel = createChannel(obj, channel_number, meta_data) 
            %CREATECHANNEL - Function to create a sensor channel. 
            %
            %   sensor_channel = createChannel(obj, channel_number, meta_data)
            %
            %   sensor_channel [out] - Sensor channel object (Type0 or Dummy).
            %   obj [in] - Sensor object.
            %   channel_number [in] - Sensor channel identification number.
            %   meta_data [in] - Meta data of the sensor channel obtained from the sensor. 
            %
            struct_id = typecast(meta_data(1:2), 'uint16');

            switch struct_id
                case hex2dec('0000')
                    sensor_channel = TMSiSAGA.SensorChannelType0(obj, channel_number, meta_data);
                case hex2dec('FFFF')
                    sensor_channel = TMSiSAGA.SensorChannelDummy(obj, channel_number, meta_data); 
                otherwise
                    throw(MException('SensorChannel:parse', 'Invalid sensor channel struct id.'));
            end
        end
    end
end
