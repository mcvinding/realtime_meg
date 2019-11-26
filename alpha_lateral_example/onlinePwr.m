%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ONLINE ALPHA/MU LATERALIATION
% Last updated 2017-09-05 MCV
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Setup
addpath /home/mikkel/fieldtrip/fieldtrip
addpath /home/mikkel/fieldtrip/fieldtrip/external/mne
ft_defaults


% add FieldTrip buffer here...                      [!!!]

%% Initiation variables
left_sens = {'MEG043','MEG044','MEG181','MEG182'};
right_sens = {'MEG113','MEG114','MEG221','MEG222'};


% Data import and peak detection vars
windowsize  = 1.0;      % seconds
peakThres   = 0.4;      % Threshold for determining movement peaks. % of max 
padsize     = 0.1;      % seconds
arbThresh   = 0.1;      % Arbitrary cutoff to avoid detecting noise peaks!

% Set-up data variables
filename = 'buffer://130.229.40.57:1972';
% Dummy
filename = '/archive/20057_working_memory/MEG/NatMEG_0264/161006/finger_wm.fif';

%% Do analysis
slct_channels = [left_sens, right_sens];

% data = ft_



%% Prepeare and run data
% Find accelerometer data
% hdr = [];   
try
    hdr = ft_read_header(filename,'checkmaxfilter',false);
    chanL_idx = cellfun(@(ss) any(cellfun(@(kk) ~isempty(strfind(ss,kk)), left_sens)), hdr.label); % The amazing cellfun
    chanR_idx = cellfun(@(ss) any(cellfun(@(kk) ~isempty(strfind(ss,kk)), right_sens)), hdr.label); % The amazing cellfun
    allChan_idx = chanL_idx | chanR_idx;
catch
    error('Could not read buffer. Check stuff.');
end

windowlen = round(windowsize*hdr.Fs);
padlen    = round(padsize*hdr.Fs); % samples FIXME should be even

% Get initial samples
endsample = hdr.nSamples;
begsample = endsample - windowlen + 1;

cfg                = [];
cfg.blocksize      = 1;                            % seconds
cfg.foilim         = [0 30];                       % frequency-of-interest limits, Hz
cfg.dataset        = 'buffer://localhost:1972';    % where to read the data from
ft_realtime_powerestimate(cfg)


%% Loop
while true %%strcmp(get(t_total,'Running'),'on')
    dataL = ft_read_data(filename, 'begsample', begsample-padlen, 'endsample', endsample+padlen, 'chanindx', chanL_idx, 'blocking', true, 'timeout', 5,'checkmaxfilter',false);
    dataR = ft_read_data(filename, 'begsample', begsample-padlen, 'endsample', endsample+padlen, 'chanindx', chanR_idx, 'blocking', true, 'timeout', 5,'checkmaxfilter',false);

    tim = ((begsample-padlen):(endsample+padlen))/hdr.Fs;

%     dat = sqrt(sum(ft_preproc_baselinecorrect(dat).^2,1));
    dataL = abs(sum(ft_preproc_baselinecorrect(dataL),1));
    
    datZ = zscore(dataL);

    dataL(end) = 0;
    thresh = dataL;
    thresh(datZ<1.5) = 0;
%     thresh(thresh<(peakThres*max(thresh))) = 0;
    thresh(thresh<arbThresh) = 0;      
    
    plotDummy = dataL;
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
        plot(tim, dataL)
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



