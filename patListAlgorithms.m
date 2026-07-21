% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Reconstruction Algorithm Registry & Core Catalog
% Authors:   Parsa Shahidi
% Date:      June 2026
%
% Description:
%   This function serves as the central registry for all supported photo-
%   acoustic image reconstruction algorithms within PATBox. It catalogs 
%   diverse methodologies including conventional Delay-and-Sum (DAS), 
%   adaptive beamforming variants, transform-based operations (FBP/UBP), 
%   Acoustic Time Reversal (TR), and iterative optimization frameworks.
% =========================================================================

function names = patListAlgorithms()
%PATLISTALGORITHMS List supported reconstruction algorithm names.

    names = {
        'DAS'
        'CF-DAS'
        'DMAS'
        'DS-DMAS'
        'MV-DAS'
        'VDAS'
        'SCF-DAS'
        'CFMV-DAS'
        'FBP'
        'UBP'
        'DMAS-UBP'
        'VDAS-UBP'
        'TR'
        'ITERATIVE-DAS'
        'ITERATIVE-TR'
    };
end
