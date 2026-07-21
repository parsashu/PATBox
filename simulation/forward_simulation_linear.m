function [sensor_data, sensor, kgrid, source, noisy_p0_visual, sound_speed] = forward_simulation_linear(img_path, noise_level, sim_opts)
    % RUN_FORWARD_SIMULATION Sets up the k-Wave grid, medium, sensor, and runs the simulation.

    if nargin < 3
        sim_opts = struct();
    end

    % Medium properties
    sound_speed = getSimOption(sim_opts, 'SoundSpeed', 1500);
    density = getSimOption(sim_opts, 'Density', 1000);

    % Grid setup
    [Nx, Ny, dx, dy] = forwardSimGridOptions(sound_speed, sim_opts);

    % Sensor setup (e.g., ATL L7-4 or Verasonics L12-5)
    num_transducers = getSimOption(sim_opts, 'NumTransducers', 128);
    pitch = getSimOption(sim_opts, 'Pitch', 0.3e-3);
    kerf = getSimOption(sim_opts, 'Kerf', 0.03e-3);
    element_width = pitch - kerf;

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

    % Create linear sensor array at the top
    sensor.mask = zeros(Nx, Ny);
    
    % Calculate spacing in terms of grid points
    pitch_points = round(pitch / dx); 
    total_array_width_points = (num_transducers - 1) * pitch_points + 1;
    
    % Center transducers on the top row and space them by 'pitch'
    start_idx = round((Ny - total_array_width_points) / 2) + 1;
    sensor_indices = start_idx : pitch_points : (start_idx + total_array_width_points - 1);
    
    sensor.mask(1, sensor_indices) = 1; 

    % Add Directivity Angle (0 points straight down in k-Wave's convention for the top row)
    sensor.directivity_angle = zeros(Nx, Ny); 

    % Add Directivity Size (simulates the physical width of the element, subtracting the kerf)
    sensor.directivity_size = element_width; 

    fprintf('Sensor configuration: Linear Top Array (%d sensors, pitch: %.2f mm, kerf: %.2f mm)\n', ...
            sum(sensor.mask(:)), pitch*1000, kerf*1000);

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
