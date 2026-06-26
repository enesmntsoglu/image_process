% Verilerin tanımlanması (Table 1'den alınan veriler)
% T: Kelvin cinsinden sıcaklıklar
% U_up: Yukarı yönlü (U_\Uparrow) voltaj değerleri (mV)
% U_down: Aşağı yönlü (U_\Downarrow) voltaj değerleri, bazı satırlarda mevcut değil

T = [289, 323, 348, 373, 398, 423, 448, 473, 523, 548, 573, 598, 623];
U_up = [0.78e-4, 1.82e-4, 2.95e-4, 4.42e-4, 6.09e-4, 8.14e-4, 10.70e-4, 13.50e-4, 16.04e-4, 19.41e-4, 2.35e-3, 2.78e-3, 3.25e-3];
U_down = [NaN, NaN, NaN, NaN, NaN, 6.4e-4, 10.3e-4, 1.23e-3, 1.65e-3, 1.96e-3, 2.31e-3, 2.70e-3, 3.16e-3];

%% Grafik 1: Log-Log Grafiği (U_up vs. T)
figure;
loglog(T, U_up, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 8);
xlabel('Sıcaklık, T (K)');
ylabel('Voltaj, U_{\Uparrow} (mV)');
title('Log-Log Grafiği: U_{\Uparrow} vs. T');
grid on;
hold on;

% Logaritmik veriler üzerinde doğrusal regresyon (log10 tabanında)
logT = log10(T);
logU = log10(U_up);
p = polyfit(logT, logU, 1);  % p(1): eğim, p(2): kesme noktası
egim = p(1);

% Uygun doğrusal fit çizgisi oluşturma
T_fit = linspace(min(T), max(T), 100);
logT_fit = log10(T_fit);
logU_fit = polyval(p, logT_fit);
U_fit = 10.^logU_fit;  % log-ölçek dönüşümü
loglog(T_fit, U_fit, 'r--', 'LineWidth', 2);
legend('Veri', sprintf('Fit: egim = %.2f', egim));
hold off;

%% Grafik 2: U_up vs. (T^4 - T_0^4) Grafiği
% T0: Referans oda sıcaklığı (289 K olarak verilmiş)
T0 = 289;
DeltaT4 = T.^4 - T0^4;  % Her bir T için T^4 - T0^4 hesaplanır

figure;
plot(DeltaT4, U_up, 'ks-', 'LineWidth', 1.5, 'MarkerSize', 8);
xlabel('T^4 - T_0^4 (K^4)');
ylabel('Voltaj, U_{\Uparrow} (mV)');
title('Grafik: U_{\Uparrow} vs. (T^4 - T_0^4)');
grid on;
