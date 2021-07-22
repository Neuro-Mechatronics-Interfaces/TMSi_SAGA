function StimHreflexTMSi
close all
clear all %#ok<CLALL>.
global handles
global s0
handles = struct;
% delete any existing instruments on startup
delete(instrfind) %cleaning things
handles.MainWindow = figure('Name','StimGUI','Units','Normalized',...
    'Outerposition',[0 0 1 1],'Visible', 'On','Color',[0.5412 1 0.8039]);
handles.LeftPanel= uipanel('Parent',handles.MainWindow,'BorderType','none',...
    'Units','normalized','Position',[0 0 0.5 1],'BackgroundColor',[0.5412 1 0.8039]);
handles.RightPanel= uipanel('Parent',handles.MainWindow,'BorderType','none',...
    'Units','normalized','Position',[0.5 0 0.5 1],'BackgroundColor',[0.5412 1 0.8039]);
% check that DAQ is connected and recongnized by computer
handles.daqdisplay = uicontrol('Parent',handles.LeftPanel,'Style','text',...
    'BackgroundColor',[0.5412 1 0.8039],'Units','Normalized',...
    'Position',[0.02 0.94 0.1 0.05],'FontSize',11,'ForegroundColor',[0 0 0],'String',[]);
refreshDAQ
handles.Refresh = uicontrol('Parent',handles.LeftPanel,'Units',...
    'Normalized','Style','pushbutton','Position',[.15 .95 .18 .035],...
    'String','Refresh DAQ','BackgroundColor',[0 0.455 1],'FontSize',16,...
    'ForegroundColor',[1,1,1],'Callback',{@refreshDAQ});
handles.PulseWidthText = uicontrol('Style','text','BackgroundColor',[0.5412 1 0.8039],...
    'parent',handles.LeftPanel,'units','normalized','ForegroundColor',[0 0 0],...
    'Position',[0.01 0.88 0.2 0.05],'String','Pulse Width (ms)','FontSize',14);
handles.PulseWidth = uicontrol('Style','edit','parent',handles.LeftPanel,...
    'units','normalized','position',[0.25 0.9 0.07 0.04],'FontSize',14,...
    'Callback',{@pulsewidth_callback});
handles.AmpText = uicontrol('Style','text','BackgroundColor',[0.5412 1 0.8039],...
    'parent',handles.LeftPanel,'units','normalized','ForegroundColor',[0 0 0],...
    'position',[0.0 0.825 0.2 0.05],'String','Amplitude (mA)','FontSize',14);
handles.Amp = uicontrol('Style','edit','parent',handles.LeftPanel,...
    'units','normalized','position', [0.25 0.845 0.07 0.04],'FontSize',14,...
    'Callback',{@stimamp_callback});
handles.SingleStim = uicontrol('Parent',handles.LeftPanel,'Units',...
    'Normalized','Style','pushbutton','Position',[.05 .79 .25 .045],...
    'String','Stim Single Pulse','BackgroundColor',[0 0.455 1],'FontSize',16,...
    'ForegroundColor',[1,1,1],'Callback',{@singleStim});
handles.LowerAmpText = uicontrol('Style','text','BackgroundColor',[0.5412 1 0.8039],...
    'parent',handles.LeftPanel,'units','normalized','ForegroundColor',[0 0 0],...
    'position',[0.02 0.71 0.2 0.05],'String','Lower Amp Limit (mA)','FontSize',14);
handles.LowerAmp = uicontrol('Style','edit','parent',handles.LeftPanel,...
    'units','normalized','position', [0.25 0.73 0.07 0.04],'FontSize',14,...
    'Callback',{@loweramp_callback});
handles.UpperAmpText = uicontrol('Style','text','BackgroundColor',[0.5412 1 0.8039],...
    'parent',handles.LeftPanel,'units','normalized','ForegroundColor',[0 0 0],...
    'position',[0.02 0.65 0.2 0.05],'String','Upper Amp Limit (mA)','FontSize',14);
handles.UpperAmp = uicontrol('Style','edit','parent',handles.LeftPanel,...
    'units','normalized','position', [0.25 0.67 0.07 0.04],'FontSize',14,...
    'Callback',{@upperamp_callback});
handles.TbetweenText = uicontrol('Style','text','BackgroundColor',[0.5412 1 0.8039],...
    'parent',handles.LeftPanel,'units','normalized','ForegroundColor',[0 0 0],...
    'position',[0.006 0.59 0.25 0.05],'String','Time Between Pulses (s)','FontSize',14);
handles.Tbetween = uicontrol('Style','edit','parent',handles.LeftPanel,...
    'units','normalized','position', [0.25 0.61 0.07 0.04],'FontSize',14,...
    'Callback',{@timebetweenstim_callback});
