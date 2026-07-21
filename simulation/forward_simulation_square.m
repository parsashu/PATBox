function [sensor_data, sensor, kgrid, source, noisy_p0_visual, sound_speed] = forward_simulation_square(img_path, noise_level, sim_opts)
    % FORWARD_SIMULATION_SQUARE Run k-Wave forward simulation with a square
    % sensor formed by four inward-facing linear arrays with directivity.

    if nargin < 3
        sim_opts = struct();
    end

    sound_speed = getSimOption(sim_opts, 'SoundSpeed', 1500);
    density = getSimOption(sim_opts, 'Density', 1000);

    [Nx, Ny, dx, dy] = forwardSimGridOptions(sound_speed, sim_opts);

    % Sensor setup (same element geometry as forward_simulation_linear)
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

    % Create square sensor from four centered linear arrays
    sensor.mask = zeros(Nx, Ny);

    pitch_points = round(pitch / dx);
    total_array_length_points = (num_transducers - 1) * pitch_points + 1;

    start_x = round((Nx - total_array_length_points) / 2) + 1;
    sensor_indices_x = start_x : pitch_points : (start_x + total_array_length_points - 1);

    start_y = round((Ny - total_array_length_points) / 2) + 1;
    sensor_indices_y = start_y : pitch_points : (start_y + total_array_length_points - 1);

    % Top and bottom: linear arrays along y
    sensor.mask(1, sensor_indices_y) = 1;
    sensor.mask(Nx, sensor_indices_y) = 1;

    % Left and right: linear arrays along x
    sensor.mask(sensor_indices_x, 1) = 1;
    sensor.mask(sensor_indices_x, Ny) = 1;

    % Four fixed directivity angles (one per side) for fast k-Wave simulation.
    % 0 = max sensitivity in x (up/down), pi/2 = max sensitivity in y (left/right).
    sensor.directivity_angle = zeros(Nx, Ny);
    sensor.directivity_angle(1, :) = 0;        % top, pointing down
    sensor.directivity_angle(end, :) = 0;      % bottom, pointing up
    sensor.directivity_angle(:, 1) = pi/2;    % left, pointing right
    sensor.directivity_angle(:, end) = pi/2;  % right, pointing left
    sensor.directivity_size = element_width;

    fprintf(['Sensor configuration: Square Array (%d sensors, %d per side, ', ...
             'pitch: %.2f mm, kerf: %.2f mm)\n'], ...
            sum(sensor.mask(:)), num_transducers, pitch * 1000, kerf * 1000);

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
