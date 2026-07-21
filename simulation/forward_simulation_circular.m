% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Forward Simulation Module - Circular Array Configuration
% Authors:   Bahareh Khishkhah & Parsa Shahidi
% Date:      June 2026
%
% Description:
%   This function executes a 2D photoacoustic forward simulation centered 
%   around a circular transducer array configuration using k-Wave. It's dynamic-
%   Ally reads system properties via option structures, maps a full tomographic
%   circular binary sensor mask snapped to the grid, handles time-step resolution,
%   and injects signal-proportional Gaussian noise into the calculated data.
% =========================================================================


function [sensor_data, sensor, kgrid, source, noisy_p0_visual, sound_speed] = forward_simulation_circular(img_path, noise_level, sim_opts)
    % RUN_FORWARD_SIMULATION Sets up the k-Wave grid, medium, sensor, and runs the simulation.

    if nargin < 3
        sim_opts = struct();
    end

    sound_speed = getSimOption(sim_opts, 'SoundSpeed', 1500);
    density = getSimOption(sim_opts, 'Density', 1000);

    [Nx, Ny, dx, dy] = forwardSimGridOptions(sound_speed, sim_opts);

    % Create k-Wave grid
    kgrid = kWaveGrid(Nx, dx, Ny, dy);

    % Define medium
    medium.sound_speed = sound_speed;
    medium.density = density;

    % Simulation parameters
    PML_size = 20;
    input_args = {
        'PMLInside', false, ...
        'PMLSize', PML_size, ...
        'PlotPML', false, ...
        'Smooth', false, ...
        'PlotSim', false
        };

    % Create initial pressure distribution
    p0_magnitude = 2;
    if ~exist(img_path, 'file')
        error('Could not find image file at: %s', img_path);
    end
    
    p0 = p0_magnitude * loadImage(img_path);
    p0 = resize(p0, [Nx, Ny]);
    p0 = smooth(p0, true);
    source.p0 = p0;

    % Time array
    kgrid.makeTime(medium.sound_speed);

    % =========================================================================
    % --- CIRCULAR SENSOR SETUP (Binary Grid, Snapped to Pixels) ---
    % =========================================================================
    % Calculate radius in grid points (pixels)
    radius_pixels = min(Nx, Ny)/2 - 30;
    
    % Calculate the center of the grid
    cx = floor(Nx/2) + 1;
    cy = floor(Ny/2) + 1;
    
    % Create the binary mask [Nx x Ny]
    sensor.mask = makeCircle(Nx, Ny, cx, cy, radius_pixels);
    
    % The number of transducers is the number of 1s in the mask
    actual_num_transducers = sum(sensor.mask(:));
    
    fprintf('Sensor configuration: Circular Binary Array (%d sensors)\n', actual_num_transducers);

    % Run simulation
    sensor.record = {'p'};
    sensor_data = kspaceFirstOrder2D(kgrid, medium, source, sensor, input_args{:}, 'DataCast', 'gpuArray-single');

    % --- ADD NOISE ---
    noise_std = noise_level * max(sensor_data.p(:)); 
    sensor_data.p = sensor_data.p + noise_std * randn(size(sensor_data.p));
    fprintf('Added %.0f%% Gaussian noise to sensor data.\n\n', noise_level * 100);

    % Create a noisy version of the true initial pressure for visual comparison
    noise_std_p0 = noise_level * max(source.p0(:));
    noisy_p0_visual = source.p0 + noise_std_p0 * randn(size(source.p0));
end
