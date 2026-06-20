function report = audit_poc(varargin)
%AUDIT_POC Reproducible audit of the three proof-of-concept decoders.

parser = inputParser;
addParameter(parser, 'NumCodewords', 10000, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 1 && fix(x) == x);
addParameter(parser, 'Seed', 2020, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x));
addParameter(parser, 'NoiseSNRdB', 20, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x));
parse(parser, varargin{:});
options = parser.Results;
rng(options.Seed, 'twister');

modulation = 64;
preTag = complex(randn(2), randn(2));
postTag = complex(randn(2), randn(2));
baseline = postTag * preTag;
txReference = WiFiData(2, modulation);
referenceCode = [-1 1];
rxReference = baseline \ postTag * diag(referenceCode) * preTag * txReference;

liteChannel = rxReference / txReference;
accurateChannel = CHest_VMscatter_Accurate(txReference, rxReference);
efficientChannel = CHest_VMscatter_Efficient(txReference, rxReference);
driftedPreTag = preTag + 0.5 .* complex(randn(2), randn(2));

errors = zeros(1, 3);
noisyEfficientErrors = 0;
driftEfficientErrors = 0;
for codewordIndex = 1:options.NumCodewords
    tagBits = randi([0 1], 1, 2);
    code = SpaceTimeCode(tagBits);
    tx1 = WiFiData(2, modulation);
    tx2 = WiFiData(2, modulation);
    rx1 = baseline \ postTag * diag(code(:, 1)) * preTag * tx1;
    rx2 = baseline \ postTag * diag(code(:, 2)) * preTag * tx2;

    liteBits = Decode_VMscatter_Lite(tx1, rx1, tx2, rx2, liteChannel);
    accurateBits = SpaceTimeDecode(Decode_VMscatter_Accurate( ...
        tx1, rx1, tx2, rx2, accurateChannel));
    efficientBits = SpaceTimeDecode(Decode_VMscatter_Efficient( ...
        tx1, rx1, tx2, rx2, efficientChannel));
    errors = errors + [sum(liteBits ~= tagBits), ...
        sum(accurateBits ~= tagBits), sum(efficientBits ~= tagBits)];

    signalPower = mean(abs([rx1(:); rx2(:)]).^2);
    noiseVariance = signalPower / db2pow(options.NoiseSNRdB);
    noisyRx1 = rx1 + sqrt(noiseVariance / 2) .* ...
        (randn(size(rx1)) + 1i * randn(size(rx1)));
    noisyRx2 = rx2 + sqrt(noiseVariance / 2) .* ...
        (randn(size(rx2)) + 1i * randn(size(rx2)));
    noisyBits = SpaceTimeDecode(Decode_VMscatter_Efficient( ...
        tx1, noisyRx1, tx2, noisyRx2, efficientChannel));
    noisyEfficientErrors = noisyEfficientErrors + sum(noisyBits ~= tagBits);

    driftRx1 = baseline \ postTag * diag(code(:, 1)) * driftedPreTag * tx1;
    driftRx2 = baseline \ postTag * diag(code(:, 2)) * driftedPreTag * tx2;
    driftBits = SpaceTimeDecode(Decode_VMscatter_Efficient( ...
        tx1, driftRx1, tx2, driftRx2, efficientChannel));
    driftEfficientErrors = driftEfficientErrors + sum(driftBits ~= tagBits);
end

badReference = [-1 -1];
referenceDesignRank = rank([ones(2, 1), referenceCode(:)]);
badReferenceRank = rank([ones(2, 1), badReference(:)]);

illConditionedPreTag = [1 1; 1 1 + 1e-10];

report = struct;
report.seed = options.Seed;
report.numCodewords = options.NumCodewords;
report.noiselessBitErrors = struct( ...
    'Lite', errors(1), 'Accurate', errors(2), 'Efficient', errors(3));
report.noisyEfficientBER = noisyEfficientErrors / (2 * options.NumCodewords);
report.driftEfficientBER = driftEfficientErrors / (2 * options.NumCodewords);
report.referenceDesignRank = referenceDesignRank;
report.badReferenceRank = badReferenceRank;
report.preTagCondition = cond(preTag);
report.illConditionedExample = cond(illConditionedPreTag);
report.driftMagnitude = norm(driftedPreTag - preTag, 'fro') / norm(preTag, 'fro');
report.assumptions = [ ...
    "2x2 invertible complex pre/post channels"; ...
    "flat channel over all WiFi tones used by one tag codeword"; ...
    "channel constant from reference through both Alamouti symbols"; ...
    "symbol-level BPSK tag coefficients"; ...
    "reference matrix [all-ones, reference] has full rank"];
end
