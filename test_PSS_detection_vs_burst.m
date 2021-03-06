clear;clc;

% ------ script control parameters -------
rng(2)
plot_cdf = 0;
MCtimes = 5e2; % Monte Carlo simulation
Pfa = 0.05; % target pfa in setting threshold
pd = 0.9; % target pd
SNR_data_range = -30:0.1:-10;
SNR_range = SNR_data_range + 0;
SNR_num = length(SNR_range);
% burst_range = [16,32,48,64];
burst_range = 16:1:64;
for mm = 1:length(burst_range)

%% --------- System Setting --------

STO = 'zero'; % Type of sample timing offset
BFtype = 'PN'; % Type of beamformer in IA
STOinfo = 1; % Assuming perfect knowledge of peak
M_burst = [burst_range(mm), burst_range(mm)]; % Number of bursts in IA; For directional use [M_Tx_BF,M_Rx_BF] for beams in BS and UE


%% ---------- Detection statistic in H0 ------------------
for ss = 1:SNR_num
    noise_pow = 10^(-SNR_range(ss)/10);
    
%     % plot cdf of detection statistics (emprical)
%     if plot_cdf
%         figure
%         [a,b] = ecdf(peak_pow_H0(ss,:));
%         plot(b,a);hold on
%         grid on
%     end
    
    mu(ss) = noise_pow/127;
    sigma(ss) = noise_pow/127*sqrt(2/M_burst(1));
    N = 254;
    switch STOinfo
        case 1
            mu_max(ss) = mu(ss);
            sigma_max(ss) = sigma(ss)*0.8; % it seems a factor of 0.8 gives more fit
            x = linspace(mu_max(ss)-4*sigma_max(ss),mu_max(ss)+4*sigma_max(ss),1e3);
            y = normpdf(x,mu_max(ss),sigma_max(ss));
        case 0
            mu_max(ss) = (mu(ss) - sigma(ss)*(-qfuncinv(1/N)))*0.9; % it seems a factor of 0.9 gives more fit
            sigma_max(ss) = -sigma(ss)/(-qfuncinv(1/N));
            x = linspace(mu_max(ss)-4*sigma_max(ss),mu_max(ss)+4*sigma_max(ss),1e3);
            y = evpdf(-x,-mu_max(ss),sigma_max(ss));
    end
    for xx = 1:length(x)
        theo_cdf(xx) = sum(y(1:xx))*(x(2)-x(1));
    end
    
    [~,TH_theo_index] = min(abs(theo_cdf-(1-Pfa)));
    TH_theo(ss) = x(TH_theo_index);
    
    % plot cdf of detection statistics (theo)
    if plot_cdf
        plot(x,theo_cdf);hold on
        title(num2str(SNR_range(ss)))
        legend('sim.','theo.')
    end

end

%% ------- Detection statistics in H1 --------------
for ss = 1:SNR_num
    noise_pow = 10^(-SNR_range(ss)/10);

    % plot cdf of detection statistics (emprical)
    if plot_cdf
        [a,b] = ecdf(peak_pow_H1(ss,:));
        figure
        plot(b,a);hold on
        grid on
    end
    
    switch STOinfo
        case 1
            switch STO
                case 'zero'
                    mu_H1 = 1*0.95 + mu_max(ss); % it seems a factor of 0.95 gives more fit
                    sigma_H1 = sqrt((sqrt(11)/sqrt(127))^2 + (sigma_max(ss))^2); 
                    x = linspace(mu_H1-4*sigma_H1,mu_H1+4*sigma_H1,1e3);
                    y = normpdf(x,mu_H1,sigma_H1);
                    for xx = 1:length(x)
                        theo_cdf_H1(xx) = sum(y(1:xx))*(x(2)-x(1));
                    end
                    [~, H1_theo_index(ss)] = min(abs((x-TH_theo(ss))));
                    Pm_theo(ss) = theo_cdf_H1(H1_theo_index(ss));
                case 'random'
                    mu_H1 = 0.6681 + mu_max(ss); % mean value of t^2-2t+1 when t \in [0,1]
                    sigma_H1 = sqrt((sqrt(11)/sqrt(127))^2 + (sigma_max(ss))^2); 
                    x = linspace(mu_H1-4*sigma_H1,mu_H1+4*sigma_H1,1e3);
                    y = normpdf(x,mu_H1,sigma_H1);
                    for xx = 1:length(x)
                        theo_cdf_H1(xx) = sum(y(1:xx))*(x(2)-x(1));
                    end
                    [~, H1_theo_index(ss)] = min(abs((x-TH_theo(ss))));
                    Pm_theo(ss) = theo_cdf_H1(H1_theo_index(ss));
            end
        case 0 % it's conservative to consider true correlation peak (detected peak is always higher than it!)
            mu_H1 = 0.75 + mu(ss); % mean value of t^2-2t+1 when t \in [0,1]
            sigma_H1 = sqrt((sqrt(11)/sqrt(127))^2 + (sigma(ss))^2); 
            x = linspace(mu_H1-4*sigma_H1,mu_H1+4*sigma_H1,1e3);
            y = normpdf(x,mu_H1,sigma_H1);
