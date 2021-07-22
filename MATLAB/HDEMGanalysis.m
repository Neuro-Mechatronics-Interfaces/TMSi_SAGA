% This function creates a user interface that will display high density
% electromyographic data (HDEMG). It has options to visualize the data in
% multiple ways, extract features from the data
% Last modified: by Ashley Dalrymple

function HDEMGanalysis
close all
global FiltSett
global filename
% set before load in case over-written
FiltSett = cell(1,4);
FiltSett{1,1} = 'Action';
FiltSett{1,2} = 'LP freq';
FiltSett{1,3} = 'HP freq';
FiltSett{1,4} = 'order';

[FileName,~,~] = uigetfile; %User selects file and GUI gets the file name and the path to the file
[~,filename,extension] = fileparts(FileName);
if extension == '.Poly5' %#ok<BDSCA>
    % Data = TMSiSAGA.Poly5.read('Recr curve-20191220T101244.DATA.poly5');
    Data = TMSiSAGA.Poly5.read(FileName);
    HDdata = Data.samples(1:64,:)'; % data as column vectors, each column is a new channel
    Trig = Data.samples(end - 2,:)'; % trigger signal is third from last
    DataLength = Data.num_samples; %Number of datapoints in each channel of data
    [~,Chans] = size(Data.channels); %Number of channels
    if Chans > 67 % more data than just HD grid was recorded
        NumBPChans = Chans - 67;
        if NumBPChans == 1
            BPData = Data.samples(65,:)';
        else
            BPData = Data.samples(65:(Chans - 3),:)';
        end
        EMGdata = [HDdata,BPData];
    else
        EMGdata = HDdata;
        NumBPChans = 0;
        BPData = [];
    end
    DataChannels = Chans - 3; % extra channels removed, incl HD and BP EMG
    StaticData = [EMGdata,Trig];
    % ************************************* return and fix this session
    %     elseif extension == '.mat'
    %         load(FileName)
    %         [DataLength,DataChannels] = size(Data);
    %         if length(detect) > DataChannels % for split files
    %             detecthold = detect{DataChannels}; % get new DataChannels from loaded file
    %             detect = [];
    %             detect{DataChannels} = detecthold; % only keep relevant channel's detected episodes
    %              filthold = FiltSett{DataChannels};
    %             FiltSett = [];
    %             FiltSett{DataChannels} = filthold;
    %             setthold = SepSett{DataChannels};
    %             SepSett = [];
    %             SepSett{DataChannels} = setthold;
    %         end
    %         if ~isempty(detect)
    %             ChansData = [];
    %                 for i = 1:length(detect)
    %                     if ~isempty(detect{i})
    %                         ChansData = [ChansData,i]; % finds channels that had features extracted
    %                     end
    %                 end
    %             DataChannels = ChansData(1); % for display of plot label
    %         end
end

%Variables
SampleFrequency = Data.sample_rate;
MaxTime = Data.time;                               %Duration of data
PlotDomain = (0 + MaxTime/DataLength:MaxTime/DataLength:MaxTime)';     %Creates a time point for each point of data
PlotSpacing = 1;                                                    %lowers the number of points the GUI plots
xLimits = [0,MaxTime];                                             %min and max domain of the plots
xRange = MaxTime;                                                   %Time shown of the plots
handles = struct;                                                   %make handles to objects in GUI global
handles.checkedchans = ones(DataChannels,1);                        % initialize so all channels will be displayed

