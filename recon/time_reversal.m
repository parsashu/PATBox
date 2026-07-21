% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Numerical Acoustic Time Reversal (TR) Physics Engine
% Date:      June 2026
%
% Description:
%   This function implements the numerically exact Acoustic Time Reversal (TR) 
%   reconstruction algorithm using k-Wave's k-space pseudospectral solver. 
%   It maps the recorded time-series pressure signals as a Dirichlet boundary 
%   condition, running the acoustic wave equation backward in time. This methodology 
%   natively accounts for complex wave propagation physics, making it the primary 
%   benchmark for quantitative accuracy and optimal adjoint updates in the 
%   iterative optimization framework.
% =========================================================================

function p0_recon = time_reversal(sensor_data, sensor_mask, kgrid, sound_speed, varargin)

    % Parse optional inputs
    p = inputParser;
    addParameter(p, 'envelope_signal', false, @islogical);
    addParameter(p, 'remove_negatives', true, @islogical);
    addParameter(p, 'bandpass_filter', false, @islogical);
    addParameter(p, 'frequency_low', 0.1e6, @isnumeric);
    addParameter(p, 'frequency_high', 10e6, @isnumeric);
    addParameter(p, 'interp_method', 'linear', @ischar);
    parse(p, varargin{:});

    envelope_signal_flag = p.Results.envelope_signal;
    remove_negatives_flag = p.Results.remove_negatives;
    filter_flag = p.Results.bandpass_filter;
    interp_method = p.Results.interp_method; %#ok<NASGU>

    % Extract sensor data if it's a structure
    if isstruct(sensor_data)
        if isfield(sensor_data, 'p')
            sensor_signals = sensor_data.p;
        else
            error('sensor_data structure must contain field ''p''');
        end
    else
        sensor_signals = sensor_data;
    end

    % Get time information
    dt = kgrid.dt;
    Nt = kgrid.Nt;
    
    % k-Wave input checker crash fix
    if ischar(kgrid.t_array) && strcmp(kgrid.t_array, 'auto')
        kgrid.t_array = (0:Nt-1) * dt;
    end

    % Find sensor positions from mask
    [sensor_x_idx, ~] = find(sensor_mask > 0);
    num_sensors = length(sensor_x_idx);

    if num_sensors == 0
        error('No sensors found in sensor_mask');
    end

    % Handle k-Wave data format: ensure [sensors x time]
    if size(sensor_signals, 2) == num_sensors && size(sensor_signals, 1) == Nt
        sensor_signals = sensor_signals.';
    end

    % Apply bandpass filter if requested
    if filter_flag
        sensor_signals = applySensorBandpassFilter(sensor_signals, dt, p.Results.frequency_low, p.Results.frequency_high);
    end
    fprintf('Performing Time Reversal reconstruction using k-Wave...\n');

    % Define the medium properties
    medium.sound_speed = sound_speed;
    medium.density = 1000;

    % Setup the sensor for Time Reversal
    sensor.mask = sensor_mask;
    sensor.time_reversal_boundary_data = single(sensor_signals);

    % Empty source struct
    source = struct();

    % Run the k-Wave solver backward in time
    p0_recon = kspaceFirstOrder2D(kgrid, medium, source, sensor, ...
        'PMLInside', false, ...
        'PMLSize', 20, ...
        'PlotPML', false, ...
        'Smooth', false, ...
        'PlotSim', false, ...
        'DataCast', 'gpuArray-single');

    % Enforce double precision for MATLAB post-processing
    p0_recon = double(p0_recon);

    p0_recon = finalizeReconImage(p0_recon, envelope_signal_flag, remove_negatives_flag);

    fprintf('Time Reversal reconstruction completed.\n');

end
