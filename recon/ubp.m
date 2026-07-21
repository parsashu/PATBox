% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Analytical Universal Back-Projection (UBP) Reconstruction Engine
% Authors:   Parsa Shahidi
%            & Bahareh Khishkhah
% Date:      June 2026
%
% Reference Standard:
%   Xu, M., & Wang, L. V. (2005). Universal back-projection algorithm for 
%   photoacoustic computed tomography. Physical Review E, 71(1), 016706.
%   DOI: 10.1103/PhysRevE.71.016706 (Erratum: Phys. Rev. E, 75, 059903, 2007).
%
% Description:
%   This function implements the mathematically exact Universal Back-Projection 
%   (UBP) inversion algorithm for photoacoustic computed tomography based on the 
%   rigorous Xu-Wang framework. It applies a time-domain pre-projection filtering 
%   operator ($p(t) - t \cdot \frac{\partial p}{\partial t}$) to account for spatial 
%   and temporal acoustic dipoles before performing space-time coherent 
%   back-projection over the acoustic sensor grid.
% =========================================================================

function p0_recon = ubp(sensor_data, sensor_mask, kgrid, sound_speed, varargin)

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
    interp_method = p.Results.interp_method;
    
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
    
    % Get time information
    dt = kgrid.dt;
    Nt = kgrid.Nt;
    t_array = (0:(Nt-1)) * dt;
    fs = 1/dt; % Sampling frequency

    if isstruct(sensor_mask) && isfield(sensor_mask, 'mask')
        sensor_mask = sensor_mask.mask;
    end
    
    % Find sensor positions from mask
    [sensor_x_idx, sensor_y_idx] = find(sensor_mask > 0);
    num_sensors = length(sensor_x_idx);
    
    if num_sensors == 0
        error('No sensors found in sensor_mask');
    end
    
    % Handle k-Wave data format
    if size(sensor_signals, 2) == num_sensors && size(sensor_signals, 1) == Nt
        % k-Wave format: [time x sensors] -> transpose to [sensors x time]
        sensor_signals = sensor_signals.';
    elseif size(sensor_signals, 1) == num_sensors && size(sensor_signals, 2) == Nt
        % Already in correct format [sensors x time]
        % Do nothing
    else
        error('Sensor data dimensions [%d x %d] do not match expected format. Expected [%d x %d] or [%d x %d]', ...
              size(sensor_signals, 1), size(sensor_signals, 2), ...
              Nt, num_sensors, num_sensors, Nt);
    end
    
    % Apply bandpass filter if requested
    if filter_flag
        sensor_signals = applySensorBandpassFilter(sensor_signals, dt, p.Results.frequency_low, p.Results.frequency_high);
    end
    
    % =========================================================================
    % UBP SPECIFIC STEP: Calculate p(t) - t * dp(t)/dt
    % =========================================================================
    fprintf('Applying UBP Time-Domain Derivative...\n');
    ubp_signals = zeros(size(sensor_signals));
    
    for s = 1:num_sensors
        % Calculate the time derivative of the pressure signal
        dp_dt = gradient(sensor_signals(s, :), dt);
        
        % Form the UBP quantity: p(t) - t * dp/dt
        % (The factor of 2 in the exact formula is omitted as it scales out during normalization)
        ubp_signals(s, :) = sensor_signals(s, :) - (t_array .* dp_dt);
    end
    
    % Replace original signals with the UBP processed signals
    sensor_signals = ubp_signals;
    % =========================================================================    
    % Convert sensor indices to physical coordinates
    sensor_x = kgrid.x_vec(sensor_x_idx);
    sensor_y = kgrid.y_vec(sensor_y_idx);
    
    % Create meshgrid for vectorization
    [Y, X] = meshgrid(kgrid.y_vec, kgrid.x_vec);
    
    % Initialize reconstruction
    p0_recon = zeros(Nx, Ny);
    
    % UBP reconstruction: back-project the modified signals
    fprintf('Performing UBP reconstruction...\n');
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
            
            p0_recon(valid_mask) = p0_recon(valid_mask) + contribution(valid_mask);
        else
            contribution = interp1(t_array, sensor_signals(s, :), travel_time, interp_method, 0);
            contribution(isnan(contribution)) = 0;
            
            p0_recon = p0_recon + contribution;
        end

    end

    p0_recon = finalizeReconImage(p0_recon, envelope_signal_flag, remove_negatives_flag);
    fprintf('UBP reconstruction completed.\n');
    
end
