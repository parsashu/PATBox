function [sensor_data,sensor,kgrid,source,p0_reference,sound_speed] = ...
        forward_simulation_linear(img_path,noise_level,sim_opts)
%FORWARD_SIMULATION_LINEAR Deprecated compatibility wrapper.
    if nargin<2, noise_level=0; end
    if nargin<3, sim_opts=struct(); end
    [sensor_data,sensor,kgrid,source,p0_reference,sound_speed] = ...
        forward_simulation_legacy_adapter(img_path,noise_level,sim_opts,'linear');
end
