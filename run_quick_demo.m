function result = run_quick_demo
%RUN_QUICK_DEMO Check the complete VMScatter simulation data flow quickly.
% This run is intentionally short and is not suitable for publication BER.

versionRoot = fileparts(mfilename('fullpath'));
oldPath = path;
cleanup = onCleanup(@() path(oldPath));
restoredefaultpath;
addpath(fullfile(versionRoot, '802.11nHT'));
addpath(fullfile(versionRoot, 'tests'));
result = run_all_reference_profiles( ...
    'SNR', 2:2:10, ...
    'MinBits', 2560, ...
    'MaxBits', 25600, ...
    'TargetErrors', 100, ...
    'Plot', true, ...
    'SaveResults', true);
disp(result.summary);
if result.anyProfileSucceeded
    fprintf('Profiles satisfying the strict 244 reliability criterion: %s\n', ...
        strjoin(cellstr(result.successfulProfiles), ', '));
else
    fprintf(['No profile satisfied the strict criterion in this short run. ' ...
        'Run run_full_evaluation.m before drawing a conclusion.\n']);
end
clear cleanup
end
