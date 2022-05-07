classdef Library < TMSiSAGA.HiddenHandle
    %LIBRARY Class to initialize the TMSiSAGA library.
    %
    %   This class has to be instantized atleast once in your application. It will allow you
    %   to query devices, based on the interface of the docking station and data recorder. 
    %   It also keeps track of which devices are currently in open state and/or are currently
    %   in sampling mode. The function cleanUp(), can be used to stop all sampling and disconnect
    %   all devices created with this library, it will also unload the currently library to leave
    %   the entire system in a stable state. The function cleanUp() should be used in a try catch
    %   statement (see examples on how to use it).
    %
    %LIBRARY Properties:
    %   connected_devices - Keep tracks of all open devices
    %   sampling_devices - Keep track of all sampling devices
    %   
    %LIBRARY Methods:
    %   Library - Constructor to create an instance of this object.
    %   getDevices - Get a list of Device objects of all found devices.
    %   getDevice - Get a single Device object based on id and interface type.
    %   getFirstAvailableDevice - Get first available device on given interfaces.
    %   deviceConnected - (internal use) Called when a device connects.
    %   deviceDisconnected - (internal use) Called when a device disconnects.
    %   deviceStartedSampling - (internal use) Called when a device starts sampling.
    %   deviceStoppedSampling - (internal use) Called when a device stops sampling.
    %   stopSamplingOnAllDevices - Stop all devices that are currently sampling.
    %   disconnectAllDevices - Disconnect all device that are currently open.
    %   cleanUp - All devices stop sampling, and are disconnected, and library is unloaded.
    %
    %LIBRARY Example 1:
    %   library = TMSiSAGA.Library();
    %
    %   device = library.getFirstAvailableDevice('network', 'electrical');
    %
    %   library.cleanUp();
    %
    %LIBRARY Example 2:
    %   library = TMSiSAGA.Library();
    %   
    %   try
    %       % Code and device sampling here
    %   catch e
    %       library.cleanUp();
    %   end
    %
    %LIBRARY Example 3:
    %   library = TMSiSAGA.Library();
    %   
    %   try
    %       device = library.getDevice(1, 'wifi');
    %
    %       % Code and device sampling here
    %   catch e
    %       library.cleanUp();
    %   end

    properties
        % Keep tracks of all open devices
        connected_devices

        % Keep track of all sampling devices
        sampling_devices 
    end

    methods
        function obj = Library()
            %LIBRARY - Initialize the library 
            %
            %   obj = Library()
            %
            %   obj [out/in] - Library object.
            %
            
            obj.connected_devices = {};
            obj.sampling_devices = {};
            TMSiSAGA.Library.loadLibrary();
        end
        
        function delete(obj)
           %DELETE  Overload delete method to ensure we always clean up...
            obj.cleanUp(); 
        end

        function devices = getDevices(obj, ds_interface, dr_interface, numOfRetries)
            %GETDEVICES - Get a list of devices that are connected to the
            %PC with the specified interfaces. By default it searches on
            %ds_interface = network and dr_interface = electrical.
            %
            %   devices = getDevices(obj, ds_interface, dr_interface, numOfRetries)
            %
            %   devices [out] - List of devices connected to the PC over the specified interface. 
            %   obj [in] - Library object.
            %   ds_interface [in] - (Optional) Interface type that is used the docking station.
            %   dr_interface [in] - (Optional) Interface type that is used by the data recorder.
            %   numOfRetries [in] - (Optional) Number of retries that are performed to discover connected devices.
            
            if ~exist('ds_interface', 'var')
                ds_interface = {'usb', 'network'};
            else
                if ~iscell(ds_interface)
                    ds_interface = {ds_interface};
                end
            end
        
            if ~exist('dr_interface', 'var')
                dr_interface = {'electrical', 'optical', 'wifi'};
            else
                if ~iscell(dr_interface)
                    dr_interface = {dr_interface};
                end
            end

            if ~exist('numOfRetries', 'var')
                numOfRetries = 2;
            end
            
            % Get a list of all connected devices
            devices = [];
            for k = 1:numel(ds_interface)
                for j = 1:numel(dr_interface)
                    try
                        device_list = TMSiSAGA.DeviceLib.getDeviceList(...
                            TMSiSAGA.TMSiUtils.toInterfaceTypeNumber(ds_interface{k}), ...
                            TMSiSAGA.TMSiUtils.toInterfaceTypeNumber(dr_interface{j}), numOfRetries);
                    catch
                        fprintf(1, 'No devices on interface (<strong>%s::%s</strong>)\n', ds_interface{k}, dr_interface{j});
                        continue;
                    end

                    % Create a device object for all discovered devices
                    for i=1:numel(device_list)
                        devices = vertcat(devices, TMSiSAGA.Device(obj, int64(device_list(i).TMSiDeviceID), dr_interface{j})); %#ok<AGROW>
                    end
                end
            end
            if isempty(devices)
                fprintf(1, '\t->\tNo devices found.\n');
            end
        end

        function device = getDevice(obj, device_id, dr_interface)
            %GETDEVICE - Get a single device by ID and DR interface.
            %
            %   device = getDevice(obj, device_id, dr_interface)
            %
            %   device [out] - Discovered device with the specified id and Data Recorder interface type.
            %   obj [in] - Library object.
            %   device_id [in] - Unique device id for this device.
            %   dr_interface [in] - Interface type that is used by the data recorder.
            %
            
            device = TMSiSAGA.Device(obj, int64(device_id), dr_interface);
        end

        function device = getFirstAvailableDevice(obj, ds_interface, dr_interface, numOfRetries)
            %GETFIRSTAVAILABLEDEVICE - Get the first device available on
            %   the selected interfaces. It will select the first one that is
            %   'available', this is just the first device that is returned by
            %   the getDevices function.
            %
            %   device = getFirstAvailableDevice(obj, ds_interface, dr_interface, numOfRetries)
            %
            %   device [out] - First availabe device connected to the PC over the specified interface. 
            %   obj [in] - Library object.
            %   ds_interface [in] - (Optional) Interface type that is used the docking station.
            %   dr_interface [in] - (Optional) Interface type that is used by the data recorder.
            %   numOfRetries [in] - (Optional) Number of retries that are performed to discover connected devices.
           
            if ~exist('ds_interface', 'var')
                ds_interface = 'network';
            end
        
            if ~exist('dr_interface', 'var')
                dr_interface = 'electrical';
            end
            
            if ~exist('numOfRetries', 'var')
                numOfRetries = 0;
            end
        
            % Get a list of all connected devices
            devices = obj.getDevices(ds_interface, dr_interface, numOfRetries);
        
            if numel(devices) < 1
                throw(MException('getFirstDevice', 'No device found'));
            end
            % Output the first discovered device
            device = devices{1};
        end

        function deviceConnected(obj, device)
            %DEVICECONNECTED - This function is used by the framework to
            %   keep track what device has been connected so far. Should not be
            %   used by the user.
            %
            %   deviceConnected(obj, device)
            %
            %   obj [in] - Library object.
            %   device [in] - Connected device.
            %
            
            for i=1:numel(obj.connected_devices)
                if obj.connected_devices{i}.device_id == device.device_id
                    return
                end
            end

            obj.connected_devices{numel(obj.connected_devices) + 1} = device;
        end

        function deviceDisconnected(obj, device)
            %DEVICEDISCONNECTED - This function is used by the framework to
            %   keep track which device has been disconnected. Should not be
            %   used by the user.
            %
            %   deviceDisconnected(obj, device)
            %
            %   obj [in] - Library object.
            %   device [in] - Connected device.
            %
            
            index = false(1, numel(obj.connected_devices));
            
            for i=1:numel(obj.connected_devices)
                index(i) = obj.connected_devices{i}.device_id ~= device.device_id;
            end

            obj.connected_devices = obj.connected_devices(index);
        end

        function deviceStartedSampling(obj, device)
            %DEVICESTARTEDSAMPLING - Is called by the framework when a
            %   device has started sampling. Should not be called by the user
            %   directly.
            %
            %   deviceStartedSampling(obj, device)
            %   
            %   obj [in] - Library object.
            %   device [in] - Connected device.
            %
            
            for i=1:numel(obj.sampling_devices)
                if obj.sampling_devices{i}.device_id == device.device_id
                    return
                end
            end

            obj.sampling_devices{numel(obj.sampling_devices) + 1} = device;
        end

        function deviceStoppedSampling(obj, device)
            %DEVICESTOPPEDSAMPLING - Is called by the framework when a
            %   device has stopped sampling. Should not be called by the user
            %   directly.
            %
            %   deviceStoppedSampling(obj, device)
            %
            %   obj [in] - Library object.
            %   device [in] - Connected device.
            %
            
            index = false(1, numel(obj.sampling_devices));
            
            for i=1:numel(obj.sampling_devices)
                index(i) = obj.sampling_devices{i}.device_id ~= device.device_id;
            end

            obj.sampling_devices = obj.sampling_devices(index);
        end

        function stopSamplingOnAllDevices(obj)
            %STOPSAMPLINGONALLDEVICES - A function that can be called to
            %   stop sampling on all connected and sampling devices.
            %
            %   stopSamplingOnAllDevices(obj)
            %
            %   obj [in] - Library object.
            %
            
            for i=1:numel(obj.sampling_devices)
                obj.sampling_devices{i}.stop();
            end
        end

        function disconnectAllDevices(obj)
            %DISCONNECTALLDEVICES - A function that can be called to
            %   disconnect all devices that are currently connected.
            %
            %   disconnectAllDevices(obj)
            %
            %   obj [in] - Library object.
            %
            
            for i=1:numel(obj.connected_devices)
                obj.connected_devices{i}.disconnect();
            end
        end

        function cleanUp(obj)
            %CLEANUP - Call this function when you have to 'reset' the
            %   devices. It will stop sampling on all devices, then
            %   disconnects all devices and finally unloads the library.
            %   Starting new sampling requires you to create a new library.
            %
            %   cleanUp(obj)
            %
            %   obj [in] - Library object.
            %          
            try
                obj.stopSamplingOnAllDevices();
            catch me
                fprintf(1, '\t->\tFailed to stop device sampling with following error message: <strong>%s</strong>\n', me.message);
            end
            try
                obj.disconnectAllDevices();
            catch me
                fprintf(1, '\t->\tFailed disconnect with following error message: <strong>%s</strong>\n', me.message);
            end
            try
                TMSiSAGA.Library.unloadLibrary();
            catch me
                fprintf(1, '\t->\tFailed to unload library with following error message: <strong>%s</strong>\n', me.message);
            end
        end
    end
    
    methods (Static, Access = public)
        function tf = isLoaded()
            tf = libisloaded('TMSiSagaDeviceLib'); 
        end
        
        function loadLibrary()
            if TMSiSAGA.Library.isLoaded()
                disp('Library is already loaded.');
            else
                loadlibrary('TMSiSagaDeviceLib.dll', @TMSiSAGA.TMSiSagaDeviceLib64);
            end
        end

        function unloadLibrary()
            if TMSiSAGA.Library.isLoaded()
                unloadlibrary TMSiSagaDeviceLib;
            else
                disp('Library was not loaded.');
            end
        end
    end
end