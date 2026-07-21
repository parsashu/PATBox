% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Coherence-Weighted Minimum Variance Delay-and-Sum (CFMV-DAS) Engine
% Authors:   Parsa Shahidi & Bahareh Khishkhah
% Date:      June 2026
%
% Description:
%   This function implements a hybrid, adaptive CFMV-DAS reconstruction 
%   algorithm for photoacoustic imaging. It unifies the adaptive spatial 
%   filtering of Minimum Variance (MV) beamforming—stabilized via diagonal 
%   loading—with the non-linear sidelobe suppression of the Coherence Factor 
%   (CF). The formulation optimizes pixel-specific sensor apodization weights 
%   to aggressively minimize multi-path acoustic clutter and noise covariance.
% =========================================================================


function p0_recon = cfmvdas(sensor_data, sensor_mask, kgrid, sound_speed, varargin)
    % CFMV-DAS: Coherence-weighted Minimum Variance Delay and Sum
    % Combines the analytical Sherman-Morrison MV-DAS with the CFDAS (QDAS) Coherence Factor.

    % Parse optional inputs
    p = inputParser;
    addParameter(p, 'envelope_signal', false, @islogical);
    addParameter(p, 'remove_negatives', true, @islogical);
    addParameter(p, 'bandpass_filter', false, @islogical);
    addParameter(p, 'frequency_low', 0.1e6, @isnumeric);
    addParameter(p, 'frequency_high', 10e6, @isnumeric);
    addParameter(p, 'interp_method', 'linear', @ischar);
    addParameter(p, 'dl_factor', 1.0, @isnumeric); % Diagonal Loading for MV
    parse(p, varargin{:});
    
    envelope_signal_flag = p.Results.envelope_signal;
    remove_negatives_flag = p.Results.remove_negatives;
    filter_flag = p.Results.bandpass_filter;
    interp_method = p.Results.interp_method;
    dl_factor = p.Results.dl_factor;
    
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
    
    % Get grid dimensions
    Nx = kgrid.Nx;
    Ny = kgrid.Ny;
    dx = kgrid.dx;
    dy = kgrid.dy;
    
    % Get time information
    dt = kgrid.dt;
    Nt = kgrid.Nt;
    t_array = (0:(Nt-1)) * dt;
    
    % Find sensor positions from mask
    [sensor_x_idx, sensor_y_idx] = find(sensor_mask > 0);
    num_sensors = length(sensor_x_idx);
    
    if num_sensors == 0
        error('No sensors found in sensor_mask');
    end
    
    % Handle k-Wave data format
    if size(sensor_signals, 2) == num_sensors && size(sensor_signals, 1) == Nt
        sensor_signals = sensor_signals.';
    elseif size(sensor_signals, 1) == num_sensors && size(sensor_signals, 2) == Nt
        % Already in correct format
    else
        error('Sensor data dimensions do not match expected format.');
    end
    
    % Convert sensor indices to physical coordinates
    sensor_x = kgrid.x_vec(sensor_x_idx);
    sensor_y = kgrid.y_vec(sensor_y_idx);
    
    % Create meshgrid for vectorization
    [Y, X] = meshgrid(kgrid.y_vec, kgrid.x_vec);    
    % Apply bandpass filter to signals if requested
    if filter_flag
        sensor_signals = applySensorBandpassFilter(sensor_signals, dt, p.Results.frequency_low, p.Results.frequency_high);
    end
    
    % --- INITIALIZATION ---
    % Using memory-efficient accumulators instead of a full 3D array
    S_das = zeros(Nx, Ny);  % Sum of delayed signals
    E = zeros(Nx, Ny);      % Sum of squared delayed signals (Spatial Energy)
    
    fprintf('Performing CFMV-DAS reconstruction (with Diagonal Loading)...\n');
    fprintf('Grid size: %d x %d, Sensors: %d\n', Nx, Ny, num_sensors);
    
    for s = 1:num_sensors
        % Calculate distance from all pixels to current sensor
        distance = sqrt((X - sensor_x(s)).^2 + (Y - sensor_y(s)).^2);
        
        % Calculate travel time matrix [Nx, Ny]
        travel_time = distance / sound_speed;
        
        % Interpolate signal for this sensor
        if strcmp(interp_method, 'nearest')
            time_idx = round(travel_time / dt) + 1;
            valid_mask = (time_idx >= 1) & (time_idx <= Nt);
            contribution = zeros(Nx, Ny);
            contribution(valid_mask) = sensor_signals(s, time_idx(valid_mask));
        else
            contribution = interp1(t_array, sensor_signals(s, :), travel_time, interp_method, 0);
        end
        
        % Accumulate sums
        S_das = S_das + contribution;
        E = E + (contribution.^2);
    end
    
    % =========================================================
    % CFDAS WEIGHT CALCULATION & APPLICATION
    % =========================================================
    fprintf('Computing CVDAS Adaptive Weights...\n');
    
    % MV-DAS Component
    lambda = (dl_factor .* E ./ num_sensors) + 1e-12;
    mv_num = lambda .* S_das;
    mv_den = num_sensors .* (lambda + E) - (S_das.^2);
    mv_recon = mv_num ./ mv_den;
    
    % CF (Coherence Factor) Component from QDAS
    cf_num = S_das.^2;
    cf_den = num_sensors .* E + eps;
    CF = cf_num ./ cf_den;
    
    % Combine into CFDAS
    p0_recon = CF .* mv_recon;

    p0_recon = finalizeReconImage(p0_recon, envelope_signal_flag, remove_negatives_flag);
    
    fprintf('CFMV-DAS reconstruction completed.\n');
end
