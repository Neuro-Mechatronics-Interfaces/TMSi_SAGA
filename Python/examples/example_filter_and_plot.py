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

Example : This example shows how to couple an additional signal processing object
            to the plotter. The application of a bandpass filter on the first 
            24 UNI channels is demonstrated. The filter is only applied to the 
            plotter, the saved data does not contain any filtered data. 

@version: 2021-06-07

'''

import sys
sys.path.append("../")

from PySide2 import QtWidgets
import numpy as np

from TMSiSDK import tmsi_device
from TMSiSDK import plotters
from TMSiSDK.device import DeviceInterfaceType, ChannelType, DeviceState
from TMSiSDK.error import TMSiError, TMSiErrorCode, DeviceErrorLookupTable
from TMSiSDK.file_writer import FileWriter, FileFormat
from TMSiSDK import filters


try:
    # Initialise the TMSi-SDK first before starting using it
    tmsi_device.initialize()
    
    # Create the device object to interface with the SAGA-system.
    dev = tmsi_device.create(tmsi_device.DeviceType.saga, DeviceInterfaceType.docked, DeviceInterfaceType.usb)
    
    # Find and open a connection to the SAGA-system and print its serial number
    dev.open()
    
    # Set the sample rate to 500 Hz
    dev.config.base_sample_rate = 4000
    dev.config.set_sample_rate(ChannelType.all_types, 8)
    
    # Enable UNI channels 1 to 24
    UNI_list = np.arange(1,25)
    
    # Retrieve all channels from the device and update which should be enabled
    ch_list = dev.config.channels
    
    #Initialise counter per channel type
    UNI_count = 0
   
    for idx, ch in enumerate(ch_list):
        if (ch.type == ChannelType.UNI):
            if UNI_count in UNI_list:
                ch.enabled = True
            else:
                ch.enabled = False
            UNI_count += 1
        else :
            ch.enabled = False
    dev.config.channels = ch_list
    
    # Initialise a file-writer class (Poly5-format) and state its file path
    file_writer = FileWriter(FileFormat.poly5, "./measurements/example_filter_and_plot.poly5")
    # Define the handle to the device
    file_writer.open(dev)
    
    # Initialise filter
    filter_appl = filters.RealTimeFilter(dev)
    filter_appl.generateFilter(Fc_hp=5, Fc_lp=100)
    
    # Check if there is already a plotter application in existence
    plotter_app = QtWidgets.QApplication.instance()
    
    # Initialise the plotter application if there is no other plotter application
    if not plotter_app:
        plotter_app = QtWidgets.QApplication(sys.argv)
    
    # Define the GUI object and show it
    plot_window = plotters.RealTimePlot(figurename = 'A RealTimePlot', 
                                        device = dev, 
                                        channel_selection = [0, 1, 2], 
                                        filter_app = filter_appl)
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
        print("  => device error : 0x", hex(dev.status.error))
        DeviceErrorLookupTable(hex(dev.status.error))
        
finally:
    # Close the connection to the device when the device is opened
    if dev.status.state == DeviceState.connected:
        dev.close()
