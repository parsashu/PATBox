function [versionText, details] = patVersion()
%PATVERSION Return the installed PATBox package version and provenance.

    root=fileparts(mfilename('fullpath'));
    versionFile=fullfile(root,'VERSION');
    if isfile(versionFile)
        versionText=strtrim(fileread(versionFile));
    else
        versionText='unknown';
    end

    if nargout>1
        details=struct();
        details.version=versionText;
        details.root=root;
        details.matlab_version=version;
        details.computer=computer;
        details.kwave_grid_path=which('kWaveGrid');
        details.kwave_solver_path=which('kspaceFirstOrder2D');
        details.kwave_array_path=which('kWaveArray');
    end
end
