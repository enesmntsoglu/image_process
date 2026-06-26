%% ==== VOLPREX sadece: zorlu (seyrek) phantom için dayanıklı görselleştirme ====
% Gerekli: vol_preX (25x25x20 gibi), q_Y (yoğunluk), isteğe bağlı: voxel2mm
if ~exist('voxel2mm','var'); voxel2mm = 0.1; end  % 0.1 mm/voxel
V = vol_preX;
[Ny, Nx, Nz] = size(V);

% Figür
f = figure('Name','VOLPREX - Robust 3B Görsel','Color','w','Units','normalized','Position',[0.2 0.1 0.6 0.8]);
ax = axes('Parent',f);

% Eşikler
iso_ratio_volprex = 0.25;              % 1) ham hacim için izoyüzey eşiği (max(V)*ratio)
thr1 = max(V(:)) * iso_ratio_volprex;   % örn. 0.15 * 0.25 = 0.0375

% 1) Doğrudan izoyüzey denemesi
ok = try_iso(ax, V, thr1, 'VOLPREX', [0.40 0.20 0.80], Nx, Ny, Nz, voxel2mm);

% 2) Olmadıysa, hafif yumuşatma ile tekrar
if ~ok
    Vs = smooth3(V, 'box', [3 3 3]);         % hafif blur; ince çubukları “hacim”e dönüştürür
    thr2 = 0.5 * max(Vs(:));                 % adaptif eşik (maksimumun yarısı pratikte iyi çalışır)
    ok = try_iso(ax, Vs, thr2, 'VOLPREX (smoothed)', [0.35 0.35 0.85], Nx, Ny, Nz, voxel2mm);
end

% 3) Hâlâ yüzey yoksa, nokta/voxel fallback
if ~ok
    robust_voxel_scatter(ax, V, q_Y, Nx, Ny, Nz, voxel2mm);
end

% Ortak eksen-limit etiket ayarları (mm)
xlim(ax,[0 Nx]*voxel2mm); ylim(ax,[0 Ny]*voxel2mm); zlim(ax,[0 Nz]*voxel2mm);
xt = linspace(0, Nx*voxel2mm, 6); yt = linspace(0, Ny*voxel2mm, 6); zt = linspace(0, Nz*voxel2mm, 6);
xticks(ax, xt); yticks(ax, yt); zticks(ax, zt);
xticklabels(ax, arrayfun(@(v) sprintf('%.1f', v), xt, 'UniformOutput', false));
yticklabels(ax, arrayfun(@(v) sprintf('%.1f', v), yt, 'UniformOutput', false));
zticklabels(ax, arrayfun(@(v) sprintf('%.1f', Nz*voxel2mm - v), zt, 'UniformOutput', false)); % Z etiketi ters

xlabel(ax,'X (mm)'); ylabel(ax,'Y (mm)'); zlabel(ax,'Z (mm)');
grid(ax,'on'); box(ax,'on'); daspect(ax,[1 1 1]); view(ax,3);

%% ==== Yardımcılar ====
function ok = try_iso(ax, V, thr, ttl, fcolor, Nx, Ny, Nz, voxel2mm)
    % V: hacim, thr: eşik. Başarılıysa true döner, başarısızsa false.
    ok = false;
    if ~isfinite(thr) || thr <= 0 || max(V(:))<=0
        title(ax, [ttl ' (yüzey eşiği yetersiz)']); return;
    end
    [F, Vert] = isosurface(V, thr);
    if isempty(F) || isempty(Vert)
        title(ax, [ttl ' (iso-surface yok)']); return;
    end
    % Görselleştir (mm)
    Vert = double(Vert);
    % Y'yi ayna (senin önceki görsel hiyerarşinle uyumlu olsun)
    Vert(:,2) = Ny - Vert(:,2) + 1;
    Vert_mm = Vert * voxel2mm;

    cla(ax);
    % Gölge projeksiyonlar (opsiyonel görsel derinlik)
    shadowColor = [0.6 0.6 0.6]; shadowAlpha = 0.18;
    xPlane_mm = 1 * voxel2mm;           % X-min düzlemi
    yPlane_mm = Ny * voxel2mm;          % Y-max düzlemi
    zPlane_mm = 1 * voxel2mm;           % Z-min düzlemi

    Vxy_mm = Vert_mm; Vxy_mm(:,3) = zPlane_mm;
    patch(ax,'Faces',F,'Vertices',Vxy_mm,'FaceColor',shadowColor,'FaceAlpha',shadowAlpha,'EdgeColor','none','FaceLighting','none');

    Vxz_mm = Vert_mm; Vxz_mm(:,2) = yPlane_mm;
    patch(ax,'Faces',F,'Vertices',Vxz_mm,'FaceColor',shadowColor,'FaceAlpha',shadowAlpha,'EdgeColor','none','FaceLighting','none');

    Vyz_mm = Vert_mm; Vyz_mm(:,1) = xPlane_mm;
    patch(ax,'Faces',F,'Vertices',Vyz_mm,'FaceColor',shadowColor,'FaceAlpha',shadowAlpha,'EdgeColor','none','FaceLighting','none');

    % Ana yüzey
    p = patch(ax,'Faces',F,'Vertices',Vert_mm,'FaceColor',fcolor,'EdgeColor','none','FaceAlpha',0.90);
    camlight(ax,'headlight'); lighting(ax,'gouraud'); material(ax,'dull');
    set(p,'HitTest','off','PickableParts','none');

    title(ax, sprintf('%s (thr=%.3g)', ttl, thr));
    ok = true;
end

function robust_voxel_scatter(ax, V, q_Y, Nx, Ny, Nz, voxel2mm)
    % Yüzey çıkarılamadıysa, nonzero voxelleri nokta/küp gibi göster.
    [yy, xx, zz] = ind2sub(size(V), find(V > 0));
    if isempty(xx)
        cla(ax); title(ax, 'VOLPREX (nonzero voxel yok)'); return;
    end
    % mm koordinatlarına çevir
    X = xx * voxel2mm; Y = (size(V,1) - yy + 1) * voxel2mm; Z = zz * voxel2mm;
    cla(ax);
    % Quantum yield'e göre marker boyutu/şeffaflığı (opsiyonel)
    vv = V(V>0);
    s = 30 * (vv / max(vv));  % normalize boyut
    s(s<10) = 10;

    scatter3(ax, X, Y, Z, s, vv, 'filled', 'MarkerFaceAlpha', 0.85);
    colormap(ax, parula); colorbar(ax);
    title(ax, sprintf('VOLPREX (voxel scatter)  #vox=%d, q_Y=%.3g', numel(vv), q_Y));
end
%%
