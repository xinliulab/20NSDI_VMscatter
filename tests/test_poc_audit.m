function report = test_poc_audit(numCodewords)
%TEST_POC_AUDIT Validate all three ideal-model PoC decoders.

if nargin < 1
    numCodewords = 10000;
end
repoRoot = fileparts(fileparts(mfilename('fullpath')));
pocPath = fullfile(repoRoot, 'Proof-of-Concept_Simulation');
addpath(pocPath);
cleanup = onCleanup(@() rmpath(pocPath));

report = audit_poc('NumCodewords', numCodewords, 'Seed', 2020);
assert(report.noiselessBitErrors.Lite == 0, 'PoC Lite decoder produced errors.');
assert(report.noiselessBitErrors.Accurate == 0, 'PoC Accurate decoder produced errors.');
assert(report.noiselessBitErrors.Efficient == 0, 'PoC Efficient decoder produced errors.');
assert(report.referenceDesignRank == 2, 'The documented reference must be full rank.');
assert(report.badReferenceRank == 1, 'The all-minus-one reference should be rejected.');
end
