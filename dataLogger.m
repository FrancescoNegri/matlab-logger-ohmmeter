%% Clear the MATLAB environment
clc;
close all;
clear global;
clear;

%% Session parameters
defaultID = datetime('now');
dateFormat = 'yyyymmdd';
timeFormat = 'HHMMSS';
dateStr = datestr(defaultID, dateFormat);
timeStr = datestr(defaultID, timeFormat);
defaultID = strcat(dateStr, "T", timeStr);

prompt = {'Enter the measurement session ID: '};
dlgtitle = 'Input ID';
dims = [1 50];
definput = {char(defaultID)};
sessionID = inputdlg(prompt,dlgtitle,dims,definput);
if (isempty(sessionID))
    sessionID = defaultID;
else
    sessionID = string(sessionID{1});
end

fprintf("Session started with ID: %s \n", sessionID);

%% Plot config
plotTitle = 'Rx vs. t';             % plot title
xLabel = 'Time t   [s]';            % x-axis label
yLabel = 'Resistance Rx(t)   [Ohm]';% y-axis label
plotGrid = 'on';                    % 'off' to turn off grid
minY = 0;                           % set y-min
maxY = inf;                         % set y-max
minX = 0;                           % set x-min
maxX = 700;                         % set x-max
scrollWidth = 10;                   % display period in plot, plot entire data log if <= 0

% Data vars
t = zeros(maxX*25, 1);
Rx = zeros(maxX*25, 1);
timeMarkers = zeros(10, 1);
count = 0;
tmCount = 0;

%% Set up plot
plotGraph = plot(t,Rx,'xb'); % Il punto (0,0) è legato all'inizializzazione del grafico!
title(strcat(plotTitle, " - ID: ", sessionID),'FontSize',15);
xlabel(xLabel,'FontSize',10);
ylabel(yLabel,'FontSize',10);
axis([minX maxX minY maxY]);
grid(plotGrid);

%% Connect to Arduino and wait
arduinoPort = 'COM6';
baudRate = 115200;

%in-loop vars
tempData = 0;
tempR = 0;
tempT = 0;

disp("Ready. Press a key to start the serial connection. Pay attention not to exceed the timeout period!");
pause();    % Wait for key to be pressed
stopFlag = stopLoop({'IMPORTANT: press OK to stop measuring data before time expires.'}); 
markerFlag =stopLoop({'Set time marker'});

connectionErrorFlag = false;
try
    s = serialport(arduinoPort, baudRate);
catch
    connectionErrorFlag = true;
    errordlg('Could not connect to Arduino device. Stopping execution.', 'Connection Error');   
end

if (connectionErrorFlag == false)
    samplingFrequency = num2str(extractNum(readline(s)));
    fprintf("Sampling frequency: %s Hz\n", samplingFrequency);
    disp("Recording...");

    %% Plotting
    while(~stopFlag.Stop())
        count = count + 1;
        tempData = readline(s);
        tempData = strsplit(tempData, ';');
        tempR = str2double(tempData(1));
        if (tempR == -1) 
            count = count - 1;
            break;
        end
        tempT = str2double(tempData(2))/1000;

        if (markerFlag.Stop())
            tmCount = tmCount + 1;
            timeMarkers(tmCount) = tempT;
            markerFlag = stopLoop({'Set time marker.'});
        end

        t(count) = tempT;
        Rx(count) = tempR;
        
        disp(Rx(count));
        set(plotGraph,'XData',t,'YData',Rx);
    end

    fprintf("Done. Samples gathered: %d \n", count);
end

stopFlag.Clear();
markerFlag.Clear();
clear stopFlag markerFlag;
clear s plotGraph plotGrid plotTitle minX maxX minY maxY scrollWidth;
clear tempData tempR tempT xLabel yLabel;
clear arduinoPort baudRate prompt;
clear dateFormat dateStr timeStr defaultID definput dims dlgtitle timeFormat;

if (connectionErrorFlag == false)
    %% Create final data table
    Rx = Rx(1:count);
    t = t(1:count);
    dataTable = [t, Rx];
    dataTable = [["t", "R"]; dataTable];
    

    if (tmCount >= 1)
        timeMarkers = timeMarkers(1:tmCount);
        timeMarkers = [["t"]; timeMarkers];
    else 
        timeMarkers = [];
    end

    %% Saving data
    disp("Saving data ...");

    sessionID = strcat(sessionID, "_", samplingFrequency, "Hz");

    if (tmCount >= 1)
        fileName = strcat("data/", sessionID, "_TIME_MARKERS", ".xlsx");
        writematrix(timeMarkers, fileName);
    end

    fileName = strcat("data/", sessionID, ".xlsx");
    writematrix(dataTable, fileName);
    fprintf("Saved as: %s \n", fileName);
end