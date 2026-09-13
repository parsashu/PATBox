function configs = generalizationAcquisitionConfigs()
%GENERALIZATIONACQUISITIONCONFIGS
% Acquisition configurations for morphology/generalizability study.
%
% All configurations:
%   - full 360-degree view
%   - finite 0.20-mm detector elements
%   - heterogeneous acoustic medium
%   - power-law attenuation
%   - AWGN at 20 dB
%
% Differences:
%
% A1: reference
% A2: fewer receivers
% A3: shifted detector center frequency

    %% =========================================================
    % A1
    % ==========================================================

    configs(1) = struct( ...
        'Id','A1_reference', ...
        'Label','128 ch, 2 MHz', ...
        'NumTransducers',128, ...
        'CenterFrequency',2e6, ...
        'FractionalBandwidthPercent',80);

    %% =========================================================
    % A2
    % ==========================================================

    configs(2) = struct( ...
        'Id','A2_N96', ...
        'Label','96 ch, 2 MHz', ...
        'NumTransducers',96, ...
        'CenterFrequency',2e6, ...
        'FractionalBandwidthPercent',80);

    %% =========================================================
    % A3
    % ==========================================================

    configs(3) = struct( ...
        'Id','A3_fc3MHz', ...
        'Label','128 ch, 3 MHz', ...
        'NumTransducers',128, ...
        'CenterFrequency',3e6, ...
        'FractionalBandwidthPercent',80);

end