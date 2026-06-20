function report = run_poc_simulation(varargin)
%RUN_POC_SIMULATION Run the reproducible VMscatter decoding demonstration.
%   REPORT = RUN_POC_SIMULATION runs 1,000 two-bit codewords by default.
%   Use RUN_POC_SIMULATION('NumCodewords', N) for a shorter demonstration.

if nargin == 0
    report = audit_poc('NumCodewords', 1000);
else
    report = audit_poc(varargin{:});
end

fprintf('VMscatter proof-of-concept (%d codewords, seed %d)\n', ...
    report.numCodewords, report.seed);
fprintf('  Lite noiseless bit errors:      %d\n', ...
    report.noiselessBitErrors.Lite);
fprintf('  Accurate noiseless bit errors:  %d\n', ...
    report.noiselessBitErrors.Accurate);
fprintf('  Efficient noiseless bit errors: %d\n', ...
    report.noiselessBitErrors.Efficient);
fprintf('  Efficient BER at configured noise SNR: %.6g\n', ...
    report.noisyEfficientBER);
fprintf('  Efficient BER with channel drift:      %.6g\n', ...
    report.driftEfficientBER);
fprintf('  Valid reference rank: %d; invalid reference rank: %d\n', ...
    report.referenceDesignRank, report.badReferenceRank);
end