handles.NumSweepsText = uicontrol('Style','text','BackgroundColor',[0.5412 1 0.8039],...
    'parent',handles.LeftPanel,'units','normalized','ForegroundColor',[0 0 0],...
    'position',[0.004 0.53 0.25 0.05],'String','# of Sweeps in Curve','FontSize',14);
handles.NumSweeps = uicontrol('Style','edit','parent',handles.LeftPanel,...
    'units','normalized','position', [0.25 0.55 0.07 0.04],'FontSize',14,...
    'Callback',{@numsweeps_callback});
handles.NumRepsText = uicontrol('Style','text','BackgroundColor',[0.5412 1 0.8039],...
    'parent',handles.LeftPanel,'units','normalized','ForegroundColor',[0 0 0],...
    'position',[0.02 0.47 0.2 0.05],'String','# of Repetitions','FontSize',14);
handles.NumReps = uicontrol('Style','edit','parent',handles.LeftPanel,...
    'units','normalized','position', [0.25 0.49 0.07 0.04],'FontSize',14,...
    'Callback',{@numreps_callback});
handles.RecCurveStim = uicontrol('Parent',handles.LeftPanel,'Units',...
    'Normalized','Style','pushbutton','Position',[.05 .435 .25 .045],...
    'String','Stim Recruitment Curve','BackgroundColor',[0 0.455 1],'FontSize',16,...
    'ForegroundColor',[1,1,1],'Callback',{@RecCurveStim_callback});
handles.TotalTimeText = uicontrol('Style','text','BackgroundColor',[0.5412 1 0.8039],...
    'parent',handles.LeftPanel,'units','normalized','ForegroundColor',[0 0 0],...
    'position',[0.01 0.392 0.1 0.03],'String','Total Time:','FontSize',13);
handles.TotalTime = uicontrol('Style','edit','parent',handles.LeftPanel,...
    'units','normalized','position',[0.11 0.395 0.05 0.03],'FontSize',12);
handles.TimeLeftText = uicontrol('Style','text','BackgroundColor',[0.5412 1 0.8039],...
    'parent',handles.LeftPanel,'units','normalized','ForegroundColor',[0 0 0],...
    'position',[0.18 0.392 0.1 0.03],'String','Time Left:','FontSize',13);
handles.TimeLeft = uicontrol('Style','edit','parent',handles.LeftPanel,...
    'units','normalized','position',[0.28 0.395 0.05 0.03],'FontSize',12);
handles.StopStim = uicontrol('Parent',handles.LeftPanel,'Units',...
    'Normalized','Style','pushbutton','Position',[.21 .355 .1 .035],...
    'String','STOP!','BackgroundColor',[0 0 0],'FontSize',16,...
    'ForegroundColor',[1,1,1],'Callback',{@stopStim_callback});
handles.ResetTable = uicontrol('Parent',handles.LeftPanel,'Units',...
    'Normalized','Style','pushbutton','Position',[.04 .355 .14 .035],...
    'String','Reset Table','BackgroundColor',[0 0 0],'FontSize',16,...
    'ForegroundColor',[1,1,1],'Callback',{@ResetTable});
handles.recruitTable = uitable('Parent',handles.LeftPanel,'Units',...
    'Normalized','Position',[0.02 .02 .32 .33],'ColumnWidth',{45});
