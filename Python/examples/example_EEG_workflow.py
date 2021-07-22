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

Example : This example shows the functionality of the impedance plotter and the 
            data stream plotter. The example is structured as if an EEG 
            measurement is performed, so the impedance plotter is displayed in 
            head layout. The channel names are set to the name convention of 
            the TMSi EEG cap using a pre-configured EEG configuration. 

@version: 2021-06-07

'''

import sys
sys.path.append("../")
import time

from PySide2 import QtWidgets

from TMSiSDK import tmsi_device
from TMSiSDK import plotters
from TMSiSDK.device import DeviceInterfaceType, DeviceState
from TMSiSDK.file_writer import FileWriter, FileFormat
from TMSiSDK.error import TMSiError, TMSiErrorCode, DeviceErrorLookupTable


try:
    # Initialise the TMSi-SDK first before starting using it
    tmsi_device.initialize()
    
    # Create the device object to interface with the SAGA-system.
    dev = tmsi_device.create(tmsi_device.DeviceType.saga, DeviceInterfaceType.docked, DeviceInterfaceType.usb)
    
    # Find and open a connection to the SAGA-system and print its serial number
    dev.open()
    
    # Load the EEG channel set and configuration
    print("load EEG config")
    if dev.config.num_channels<64:
        dev.load_config("./configs/saga_config_EEG32.xml")
    else:
        dev.load_config("./configs/saga_config_EEG64.xml")
    
    
    # Check if there is already a plotter application in existence
    plotter_app = QtWidgets.QApplication.instance()
    
    # Initialise the plotter application if there is no other plotter application
    if not plotter_app:
        plotter_app = QtWidgets.QApplication(sys.argv)
        
    # Define the GUI object and show it
    window = plotters.ImpedancePlot(figurename = 'An Impedance Plot', device = dev, layout = 'head')
    window.show()
    
    # Enter the event loop
    plotter_app.exec_()
    
    # Pause for a while to properly close the GUI after completion
    print('\n Wait for a bit while we close the plot... \n')
    time.sleep(1)
    
    # Initialise a file-writer class (Poly5-format) and state its file path
    file_writer = FileWriter(FileFormat.poly5, "./measurements/measurement1.poly5")
    # Define the handle to the device
    file_writer.open(dev)

    # Define the GUI object and show it 
    # The channel selection argument states which channels need to be displayed initially by the GUI
    plot_window = plotters.RealTimePlot(figurename = 'A RealTimePlot', 
                                        device = dev, 
                                        channel_selection = [0,1,2])
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