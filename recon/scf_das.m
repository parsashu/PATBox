% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Phase-Coherent Sign Coherence Factor (SCF-DAS) Beamformer
% Authors:   Parsa Shahidi
%            & Bahareh Khishkhah
% Date:      June 2026
%
% Description:
%   This function implements the non-linear Sign Coherence Factor weighted 
%   Delay-and-Sum (SCF-DAS) reconstruction algorithm for PATBox. It quantifies 
%   the spatial phase alignment of acoustic wavefronts by computing the voxel-specific 
%   variance of the signs (polarities) of time-delayed channel data. This sign-only 
%   coherence map acts as a spatial filter, scaling the standard linear DAS 
%   reconstruction to highly suppress acoustic clutter and sidelobes.
% =========================================================================

function p0_recon = scf_das(sensor_data, sensor_mask, kgrid, sound_speed, varargin)
    % SCFDAS - Sign Coherence Factor weighted Delay-and-Sum for Photoacoustic Tomography
    %
    % This function reconstructs a photoacoustic image using a Delay-and-Sum
    % algorithm where each pixel is weighted by the Sign Coherence Factor (SCF).
    % The SCF is derived from the variance of the signs of the time-delayed
    % channel data.

        % Parse optional inputs
        p = inputParser;
        addParameter(p, 'envelope_signal', false, @islogical);
        addParameter(p, 'remove_negatives', true, @islogical);
        addParameter(p, 'bandpass_filter', false, @islogical);
        addParameter(p, 'frequency_low', 0.1e6, @isnumeric);
        addParameter(p, 'frequency_high', 10e6, @isnumeric);
        addParameter(p, 'interp_method', 'linear', @ischar);
        addParameter(p, 'scf_power', 1.0, @isnumeric); % Power for SCF weight
        parse(p, varargin{:});
        
        envelope_signal_flag = p.Results.envelope_signal;
        remove_negatives_flag = p.Results.remove_negatives;
        filter_flag = p.Results.bandpass_filter;
        interp_method = p.Results.interp_method;
        scf_power = p.Results.scf_power;
        
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
        else
            error('Sensor data dimensions [%d x %d] do not match expected format. Expected [%d x %d] or [%d x %d]', ...
                  size(sensor_signals, 1), size(sensor_signals, 2), ...
                  Nt, num_sensors, num_sensors, Nt);
        end
        
        % Convert sensor indices to physical coordinates
        sensor_x = kgrid.x_vec(sensor_x_idx);
        sensor_y = kgrid.y_vec(sensor_y_idx);
        
        % Create meshgrid for vectorization
        [Y, X] = meshgrid(kgrid.y_vec, kgrid.x_vec);
        
        % --- SCFDAS MODIFICATION: Initialize arrays for SCFDAS calculations ---
        p0_das = zeros(Nx, Ny);
        p0_sign_sum = zeros(Nx, Ny);      % Sum of signs
        p0_sq_sign_sum = zeros(Nx, Ny);   % Sum of squared signs        
        % Apply bandpass filter if requested
        if filter_flag
            sensor_signals = applySensorBandpassFilter(sensor_signals, dt, p.Results.frequency_low, p.Results.frequency_high);
        end
        
        % SCFDAS reconstruction: calculate contributions and running sums
        fprintf('Performing SCFDAS reconstruction...\n');
        fprintf('Grid size: %d x %d, Sensors: %d, scf_power: %.1f\n', Nx, Ny, num_sensors, scf_power);
        
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
            
            % Accumulate for standard DAS
            p0_das = p0_das + contribution;
            
            % --- SCFDAS MODIFICATION: Accumulate sums for sign variance ---
            s_sign = sign(contribution);
            p0_sign_sum = p0_sign_sum + s_sign;
            p0_sq_sign_sum = p0_sq_sign_sum + s_sign.^2;
        end
        
        % --- CALCULATE SCFDAS WEIGHTS AND FINAL IMAGE ---
        M = num_sensors;
        
        if M > 1
            % Calculate the variance of signs for every pixel: Var = [Sum(x^2) - (Sum(x))^2 / M] / (M-1)
            sign_variance = (p0_sq_sign_sum - (p0_sign_sum.^2) / M) / (M - 1);
            
            % Prevent tiny negative numbers caused by floating point precision
            sign_variance(sign_variance < 0) = 0;
            
            % Convert sign variance to Sign Coherence Factor (SCF)
            % SCF = 1 (perfect coherence, var=0), SCF = 0 (no coherence, var=1)
            w = 1 - sqrt(sign_variance);
            
            % Apply optional power to the weighting factor
            w = w .^ scf_power;
        else
            % If only one sensor, coherence cannot be calculated, so weight is 1
            w = ones(Nx, Ny);
        end
        
        % Final SCFDAS Image = w(r) * A_DAS(r)
        p0_recon = w .* p0_das;

    p0_recon = finalizeReconImage(p0_recon, envelope_signal_flag, remove_negatives_flag);
        
        fprintf('SCFDAS reconstruction completed.\n');
        
end
