%EXAMPLE - Sample data and store in memory
%   Sample data from the device and store the resulting samples in a Data
%   objects that is directly accessible in Matlab. Close the plot window to
%   stop the sampling. Sampled data is accessible in the data variable.
%

% Initialize the library
lib = TMSiSAGA.Library();

%% Set up the DAQ (Mcc daq)

%Get the MCC DAQ available to our Machine and MATLAB
devices = daq.getDevices;

%Create a session using MCC DAQ and set the output rate
session = daq.createSession('ni');
session.Rate = 50000;

%Set the output analog channel to signal to the stimulator
deviceName = 'Dev1';
channelID = 'ao0';
measurementType = 'Voltage';

addAnalogOutputChannel(session,deviceName,channelID,measurementType);

%% Create the stim pulses

% parameters for trigger pulse wave
PW = 500*10^-6;         % 200 us - will send a single '5V' to trigger stim on bc update rate is 200 us
PA = 5;                      % 5 V
PF = 100;                    % pulse frequency - change depending on how often you want it to trigger stim(10 pulses per second)
period = 1/PF;            % In seconds
% session.Rate = 500000;        % output rate - limits us to 200 us PW
IPI = round((period-PW)*session.Rate); %Inter pulse Interval


restPeriod = 2 ; %in seconds
IBI = round(restPeriod *session.Rate); %Inter Bursts Interval


%Create single pulse
%Design the square wave based on the maximum session rate of the DAQ
%system(PW*a_s.Rate this scaling the output based on the DAQ maximum output rate)
y = [PA*ones(1,round(PW*session.Rate)) zeros(1,IPI)];       % this is where you can make a square wave adjust as needed
plot(y)

y = y';
trainy = y;


%create train of pulses with IPI
train_pulses = repmat(trainy,PF,1); %ten pulses per second
% figure(1)
% plot(train_pulses)
% set(gca,'ylim',[0 PA+.5])
% title('Single bursts with IPI')


%create train of pulses with IBI
%Add the Inter Burst Interval
trian_pulses_withIBI = [train_pulses;zeros(IBI,1)];
% figure(2)
% plot(trian_pulses_withIBI)
% set(gca,'ylim',[0 PA+.5])
% title(['train of pulses with Inter Burst Period : ' num2str(restPeriod) ' Seconds!'])


% TMSI


% Code within the try-catch to ensure that all devices are stopped and
% closed properly in case of a failure.
try
    % Get a single device from the connected devices
    device = lib.getFirstAvailableDevice('usb', 'electrical');
    
    % Open a connection to the device
    device.connect();
    
    % Reset device config
    device.resetDeviceConfig();
    
    % We need to update the configuration of the device
    device.updateDeviceConfig();
    
    % Create a real time plot
    rPlot = TMSiSAGA.RealTimePlot('Plot', device.sample_rate, device.getActiveChannels());
%     %     rPlot.show();
    
    % Create a file storage
    data = TMSiSAGA.Data('Plot', device.sample_rate, device.getActiveChannels());
    
    % Start sampling on the device
    device.start();
    
    % As long as we do not press the X or 'q' keep on sampling from the
    % device.
    %     while rPlot.is_visible
    
    
    
    
    for i = 1:10000
        % Sample from device
        [samples, num_sets, type] = device.sample();
        
        % Append samples to the plot and redraw
        if num_sets > 0
            rPlot.append(samples);
            data.append(samples);
            
            
            
            
            trialnum = 5; %number of trials
            trialDuration = length(trian_pulses_withIBI)/session.Rate; %In seconds
            
            triggersVector = repmat(trian_pulses_withIBI,trialnum,1);
            
            
            time = ((0 : length(triggersVector)-1)/session.Rate)';
            figure(3)
            plot(time,triggersVector)
            set(gca,'ylim',[0 PA+.5])
            xlabel('Time(s)'),ylabel('Voltage')
            title(['Bursts vector for ' num2str(trialnum) ' trials'])
            
            
            
            % save output waveform before sending to DAQ
            queueOutputData(session,triggersVector);
            % send to stimulator
            startForeground(session);
            
            figure(1);
            rPlot.draw();
        end
    end
    % Stop sampling on the device
    device.stop();
    
    % Disconnect from device
    device.disconnect();
catch e
    
    % In case of an error close all still active devices and clean up
    % library itself
    lib.cleanUp();
    
    % Rethrow error to ensure you get a message in console
    rethrow(e)
end