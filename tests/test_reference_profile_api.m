function test_reference_profile_api
%TEST_REFERENCE_PROFILE_API Check profile names and explicit symbol counts.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
htPath = fullfile(repoRoot, '802.11nHT');
addpath(htPath);
cleanup = onCleanup(@() rmpath(htPath));

expectedRepeats = [1 2 4];
for index = 1:numel(expectedRepeats)
    [~, ~, schedule222] = vmscatterBuildPacketSchedule( ...
        2, 128, expectedRepeats(index));
    [~, ~, schedule244] = vmscatterBuildPacketSchedule( ...
        4, 64, expectedRepeats(index));
    assert(schedule222.numReferenceSymbols == expectedRepeats(index));
    assert(schedule244.numReferenceSymbols == 3 * expectedRepeats(index));
    assert(schedule222.numDataSymbols == 256);
    assert(schedule244.numDataSymbols == 256);
end

didThrow = false;
try
    run_reference_profile_comparison('Profile', 'Unknown');
catch exception
    didThrow = contains(exception.message, 'Profile') || ...
        contains(exception.identifier, 'InputParser');
end
assert(didThrow, 'Unknown reference profiles must be rejected.');
end
