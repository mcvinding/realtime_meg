cfg                = [];
cfg.channel        = 1:10;                         % list with channel "names"
cfg.blocksize      = 1;                            % seconds
cfg.fsample        = 250;                          % sampling frequency, Hz
cfg.lpfilter       = 'yes';                        % apply a low-pass filter
cfg.lpfreq         = 20;                           % filter frequency, Hz
cfg.target.dataset = 'buffer://localhost:1972';    % where to write the data
ft_realtime_signalproxy(cfg)