%% GUI for controlling analog output of NI DAQ. Stimulation to be used for transcutaneous spinal cord stimulation
% Designed by Ashley Dalrymple
function SinglePulseguiControlStim
close all
clear all %#ok<CLALL>.
global handles
global s0
handles = struct;
% delete any existing instruments on startup
delete(instrfind) %cleaning things
handles.MainWindow = figure('Name','StimGUI','Units','Pixels','Position',...
    [100 200 800 600],'MenuBar','none', 'NumberTitle','Off', 'Resize',...
    'Off', 'Toolbar','none','Visible', 'On', 'Color',[.294,0,.51]); 
handles.LeftPanel= uipanel('Parent',handles.MainWindow,'BorderType','none',...
    'Units','normalized','Position',[0 0 0.5 1],'BackgroundColor',[.294,0,.51]);
handles.RightPanel= uipanel('Parent',handles.MainWindow,'BorderType','none',...
    'Units','normalized','Position',[0.5 0 0.5 1],'BackgroundColor',[.294,0,.51]);       
% check that DAQ is connected and recongnized by computer
handles.daqdisplay = uicontrol('Parent',handles.LeftPanel,'Style','text','BackgroundColor',[.294,0,.51],'Units','Pixels',...
    'Position',[10 550 200 30],'FontSize',11,'ForegroundColor',[1,1,1],'String',[]);
refreshDAQ
handles.Refresh = uicontrol('Parent',handles.LeftPanel,'Units',...
    'Normalized','Style','pushbutton','Position',[.53 .93 .2 .05],...
    'String','Refresh DAQ','BackgroundColor',[.504,0,.88],...
    'ForegroundColor',[1,1,1],'Callback',{@refreshDAQ});
handles.StimFrequencyText = uicontrol('Style','text','BackgroundColor',[.294,0,.51],...
    'parent', handles.LeftPanel,'units','normalized','ForegroundColor',[1,1,1],...
    'position',[0.03 0.65 0.52 0.2],'String','Stim Frequency (Hz)','FontSize',14);
handles.StimFrequency = uicontrol('Style','edit','parent',handles.LeftPanel,...
    'units','normalized','position', [0.55 0.8 0.13 0.06],'FontSize',14,...
    'Callback',{@frequency_callback});
handles.PulseWidthText = uicontrol('Style','text','BackgroundColor',[.294,0,.51],...
    'parent', handles.LeftPanel,'units','normalized','ForegroundColor',[1,1,1],...
    'position',[0.01 0.55 0.5 0.2],'String','Pulse Width (ms)','FontSize',14);
handles.PulseWidth = uicontrol('Style','edit','parent',handles.LeftPanel,...
    'units','normalized','position',[0.55 0.7 0.13 0.06],'FontSize',14,...
    'Callback',{@pulsewidth_callback});  
handles.AmpLimitText = uicontrol('Style','text','BackgroundColor',[.294,0,.51],...
    'parent', handles.LeftPanel,'units','normalized','ForegroundColor',[1,1,1],...
    'position',[0.0 0.45 0.5 0.2],'String','Amp Limit (mA)','FontSize',14);
handles.AmpLimit = uicontrol('Style','edit','parent', handles.LeftPanel,...
    'units','normalized','position', [0.55 0.6 0.13 0.06],'FontSize',14,...
    'Callback',{@maxamp_callback});
handles.StimAmpText = uicontrol('Style','text','BackgroundColor',[.294,0,.51],...
    'parent', handles.LeftPanel,'units','normalized','ForegroundColor',[1,1,1],...
    'position',[0.02 0.25 0.85 0.2],'String','Stimulation Amplitude (mA)','FontSize',20);
handles.StimAmp = uicontrol('Style','edit','FontSize',60,'parent',handles.LeftPanel,...
    'units','normalized','position', [0.22 0.18 0.4 0.2],'Callback',{@stimamp_callback});
handles.DefaultSett = uicontrol('Parent',handles.LeftPanel,'Units',...
    'Normalized','Style','pushbutton','Position',[.03 .07 .25 .06],...
    'String','Default Settings','BackgroundColor',[.504,0,.88],...
    'ForegroundColor',[1,1,1],'Callback',{@defaultSett},'FontSize',10);
