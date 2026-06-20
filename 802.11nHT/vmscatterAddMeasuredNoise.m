function [noisySignal, noiseVariance] = vmscatterAddMeasuredNoise(signal, snrDb)
%VMSCATTERADDMEASUREDNOISE Add complex AWGN using measured signal power.

validateattributes(signal, {'double'}, {'finite', 'nonempty'}, mfilename, 'signal');
validateattributes(snrDb, {'numeric'}, {'real', 'scalar', 'finite'}, mfilename, 'snrDb');

signalPower = mean(abs(signal(:)).^2);
noiseVariance = signalPower / db2pow(snrDb);
noise = sqrt(noiseVariance / 2) .* ...
    (randn(size(signal)) + 1i * randn(size(signal)));
noisySignal = signal + noise;
end
