'''
Copyright 2021 Twente Medical Systems international B.V., Oldenzaal The Netherlands

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

#######  #     #   #####   #  ######      #     #
   #     ##   ##  #        #  #     #     #     #
   #     # # # #  #        #  #     #     #     #
   #     #  #  #   #####   #  ######       #   #
   #     #     #        #  #  #     #      #   #
   #     #     #        #  #  #     #       # #
   #     #     #  #####    #  ######   #     #     #

Example : This example shows how to change the interface between SAGA's Docking
            Station and Data Recorder. 

@version: 2021-06-07

'''
import sys
sys.path.append("../")

import time

from TMSiSDK import tmsi_device
from TMSiSDK.error import TMSiError, TMSiErrorCode, DeviceErrorLookupTable
from TMSiSDK.device import DeviceInterfaceType, DeviceState
from TMSiSDK.file_writer import FileWriter, FileFormat

try:
    # Initialize the TMSi-SDK first before starting using it
    tmsi_device.initialize()

    # Create the device object to interface with the SAGA-system.
    dev = tmsi_device.create(tmsi_device.DeviceType.saga, DeviceInterfaceType.docked, DeviceInterfaceType.usb)

    # Find and open a connection to the SAGA-system
    dev.open()
    
    # Choose the desired DR-DS interface type 
    dev.config.set_interface_type(DeviceInterfaceType.optical)
    
    # Close the connection to the device (with the original interface type)
    dev.close()
    
    # Wait for a bit while the connection is closed
    time.sleep(1)
    
    # Create the device object with the new interface type
    dev = tmsi_device.create(tmsi_device.DeviceType.saga, DeviceInterfaceType.optical, DeviceInterfaceType.usb)
    
    # Find and open the connection to the SAGA-system
    dev.open()

    ch_list = dev.config.channels
    
    for idx, ch in enumerate(ch_list):
        ch.enabled = True
    dev.config.channels = ch_list

    # Before the measurement starts first a file-writer-object must be created and opened.
    # Upon creation specify :
    #   - the data-format 'poly5' to be used
    #   - the filepath/name, where the file must be stored
    # then 'link' the file-writer-instance to the device.
    # The file-writer-object is now ready to capture the measurement-data and
    # write it to the specified file.
    file_writer = FileWriter(FileFormat.poly5, "./measurements/switched_interface_type_measurement.poly5")
    file_writer.open(dev)

    # Start the measurement and wait 10 seconds. In the mean time the file-writer-instance
    # will capture the sampling data and store it into the specified file in the 'poly5'-data format.
    dev.start_measurement()

    # Wait for 10 seconds
    time.sleep(10)

    # Stop the measurement
    dev.stop_measurement()

    # Close the file-writer-instance.
    # The sample-data of the measurement has been archived into the specified file.
    file_writer.close()

    # Close the connection to the SAGA-system
    dev.close()

except TMSiError as e:
    print("!!! TMSiError !!! : ", e.code)
    if (e.code == TMSiErrorCode.device_error) :
        print("  => device error : ", hex(dev.status.error))
        DeviceErrorLookupTable(hex(dev.status.error))
        
finally:
    # Close the connection to the device when the device is opened
    if dev.status.state == DeviceState.connected:
        dev.close()