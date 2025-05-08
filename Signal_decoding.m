
% Signal_decoding: This program extract the image from the received APT signal  
% Copyright (C) 2025  Mohammad Safa
% GitHub Repository: https://github.com/mhr98/APT-Receiver
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <https://www.gnu.org/licenses/>.

%% Parameters
fs=12.5e3;  % Change depending on your signal
input_signal=out.yout';    % Form Simulink
samples_per_line = 0.5*fs;      % Number of samples per line
sync_half_period = floor(fs*2/4160);   % Sync pulse A half-period in samples (2T)
num_cycles = 7;          % Number of square wave cycles in sync pulse
pixels_per_line=2080;    % Number of words per line

%% Generate sync pulse A reference
sync_ref = repmat([ones(1, sync_half_period), zeros(1, sync_half_period)], 1, num_cycles);
sync_ref=[zeros(1, 2*sync_half_period) sync_ref zeros(1, 4*sync_half_period)];
sync_ref = sync_ref - mean(sync_ref);  % Remove DC offset

%% Sync
% Cross-correlate input signal with sync reference
[corr, lags] = xcorr(input_signal, sync_ref);
corr = corr(lags >= 0);  % Keep non-negative lags

% Find peaks in correlation (sync pulse positions)
min_peak_distance = round(0.9 * samples_per_line); % Expected line length
[~, peak_indices] = findpeaks(corr, 'MinPeakHeight', 0.5*max(corr), ...
                              'MinPeakDistance', min_peak_distance);

% Validate peak spacing to filter false positives
peak_diff = diff(peak_indices);
valid_peaks = peak_indices([true, abs(peak_diff - samples_per_line) < 0.1 * samples_per_line]);

%% Decoding
num_lines = numel(valid_peaks);
lines = zeros(num_lines, pixels_per_line);

for i = 1:num_lines
    % Extract raw samples for this line
    start_idx = valid_peaks(i);
    end_idx = start_idx + samples_per_line - 1;
    
    if end_idx > length(input_signal)
        num_lines = i - 1;
        break;
    end
    
    line_samples = input_signal(start_idx:end_idx);
    
    % Resample to pixel resolution
    lines(i,:) = resample(line_samples, pixels_per_line, samples_per_line);
end

lines = lines(1:num_lines, :);  % Trim incomplete lines

full_image = uint8(255 * mat2gray(lines)); % Convert to 8-bit grayscale

%% Plotting
figure;
imshow(full_image);
title('APT Full Line Image (Channel A + Channel B)');
xlabel('Pixels (1040 ChA + 1040 ChB)');