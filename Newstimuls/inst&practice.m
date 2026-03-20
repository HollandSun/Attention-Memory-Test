
clear;
clc;

img_size = 256;
SSNR     = 0.4;

% ---- 路径 ----
stimulus_dir = 'stimulus';
target_dir   = fullfile(stimulus_dir, 'target');
noise_dir    = fullfile(stimulus_dir, 'noise');
cue_dir      = fullfile(stimulus_dir, 'cue');

% grayscale_mode = 'noise'：noise 是灰度，target 保持原色
% （直接读现有 noise 图，本身已经是灰度的，无需额外转换）

%% 创建输出文件夹
if ~exist(cue_dir, 'dir'), mkdir(cue_dir); end

%% 读取所有 target 图片
img_exts = {'*.png','*.jpg','*.jpeg'};
target_files = [];
for e = 1:numel(img_exts)
    target_files = [target_files; dir(fullfile(target_dir, img_exts{e}))]; %#ok<AGROW>
end

if isempty(target_files)
    error('在 %s 下没有找到任何图片！', target_dir);
end

[~, sort_idx] = sort({target_files.name});
target_files  = target_files(sort_idx);
n_targets     = numel(target_files);
fprintf('找到 %d 张 target 图片\n', n_targets);

%% 读取所有 noise 图片路径
noise_files = [];
for e = 1:numel(img_exts)
    noise_files = [noise_files; dir(fullfile(noise_dir, img_exts{e}))]; %#ok<AGROW>
end

if isempty(noise_files)
    error('在 %s 下没有找到任何 noise 图片！', noise_dir);
end

n_noise = numel(noise_files);
fprintf('找到 %d 张 noise 图片\n', n_noise);

%% 生成 Cue
fprintf('生成 Cue...\n');

for i = 1:n_targets

    % 读 target
    target = double(imread(fullfile(target_files(i).folder, target_files(i).name)));
    if size(target, 3) == 1                           % 灰度转 RGB
        target = repmat(target, [1 1 3]);
    end
    if size(target,1) ~= img_size || size(target,2) ~= img_size
        target = double(imresize(uint8(target), [img_size, img_size]));
    end

    % 从 noise 文件夹随机选一张
    rand_idx   = randi(n_noise);
    noise_raw  = imread(fullfile(noise_files(rand_idx).folder, noise_files(rand_idx).name));

    % resize 保险
    if size(noise_raw,1) ~= img_size || size(noise_raw,2) ~= img_size
        noise_raw = imresize(noise_raw, [img_size, img_size]);
    end

    % grayscale_mode = 'noise'：把 noise 转灰度后复制到 3 通道
    noise_gray   = double(rgb2gray(noise_raw));       % [H x W]，范围 0-255
    cue_noise    = repmat(noise_gray, [1 1 3]);       % [H x W x 3]

    % 混合：cue = SSNR * target + (1-SSNR) * noise
    cue = SSNR * target + (1 - SSNR) * cue_noise;
    cue = uint8(min(max(cue, 0), 255));

    % 输出文件名与 target 同名，前缀换成 cue_
    [~, base_name, ~] = fileparts(target_files(i).name);
    out_path = fullfile(cue_dir, sprintf('cue_%s.png', base_name));
    imwrite(cue, out_path);

    if mod(i, 20) == 0 || i == n_targets
        fprintf('  已完成 %d / %d\n', i, n_targets);
    end
end

fprintf('全部完成！共生成 %d 张 cue，保存在 %s\n', n_targets, cue_dir);