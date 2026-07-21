function p0_recon = vdas_ubp(sensor_data, sensor_geometry, kgrid, sound_speed, varargin)
    % VDAS_UBP merges Universal Back-Projection preprocessing with Variance 
    % Delay and Sum reconstruction.
    
    % Parse optional inputs
    p = inputParser;
    addParameter(p, 'envelope_signal', false, @islogical);
    addParameter(p, 'remove_negatives', true, @islogical);
    addParameter(p, 'bandpass_filter', false, @islogical);
    addParameter(p, 'frequency_low', 0.1e6, @isnumeric);
    addParameter(p, 'frequency_high', 10e6, @isnumeric);
    addParameter(p, 'interp_method', 'linear', @ischar);
    addParameter(p, 'k_power', 1.0, @isnumeric);
    parse(p, varargin{:});
    
    envelope_signal_flag = p.Results.envelope_signal;
    remove_negatives_flag = p.Results.remove_negatives;
    filter_flag = p.Results.bandpass_filter;
    interp_method = p.Results.interp_method;
    k_power = p.Results.k_power;
    
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
        ubp_signals(s, :) = sensor_signals(s, :) - (t_array .* dp_dt);
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
    
    % Initialize arrays for VDAS calculations
    p0_das = zeros(Nx, Ny);
    p0_sq_sum = zeros(Nx, Ny);
    
    % VDAS-UBP reconstruction
    fprintf('Performing VDAS-UBP reconstruction...\n');
    fprintf('Grid size: %d x %d, Sensors: %d, k_power: %.1f\n', Nx, Ny, num_sensors, k_power);
    
    
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
        % VDAS Core Calculation: accumulate values for variance mapping
        % =========================================================================
        p0_das = p0_das + contribution;
        p0_sq_sum = p0_sq_sum + (contribution.^2);
    end
    
    % =========================================================================
    % CALCULATE VDAS WEIGHTS AND FINAL IMAGE
    % =========================================================================
    % Calculate the variance across sensors: $Var = [\sum x^2 - (\sum x)^2 / M] / (M-1)$
    M = num_sensors;
    pixel_variance = (p0_sq_sum - (p0_das.^2) / M) / (M - 1);
    
    % Prevent tiny negative numbers caused by floating point precision
    pixel_variance(pixel_variance < 0) = 0;
    
    % Calculate the weighting factor: $w(r) = [ V(r) / \max(V) ]^k$
    max_var = max(pixel_variance(:));
    if max_var > 0
        w = (pixel_variance / max_var) .^ k_power;
    else
        w = zeros(Nx, Ny);
    end
    
    % Final VDAS Image = $w(r) \times A_{DAS}(r)$
    p0_recon = w .* p0_das;

    p0_recon = finalizeReconImage(p0_recon, envelope_signal_flag, remove_negatives_flag);
    fprintf('VDAS-UBP reconstruction completed.\n');
    
end