ResetTable
% set default values
set(handles.PulseWidth,'String','1');
set(handles.Amp,'String','2');
set(handles.LowerAmp,'String','0.1');
set(handles.UpperAmp,'String','20');
set(handles.Tbetween,'String','2');
set(handles.NumSweeps,'String','20');
set(handles.NumReps,'String','3');
% Callback functions
    function refreshDAQ(~,~)
        daqreset
        handles.devices = daq.getDevices;
        if isempty(handles.devices)
            daqstr = 'No DAQ connected';
        else
            daqstr = 'DAQ connected';
            set(handles.daqdisplay,'String',daqstr);
            s0 = daq.createSession('ni');
            s0.Rate = 10000;
            %             s0.IsContinuous = true;
            ME = [];
            try
                addAnalogOutputChannel(s0,'Dev1',0,'Voltage'); % for stimulation control. Patch panel = ao2
                addAnalogOutputChannel(s0,'Dev1',1,'Voltage'); % for trigger. Patch panel = ao3
            catch ME
                daqstr = 'No DAQ connected';
                set(handles.daqdisplay,'String',daqstr);
            end
            if isempty(ME)
                daqstr = 'DAQ connected';
            end
        end
        set(handles.daqdisplay,'String',daqstr);
    end
    function pulsewidth_callback(hObject,~)
        newval = get(hObject,'String');
        if isnan(str2double(newval))
            set(handles.PulseWidth,'String','0');
        else
            set(handles.PulseWidth,'String',newval);
        end
    end
    function stimamp_callback(hObject,~)
        newval = get(hObject,'String');
        if isnan(str2double(newval))
            set(handles.Amp,'String','0');
        else
            set(handles.Amp,'String',newval);
        end
    end
    function loweramp_callback(hObject,~)
        newval = get(hObject,'String');
        if isnan(str2double(newval))
            set(handles.LowerAmp,'String','0');
        else
            set(handles.LowerAmp,'String',newval);
        end
    end
    function upperamp_callback(hObject,~)
        newval = get(hObject,'String');
        if isnan(str2double(newval))
            set(handles.UpperAmp,'String','0');
        else
            set(handles.UpperAmp,'String',newval);
        end
    end
    function timebetweenstim_callback(hObject,~)
        newval = get(hObject,'String');
        if isnan(str2double(newval))
            set(handles.Tbetween,'String','5');
        else
            set(handles.Tbetween,'String',newval);
        end
    end
    function numsweeps_callback(hObject,~)
        newval = get(hObject,'String');
        if isnan(str2double(newval))
            set(handles.NumSweeps,'String','0');
        else
            set(handles.NumSweeps,'String',newval);
        end
    end
    function numreps_callback(hObject,~)
        newval = get(hObject,'String');
        if isnan(str2double(newval))
            set(handles.NumReps,'String','0');
        else
            set(handles.NumReps,'String',newval);
        end
    end
    function singleStim(~,~)
        if isempty(handles.devices)
            warndlg('No DAQ connected! Please connect and reset DAQ.');
        else
            pulseTime = str2double(get(handles.Tbetween,'String'));
            PWpts = (str2double(get(handles.PulseWidth,'String')))*10;
            trigVector = zeros((s0.Rate)*pulseTime,1);
            trigVector(11:11+PWpts) = 5; % set trigger to 5V after short delay
            stimVector = zeros((s0.Rate)*pulseTime,1);
            StimAmp = str2double(get(handles.Amp,'String')); % amplitude for this round
            StimVolts = (StimAmp*10)/1000; % convert output for DAQ
            stimVector(1:end-1) = StimVolts;
            stimVector(end) = 0; % last point = 0 for safety
            % Initialize the library
            lib = TMSiSAGA.Library();
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
                %     rPlot.show();
                % Create a file storage
                data = TMSiSAGA.Data('Plot', device.sample_rate, device.getActiveChannels());
                % Start sampling on the device
                device.start();
                pause(2)
                queueOutputData(s0,[stimVector trigVector]);
                startForeground(s0); % so that don't loop faster than commands send
                beep
                [samples, num_sets, type] = device.sample();
                save('test','data','samples','num_sets') % *****************************************************************
                device.stop();
                % Disconnect from device
                device.disconnect();
                
                
                
                % save stim params so can link to EMG file
            Tablesave = handles.T;
            set(handles.TotalTime,'String','00:00');
            filenamesave = inputdlg('What would you like to name this file?  ','s');
            filenamestr = filenamesave{1,1};
            save(filenamestr,'randStim','lowerAmp','upperAmp','numsweeps','pulseTime','numReps','Tablesave','data')
            catch e
                % In case of an error close all still active devices and clean up
                % library itself
                lib.cleanUp();
                % Rethrow error to ensure you get a message in console
                rethrow(e)
            end
            % see if stimulation amplitude has been used before
            Amp = str2double(get(handles.Amp,'String'));
            eqAmp = cellfun(@(y)isequal(y,Amp),handles.T);
            [row, col] = find(eqAmp);
            if length(row) > 1 % if the number of reps == amplitude somewhere in table, extract odd index in row
                rowOdd = rem(row,2); % for each element in row, find the odd one
                rowOddind = find(rowOdd ~= 0);
                row = row(rowOddind);
                col = col(rowOddind);
            end
            if isempty(row) % amplitude has not been stimulated yet
                nz = find(cellfun(@isempty,handles.T)); % append to table, find non-zero elements of Table
                [m,~] = size(handles.T);
                remdiv = rem(nz(1),m); % remainder after division == row
                div = floor(nz(1)/m); % number of divisions == columns used
                handles.T(remdiv,div+1) = {Amp}; % amplitude entered in next avail cell
                handles.T(remdiv+1,div+1) = {1}; % number of times repeated amp
            else % amplitude has been stimulated already
                handles.T{row+1,col} = handles.T{row+1,col}+1; % increase rep by 1 stim
            end
            handles.recruitTable.Data = handles.T; % update table in GUI
        end
        
    end
    function RecCurveStim_callback(~,~)
        if isempty(handles.devices)
            warndlg('No DAQ connected! Please connect and reset DAQ.');
        else
            lowerAmp = str2double(get(handles.LowerAmp,'String'));
            upperAmp = str2double(get(handles.UpperAmp,'String'));
            numsweeps = str2double(get(handles.NumSweeps,'String'));
            ampDiffs = (upperAmp - lowerAmp)/(numsweeps-1); % get vector of all amps to stim
            if ampDiffs == 0 % same amplitude for lower and upper amps
                ampsStim = repmat(lowerAmp,[numsweeps,1]);
            else
                ampsStim = [lowerAmp:ampDiffs:upperAmp]'; %#ok<NBRAK>
            end
            numReps = str2double(get(handles.NumReps,'String'));
            ampsStimrep = repmat(ampsStim,[numReps,1]); % repeat vector by number of reps
            randStim = round(ampsStimrep(randperm(length(ampsStimrep))),1); % randomize amplitudes for stimulation
            pulseTime = str2double(get(handles.Tbetween,'String'));
            PWpts = (str2double(get(handles.PulseWidth,'String')))*10;
            tsec = pulseTime*length(randStim); % time to collect curve in seconds
            TotalTime = char(duration(seconds(tsec),'format','mm:ss'));
            set(handles.TotalTime,'String',TotalTime);
            set(handles.TimeLeft,'String',TotalTime);
            % Initialize the library
            lib = TMSiSAGA.Library();
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
                % Create a file storage
                data = TMSiSAGA.Data('Plot', device.sample_rate, device.getActiveChannels());
                % Start sampling on the device
                device.start();
                pause(2)
                % loop for every amp level, stimulate
                for j = 1:length(randStim) % for each amplitude to stimulate
                    trigVector = zeros((s0.Rate)*pulseTime,1);
                    trigVector(11:11+PWpts) = 5; % set trigger to 5V after short delay
                    stimVector = zeros((s0.Rate)*pulseTime,1);
                    StimAmp = randStim(j); % amplitude for this round
                    StimVolts = (StimAmp*10)/1000; % convert output for DAQ
                    if j == length(randStim) % last point
                        stimVector(1:end-1) = StimVolts;
                        stimVector(end) = 0;
                    else
                        stimVector(1:end) = StimVolts;
                    end
                    queueOutputData(s0,[stimVector trigVector]);
                    startForeground(s0); % so that don't loop faster than commands send
                    beep
                    [samples, num_sets, type] = device.sample();
                    % Append samples to the plot and redraw
                    if num_sets > 0
                        rPlot.append(samples);
                        data.append(samples);
                    end
                    TimeUsed = j*pulseTime; % update time display
                    TLeftSec = tsec - TimeUsed;
                    TimeLeft = char(duration(seconds(TLeftSec),'format','mm:ss'));
                    set(handles.TimeLeft,'String',TimeLeft);
                    % update table
                    eqAmp = cellfun(@(y)isequal(y,StimAmp),handles.T);
                    [row, col] = find(eqAmp);
                    if length(row) > 1 % if the number of reps == amplitude somewhere in table, extract odd index in row
                        rowOdd = rem(row,2); % for each element in row, find the odd one
                        rowOddind = find(rowOdd ~= 0);
                        row = row(rowOddind);
                        col = col(rowOddind);
                    end
                    if isempty(row) % amplitude has not been stimulated yet
                        nz = find(cellfun(@isempty,handles.T)); % append to table, find non-zero elements of Table
                        [m,~] = size(handles.T);
                        if isempty(nz) % table is full, make table larger by adding a column
                            newcol = cell(m,1);
                            handles.T = horzcat(handles.T,newcol);
                            nz = find(cellfun(@isempty,handles.T));
                        end
                        remdiv = rem(nz(1),m); % remainder after division == row
                        div = floor(nz(1)/m); % number of divisions == columns used
                        handles.T(remdiv,div+1) = {StimAmp}; % amplitude entered in next avail cell
                        handles.T(remdiv+1,div+1) = {1}; % number of times repeated amp
                    else % amplitude has been stimulated already
                        handles.T{row+1,col} = handles.T{row+1,col}+1; % increase rep by 1 stim
                    end
                    handles.recruitTable.Data = handles.T; % update table in GUI
                end
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
            % save stim params so can link to EMG file
            Tablesave = handles.T;
            set(handles.TotalTime,'String','00:00');
            filenamesave = inputdlg('What would you like to name this file?  ','s');
            filenamestr = filenamesave{1,1};
            save(filenamestr,'randStim','lowerAmp','upperAmp','numsweeps','pulseTime','numReps','Tablesave','data')
        end
    end
    function stopStim_callback(~,~)
        stop(s0)
        refreshDAQ
        device.stop();
        % Disconnect from device
        device.disconnect();
    end
    function ResetTable(~,~)
        handles.T = cell(16,6);
        for i = 1:16
            if mod(i,2) == 1 % odd
                handles.T{i,1} = 'Amp';
            elseif mod(i,2) == 0 % even
                handles.T{i,1} = 'Rep';
            end
        end
        handles.recruitTable.Data = handles.T;
    end
end








