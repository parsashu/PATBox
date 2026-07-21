% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Adaptive Minimum Variance Delay-and-Sum (MV-DAS) Beamforming Engine
% Authors:   Parsa Shahidi
%            & Bahareh Khishkhah
% Date:      June 2026
%
% Description:
%   This function implements an analytically optimized, data-adaptive Minimum 
%   Variance (Capon) beamformer integrated into a Delay-and-Sum framework for 
%   photoacoustic tomography. By leveraging the Sherman-Morrison matrix identity, 
%   this algorithm estimates voxel-specific adaptive spatial weights via a 
%   vectorized formulation. It completely bypasses the computationally heavy 
%   $O(N^3)$ sample covariance matrix inversion, incorporating dynamic diagonal 
%   loading to maximize lateral resolution and suppress acoustic clutter.
% =========================================================================

function p0_recon = mv_das(sensor_data, sensor_mask, kgrid, sound_speed, varargin)

    % Parse optional inputs
    p = inputParser;
    addParameter(p, 'envelope_signal', false, @islogical);
    addParameter(p, 'remove_negatives', true, @islogical);
    addParameter(p, 'bandpass_filter', false, @islogical);
    addParameter(p, 'frequency_low', 0.1e6, @isnumeric);
    addParameter(p, 'frequency_high', 10e6, @isnumeric);
    addParameter(p, 'interp_method', 'linear', @ischar);
    % Diagonal Loading factor (epsilon), 0.01 is a standard to make R invertible
    addParameter(p, 'dl_factor', 1.0, @isnumeric);      
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
    
    % Vectorization
    [Y, X] = meshgrid(kgrid.y_vec, kgrid.x_vec);    
    % Apply bandpass filter if requested
    if filter_flag
        sensor_signals = applySensorBandpassFilter(sensor_signals, dt, p.Results.frequency_low, p.Results.frequency_high);
    end
    
    % Initialize 3D array to hold all delayed signals simultaneously
    fprintf('Performing Time Delays...\n');
    fprintf('Grid size: %d x %d, Sensors: %d\n', Nx, Ny, num_sensors);
    
    delayed_signals = zeros(Nx, Ny, num_sensors);
    
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
            delayed_signals(:, :, s) = contribution;
        else
            contribution = interp1(t_array, sensor_signals(s, :), travel_time, interp_method, 0);
            delayed_signals(:, :, s) = contribution;
        end
    end
    
    % =========================================================
    % MV-DAS WEIGHT CALCULATION & APPLICATION
    % =========================================================
    fprintf('Computing MV-DAS Adaptive Weights...\n');
    
    % Standard DAS Output (Spatial sum of all sensors)
    S_das = sum(delayed_signals, 3);
    
    % Spatial Energy (Sum of squares of the delayed signals)
    E = sum(delayed_signals.^2, 3);
    
    % Diagonal Loading (Lambda) to prevent matrix singularity
    % Lambda = (epsilon * trace(R) / N) + tiny_constant
    lambda = (dl_factor .* E ./ num_sensors) + 1e-12;
    
    % Analytical MV-DAS Equation (Sherman-Morrison Vectorization)
    % This skips the O(N^3) matrix inversion (inv(R)) entirely.
    num = lambda .* S_das;
    den = num_sensors .* (lambda + E) - (S_das.^2);
    
    p0_recon = num ./ den;

    p0_recon = finalizeReconImage(p0_recon, envelope_signal_flag, remove_negatives_flag);
    fprintf('MV-DAS reconstruction completed.\n');
    
end