handles.SaveSett = uicontrol('Parent',handles.LeftPanel,'Units',...
    'Normalized','Style','pushbutton','Position',[.3 .07 .25 .06],...
    'String','Save Settings','BackgroundColor',[.504,0,.88],...
    'ForegroundColor',[1,1,1],'Callback',{@saveSett},'FontSize',10);
handles.LoadSett = uicontrol('Parent',handles.LeftPanel,'Units',...
    'Normalized','Style','pushbutton','Position',[.57 .07 .25 .06],...
    'String','Load Settings','BackgroundColor',[.504,0,.88],...
    'ForegroundColor',[1,1,1],'Callback',{@loadSett},'FontSize',10);

handles.StimTimeText = uicontrol('Style','text','BackgroundColor',[.294,0,.51],...
    'parent', handles.RightPanel,'units','normalized','ForegroundColor',[1,1,1],...
    'position',[0.1 0.65 0.52 0.2],'String','Stimulation Time (s)','FontSize',14);
handles.StimTime = uicontrol('Style','edit','parent',handles.RightPanel,...
    'units','normalized','position', [0.63 0.8 0.13 0.06],'FontSize',14,...
    'Callback',{@stimtime_callback});
handles.StartStim = uicontrol('Parent',handles.RightPanel,'Units',...
    'Normalized','Style','pushbutton','Position',[.23 .45 .4 .25],...
    'String','START','BackgroundColor',[.504,0,.88],'FontSize',28,...
    'ForegroundColor',[1,1,1],'Callback',{@startStim});
handles.StopStim = uicontrol('Parent',handles.RightPanel,'Units',...
    'Normalized','Style','pushbutton','Position',[.23 .13 .4 .25],...
    'String','STOP','BackgroundColor',[.504,0,.88],'FontSize',28,...
    'ForegroundColor',[1,1,1],'Callback',{@stopStim});
defaultSett
% % set default values
% set(handles.StimFrequency,'String','30');
% set(handles.PulseWidth,'String','1');
% set(handles.AmpLimit,'String','150');
% set(handles.StimAmp,'String','2');
% set(handles.StimTime,'String','5');

% Callback functions
function refreshDAQ(~,~)
    daqreset
    devices = daq.getDevices;
    if isempty(devices)
        daqstr = 'No DAQ connected';
    else
        daqstr = 'DAQ successfully connected';
    end
    set(handles.daqdisplay,'String',daqstr);
    s0 = daq.createSession('ni');
    s0.Rate = 10000;
%     s1 = daq.createSession('ni');
%     s1.Rate = 10000;
    ME = [];
    try 
        addAnalogOutputChannel(s0,'Dev1',1,'Voltage');
        addAnalogOutputChannel(s0,'Dev1',0,'Voltage');
%         addDigitalChannel(s1,'Dev1','Port1/Line1','OutputOnly'); % second connection from left, top
%         outputSingleScan(s1,0);
    catch ME
        daqstr = 'No DAQ connected';
        set(handles.daqdisplay,'String',daqstr);
    end
    if isempty(ME)
        daqstr = 'DAQ successfully connected';
        set(handles.daqdisplay,'String',daqstr);
    end
end
function frequency_callback(hObject,~)
    newval = get(hObject,'String');
    if isnan(str2double(newval))
        set(handles.StimFrequency,'String','0');
    else 
        set(handles.StimFrequency,'String',newval);
    end
end
function pulsewidth_callback(hObject,~)
    newval = get(hObject,'String');
    if isnan(str2double(newval))
        set(handles.PulseWidth,'String','0');
    else 
        set(handles.PulseWidth,'String',newval);
    end
end
function maxamp_callback(hObject,~)
    newval = get(hObject,'String');
    if isnan(str2double(newval))
        set(handles.AmpLimit,'String','0');
    else 
        set(handles.AmpLimit,'String',newval);
    end
