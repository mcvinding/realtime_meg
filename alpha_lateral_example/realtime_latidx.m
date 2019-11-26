function realtime_latidx(cfg)
 
% FT_REALTIME_POWERESTIMATE is an example realtime application for online
% power estimation. It should work both for EEG and MEG.
%
% Use as
%   ft_realtime_powerestimate(cfg)
% with the following configuration options
%   cfg.left_chan   = cell-array, see FT_CHANNELSELECTION (default = 'all')
%   cfg.right_chan  = cell-array, see FT_CHANNELSELECTION (default = 'all')
%   cfg.foilim      = [Flow Fhigh] (default = [0 120])
%   cfg.blocksize   = number, size of the blocks/chuncks that are processed (default = 1 second)
%   cfg.bufferdata  = whether to start on the 'first or 'last' data that is available (default = 'last')
%   cfg.foi         = frequency band of interest [start stop]
%
% The source of the data is configured as
%   cfg.dataset       = string
% or alternatively to obtain more low-level control as
%   cfg.datafile      = string
%   cfg.headerfile    = string
%   cfg.eventfile     = string
%   cfg.dataformat    = string, default is determined automatic
%   cfg.headerformat  = string, default is determined automatic
%   cfg.eventformat   = string, default is determined automatic
%
% To stop the realtime function, you have to press Ctrl-C
 
% Copyright (C) 2008, Robert Oostenveld
%
% Subversion does not use the Log keyword, use 'svn log <filename>' or 'svn -v log | less' to get detailled information
 
% set the default configuration options
if ~isfield(cfg, 'dataformat'),     cfg.dataformat = [];      end % default is detected automatically
if ~isfield(cfg, 'headerformat'),   cfg.headerformat = [];    end % default is detected automatically
if ~isfield(cfg, 'eventformat'),    cfg.eventformat = [];     end % default is detected automatically
if ~isfield(cfg, 'blocksize'),      cfg.blocksize = 1;        end % in seconds
% if ~isfield(cfg, 'channel'),        cfg.channel = 'all';      end
if ~isfield(cfg, 'foilim'),         cfg.foilim = [0 120];     end
if ~isfield(cfg, 'bufferdata'),     cfg.bufferdata = 'first';  end % first or last
if ~isfield(cfg, 'foi'),            cfg.foi = [8 12];           end % frequency band of interest

% Select left/right channels (defaults as what I expect)
if ~isfield(cfg, 'left_chan')
    cfg.left_chan = {'MEG0431','MEG0441','MEG1811','MEG1821'};  
end % first or last
if ~isfield(cfg, 'right_chan')   
    cfg.right_chan = {'MEG1131','MEG1141','MEG2211','MEG2221'};
end % first or last

cfg.channel = [cfg.left_chan cfg.right_chan];

% translate dataset into datafile+headerfile
cfg = ft_checkconfig(cfg, 'dataset2files', 'yes');
cfg = ft_checkconfig(cfg, 'required', {'datafile' 'headerfile'});
 
% ensure that the persistent variables related to caching are cleared
clear read_header
% start by reading the header from the realtime buffer
hdr = ft_read_header(cfg.headerfile, 'cache', true, 'retry', true, 'checkmaxfilter',false);

chanL_idx = find(cellfun(@(ss) any(cellfun(@(kk) ~isempty(strfind(ss,kk)), cfg.left_chan)), hdr.label)); % The amazing cellfun
chanR_idx = find(cellfun(@(ss) any(cellfun(@(kk) ~isempty(strfind(ss,kk)), cfg.right_chan)), hdr.label)); % The amazing cellfun
allChan_idx = chanL_idx | chanR_idx;


% define a subset of channels for reading
cfg.channel = ft_channelselection(cfg.channel, hdr.label);
% chanindx    = match_str(hdr.label, cfg.channel);
nchan_left      = length(chanL_idx);
nchan_right     = length(chanR_idx);
nchan = nchan_left+nchan_right;

if nchan==0
  error('no channels were selected');
end
 
% determine the size of blocks to process
blocksize = round(cfg.blocksize * hdr.Fs);
 
% this is used for scaling the figure
powmax = 0;
latmax = 0;
latmin = 0;

% set up the spectral estimator
specest = spectrum.welch('Hamming', min(hdr.Fs, blocksize));
 
prevSample  = 0;
count       = 0;

