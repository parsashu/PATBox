% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Hybrid DMAS-UBP Non-Linear Reconstruction Engine
% Authors:   Parsa Shahidi
%            & Bahareh Khishkhah
% Date:      June 2026
%
% Description:
%   This function implements a high-performance, hybrid DMAS-UBP photoacoustic 
%   reconstruction algorithm. It integrates the time-domain derivative back-
%   projection physics of the Universal Back-Projection (UBP) formulation with 
%   the non-linear sidelobe-suppression capabilities of the Delay-Multiply-
%   and-Sum (DMAS) framework. Additionally, the engine incorporates dynamic 
%   transducer directivity angle compensation to maximize resolution in 
%   limited-view acoustic detection fields.
% =========================================================================

function p0_recon = dmas_ubp(sensor_data, sensor_geometry, kgrid, sound_speed, varargin)
    % DMAS_UBP merges Universal Back-Projection preprocessing with Delay 
    % Multiply and Sum reconstruction.
    
    % Parse optional inputs
    p = inputParser;
    addParameter(p, 'envelope_signal', false, @islogical);
    addParameter(p, 'remove_negatives', true, @islogical);
    addParameter(p, 'bandpass_filter', false, @islogical);
    addParameter(p, 'frequency_low', 0.1e6, @isnumeric);
    addParameter(p, 'frequency_high', 10e6, @isnumeric);
    addParameter(p, 'interp_method', 'linear', @ischar);
    addParameter(p, 'ubp_weight', 0.015, @isnumeric);
    parse(p, varargin{:});
    
    envelope_signal_flag = p.Results.envelope_signal;
    remove_negatives_flag = p.Results.remove_negatives;
    filter_flag = p.Results.bandpass_filter;
    interp_method = p.Results.interp_method;
    ubp_weight = p.Results.ubp_weight; 
    
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
    
    % Accept either a plain sensor mask or the full sensor struct.
    if isstruct(sensor_geometry)
        sensor_mask = sensor_geometry.mask;
        has_directivity = isfield(sensor_geometry, 'directivity_angle');
        if has_directivity
            directivity_angle_map = sensor_geometry.directivity_angle;
        else
            directivity_angle_map = [];
        end
    else
        sensor_mask = sensor_geometry;
        has_directivity = false;
        directivity_angle_map = [];
    end

    % Get grid dimensions
    Nx = kgrid.Nx;
    Ny = kgrid.Ny;
    
    % Get time information
    dt = kgrid.dt;
    Nt = kgrid.Nt;
    if ~isempty(kgrid.t_array) && ~ischar(kgrid.t_array)
        t_array = kgrid.t_array(:).';
    else
        t_array = (0:(Nt-1)) * dt;
    end
    fs = 1/dt;
    
    % Find sensor positions from mask
    [sensor_x_idx, sensor_y_idx] = find(sensor_mask > 0);
    num_sensors = length(sensor_x_idx);
    
    if num_sensors == 0
        error('No sensors found in sensor_mask');
    end
    
    % Handle k-Wave data format: transpose to [num_sensors x num_time_steps]
    if size(sensor_signals, 2) == num_sensors && size(sensor_signals, 1) == Nt
        sensor_signals = sensor_signals.';
    elseif size(sensor_signals, 1) == num_sensors && size(sensor_signals, 2) == Nt
        % Already in correct format
    else
        error('Sensor data dimensions [%d x %d] do not match expected format.', ...
              size(sensor_signals, 1), size(sensor_signals, 2));
    end
    
    % Apply bandpass filter if requested
    if filter_flag
        sensor_signals = applySensorBandpassFilter(sensor_signals, dt, p.Results.frequency_low, p.Results.frequency_high);
    end
    
    % =========================================================================
    % UBP SPECIFIC STEP: Calculate $p(t) - t \times \frac{dp(t)}{dt}$
    % =========================================================================
    fprintf('Applying UBP Time-Domain Derivative...\n');
    ubp_signals = zeros(size(sensor_signals));
    
    for s = 1:num_sensors
        % Calculate the time derivative of the pressure signal
        dp_dt = gradient(sensor_signals(s, :), dt);
        
        % Form the UBP quantity
        ubp_signals(s, :) = sensor_signals(s, :) - (ubp_weight * (t_array .* dp_dt));
    end
    
    % Replace original signals with the UBP processed signals
    sensor_signals = ubp_signals;
    % =========================================================================    
    % Convert sensor indices to physical coordinates
    sensor_x = kgrid.x_vec(sensor_x_idx);
    sensor_y = kgrid.y_vec(sensor_y_idx);
    if has_directivity
        sensor_angle = zeros(num_sensors, 1);
        for s = 1:num_sensors
            sensor_angle(s) = directivity_angle_map(sensor_x_idx(s), sensor_y_idx(s));
        end
    end
    
    % Create meshgrid for vectorization
    [Y, X] = meshgrid(kgrid.y_vec, kgrid.x_vec);
    
    % Initialize DMAS running sums (Optimized O(N) approach)
    sum_y = zeros(Nx, Ny);
    sum_y_sq = zeros(Nx, Ny);
    
    % DMAS-UBP reconstruction
    fprintf('Performing DMAS-UBP reconstruction...\n');
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
            contribution(isnan(contribution)) = 0;
        end

        if has_directivity
            ray_angle = atan2(Y - sensor_y(s), X - sensor_x(s));
            angle_error = atan2(sin(ray_angle - sensor_angle(s)), cos(ray_angle - sensor_angle(s)));
            directivity_weight = max(cos(angle_error), 0);
            contribution = contribution .* directivity_weight;
        end
        
        % =========================================================================
        % DMAS Core Calculation
        % =========================================================================
        sum_y = sum_y + (sign(contribution) .* sqrt(abs(contribution)));
        sum_y_sq = sum_y_sq + abs(contribution);
    end
    
    % Finalize DMAS calculation using the algebraic expansion
    p0_recon = abs(0.5 * ((sum_y .^ 2) - sum_y_sq));

    p0_recon = finalizeReconImage(p0_recon, envelope_signal_flag, remove_negatives_flag);
    
    fprintf('DMAS-UBP reconstruction completed.\n');
    
end
