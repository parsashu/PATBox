function [Nx, Ny, dx, dy] = forwardSimGridOptions(sound_speed, opts)
%FORWARDSIMGRIDOPTIONS Grid size and spacing from simulation options.

    if nargin < 2 || isempty(opts)
        opts = struct();
    end

    Nx = getSimOption(opts, 'GridSize', 512);
    Ny = Nx;

    f_max = getSimOption(opts, 'MaxFrequency', 5.0e6);
    if f_max > 0
        dx = sound_speed / (3 * f_max);
    else
        dx = 0.1e-3;
    end
    dy = dx;
end
