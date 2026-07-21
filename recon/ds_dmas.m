% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Sub-Array Based Delay-Sum-Multiply-and-Sum (DS-DMAS) Engine
% Authors:   Parsa Shahidi
%            &  Bahareh Khishkhah
% Date:      June 2026
%
% Description:
%   This function implements the dual-stage DS-DMAS reconstruction algorithm
%   for photoacoustic tomography. By partitioning the transducer array into 
%   distinct sub-arrays, it applies standard linear coherent summing within 
%   each sub-group (Stage 1: DAS) before executing cross-combinatorial non-linear 
%   multiplication across consolidated sub-array outputs (Stage 2: DMAS). 
%   This spatial partitioning framework enhances clutter noise immunity in 
%   optically heterogeneous media.
% =========================================================================

function p0_recon = ds_dmas(sensor_data, sensor_mask, kgrid, sound_speed, varargin)

    % Parse optional inputs
    p = inputParser;
    addParameter(p, 'envelope_signal', false, @islogical);
    addParameter(p, 'remove_negatives', true, @islogical);
    addParameter(p, 'bandpass_filter', false, @islogical);
    addParameter(p, 'frequency_low', 0.1e6, @isnumeric);
    addParameter(p, 'frequency_high', 10e6, @isnumeric);
    addParameter(p, 'interp_method', 'linear', @ischar);
    addParameter(p, 'num_subarrays', 20, @isnumeric);
    parse(p, varargin{:});

    envelope_signal_flag = p.Results.envelope_signal;
    remove_negatives_flag = p.Results.remove_negatives;
    filter_flag = p.Results.bandpass_filter;
    interp_method = p.Results.interp_method;
    num_subarrays = p.Results.num_subarrays;
    
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
    
    % Ensure num_subarrays is valid
    if num_subarrays > num_sensors
        warning('num_subarrays (%d) > num_sensors (%d). Setting num_subarrays to num_sensors.', num_subarrays, num_sensors);
        num_subarrays = num_sensors;
    end
    
    % Handle k-Wave data format: sensor_data.p is [num_time_steps x num_sensors]
    if size(sensor_signals, 2) == num_sensors && size(sensor_signals, 1) == Nt
        sensor_signals = sensor_signals.';
    elseif size(sensor_signals, 1) == num_sensors && size(sensor_signals, 2) == Nt
        % Already in correct format
    else
        error('Sensor data dimensions [%d x %d] do not match expected format.', ...
              size(sensor_signals, 1), size(sensor_signals, 2));
    end
    
    % Convert sensor indices to physical coordinates
    sensor_x = kgrid.x_vec(sensor_x_idx);
    sensor_y = kgrid.y_vec(sensor_y_idx);
    
    % Create meshgrid for vectorization
    [Y, X] = meshgrid(kgrid.y_vec, kgrid.x_vec);    
    % Apply bandpass filter if requested
    if filter_flag
        sensor_signals = applySensorBandpassFilter(sensor_signals, dt, p.Results.frequency_low, p.Results.frequency_high);
    end
    
    % Initialize DMAS running sums for Stage 2
    sum_y = zeros(Nx, Ny);
    sum_y_sq = zeros(Nx, Ny);
    
    % DS-DMAS reconstruction
    fprintf('Performing DS-DMAS reconstruction...\n');
    fprintf('Grid size: %d x %d, Sensors: %d, Sub-arrays: %d\n', Nx, Ny, num_sensors, num_subarrays);
    
    
    % Determine sensors per group
    sensors_per_group = ceil(num_sensors / num_subarrays);
    
    % Iterate over sub-arrays
    for k = 1:num_subarrays
        
        start_idx = (k-1) * sensors_per_group + 1;
        end_idx = min(k * sensors_per_group, num_sensors);
        
        if start_idx > num_sensors
            break; % Safety catch
        end
        
        % Stage 1: DAS running sum for the current sub-array
        sub_array_das = zeros(Nx, Ny);
        
        for s = start_idx:end_idx
            % Calculate distance from all pixels to current sensor
            distance = sqrt((X - sensor_x(s)).^2 + (Y - sensor_y(s)).^2);
            
            % Calculate travel time matrix
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
            
            % Accumulate DAS for this sub-array
            sub_array_das = sub_array_das + contribution;
        end
        
        % Stage 2: Apply DMAS expansion to the consolidated sub-array output
        sum_y = sum_y + (sign(sub_array_das) .* sqrt(abs(sub_array_das)));
        sum_y_sq = sum_y_sq + abs(sub_array_das);
    end
    
    % Finalize DMAS calculation using the algebraic expansion
    p0_recon = abs(0.5 * ((sum_y .^ 2) - sum_y_sq));

    p0_recon = finalizeReconImage(p0_recon, envelope_signal_flag, remove_negatives_flag);
    fprintf('DS-DMAS reconstruction completed.\n');
    
end
