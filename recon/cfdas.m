% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Coherence Factor Delay-and-Sum (CF-DAS) Reconstruction Engine
% Authors:  Parsa Shahidi & Bahareh Khishkhah
% Date:      June 2026
%
% Description:
%   This function implements an adaptive, coherence-weighted Delay-and-Sum 
%   reconstruction algorithm for photoacoustic tomography. It dynamically 
%   computes the spatial travel-time matrices for every transducer element, 
%   performs sub-sample interpolation of raw acoustic pressure RF signals, 
%   and calculates a pixel-by-pixel Coherence Factor (CF) map to suppress 
%   side-lobe artifacts, suppress background noise, and improve lateral resolution.
% =========================================================================

function p0_recon = cfdas(sensor_data, sensor_mask, kgrid, sound_speed, varargin)
% = CFDAS

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

% --- QDAS INITIALIZATION ---
delayed_sum = zeros(Nx, Ny);      % For the numerator: sum of signals
delayed_sum_sq = zeros(Nx, Ny);   % For the denominator: sum of squared signals
% Apply bandpass filter if requested
if filter_flag
    sensor_signals = applySensorBandpassFilter(sensor_signals, dt, p.Results.frequency_low, p.Results.frequency_high);
end

fprintf('Performing QDAS reconstruction...\n');
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
    
    % --- QDAS ACCUMULATION ---
    % Add to the standard sum
    delayed_sum = delayed_sum + contribution;
    
    % Add to the squared sum
    delayed_sum_sq = delayed_sum_sq + (contribution.^2);
end

% --- QDAS WEIGHT CALCULATION ---
% Calculate the Coherence Factor (CF) for every pixel
% Added 'eps' (a tiny number) to prevent division by zero errors in empty pixels
numerator = delayed_sum.^2;
denominator = num_sensors * delayed_sum_sq + eps;
CF = numerator ./ denominator;

% Apply the Coherence Factor weight to the standard DAS output
p0_recon = CF .* delayed_sum;

    p0_recon = finalizeReconImage(p0_recon, envelope_signal_flag, remove_negatives_flag);

fprintf('Performing CF-DAS (Coherence Factor Delay-and-Sum) reconstruction...\n');
fprintf('Grid size: %d x %d, Active Sensors: %d\n', Nx, Ny, num_sensors);


end
