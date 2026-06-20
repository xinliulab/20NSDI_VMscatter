function report = test_release_smoke
%TEST_RELEASE_SMOKE Run one noisy packet per architecture and profile.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
htPath = fullfile(repoRoot, '802.11nHT');
addpath(htPath);
cleanupPath = onCleanup(@() rmpath(htPath));

outputDirectory = tempname;
mkdir(outputDirectory);
cleanupFiles = onCleanup(@() rmdir(outputDirectory, 's'));

report = run_all_reference_profiles( ...
    'SNR', 10, ...
    'MinBits', 256, ...
    'MaxBits', 256, ...
    'TargetErrors', 1, ...
    'Plot', false, ...
    'SaveResults', true, ...
    'OutputDirectory', outputDirectory);

assert(height(report.summary) == 3, ...
    'The release smoke test must return all three profiles.');
assert(exist(fullfile(outputDirectory, 'profile_summary.csv'), 'file') == 2);
assert(exist(fullfile(outputDirectory, 'all_profiles.mat'), 'file') == 2);

clear cleanupFiles cleanupPath
end