GUIBuilder                                                          %call the function that builds each component (window, pushbuttons, graph, ect) of the
%GUI along with their corresponding functions
PlotData                                                            %Draw the data onto the GUI

    function GUIBuilder
        % create window
        handles.MainWindow = figure('Menubar','figure','Units','normalized','outerposition',[0 0 1 1]);
        
        SliderPanel
        
        % creates upper left button panel
        handles.TopPanel= uipanel('Parent',handles.MainWindow,'Units',...
            'normalized','Position',[0 0.9 0.2 .1]);
        % load data new data file
        handles.loadfile = uicontrol('style','pushbutton','parent',...
            handles.TopPanel,'units','normalized','string','Load File',...
            'position',[.25 .55 .5 .35],'fontsize',12,'BackgroundColor',...
            [0.5412 1 0.8039],'callback',{@loadFile,handles});
        function loadFile(~,~,~)
            close(handles.MainWindow)
            [FileName,~,~] = uigetfile;                  %User selects file and GUI gets the file name and the path to the file
            [~,filename,extension] = fileparts(FileName);
            FiltSett = cell(1,4);
            FiltSett{1,1} = 'Action';
            FiltSett{1,2} = 'LP freq';
            FiltSett{1,3} = 'HP freq';
            FiltSett{1,4} = 'order';
            if strcmp(extension,'.Poly5')
                [~,filename,~] = fileparts(filename); % need extra step of removing extension from file name
                Data = TMSiSAGA.Poly5.read(FileName);
                HDdata = Data.samples(1:64,:)'; % data as column vectors, each column is a new channel
                Trig = Data.samples(end - 2,:)'; % trigger signal is third from last
                DataLength = Data.num_samples; %Number of datapoints in each channel of data
                [~,Chans] = size(Data.channels); %Number of channels
                if Chans > 67 % more data than just HD grid was recorded
                    NumBPChans = Chans - 67;
                    if NumBPChans == 1
                        BPData = Data.samples(65,:)';
                    else
                        BPData = Data.samples(65:(Chans - 3),:)';
                    end
                    EMGdata = [HDdata,BPData];
                else
                    EMGdata = HDdata;
                    NumBPChans = 0;
                    BPData = [];
                end
                DataChannels = Chans - 3; % extra channels removed, incl HD and BP EMG
                StaticData = [EMGdata,Trig];
            elseif strcmp(extension,'.mat') % ****************************fix ************************************************************
                %                 load(FileName,'Data','FiltSett','HDdata')
                %                 DataLength = Data.num_samples; %Number of datapoints in each channel of data
                %                 [~,Chans] = size(Data.channels); %Number of channels
                %                 DataChannels = Chans - 3; % extra channels removed
                %                 StaticData = Data.samples(1:64,:)'; %Copy of original data that will not be altered from filtering etc.
            end
            % Variables
            SampleFrequency = Data.sample_rate;
            MaxTime = Data.time;                               %Duration of data
            PlotDomain = (0 + MaxTime/DataLength:MaxTime/DataLength:MaxTime)';     %Creates a time point for each point of data
            PlotSpacing = 1;                                                    %lowers the number of points the GUI plots
            xLimits = [0, MaxTime];                                             %min and max domain of the plots
            xRange = MaxTime;                                                   %Time shown of the plots
            handles = struct;                                                   %make handles to objects in GUI global
            handles.checkedchans = ones(DataChannels,1);
            
            GUIBuilder
            PlotData
        end
        handles.ZoomOn = uicontrol('style','pushbutton',...
            'parent', handles.TopPanel,'units', 'normalized',...
            'position',[0.15 0.12 0.3 0.35],'String','Zoom On',...
            'fontsize',12,'callback', {@ZoomOn},'BackgroundColor',...
            [0.5412 1 0.8039]);
        % function called when ResetZoom button is pushed
        function ZoomOn(~,~)
            delete(handles.PlotHandles)
            zoom ON
            PlotData;
        end
        % Creates Reset Zoom Buttom
        handles.ResetZoom = uicontrol('style','pushbutton',...
            'parent', handles.TopPanel,'units', 'normalized',...
            'position',[.55 .12 .3 .35],'String','Reset Zoom',...
            'fontsize',12,'callback', {@ResetZoom},'BackgroundColor',...
            [0.5412 1 0.8039]);
        % function called when ResetZoom button is pushed
        function ResetZoom(~,~)
            delete(handles.PlotHandles)
            PlotData;
            set(handles.HorizontalSlider, 'Visible','off');
        end
        % Creates panel to graph channel in
        handles.PlotPanel = zeros(DataChannels + 1,1);
        handles.PlotHandles = zeros(DataChannels + 1,1);
        handles.PlotPanel(1:DataChannels + 1) = uipanel('Parent',handles.MainWindow,...
            'Units','normalized','Position',[0.2 0.05 .82 0.99],'BackgroundColor',[1 1 1]);%[0.2 0.05 .82 0.99]
        % MiddlePanel is the middle left panel in the GUI window.
        handles.MiddlePanel= uipanel('Parent',handles.MainWindow,...
            'Units','normalized','Position',[0 0.64 0.2 .26]);
        % Filter options
        TypeTag = 'Low-Pass';
        % Creates the radio button group
        handles.filterType = uibuttongroup('parent',handles.MiddlePanel,...
            'units','normalized','position',[.05 .55 0.9 0.4],...
            'SelectionChangeFcn', @FilterType);
        % function called when filter type radio buttons are changed
        function FilterType(~, eventdata)
            TypeTag = get(eventdata.NewValue,'Tag');
            switch TypeTag
                case 'Low-Pass'
                    set(handles.HighPassEntry, 'enable', 'off');
                    set(handles.LowPassEntry, 'enable', 'on');
                    set(handles.HighPassEntry, 'string', '');
                case 'Band-Pass'
                    set(handles.HighPassEntry, 'enable', 'on');
                    set(handles.LowPassEntry, 'enable', 'on');
                case 'High-Pass'
                    set(handles.HighPassEntry, 'enable', 'on');
                    set(handles.LowPassEntry, 'enable', 'off');
                    set(handles.LowPassEntry, 'string', '');
            end
        end
        % creates the text above the top group of radio buttons
        handles.FilterTypeText = uicontrol('Style','Text',...
            'parent',handles.filterType,...
            'units','normalized','position',[0.25 0.78 .4 .25],...
            'fontsize',14,'string','Filter Type');
        % creates the Low-Pass radio button option
        handles.LowPassFilter = uicontrol('Style','radiobutton',...
            'String','Low-Pass','parent',handles.filterType,...
            'units', 'normalized','position', [0.05 0.46 0.5 0.28],...
            'fontsize',12,'HandleVisibility','off','Tag','Low-Pass');
        % creates the High-pass radio button option
        handles.HighPassFilter = uicontrol('Style','radiobutton',...
            'String','High-Pass','parent',handles.filterType,...
            'units', 'normalized','position', [0.5 0.46 0.5 0.28],...
            'fontsize',12,'HandleVisibility','off','Tag','High-Pass');
        % creates the Band-Pass radio button option
        handles.BandPassFilter = uicontrol('Style','radiobutton',...
            'String','Band-Pass','parent',handles.filterType,...
            'units', 'normalized','position', [0.05 0.08 0.5 0.28],...
            'fontsize',12,'HandleVisibility','off','Tag','Band-Pass');
        % creates the text for the low pass frequency box
        handles.LowPassText = uicontrol('Style','text',...
            'parent', handles.MiddlePanel,'units','normalized',...
            'fontsize',12,'position',[0.03 0.32 0.25 0.2],'String','LP (Hz)');
        % creates the low pass frequency entry box
        handles.LowPassEntry = uicontrol('Style','edit','fontsize',12,...
            'parent', handles.MiddlePanel,'units','normalized',...
            'position', [0.05 0.27 0.2 0.13]);
        % creates the text for the high pass frequency box
        handles.HighPassText = uicontrol('Style','text',...
            'parent', handles.MiddlePanel,'units','normalized',...
            'fontsize',12,'position', [0.32 0.32 0.25 0.2],'String','HP (Hz)');
        % creates the high pass frequency entry box
        handles.HighPassEntry = uicontrol('Style','edit','fontsize',12,...
            'parent', handles.MiddlePanel,'units','normalized',...
            'enable','off','position',[0.35 0.27 0.2 0.13]);
        % creates the text for the order box
        handles.OrderText = uicontrol('Style','text',...
            'parent', handles.MiddlePanel,'units','normalized',...
            'fontsize',12,'position', [0.67 0.32 0.25 0.2],'String','Filter Order');
        % creates the order box
        handles.OrderEntry = uicontrol('Style','edit','fontsize',12,...
            'parent', handles.MiddlePanel,'units','normalized','string','2',...
            'position',[0.68 0.27 0.2 0.13]);
        % creates the finish button
        handles.ApplyButton = uicontrol('Style','pushbutton','parent',...
            handles.MiddlePanel,'units','normalized','position',...
            [0.1 0.07 .25 .15],'string','Apply','fontsize',12,...
            'Callback',{@Apply},'BackgroundColor','k','ForegroundColor','w');
        % function called when finish button is pushed
        function Apply(~,~)
            high = str2double(get(handles.HighPassEntry,'string'))/(SampleFrequency/2);
            low = str2double(get(handles.LowPassEntry,'string'))/(SampleFrequency/2);
            order = str2double(get(handles.OrderEntry,'string'));
            switch TypeTag
                case 'Low-Pass'
                    [b,a] = butter(order,low,'low');
                    for i = 1:DataChannels
                        EMGdata(:,i) = filtfilt(b,a,EMGdata(:,i));
                    end
                    [m,~] = size(FiltSett);  % add to next row
                    FiltSett{m+1,1} = 'LP';
                    FiltSett{m+1,2} = str2double(get(handles.LowPassEntry,'string'));
                    FiltSett{m+1,4} = order;
                case 'Band-Pass'
                    [b,a] = butter(order,[low high],'bandpass');
                    for i = 1:DataChannels
                        EMGdata(:,i) = filtfilt(b,a,EMGdata(:,i));
                    end
                    [m,~] = size(FiltSett);  % add to next row
                    FiltSett{m+1,1} = 'BP';
                    FiltSett{m+1,2} = str2double(get(handles.LowPassEntry,'string'));
                    FiltSett{m+1,3} = str2double(get(handles.HighPassEntry,'string'));
                    FiltSett{m+1,4} = order;
                case 'High-Pass'
                    [b,a] = butter(order,high,'high');
                    for i = 1:DataChannels
                        EMGdata(:,i) = filtfilt(b,a,EMGdata(:,i));
                    end
                    [m,~] = size(FiltSett);  % add to next row
                    FiltSett{m+1,1} = 'HP';
                    FiltSett{m+1,3} = str2double(get(handles.HighPassEntry,'string'));
                    FiltSett{m+1,4} = order;
            end
            delete(handles.PlotHandles);
            PlotData;
            filtsettings = [order,low*(SampleFrequency/2),high*(SampleFrequency/2)];
        end
        % creates the rectify button
        handles.RectifyButton = uicontrol('Style','pushbutton',...
            'parent',handles.MiddlePanel,'units','normalized',...
            'position',[0.4 0.07 .25 .15],'string','Rectify',...
            'fontsize',12,'Callback',{@Rectify},'BackgroundColor','k','ForegroundColor','w');
        % function called when rectify button is pushed
        function Rectify(~,~)
            for i = 1:DataChannels
                EMGdata(:,i) = abs(EMGdata(:,i));
            end
            delete(handles.PlotHandles);
            [m,~] = size(FiltSett);
            FiltSett{m+1,1} = 'rectify'; % add to next row
            PlotData;
        end
        % reset filtering to remove and start over
        handles.ResetButton = uicontrol('Style','pushbutton',...
            'parent',handles.MiddlePanel,'units','normalized',...
            'position',[0.7 0.07 .25 .15],'string','Reset',...
            'fontsize',12,'Callback',{@Reset},'BackgroundColor','k','ForegroundColor','w');
        function Reset(~,~)
            for i = 1:DataChannels
                EMGdata = StaticData;
            end
            delete(handles.PlotHandles);
            FiltSett = cell(1,4);
            FiltSett{1,1} = 'Action';
            FiltSett{1,2} = 'LP freq';
            FiltSett{1,3} = 'HP freq';
            FiltSett{1,4} = 'order';
            PlotData;
        end
        %creates lower left button panel
        handles.BottomPanel= uipanel('Parent',handles.MainWindow,...
            'Units','normalized','Position',[0 0.04 0.2 .6]);
        handles.channelSelectText = uicontrol('Style','Text',...
            'parent',handles.BottomPanel,'units','normalized',...
            'position',[0.12 0.75 .8 .25],'fontsize',14,'string',...
            'Channels Displayed');
        for j = 1:DataChannels
            xrem = rem(j,8);
            if xrem == 0 % if j is divisible by 8, end of row
                x = 7;
            else
                x = xrem - 1;
            end
            jp = j-1;
            y = floor(jp/8);
            handles.ch(j) = uicontrol('Style','checkbox','String',num2str(j),...
                'parent',handles.BottomPanel,'value',1,'units',...
                'normalized','position',[0.03+0.12*x 0.85-0.05*y 0.2 0.05],'fontsize',...
                12,'Callback',{@channelselection,handles});
        end
        function  channelselection(~,~,~)
            handles.checkedchans = cell2mat(get(handles.ch,'Value')); % binary vector for checked channels of data
            PlotData
        end
        handles.SelectAll = uicontrol('style','pushbutton',...
            'parent',handles.BottomPanel,'units','normalized',...
            'position',[.10 .9 .32 .05],'String','Select All',...
            'fontsize',12,'callback',{@SelectAll,handles},'BackgroundColor',[0.6 0.4 1],'ForegroundColor','w');
        function SelectAll(~,~,~)
            set(handles.ch(1:DataChannels),'value',1)
            channelselection
        end
        handles.UnselectAll = uicontrol('style','pushbutton',...
            'parent',handles.BottomPanel,'units','normalized',...
            'position',[.60 .9 .32 .05],'String','Unselect All',...
            'fontsize',12,'callback',{@UnselectAll,handles},'BackgroundColor',[0.6 0.4 1],'ForegroundColor','w');
        function UnselectAll(~,~,~)
            set(handles.ch(1:DataChannels),'value',0)
            channelselection
        end
        handles.saveButton = uicontrol('style','pushbutton','Parent',...
            handles.BottomPanel,'Units','normalized','position',...
            [0.35 0.4 0.2 0.05],'string','Save!','FontSize',12,...
            'BackgroundColor',[0.5412 1 0.8039],'callback',{@saveProgress});
        function saveProgress(~,~) % saves settings currently saved in GUI along with updated Data file and filter settings
            ext = '_mod';
            modFileName = strcat(filename,ext);
            save(modFileName,'Data','FiltSett','EMGdata','Trig')
            a = msgbox('Progress Saved!'); %#ok<*NASGU>
        end
    end