%             for xx = 1:length(x)
%                 theo_cdf_H1(xx) = sum(y(1:xx))*(x(2)-x(1));
%             end
            [theo_cdf_H1,x] = get_emp_maxrv_cdf(mu_H1,sigma_H1,mu_max(ss),sigma_max(ss));
            [~, H1_theo_index(ss)] = min(abs((x-TH_theo(ss))));
            Pm_theo(ss) = theo_cdf_H1(H1_theo_index(ss));
    end
    
    % plot cdf of detection statistics (theo)
    if plot_cdf
        plot(x,theo_cdf_H1)
        legend('sim.','theo.')
        title(num2str(SNR_range(ss)))
    end
end
%% cross-over point of miss detection
[~,pm_cross_index] = min(abs(Pm_theo - (1-pd)));
critical_SNR(mm) = SNR_range(pm_cross_index);

%%
% ------------ MC iterations (each has all SNRs)--------------
SNR_indices = max(pm_cross_index-10,1):min(pm_cross_index+10,SNR_num);
SNR_range_sim = SNR_range(SNR_indices);
peak_pow_H1 = zeros(length(SNR_range_sim),MCtimes);
peak_pow_H0 = zeros(length(SNR_range_sim),MCtimes);
% for MCindex = 1:MCtimes
%     clc
%     fprintf('Burst Number %d:\n',burst_range(mm));
%     fprintf('Iteration %d:\n',MCindex);
%     [ peak_pow_H1(:,MCindex),...
%       peak_pow_H0(:,MCindex) ] = run_PSS_detection( SNR_range_sim,...
%                                                     STO,...
%                                                     STOinfo,...
%                                                     BFtype,...
%                                                     M_burst);
% end
% 


%% --------- Detection based on theoretical threshold --------
% Pm_sim = zeros(length(SNR_indices),1);
% Pfa_sim = zeros(length(SNR_indices),1);
% for ss = 1:length(SNR_indices)
%     Pm_sim(ss) = sum(peak_pow_H1(ss,:)<TH_theo(SNR_indices(ss)))/MCtimes;
%     Pfa_sim(ss) = sum(peak_pow_H0(ss,:)>TH_theo(SNR_indices(ss)))/MCtimes;
% end
% [critical_index_sim] = min(find(((1-pd)-Pm_sim)>0));
% critical_SNR_sim(mm) = SNR_range_sim(critical_index_sim);
%% Figure
% figure
% subplot(211)
% % plot(SNR_range_sim,Pm_sim,'-o');hold on
% plot(SNR_data_range,Pm_theo);hold on
% grid on
% xlabel('SNR (dB)')
% ylabel('Miss Detection of PSS')
% legend('Sim.','Theo.')
% subplot(212)
% % plot(SNR_range_sim,Pfa_sim,'-o');hold on
% grid on
% xlabel('SNR (dB)')
% ylabel('False Alarm Rate')
% ylim([0,0.1])
end
%%
figure
% plot(burst_range, critical_SNR_sim,'-o');hold on
plot(burst_range, critical_SNR);hold on
grid on
xlabel('Burst Number (M)')
ylabel('Critical SNR for 0.1 Pm (dB)')





