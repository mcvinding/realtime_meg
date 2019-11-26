% Analysis of tapping_tsss_mc.fif and/or realtime MEG. 
% This version last updated 2016-07-18 17:03.
clear all

% import all relevant packages and set paths
addpath('D:\NATMEG PROJECTS\20055_parkinson_motor\matlab_scripts');
addpath('C:\Users\NatMEG\Documents\MATLAB');

%initial_setup
PDmotor_initSetUp(1)
%run('PDmotor_metavars.m')
%m = setUpSharedFile('D:\NATMEG PROJECTS\20055_parkinson_motor\matlab_scripts\trigger.dat');

%% Setup parameters
%Initial variables and parameters to change
frequency       = 2;            % Frequency for tapping/PAM (in Hz);
duration        = 3;            % Duration of stimulation/tapping in minutes
expectedFreq    = frequency;    % Expected tapping frequency (in Hz)
errorWin        = .6;           % error margin for tapping frequency (in Hz +/- from expected)

% Data import and peak detection vars
windowsize  = 1.0;      % seconds
peakThres   = 0.4;      % Threshold for determining movement peaks. % of max 
padsize     = 0.1;      % seconds
arbThresh   = 0.1;      % Arbitrary cutoff to avoid detecting noise peaks!

% % Tapping variables
slowfreq    = expectedFreq-errorWin;      % Slowest allowed tapping frequency
fastfreq    = expectedFreq+errorWin;      % Fastest allowed tapping frequency
 
%Variables
lowcutoff = 1/slowfreq;
highcutoff = 1/fastfreq;

% Set-up data variables
filename = 'buffer://130.229.40.57:1972';

%% Set up triggers to prallell port
config_io;
adress = 41008;  % PORT 1: 41040, PORT 5: 41008. Use port 1.
trigger_val = 1;
outp(adress,-3);     % reset port

%% SET WHICH FINGER TO USE HERE. MUST MACH PRESENTATION!!!
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Finger      = 2% 1 = right, 2 = left

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Prepeare and run data
% Find accelerometer data
hdr = [];   
try
    hdr = ft_read_header(filename);
    misc = find(~cellfun(@isempty, strfind(hdr.label, 'MISC')));

catch
    error('Could not read buffer. Check stuff.');
end

if Finger == 1; %Right finger
    misc = misc(1:3); % first three channels
    disp('Using first three MISC channels');
elseif Finger == 2;
    misc = misc(4:6); % last three channels
    disp('Using last three MISC channels');
else
    error('ERROR: Finger variable must be 1 or 2');
end

windowlen = round(windowsize*hdr.Fs);
padlen    = round(padsize*hdr.Fs); % samples FIXME should be even

% Get initial samples
endsample = hdr.nSamples;
begsample = endsample - windowlen + 1;

% Prepare tapping vars.
tap = [];
is_cue = false; % If true the cues will appear!
ff = 1;
% trigger_send = 0;
sig = 1; % Set port value

while true %%strcmp(get(t_total,'Running'),'on')
    dat = ft_read_data(filename, 'begsample', begsample-padlen, 'endsample', endsample+padlen, 'chanindx', misc, 'blocking', true, 'timeout', 5);
    tim = ((begsample-padlen):(endsample+padlen))/hdr.Fs;

%     dat = sqrt(sum(ft_preproc_baselinecorrect(dat).^2,1));
    dat = abs(sum(ft_preproc_baselinecorrect(dat),1));
    
    datZ = zscore(dat);

    dat(end) = 0;
    thresh = dat;
    thresh(datZ<1.5) = 0;
%     thresh(thresh<(peakThres*max(thresh))) = 0;
    thresh(thresh<arbThresh) = 0;      
    
    plotDummy = dat;
    plotDummy(padlen:padlen+windowlen) = nan;
    
    [pks, locs] = findpeaks(double(thresh), 'MinPeakDistance',padlen*2.5);
    
    if isempty(pks)
        %...
    end
    
    % Padding in peak detection
    remove = find(locs<padlen+1); %+1 due to 1 sample overlap in windows
    pks(remove) = [];
    locs(remove) = [];

    remove = find(locs>(padlen+windowlen));
    pks(remove) = [];
    locs(remove) = [];

    % Plot (stop if not able to plot)
    try 
        plot(tim, dat)
        hold on
        plot(tim, thresh, 'g')
        plot(tim(locs), pks, 'ro')
        plot(tim, plotDummy, 'r')
%         plot(tim, datZ, 'k')
        hold off
        drawnow
        if isempty(locs)
            disp('No peaks detected');
        else
            disp(locs);
        end
    catch
        disp('Lost data steam. Done?!?');
        break
    end
   
    tap = cat(2, tap, tim(locs));
    iti = diff(tap);

    if length(iti) >= 8
        if isempty(pks)
            rate = [];
        else
            rate = nanmedian(iti(end-7:end));
        end
        
        if rate > lowcutoff 
            is_cue = true;
            display(['Too SLOW tapping. ITI = ',num2str(rate),' ',num2str(1/rate),'Hz'])
            %keyboard
        elseif rate < highcutoff
            is_cue = true;
            display(['Too FAST tapping. ITI = ',num2str(rate),' ',num2str(1/rate),'Hz'])
            %keyboard
        else
            display(['Rate = ',num2str(rate)]);
        end
    end 
    
    if is_cue
        display('Sending trigger');
        outp(adress,trigger_val);   % Send trigger
        WaitSecs(0.004);
        outp(adress,0);             % rest port
        is_cue = 0;
    end
            
    begsample = endsample + 1;
    endsample = begsample + round(windowsize*hdr.Fs) - 1;
    
end

