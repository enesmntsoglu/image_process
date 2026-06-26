%% Intensite Zaman Grafikleri (13:40 baz alınarak)

clc; clear; close all;

% --- Veriler ---
labels    = {'sandw\_1','sandw\_2','sandw\_3'};
times_str = {
    {'13:45','15:35','17:13'};
    {'14:25','16:07','17:41'};
    {'15:02','16:40','18:06'};
};
ints = {
    [2586, 2568, 478];
    [2128, 1477,1754];
    [4089, 4089,1112];
};

% Baz zamanı
baseT = datetime('13:40','InputFormat','HH:mm');

% Renk paleti
colors = lines(3);

%% 1) Her bir için ayrı grafik
for i = 1:3
    % Zamanı dakika cinsine çevir
    t_i = datetime(times_str{i},'InputFormat','HH:mm');
    x_i = minutes(t_i - baseT);
    y_i = ints{i};
    
    figure;
    plot(x_i, y_i, '-o', 'LineWidth',1.5, 'Color', colors(i,:));
    xlabel('Zaman (dakika, 13:40 baz)');
    ylabel('Max Intensite');
    title(sprintf('%s Intensiteleri', labels{i}));
    grid on;
    hold on;
    % Nokta etiketleri
    for j = 1:numel(x_i)
        text(x_i(j), y_i(j)+50, times_str{i}{j}, ...
             'HorizontalAlignment','center', ...
             'Color', colors(i,:), 'FontSize', 10);
    end
    hold off;
end

%% 2) Tek grafikte birleştirilmiş çizgi
allX = [];
allY = [];
allLabelIdx = [];
allTimeStr = {};

for i = 1:3
    t_i = datetime(times_str{i},'InputFormat','HH:mm');
    x_i = minutes(t_i - baseT);
    y_i = ints{i};
    allX = [allX, x_i];
    allY = [allY, y_i];
    allLabelIdx = [allLabelIdx, repmat(i,1,numel(x_i))];
    allTimeStr = [allTimeStr, times_str{i}];
end

% Zaman sırasına göre sırala
[allX, order] = sort(allX);
allY = allY(order);
allLabelIdx = allLabelIdx(order);
allTimeStr = allTimeStr(order);

figure;
plot(allX, allY, '-ok', 'LineWidth',1.5, 'MarkerFaceColor','k');
xlabel('Zaman (dakika, 13:40 baz)');
ylabel('Max Intensite');
title('Tum Sandw Intensiteleri (Tek Cizgi)');
grid on;
hold on;

% Nokta etiketleri (renkli)
for k = 1:numel(allX)
    idx = allLabelIdx(k);
    text(allX(k), allY(k)+50, sprintf('%s\n%s', labels{idx}, allTimeStr{k}), ...
         'HorizontalAlignment','center', ...
         'Color', colors(idx,:), 'FontSize', 9);
end
hold off;
