%% AYRI AYRI L CURVE
figure('Name','L-Curve (İdeal)');
loglog(reg_norm_case1, res_norm_case1, 'bo-', 'LineWidth',1.5);
xlabel('||x_{\lambda}||_1'); ylabel('||A x_{\lambda} - b||_2');
title('L-Curve (İdeal Veri)'); grid on;

figure('Name','L-Curve (Gürültülü)');
loglog(reg_norm_case2, res_norm_case2, 'r*-', 'LineWidth',1.5);
xlabel('||x_{\lambda}||_1'); ylabel('||A x_{\lambda} - b||_2');
title('L-Curve (Gürültülü Veri)'); grid on;

%% L CURVE NOKTA İSİMLENDİRME
figure;
loglog(reg_norm_case2, res_norm_case2, 'r*-', 'LineWidth',1.5);
hold on; grid on;
title('L-Curve (Gürültülü Veri)');
xlabel('||x_{\lambda}||_1');
ylabel('||A x_{\lambda} - b||_2');


% for i = 1:length(lambda_range)
%     text(reg_norm_case2(i), res_norm_case2(i), ...
%         sprintf('\\lambda=%.1e', lambda_range(i)), ...
%         'VerticalAlignment','bottom','HorizontalAlignment','left', ...
%         'FontSize',6, 'Color','red');
% end

% Daha seyrek etiket için
step = 10;  % Kaç adımda bir etiket konulacağını ayarlayın
for i = 1:step:length(lambda_range)
   text(reg_norm_case2(i), res_norm_case2(i), ...
        sprintf('\\lambda=%.1e', lambda_range(i)), ...
        'VerticalAlignment','bottom', ...
        'HorizontalAlignment','left', ...
        'FontSize', 8, ...         
        'Color','red');
end
%%
subplot(2,2,1);
isosurface(Reconstructed_GCV,threshold);
subplot(2,2,2);
isosurface(Reconstructed_GCV_ideal,threshold);
subplot(2,2,3);
isosurface((Reconstructed_GCV_ideal-Reconstructed_GCV),threshold);
