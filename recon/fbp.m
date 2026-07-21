% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Analytical Filtered Back-Projection (FBP) Reconstruction Engine
% Authors:   Parsa Shahidi
%            & Bahareh Khishkhah
% Date:      June 2026
%
% Description:
%   This function implements the classical analytical Filtered Back-Projection 
%   (FBP) algorithm for photoacoustic computed tomography. It maps the forward 
%   problem to an inverse Radon transform framework, applying a frequency-domain 
%   Ram-Lak (Ramp) filter ($|\omega|$) to compensate for the spatial blurring 
%   inherent to standard backprojection, followed by a vectorized space-time 
%   coherent interpolation over the sensor grid.
% =========================================================================

function p0_recon = fbp(sensor_data, sensor_mask, kgrid, sound_speed, varargin)

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
    dx = kgrid.dx;
    dy = kgrid.dy;
    
    % Get time information
    dt = kgrid.dt;
    Nt = kgrid.Nt;
    t_array = (0:(Nt-1)) * dt;
    fs = 1/dt; % Sampling frequency
    
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
    
    % Apply bandpass filter if requested (Before FBP specific filtering)
    if filter_flag
        sensor_signals = applySensorBandpassFilter(sensor_signals, dt, p.Results.frequency_low, p.Results.frequency_high);
    end
    
    % =========================================================================
    % FBP SPECIFIC STEP: Apply Ramp Filter (Ram-Lak) in Frequency Domain
    % =========================================================================
    % Construct angular frequency vector for FFT
    omega = (2*pi/(Nt*dt)) * [0:ceil(Nt/2)-1, -floor(Nt/2):-1]; 
    ramp_filter = abs(omega); % The $|\omega|$ filter
    
    for s = 1:num_sensors
        % Transform to frequency domain
        signal_fft = fft(sensor_signals(s, :));
        % Apply Ramp filter
        filtered_fft = signal_fft .* ramp_filter;
        % Inverse transform back to time domain
        sensor_signals(s, :) = real(ifft(filtered_fft));
    end
    % =========================================================================    
    % Convert sensor indices to physical coordinates
    sensor_x = kgrid.x_vec(sensor_x_idx);
    sensor_y = kgrid.y_vec(sensor_y_idx);
    
    % Create meshgrid for vectorization
    [Y, X] = meshgrid(kgrid.y_vec, kgrid.x_vec);
    
    % Initialize reconstruction
    p0_recon = zeros(Nx, Ny);
    
    % FBP reconstruction: back-project the filtered signals
    fprintf('Performing FBP reconstruction...\n');
    fprintf('Grid size: %d x %d, Sensors: %d\n', Nx, Ny, num_sensors);
    
    
    for s = 1:num_sensors
        % Calculate distance from all pixels to current sensor
        distance = sqrt((X - sensor_x(s)).^2 + (Y - sensor_y(s)).^2);
        
        % Calculate travel time matrix [Nx, Ny]
        travel_time = distance / sound_speed;
        
        % Interpolate signal for this sensor
        if strcmp(interp_method, 'nearest')
            % Nearest neighbor interpolation
            time_idx = round(travel_time / dt) + 1;
            
            % Filter out indices that are out of bounds
            valid_mask = (time_idx >= 1) & (time_idx <= Nt);
            
            contribution = zeros(Nx, Ny);
            contribution(valid_mask) = sensor_signals(s, time_idx(valid_mask));
            
            p0_recon = p0_recon + contribution;
        else
            % Linear or cubic interpolation
            contribution = interp1(t_array, sensor_signals(s, :), travel_time, interp_method, 0);
            
            % Add to reconstruction
            p0_recon = p0_recon + contribution;
        end
    end

    p0_recon = finalizeReconImage(p0_recon, envelope_signal_flag, remove_negatives_flag);
    fprintf('FBP reconstruction completed.\n');
    
    end
    
