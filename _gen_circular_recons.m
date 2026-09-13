% Generate circular-array reconstructions for docs galleries.
root = fileparts(mfilename('fullpath'));
pkg = fileparts(root);
addpath(pkg);
kw = strtrim(fileread(fullfile(pkg, 'kwave_path.txt')));
install_patbox(kw);

outDir = fullfile(pkg, 'output', 'recon_circular');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

img = fullfile(pkg, 'data', 'Example1.bmp');
algos = {'DAS','CF-DAS','DMAS','DS-DMAS','MV-DAS','VDAS','SCF-DAS','FBP','UBP','DMAS-UBP','VDAS-UBP','TR'};

fprintf('Simulating circular acquisition...\n');
sim = patSimulate(img, ...
    'SensorType', 'circular', ...
    'GridSize', 256, ...
    'GridSizeX', 256, ...
    'GridSizeY', 256, ...
    'NumTransducers', 128, ...
    'TargetSNRdB', 20, ...
    'NoiseModel', 'awgn', ...
    'DataCast', 'single', ...
    'PlotSimulation', false);

save(fullfile(outDir, 'sim_circular.mat'), 'sim', '-v7.3');

for i = 1:numel(algos)
    name = algos{i};
    fprintf('Reconstructing %s...\n', name);
    try
        [p0, info] = patReconstruct(sim, name, ...
            'remove_negatives', true, ...
            'envelope_signal', false, ...
            'SaveOutput', false);
        p0_recon_normalized = mat2gray(double(gather(p0)));
        algo_name = name;
        metrics = patEvaluate(p0, sim.p0_reference);
        source = struct('p0', sim.p0_reference);
        sensor_type = 'circular';
        stem = lower(strrep(name, '-', '_'));
        outFile = fullfile(outDir, sprintf('%s_recon_circular_256.mat', stem));
        save(outFile, 'p0_recon_normalized', 'algo_name', 'info', 'metrics', 'source', 'sensor_type', '-v7.3');
        fprintf('  saved %s\n', outFile);
    catch ME
        warning('Failed %s: %s', name, ME.message);
    end
end

fprintf('Done.\n');
