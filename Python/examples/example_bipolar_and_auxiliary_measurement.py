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

Example : This example shows the functionality to display the output of an AUX 
            sensor and the output of a simultaneously sampled BIP channel on 
            the screen. To do so, the channel configuration is updated and a 
            call is made to update the sensor channels. The data is saved to a 
            Poly5 file. 

@version: 2021-06-07

'''

import sys
sys.path.append("../")

from PySide2 import QtWidgets

from TMSiSDK import tmsi_device
from TMSiSDK import plotters
from TMSiSDK.device import DeviceInterfaceType, ChannelType, DeviceState
from TMSiSDK.file_writer import FileWriter, FileFormat
from TMSiSDK.error import TMSiError, TMSiErrorCode, DeviceErrorLookupTable


try:
    # Initialise the TMSi-SDK first before starting using it
    tmsi_device.initialize()
    
    # Create the device object to interface with the SAGA-system.
    dev = tmsi_device.create(tmsi_device.DeviceType.saga, DeviceInterfaceType.docked, DeviceInterfaceType.usb)
    
    # Find and open a connection to the SAGA-system and print its serial number
    dev.open()
    
    # Set the sample rate of the AUX channels to 4000 Hz
    dev.config.base_sample_rate = 4000
    dev.config.set_sample_rate(ChannelType.AUX, 1)
    dev.config.set_sample_rate(ChannelType.BIP, 1)
    
    # Enable BIP 01, AUX 1-1, 1-2 and 1-3
    AUX_list = [0,1,2]
    BIP_list = [0]
    
    # Retrieve all channels from the device and update which should be enabled
    ch_list = dev.config.channels
    
    # The counters are used to keep track of the number of AUX and BIP channels 
    # that have been encountered while looping over the channel list
    AUX_count = 0
    BIP_count = 0
    for idx, ch in enumerate(ch_list):
        if (ch.type == ChannelType.AUX):
            if AUX_count in AUX_list:
                ch.enabled = True
            else:
                ch.enabled = False
            AUX_count += 1
        elif (ch.type == ChannelType.BIP):
            if BIP_count in BIP_list:
                ch.enabled = True
            else:
                ch.enabled = False
            BIP_count += 1
        else :
            ch.enabled = False
    dev.config.channels = ch_list
    
    # Update sensor information
    dev.update_sensors()
    
    # Initialise a file-writer class (Poly5-format) and state its file path
    file_writer = FileWriter(FileFormat.poly5, "./measurements/Example_BIP_and_AUX_measurement.poly5")
    # Define the handle to the device
    file_writer.open(dev)
    
    # Check if there is already a plotter application in existence
    plotter_app = QtWidgets.QApplication.instance()
    
    # Initialise the plotter application if there is no other plotter application
    if not plotter_app:
        plotter_app = QtWidgets.QApplication(sys.argv)
    
    # Define the GUI object and show it
    plot_window = plotters.RealTimePlot(figurename = 'A RealTimePlot', device = dev)
    plot_window.show()
    
    # Enter the event loop
    plotter_app.exec_()
    
    # Delete the Plotter application
    del plotter_app
    
    # Close the file writer after GUI termination
    file_writer.close()
    
    # Close the connection to the SAGA device
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