function [lower, upper] = vmscatterBinomialCI(errors, trials, confidence)
%VMSCATTERBINOMIALCI Wilson score interval for a binomial error rate.

if nargin < 3
    confidence = 0.95;
end
validateattributes(errors, {'numeric'}, ...
    {'scalar', 'integer', 'nonnegative'}, mfilename, 'errors');
validateattributes(trials, {'numeric'}, ...
    {'scalar', 'integer', 'nonnegative'}, mfilename, 'trials');
validateattributes(confidence, {'numeric'}, ...
    {'scalar', '>', 0, '<', 1}, mfilename, 'confidence');

if trials == 0
    lower = NaN;
    upper = NaN;
    return;
end

z = -sqrt(2) * erfcinv(2 * (1 - (1 - confidence) / 2));
p = errors / trials;
denominator = 1 + z^2 / trials;
center = (p + z^2 / (2 * trials)) / denominator;
halfWidth = z * sqrt(p * (1 - p) / trials + z^2 / ...
    (4 * trials^2)) / denominator;
lower = max(0, center - halfWidth);
upper = min(1, center + halfWidth);
end