%SliderPanel is the center/right bottom panel in the GUI window.
%Contains the slider to move the data left/right in thier plots and
%a zoom/unzoom button.
    function SliderPanel
        %creates the panel at the bottom
        handles.SliderPanel = uipanel('Parent',handles.MainWindow,...
            'Units','normalized',...
            'Position',[0.2 0 .8 0.05]);
        %creates the slider
        handles.HorizontalSlider = uicontrol('style','slide',...
            'unit','normalized',...
            'parent', handles.SliderPanel,...
            'position',[0.08 0.02 0.89 0.7],...
            'min',0,'max',MaxTime,'val',0,...
            'Visible', 'off',...
            'SliderStep',[0.01 0.01],...
            'callback', {@Slide, handles});
        %function that links the slider to the plots
        function Slide(~,~,~)
            SliderLocation = get(handles.HorizontalSlider,'Value');
            set(handles.PlotHandles(DataChannels),'xlim',[SliderLocation SliderLocation + xRange]);
            xLimits = get(handles.PlotHandles(DataChannels), 'xlim');
            if xLimits(2) > MaxTime
                set(handles.PlotHandles(DataChannels),'xlim',[MaxTime - xRange MaxTime]);
            end
        end
        %creates the xZoom button
        handles.xZoom = uicontrol('style','pushbutton','parent',...
            handles.SliderPanel,'units', 'normalized','position',...
            [.04 0.4 0.02 0.5],'string','>>','callback',{@xZoom});
        %function that is called when xZoom button is pushed
        function xZoom(~,~)
            set(handles.PlotHandles(DataChannels),'xlim', [xLimits(1) + 0.1*xRange xLimits(2) - 0.1*xRange]);
            xLimits = get(handles.PlotHandles(DataChannels),'xlim');
            xRange = xLimits(2) - xLimits(1);
            set(handles.HorizontalSlider, 'Value', xLimits(1),'max', MaxTime - xRange);
            if (xLimits(2) < MaxTime || xLimits(1) > 0)
                set(handles.HorizontalSlider, 'Visible', 'on');
            end
        end
        %creates the xUnZoom button
        handles.xUnZoom = uicontrol('style','pushbutton','parent',...
            handles.SliderPanel,'units','normalized','position',...
            [.01 0.4 0.02 0.5],'string','<<','callback', {@xUnZoom});
        %function that is called when xUnZoom button is pushed
        function xUnZoom(~, ~)
            newMaxVal = xLimits(2) + 0.125*xRange;
            newMinVal = xLimits(1) - 0.125*xRange;
            if (newMaxVal > MaxTime && newMinVal < 0)
                set(handles.PlotHandles(DataChannels),'xlim',[0 MaxTime]);
                set(handles.HorizontalSlider,'Visible','off','Value',0);
            elseif newMaxVal > MaxTime
                set(handles.PlotHandles(DataChannels),'xlim',[newMinVal MaxTime]);
            elseif newMinVal < 0
                set(handles.PlotHandles(DataChannels),'xlim',[0 newMaxVal]);
            else
                set(handles.PlotHandles(DataChannels),'xlim',[newMinVal newMaxVal]);
            end
            xLimits = get(handles.PlotHandles(DataChannels),'xlim');
            xRange = xLimits(2) - xLimits(1);
            SliderLocation = get(handles.HorizontalSlider,'Value');
            if SliderLocation > (MaxTime - xRange)
                set(handles.HorizontalSlider,'Value',MaxTime - xRange);
            end
            set(handles.HorizontalSlider,'max',MaxTime - xRange);
            if (xLimits(1) <= 0 && xLimits(2) >= MaxTime)
                set(handles.PlotHandles(DataChannels),'xlim',[0 MaxTime]);
                set(handles.HorizontalSlider,'Visible','off','Value',0);
            elseif xLimits(1) < 0
                set(handles.PlotHandles(DataChannels),'xlim',[0 1.1*xRange]);
            elseif xLimits(2) > MaxTime
                set(handles.PlotHandles(DataChannels),'xlim',[MaxTime - 1.1*xRange MaxTime]);
            end
        end
    end

    function PlotData
        xLimits = [0,MaxTime];                      %resets the domain of graph to original value
        xRange = MaxTime;                           %resets the domain of graph to original value
        NumChans = nnz(handles.checkedchans);       % find the actual channels that are enabled for display
        handles.PlotHandles = zeros(NumChans+1,1); %creates space for plot handles to go
        enabledIndex = find(handles.checkedchans == 1); % get indices for enabled channels
        % plot trigger first
        handles.PlotHandles(1) = subplot(NumChans+1,1,1,'Parent',handles.PlotPanel(1));
        dTrig = diff(Trig);
        artef = find(dTrig < -200); % false trig, usually at end
        posTrig = find(dTrig > 0);
        dTrig(artef) = 0; %#ok<FNDSB>
        dTrig(posTrig) = 0; %#ok<FNDSB>
        dTrig(end+1) = 0; % to make same size as Trig again
        handles.PlotLineHandles(1) = line(PlotDomain(1:PlotSpacing:end),dTrig(1:PlotSpacing:end,:),'Parent',handles.PlotHandles(1),'Color','k'); %plot the data from a channel
        box off
        set(gca,'XColor','none')
        az = gca;
        az.YLabel.String = 'Trigger';
        az.YLabel.FontSize = 7;
        az.YLabel.Rotation = 0;
        az.YLabel.Margin = 8;
        az.YLabel.VerticalAlignment = 'middle';
        az.YLabel.HorizontalAlignment = 'right';
        set(gca,'ytick',[])
        set(gca,'Color','none')
        if NumChans ~=0
            for i = 1:NumChans - 1
                handles.PlotHandles(i+1) = subplot(NumChans+1,1,i+1,'Parent',handles.PlotPanel(i+1));
                handles.PlotLineHandles(i+1) = line(PlotDomain(1:PlotSpacing:end),EMGdata(1:PlotSpacing:end,enabledIndex(i)),'Parent',handles.PlotHandles(i+1),'Color',[.2902,0,.5804]); %plot the data from a channel
                box off
                set(gca,'XColor','none')
                ay = gca;
                set(gca,'ytick',[])
                set(gca,'Color','none')
                ay.YLabel.String = num2str(enabledIndex(i));
                ay.YLabel.FontSize = 7;
                ay.YLabel.Rotation = 0;
                ay.YLabel.Margin = 8;
                ay.YLabel.VerticalAlignment = 'middle';
                ay.YLabel.HorizontalAlignment = 'right';
            end
            % plot last one differently to have x-axes
            handles.PlotHandles(NumChans+1) = subplot(NumChans+1,1,NumChans+1,'Parent',handles.PlotPanel(NumChans+1));
            handles.PlotLineHandles(NumChans+1) = line(PlotDomain(1:PlotSpacing:end),EMGdata(1:PlotSpacing:end,enabledIndex(NumChans)),'Parent',handles.PlotHandles(NumChans+1),'Color',[.2902,0,.5804]); %plot the data from a channel
            ax = gca;
            ax.XLabel.String = 'Time (s)';
            ax.XLabel.FontSize = 12;
            set(gca,'ytick',[])
            set(gca,'TickLength',[0.003 0])
            ax.YLabel.String = (enabledIndex(NumChans));
            ax.YLabel.FontSize = 7;
            ax.YLabel.Rotation = 0;
            ax.YLabel.VerticalAlignment = 'middle';
            ax.YLabel.HorizontalAlignment = 'right';
            linkaxes(handles.PlotHandles,'x')
        else
            handles.PlotHandles = subplot(1,1,1,'Parent',handles.PlotPanel(1));
        end
    end
drawnow;                                    %refreshes the window
end



















