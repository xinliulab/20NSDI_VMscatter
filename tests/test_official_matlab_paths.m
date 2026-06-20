function paths = test_official_matlab_paths
%TEST_OFFICIAL_MATLAB_PATHS Ensure repository files do not shadow WLAN APIs.

functionsToCheck = ["wlanWaveformGenerator"; "wlanTGnChannel"; ...
    "wlanHTDataRecover"];
resolved = strings(size(functionsToCheck));
repoRoot = fileparts(fileparts(mfilename('fullpath')));
for index = 1:numel(functionsToCheck)
    resolved(index) = string(which(functionsToCheck(index)));
    assert(~startsWith(lower(resolved(index)), lower(repoRoot)), ...
        'A repository file shadows the official MathWorks API.');
    assert(contains(lower(resolved(index)), 'matlab'), ...
        'Expected an official MATLAB installation path.');
end
paths = table(functionsToCheck, resolved, ...
    'VariableNames', {'Function', 'ResolvedPath'});
end
