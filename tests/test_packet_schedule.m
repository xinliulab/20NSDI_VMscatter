function test_packet_schedule
%TEST_PACKET_SCHEDULE Validate the fair 256-bit/256-symbol packet design.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
htPath = fullfile(repoRoot, '802.11nHT');
addpath(htPath);
cleanup = onCleanup(@() rmpath(htPath));

[~, bits222, schedule222] = vmscatterBuildPacketSchedule(2, 128, 4);
[~, bits244, schedule244] = vmscatterBuildPacketSchedule(4, 64, 4);

assert(numel(bits222) == 256 && numel(bits244) == 256, ...
    'Both architectures must carry 256 tag bits per packet.');
assert(schedule222.numDataSymbols == 256 && ...
    schedule244.numDataSymbols == 256, ...
    'Both architectures must use 256 data OFDM symbols.');
assert(schedule222.numReferenceSymbols == 4, ...
    '2x2x2 must use one explicit state times four repeats.');
assert(schedule244.numReferenceSymbols == 12, ...
    '2x4x4 must use three explicit states times four repeats.');
assert(rank(schedule222.designStateMatrix) == 2 && ...
    rank(schedule244.designStateMatrix) == 4, ...
    'The LTF baseline plus explicit references must be full rank.');
assert(schedule222.numExplicitReferenceStates == 1 && ...
    schedule244.numExplicitReferenceStates == 3, ...
    'The explicit reference count must be K-1.');

didThrow = false;
try
    vmscatterBuildPacketSchedule(2, 1, 1, 'Mode', 'HighThroughput');
catch exception
    didThrow = strcmp(exception.identifier, ...
        'VMScatter:HighThroughputNotImplemented');
end
assert(didThrow, 'Reserved high-throughput mode must fail explicitly.');
end
