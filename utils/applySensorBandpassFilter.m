function sensor_signals = applySensorBandpassFilter(sensor_signals, dt, f_low, f_high)
%APPLYSENSORBANDPASSFILTER Bandpass-filter sensor time series before reconstruction.

    fs = 1 / dt;
    [b, a] = butter(4, [f_low, f_high] / (fs / 2), 'bandpass');
    for s = 1:size(sensor_signals, 1)
        sensor_signals(s, :) = filtfilt(b, a, sensor_signals(s, :));
    end
end
