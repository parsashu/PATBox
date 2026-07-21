function install_patbox(kwave_path)
% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Package Installer and k-Wave Environment Configurator
% Lead Developer:            Parsa Shahidi
% Co-Developer: Bahareh Khishkhah
% Date:                      June 2026
%
% Description:
%   This function initializes the PATBox environment within MATLAB. It dynamically 
%   maps internal source subfolders to the MATLAB search path, links the 
%   dependent k-Wave acoustics toolbox, and injects an automated boot-hook into 
%   the MATLAB preferences directory (`startup.m`) for persistent session-wide 
%   auto-loading.
%  INSTALL_PATBOX Add PATBox to the path and configure k-Wave.
%   install_patbox('/path/to/k-Wave')   % once: save path + enable auto-load
%   install_patbox()                    % load PATBox + saved k-Wave path
%   Saves the k-Wave path to PATBox/kwave_path.txt.
% =========================================================================
    pkg_root = fileparts(mfilename('fullpath'));

    addpath(pkg_root);
    addpath(fullfile(pkg_root, 'recon'));
    addpath(fullfile(pkg_root, 'simulation'));
    addpath(fullfile(pkg_root, 'utils'));

    if nargin >= 1 && ~isempty(kwave_path)
        kwave_path = char(kwave_path);
        if ~exist(kwave_path, 'dir')
            error('PATBox:KWaveNotFound', 'k-Wave folder not found: %s', kwave_path);
        end

        saveKWavePath(kwave_path, pkg_root);
        addpath(genpath(kwave_path));
        enableAutoLoad();
        fprintf('PATBox: saved k-Wave path to %s\n', kwaveConfigFile(pkg_root));
        return;
    end

    saved_kwave_path = loadKWavePath(pkg_root);
    if ~isempty(saved_kwave_path)
        ensureKWaveConfigFile(pkg_root, saved_kwave_path);
        addpath(genpath(saved_kwave_path));
        return;
    end

    default_kwave = fullfile(fileparts(pkg_root), 'k-wave-main', 'k-Wave');
    if exist(default_kwave, 'dir')
        ensureKWaveConfigFile(pkg_root, default_kwave);
        addpath(genpath(default_kwave));
        return;
    end

    ensureKWaveConfigFile(pkg_root, '');
    warning('PATBox:kWaveMissing', ...
        ['k-Wave not found. Simulation requires k-Wave.\n' ...
         'Created empty %s. Run install_patbox(''/path/to/k-Wave'') once to save the path.'], ...
        kwaveConfigFile(pkg_root));
end

function ensureKWaveConfigFile(pkg_root, kwave_path)
    cfg_file = kwaveConfigFile(pkg_root);
    if isfile(cfg_file)
        return;
    end

    fid = fopen(cfg_file, 'w');
    if fid == -1
        warning('PATBox:configWriteFailed', 'Could not create %s', cfg_file);
        return;
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', kwave_path);
end

function cfg_file = kwaveConfigFile(pkg_root)
    cfg_file = fullfile(pkg_root, 'kwave_path.txt');
end

function saveKWavePath(kwave_path, pkg_root)
    fid = fopen(kwaveConfigFile(pkg_root), 'w');
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', kwave_path);

    cfg_dir = fullfile(prefdir, 'PATBox');
    if ~exist(cfg_dir, 'dir')
        mkdir(cfg_dir);
    end

    fid = fopen(fullfile(cfg_dir, 'patbox_root.txt'), 'w');
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', pkg_root);
end

function kwave_path = loadKWavePath(pkg_root)
    kwave_path = readPlainPath(kwaveConfigFile(pkg_root));
    if ~isempty(kwave_path)
        return;
    end

    legacy_cfg = fullfile(prefdir, 'PATBox', 'kwave_path.txt');
    kwave_path = readPlainPath(legacy_cfg);
end

function kwave_path = readPlainPath(cfg_file)
    kwave_path = '';
    if ~isfile(cfg_file)
        return;
    end

    line = strtrim(fileread(cfg_file));
    if isempty(line)
        return;
    end

    if startsWith(line, 'addpath')
        eval(line);
        return;
    end

    if exist(line, 'dir')
        kwave_path = line;
    end
end

function enableAutoLoad()
    startup_file = fullfile(prefdir, 'startup.m');
    marker = '% PATBox auto-load';
    hook = [ ...
        newline marker newline ...
        'try' newline ...
        '    root = strtrim(fileread(fullfile(prefdir, ''PATBox'', ''patbox_root.txt'')));' newline ...
        '    addpath(root, fullfile(root, ''recon''), fullfile(root, ''simulation''), fullfile(root, ''utils''));' newline ...
        '    kwave = strtrim(fileread(fullfile(root, ''kwave_path.txt'')));' newline ...
        '    if ~isempty(kwave) && exist(kwave, ''dir''), addpath(genpath(kwave)); end' newline ...
        'catch ME' newline ...
        '    warning(''PATBox:autoLoadFailed'', ''%s'', ME.message);' newline ...
        'end' newline];

    if isfile(startup_file) && contains(fileread(startup_file), marker)
        return;
    end

    if isfile(startup_file)
        fid = fopen(startup_file, 'a');
    else
        fid = fopen(startup_file, 'w');
    end

    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', hook);
end
