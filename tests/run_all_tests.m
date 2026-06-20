function reports = run_all_tests(varargin)
%RUN_ALL_TESTS Run the public VMScatter PoC and HT regression suite.

parser = inputParser;
addParameter(parser, 'Full', false, @(x) islogical(x) && isscalar(x));
parse(parser, varargin{:});

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'Proof-of-Concept_Simulation'));
addpath(fullfile(repoRoot, '802.11nHT'));
cleanup = onCleanup(@() path(removeReleasePaths(path, repoRoot)));

if parser.Results.Full
    pocCodewords = 10000;
    packetCount = 100;
else
    pocCodewords = 100;
    packetCount = 1;
end

reports = struct;
reports.poc = test_poc_audit(pocCodewords);
test_packet_schedule;
reports.packetSchedule = "passed";
test_reference_profile_api;
reports.referenceProfiles = "passed";
reports.noiselessHT = test_ht_packet_noiseless(packetCount);
test_final_regressions;
reports.failureModes = "passed";
reports.officialPaths = test_official_matlab_paths;
reports.releaseSmoke = test_release_smoke;
end

function cleanedPath = removeReleasePaths(currentPath, repoRoot)
parts = strsplit(currentPath, pathsep);
releasePaths = [string(fullfile(repoRoot, '802.11nHT')), ...
    string(fullfile(repoRoot, 'Proof-of-Concept_Simulation'))];
parts = parts(~ismember(string(parts), releasePaths));
cleanedPath = strjoin(parts, pathsep);
end
