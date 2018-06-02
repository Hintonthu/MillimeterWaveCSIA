% This script evaluates beam pattern of different beamformer used in IA

clear;clc;
% --- codebook construction -----
Nt = 16;
A_stopband = 10; % attenuation outside mainlobe (dB)
vec1 = get_FSM_KW_codebook( 22.5/180*pi, 45/180*pi, Nt, A_stopband);

% vec = exp(1j*pi*(0:Nt-1).'*sin(45/180*pi));
% vec_norm = vec./norm(vec);

% ------- test hybrid approximation-------
phase_bits = 10;
vec = get_hybrid_approx( vec1, phase_bits );

vec_norm = vec./norm(vec);
% ------ spatial angle vector of ULA -------
angle_range = 90;
for kk = 1:(angle_range*2+1)
    FF(:,kk) = exp(1j*pi*(0:Nt-1).'*sin((kk - angle_range -1 )/180*pi));
end
response = 20*log10(abs(FF'*vec_norm)+1e-1);

% ------ beam pattern test -------
angle_test = 0;
% xdata = linspace(-pi/2,pi/2,181);
xdata = linspace(-pi/2,pi/2,181);
figure
plot(xdata/pi*180,response)
grid on
%%
figure
polarplot(xdata+pi,response,'linewidth',2);hold on
rlim([-10,10])
% thetalim([-90 90])
thetalim([90,270])
ax = gca;
% ax.ThetaTick = -90:22.5:90;
ax.ThetaTick = 90:22.5:270;
ax.ThetaTickLabels = {'-90','-67.5','-45','-22.5','0','22.5','45','67.5','90'};
grid on



