function test_final_regressions
%TEST_FINAL_REGRESSIONS Exercise documented final-interface failure modes.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
htPath = fullfile(repoRoot, '802.11nHT');
addpath(htPath);
cleanup = onCleanup(@() rmpath(htPath));

cfgHT = wlanHTConfig( ...
    'ChannelBandwidth', 'CBW20', ...
    'NumTransmitAntennas', 2, ...
    'NumSpaceTimeStreams', 2, ...
    'PSDULength', 2000, ...
    'MCS', 8, ...
    'ChannelCoding', 'BCC', ...
    'SpatialMapping', 'Direct');

[~, ~, schedule] = vmscatterBuildPacketSchedule(2, 1, 1);
tx = complex(randn(2, 52, schedule.numSymbols), ...
    randn(2, 52, schedule.numSymbols));
rxWrongSize = tx(:, 1:51, :);
[~, diagnostics] = vmscatterEstimateBasisOperators( ...
    tx, rxWrongSize, schedule, 1);
assert(~diagnostics.success, 'Mismatched TX/RX dimensions must be rejected.');

badSchedule = schedule;
badSchedule.designStateMatrix = ones(2);
[~, diagnostics] = vmscatterEstimateBasisOperators( ...
    tx, tx, badSchedule, 1);
assert(~diagnostics.success, 'A rank-deficient reference design must fail.');

[~, ~, detectionError] = rxDemod(zeros(1000, 2), cfgHT);
assert(detectionError, 'Packet detection failure must be reported.');

shortWaveform = zeros(wlanFieldIndices(cfgHT).HTData(1) + 100, 2);
didThrow = false;
try
    VMscatterModPacket(shortWaveform, wlanFieldIndices(cfgHT), 2, cfgHT, ...
        'NumCodewords', 128, 'ReferenceRepeats', 1);
catch exception
    didThrow = strcmp(exception.identifier, ...
        'VMScatter:InsufficientHTSymbols');
end
assert(didThrow, 'A packet with insufficient HT symbols must be rejected.');
end
