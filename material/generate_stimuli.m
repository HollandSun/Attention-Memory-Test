% generate_stimuli.m

clear; clc;

img_size = 256;    % size remmeber adjust the PTB too, if changed
SSNR     = 0.4;    % SSNR
n_noise  = 240;    % noise numbersss

raw_dir  = 'AnimacySize';          % rawimages

target_dir = 'stimuli/target_images'; % output target
cue_dir  = 'stimuli/cue_images';  % output cue
noise_dir   = 'stimuli/noise_images';% output noise

% ---- Grayscale switches ----
% 'both'   : noise and cue are both grayscale
% 'noise'  : noise is grayscale, cue keeps original color
% 'none'   : both noise and cue keep original color (default)
grayscale_mode = 'noise';
% ----------------------------

%% 
if ~exist(target_dir, 'dir'), mkdir(target_dir); end
if ~exist(noise_dir,  'dir'), mkdir(noise_dir);  end
if ~exist(cue_dir,    'dir'), mkdir(cue_dir);    end


if ~exist(target_dir, 'dir')
    error('Directory does not exist: %s', target_dir);
end

if ~exist(noise_dir, 'dir')
    error('Directory does not exist: %s', noise_dir);
end

if ~exist(cue_dir, 'dir')
    error('Directory does not exist: %s', cue_dir);
end


% just in case 



 
%% Target organize - Animate first (1-120), Inanimate after (121-240)

category_folders = dir(raw_dir);
category_folders = category_folders([category_folders.isdir]);
category_folders = category_folders(~ismember({category_folders.name}, {'.','..'}));
all_names = sort({category_folders.name});  % sort by name

% Separate Animate and Inanimate folders
animate_folders   = all_names(contains(all_names, 'Animate') & ~contains(all_names, 'Inanimate'));
inanimate_folders = all_names(contains(all_names, 'Inanimate'));

% Animate first, then Inanimate
ordered_folders = [animate_folders, inanimate_folders];

all_targets = {};
global_idx = 0;

for cat = 1:numel(ordered_folders)
    cat_path = fullfile(raw_dir, ordered_folders{cat});
    
    img_files = [dir(fullfile(cat_path,'*.png')); ...
                 dir(fullfile(cat_path,'*.jpg')); ...
                 dir(fullfile(cat_path,'*.jpeg'))];
    
    [~, sort_idx] = sort({img_files.name});
    img_files = img_files(sort_idx);
    
    for j = 1:numel(img_files)
        global_idx = global_idx + 1;
        
        raw_path = fullfile(cat_path, img_files(j).name);
        img = imread(raw_path);
        
        if size(img,1) ~= img_size || size(img,2) ~= img_size
            img = imresize(img, [img_size, img_size]);
        end
        
        if ~isa(img, 'uint8')
            img = uint8(img);
        end
        
        out_path = fullfile(target_dir, sprintf('target_%03d.png', global_idx));
        imwrite(img, out_path);
        
        all_targets{global_idx} = img;
    end
end

n_targets = global_idx;




%%% Generate noise
%% Calculate the average amplitude spectrum 

% grayscale modes use luminance channel only for amplitude
% color mode uses per-channel RGB amplitude as before
if strcmp(grayscale_mode, 'both') || strcmp(grayscale_mode, 'noise')
    avg_amplitude = zeros(img_size, img_size);
    for i = 1:n_targets
        img_gray = double(rgb2gray(all_targets{i}));
        F = fft2(img_gray);
        avg_amplitude = avg_amplitude + abs(F);
    end
    avg_amplitude = avg_amplitude / n_targets;
else
    avg_amplitude = zeros(img_size, img_size, 3);  
    for i = 1:n_targets
        img_double = double(all_targets{i});

        for c = 1:3 % chanle 3 RGB
            F = fft2(img_double(:,:,c));
            avg_amplitude(:,:,c) = avg_amplitude(:,:,c) + abs(F);
        end

    end
    avg_amplitude = avg_amplitude / n_targets;
end

clear all_targets;

%% Generate Fourier phase-scrambled noise


for i = 1:n_noise
    noise_img = zeros(img_size, img_size, 3, 'uint8');

    if strcmp(grayscale_mode, 'both') || strcmp(grayscale_mode, 'noise')
        % single channel noise then replicate to RGB (grayscale appearance)
        random_phase = (rand(img_size, img_size) * 2 - 1) * pi;
        F_new = avg_amplitude .* exp(1i * random_phase);
        noise_channel = real(ifft2(F_new));
        noise_min = min(noise_channel(:));
        noise_max = max(noise_channel(:));
        noise_channel = uint8((noise_channel - noise_min) / (noise_max - noise_min) * 255);
        noise_img = repmat(noise_channel, [1 1 3]);
    else
        % color noise: independent random phase per RGB channel
        for c = 1:3
            random_phase = (rand(img_size, img_size) * 2 - 1) * pi;
            F_new = avg_amplitude(:,:,c) .* exp(1i * random_phase);
            noise_channel = real(ifft2(F_new));
            noise_min = min(noise_channel(:));
            noise_max = max(noise_channel(:));
            noise_img(:,:,c) = uint8((noise_channel - noise_min) / (noise_max - noise_min) * 255);
        end
    end
    
    out_path = fullfile(noise_dir, sprintf('noise_%03d.png', i));
    imwrite(noise_img, out_path);
end

%% Generate Cue
% cue = SSNR * target + (1-SSNR) * noise
fprintf('Generate Cue \n');
for i = 1:n_targets
    target_path = fullfile(target_dir, sprintf('target_%03d.png', i));
    target = double(imread(target_path));
    
    % generate a new noise for target
    cue_noise = zeros(img_size, img_size, 3);

    if strcmp(grayscale_mode, 'both')
        % grayscale noise for cue: single luminance channel replicated to RGB
        random_phase = (rand(img_size, img_size) * 2 - 1) * pi;
        F_new = avg_amplitude .* exp(1i * random_phase);
        %  overlay and clip [0,255] intensity
        noise_channel = real(ifft2(F_new));
        noise_min = min(noise_channel(:));
        noise_max = max(noise_channel(:));
        noise_channel = (noise_channel - noise_min) / (noise_max - noise_min) * 255;
        cue_noise = repmat(noise_channel, [1 1 3]);
            
    elseif strcmp(grayscale_mode, 'noise')
            % grayscale noise for cue, target color preserved
            random_phase = (rand(img_size, img_size) * 2 - 1) * pi;
            F_new = avg_amplitude .* exp(1i * random_phase);
            %  overlay and clip [0,255] intensity
            noise_channel = real(ifft2(F_new));
            noise_min = min(noise_channel(:));
            noise_max = max(noise_channel(:));
            noise_channel = (noise_channel - noise_min) / (noise_max - noise_min) * 255;
            cue_noise = repmat(noise_channel, [1 1 3]);
        
    else
            % color noise for cue ('none' mode only)
            for c = 1:3
                random_phase = (rand(img_size, img_size) * 2 - 1) * pi;
                F_new = avg_amplitude(:,:,c) .* exp(1i * random_phase);
                noise_channel = real(ifft2(F_new));
                noise_min = min(noise_channel(:));
                noise_max = max(noise_channel(:));
                cue_noise(:,:,c) = (noise_channel - noise_min) / (noise_max - noise_min) * 255;
            end
     end
        
            %  overlay and clip [0,255] intensity
            cue = SSNR * target + (1 - SSNR) * cue_noise;
            cue = uint8(min(max(cue, 0), 255));
            
            out_path = fullfile(cue_dir, sprintf('cue_%03d.png', i));
            imwrite(cue, out_path);

end