lat_vect = [];
tim_vect = [];
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% this is the general BCI loop where realtime incoming data is handled
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
while true
 
  % determine number of samples available in buffer
  hdr = ft_read_header(cfg.headerfile, 'cache', true,'checkmaxfilter',false);
 
  % see whether new samples are available
  newsamples = (hdr.nSamples*hdr.nTrials-prevSample);
 
  if newsamples>=blocksize
 
    % determine the samples to process
    if strcmp(cfg.bufferdata, 'last')
      begsample  = hdr.nSamples*hdr.nTrials - blocksize + 1;
      endsample  = hdr.nSamples*hdr.nTrials;
    elseif strcmp(cfg.bufferdata, 'first')
      begsample  = prevSample+1;
      endsample  = prevSample+blocksize ;
    else
      error('unsupported value for cfg.bufferdata');
    end
 
    % remember up to where the data was read
    prevSample  = endsample;
    count       = count + 1;
    fprintf('processing segment %d from sample %d to %d\n', count, begsample, endsample);
 
    % read data segment from buffer
    dat_left = ft_read_data(cfg.datafile, 'header', hdr, 'begsample', begsample, 'endsample', endsample, 'chanindx', chanL_idx, 'checkboundary', false, 'timeout',1);
    dat_right = ft_read_data(cfg.datafile, 'header', hdr, 'begsample', begsample, 'endsample', endsample, 'chanindx', chanR_idx, 'checkboundary', false, 'timeout',1);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % from here onward it is specific to the power estimation from the data
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
    % put the data in a fieldtrip-like raw structure
    dataL.trial{1}  = dat_left;
    dataL.time{1}   = offset2time(begsample, hdr.Fs, endsample-begsample+1);
    dataL.label     = hdr.label(chanL_idx);
    dataL.hdr       = hdr;
    dataL.fsample   = hdr.Fs;
%     dataL.grad.chantype      = hdr.grad.chantype(chanL_idx);
    
    dataR = dataL;
    dataR.trial{1}  = dat_right;
    dataR.label     = hdr.label(chanR_idx);
%     dataL.grad      = hdr.grad.chantype(chanR_idx);

    % apply preprocessing options
    dataL.trial{1} = ft_preproc_baselinecorrect(dataL.trial{1});
    dataR.trial{1} = ft_preproc_baselinecorrect(dataR.trial{1});

    figure(1)
    h = get(gca, 'children');
    hold on
 
    if ~isempty(h)
      % done on every iteration
      delete(h);
    end
 
    if isempty(h)
      % done only once
      powmax = 0;
      grid on
    end
 
    % PSD estimate
    for i=1:nchan_left
      estL = psd(specest, dataL.trial{1}(i,:), 'Fs', dataL.fsample);
      if i==1
        powL = estL.Data;
      else
        powL = powL + estL.Data;
      end
    end
    
    for i=1:nchan_right
      estR = psd(specest, dataR.trial{1}(i,:), 'Fs', dataR.fsample);
      if i==1
        powR = estR.Data;
      else
        powR = powR + estR.Data;
      end
    end
 
    powL    = powL/nchan_left;             % average across channels
    powR    = powR/nchan_right;             % average across channels

    powmax = max([max(powL),max(powR), powmax]); % this keeps a history
 
    % Plot "raw" power
%     plot(estL.Frequencies, powL); hold on
%     plot(estR.Frequencies, powR,'r'); hold off
%     
%     axis([cfg.foilim(1) cfg.foilim(2) 0 powmax]);
%  
%     str = sprintf('time = %d s\n', round(mean(data.time{1})));
%     title(str);
%  
%     xlabel('frequency (Hz)');
%     ylabel('power');
%     % force Matlab to update the figure
    drawnow
    
    % Get L/R ratio
    freq_idxL = estL.Frequencies >= cfg.foi(1) & estL.Frequencies <= cfg.foi(2);
    bandPowL = mean(powL(freq_idxL));
    freq_idxR = estR.Frequencies >= cfg.foi(1) & estR.Frequencies <= cfg.foi(2);
    bandPowR = mean(powR(freq_idxR));
    
    lat_idx = (bandPowR-bandPowL)/(bandPowL+bandPowR);
    
    tim = round(mean(dataL.time{1})); %current timestamp
    
    if isempty(lat_vect)
        lat_vect = lat_idx;
        tim_vect = tim;
    elseif length(lat_vect) < 10;
        lat_vect = [lat_vect, lat_idx]; 
        tim_vect = [tim_vect, tim];
    else
        lat_vect(1:end-1) = lat_vect(2:end);
        lat_vect(end) = lat_idx;
        tim_vect(1:end-1) = tim_vect(2:end);
        tim_vect(end) = tim;
    end
    
    latmax = max([max(lat_vect), latmax]); % this keeps a history
    latmin = min([min(lat_vect), latmin]); % this keeps a history

    plot(lat_vect,tim_vect,'-ok'); hold on
    axis([-1 1 tim_vect(1) tim_vect(end)+1 ]);
    
    str = sprintf('time = %d s\n', tim);
    title(str);
    
    ylabel('Time (s)');
    xlabel('L>R <-  Lat.idx.  -> R>L');
    
    % force Matlab to update the figure
    drawnow
 
  end % if enough new samples
end % while true

