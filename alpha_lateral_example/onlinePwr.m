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

%% Set-up data variables
% Pick only one
% 1: True buffer (only works in lab)
% 2: Fake buffer generated with sigprox.m
% 3: Real offline data read as if it real-time data.

% filename = 'buffer://130.229.40.57:1972';
% filename = 'buffer://localhost:1972';
filename = '/archive/20057_working_memory/MEG/NatMEG_0264/161006/finger_wm.fif';


%% Prepeare and run data

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
cfg.datafile        = filename;    % where to read the data from
ft_realtime_powerestimate(cfg)


% Test with "alpha lateralizartion" script. Only works for the real data.
realtime_latidx(cfg)

%END