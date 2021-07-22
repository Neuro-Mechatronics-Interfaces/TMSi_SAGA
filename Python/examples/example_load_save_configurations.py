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

Example : This example shows how to load/save several different configurations 
            from/to a file (in the “configs” directory). 

@version: 2021-06-07

'''
import sys
sys.path.append("../")


from TMSiSDK import tmsi_device
from TMSiSDK.device import DeviceInterfaceType, ChannelType, DeviceState
from TMSiSDK.error import TMSiError, TMSiErrorCode, DeviceErrorLookupTable

try:
    # Initialize the TMSi-SDK first before starting using it
    tmsi_device.initialize()

    # Create the device object to interface with the SAGA-system.
    dev = tmsi_device.create(tmsi_device.DeviceType.saga, DeviceInterfaceType.docked, DeviceInterfaceType.usb)

    # Find and open a connection to the SAGA-system
    dev.open()

    # Upload a configuration from file to the device and print the active channel list
    # of this configuration
    print('Loading a configuration with one active UNI-channel : \n')
    if dev.config.num_channels<64:
        dev.load_config("./configs/saga_config_minimal32.xml")
    else:
        dev.load_config("./configs/saga_config_minimal.xml")
    
    for idx, ch in enumerate(dev.channels):
         print('[{0}] : [{1}] in [{2}]'.format(idx, ch.name, ch.unit_name))

    # Enable all UNI-channels, print the updated active channel list and save the new configuration to file
    print('\nActivate all UNI-channels : and save the configuration to the file [..\\configs\\saga_config_current.xml]')
    ch_list = dev.config.channels
    for idx, ch in enumerate(ch_list):
        if (ch.type == ChannelType.UNI):
            ch.enabled = True
        else :
            ch.enabled = False
    dev.config.channels = ch_list
    for idx, ch in enumerate(dev.channels):
         print('[{0}] : [{1}] in [{2}]'.format(idx, ch.name, ch.unit_name))

    print('\nSave the configuration to the file [..\\configs\\saga_config_current.xml]')
    dev.save_config("./configs/saga_config_current.xml")

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