end
function stimamp_callback(hObject,~)
    newval = get(hObject,'String');
    maxamp = str2double(get(handles.AmpLimit,'String'));
    if isnan(str2double(newval))
        set(handles.StimAmp,'String','0');
    elseif str2double(newval) > maxamp
        set(handles.StimAmp,'String',num2str(maxamp));
    else 
        set(handles.StimAmp,'String',newval);
    end
end
function defaultSett(~,~)
    set(handles.StimFrequency,'String','30');
    set(handles.PulseWidth,'String','1');
    set(handles.AmpLimit,'String','150');
    set(handles.StimAmp,'String','2');
    set(handles.StimTime,'String','5');
end    
function saveSett(~,~)
    htosave.StimFrequency = str2double(get(handles.StimFrequency,'String'));
    htosave.PulseWidth = str2double(get(handles.PulseWidth,'String'));
    htosave.AmpLimit = str2double(get(handles.AmpLimit,'String'));
    htosave.StimAmp = str2double(get(handles.StimAmp,'String'));
    htosave.StimTime = str2double(get(handles.StimTime,'String')); %#ok<STRNU>
    uisave('htosave')
end
function loadSett(~,~)
    [FileName,~,~] = uigetfile; % ask user to specify which settings file to load
    load(FileName,'htosave')
    StimFrequency = num2str(htosave.StimFrequency);
    PulseWidth = num2str(htosave.PulseWidth);
    AmpLimit = num2str(htosave.AmpLimit);
    StimAmp = num2str(htosave.StimAmp);
    StimTime = num2str(htosave.StimTime);
    set(handles.StimFrequency,'String',convertCharsToStrings(StimFrequency));
    set(handles.PulseWidth,'String',convertCharsToStrings(PulseWidth));
    set(handles.AmpLimit,'String',convertCharsToStrings(AmpLimit));
    set(handles.StimAmp,'String',convertCharsToStrings(StimAmp));
    set(handles.StimTime,'String',convertCharsToStrings(StimTime));
end
function stimtime_callback(hObject,~)
    newval = get(hObject,'String');
    if isnan(str2double(newval))
        set(handles.StimTime,'String','0');
    else 
        set(handles.StimTime,'String',newval);
    end
end    
function startStim(~,~)
%     stimTime = round(str2double(get(handles.StimTime,'String')),3); % in s
%     stimPulse = zeros(round(1/str2double(get(handles.StimFrequency,'String'))*1000,0)*10,1); % #pts in period of pulse incl off period
%     PWpts = 10*(str2double(get(handles.PulseWidth,'String')));
%     stimPulse(1:PWpts) = 1; % monophasic pulse length
    StimAmp = str2double(get(handles.StimAmp,'String'));
    StimVolts = (StimAmp*10)/1000; % convert output for DAQ
%     stimPulse = StimVolts*stimPulse;
%     rep = ceil((stimTime*10000)/length(stimPulse));
%     stimVector = repmat(stimPulse,[rep,1]);
%     outputSingleScan(s1,1);
%     [m,~] = size(stimVector);
%     trigVolt = 5;
%     trigVector = zeros(m,1);
%     trigVector(:,1) = trigVolt;
%     [m, ~] = size(stimVector);
%     trig = ones(m,1);
    trigVector = zeros(50000,1);
    trigVector(11:20) = 5;
    trigVector(10011:10020) = 5;
    trigVector(20011:20020) = 5;
    trigVector(30011:30020) = 5;
    trigVector(40011:40020) = 5;
    
    stimVector = zeros(50000,1);
    stimVector(1:49999) = StimVolts;
    
    
%     outputSingleScan(s1,1);
    queueOutputData(s0,[stimVector trigVector]);
%     queueOutputData(s1,stimVector);
    startBackground(s0);
%     startBackground(s1);
    beep
end
function stopStim(~,~)
    stop(s0)
    refreshDAQ
%     try stop(handles.timers.stimstart)
%         refreshDAQ
%     catch
%     end
%     try delete(timerfind('Name','TimerStartStim'))
%     catch
%         refreshDAQ
%     end
end
end
