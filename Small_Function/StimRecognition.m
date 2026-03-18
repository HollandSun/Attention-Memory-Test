function StimRecognition

%% ---- 参数配置（需要修改的都在这里） ----
CUE_DURATION  = 0.250;   % 秒，cue图片呈现时长，暂定250ms
NOISE_FRAMES  = 4;       % cue前noise帧数
FRAME_RATE    = 4;       % Hz，noise stream帧率
stim_root     = 'stimuli';
cue_dir       = fullfile(stim_root, 'cue_images');
noise_dir     = fullfile(stim_root, 'noise_images');
N_NOISE       = 240;     % noise图片总数
IMG_SIZE      = 256;     % 图片呈现尺寸（像素），与generate_stimuli.m一致
% ------------------------------------------

s = input('Enter Subject Number: ');

%% ---- PTB初始化 ----
KbName('UnifyKeyNames');
background  = [0 0 0];
whichScreen = 0;

[window, windowRect] = Screen('OpenWindow', whichScreen, background);
HideCursor(window);
slack = Screen('GetFlipInterval', window) / 2;
Screen('TextFont', window, 'Monaco');
Screen('TextSize', window, 40);

Cx = windowRect(3) / 2;
Cy = windowRect(4) / 2;

half    = IMG_SIZE / 2;
dstRect = [Cx-half, Cy-half, Cx+half, Cy+half];   % 图片居中呈现
center  = [Cx Cy Cx Cy];

%% ---- 载入所有cue图片 ----
% 扫描cue_images目录下所有cue_XXX.png
cue_files = dir(fullfile(cue_dir, 'cue_*.png'));
n_cue     = length(cue_files);
fprintf('Found %d cue images.\n', n_cue);

fprintf('Loading cue textures...\n');
cueTextures = zeros(1, n_cue);
cueNumbers  = zeros(1, n_cue);   % 存图片编号，从文件名解析
for i = 1:n_cue
    fname           = cue_files(i).name;           % e.g. 'cue_047.png'
    num_str         = regexp(fname, '\d+', 'match');
    cueNumbers(i)   = str2double(num_str{1});
    img             = imread(fullfile(cue_dir, fname));
    cueTextures(i)  = Screen('MakeTexture', window, img);
end

%% ---- 载入noise图片 ----
fprintf('Loading noise textures...\n');
noiseTextures = zeros(1, N_NOISE);
for i = 1:N_NOISE
    img              = imread(fullfile(noise_dir, sprintf('noise_%03d.png', i)));
    noiseTextures(i) = Screen('MakeTexture', window, img);
end
noisePool    = Shuffle(1:N_NOISE);
noisePoolIdx = 1;

%% ---- 键盘设置 ----
keyList = zeros(1, 256);
keyList([KbName('z') KbName('m') KbName('q')]) = 1;
ind = GetKeyboardIndices;
ind = ind(length(ind)-1);
KbQueueCreate(ind, keyList);

%% ---- 随机化trial顺序 ----
trial_order = Shuffle(1:n_cue);   % 所有cue图片随机顺序各呈现一次

%% ---- 结果存储 ----
results.cueNumber = zeros(1, n_cue);
results.response  = zeros(1, n_cue);   % 1=z, 2=m, 0=未反应
results.RT        = zeros(1, n_cue);

%% ---- 开始提示 ----
DrawFormattedText(window, ...
    'Stimulus Recognition Task\n\nPress Z or M to respond\nPress Q to quit\n\nPress SPACE to begin', ...
    'center', 'center', [255 255 255]);
Screen('Flip', window);

while KbCheck; end
while 1
    [keyIsDown, ~, keyCode] = KbCheck;
    if keyIsDown && find(keyCode,1) == KbName('space')
        prevFlip = Screen('Flip', window);
        break;
    end
end

%% ---- 主trial循环 ----
for tr = 1:n_cue
    cue_idx = trial_order(tr);
    fprintf('Trial %d/%d | cue#%d', tr, n_cue, cueNumbers(cue_idx));

    %% 注视点 500ms
    DrawFormattedText(window, '+', 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, center);
    prevFlip = Screen('Flip', window, prevFlip + 0.5 - slack);

    %% noise stream：NOISE_FRAMES帧
    frameTime = 1000 / FRAME_RATE * 0.001;   % 秒
    streamFlip = prevFlip + 0.25;
    for f = 1:NOISE_FRAMES
        % 取noise texture
        if noisePoolIdx > length(noisePool)
            noisePool    = Shuffle(1:N_NOISE);
            noisePoolIdx = 1;
        end
        ntex         = noiseTextures(noisePool(noisePoolIdx));
        noisePoolIdx = noisePoolIdx + 1;

        Screen('DrawTexture', window, ntex, [], dstRect);
        DrawFormattedText(window, '+', 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, center);
        streamFlip = Screen('Flip', window, streamFlip - slack);
        streamFlip = streamFlip + frameTime;
    end

    %% cue图片呈现 CUE_DURATION秒
    Screen('DrawTexture', window, cueTextures(cue_idx), [], dstRect);
    DrawFormattedText(window, '+', 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, center);
    cueOnset   = Screen('Flip', window, streamFlip - slack);
    streamFlip = cueOnset + CUE_DURATION;

    %% 黑屏+注视点，等待按键
    DrawFormattedText(window, '+', 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, center);
    Screen('Flip', window, streamFlip - slack);

    KbQueueStart(ind);

    % 等待z/m/q
    responded = false;
    while ~responded
        [pressed, firstpress] = KbQueueCheck(ind);
        if pressed
            kc = find(firstpress == min(firstpress(firstpress~=0)), 1);
            t_press = min(firstpress(firstpress~=0));

            if kc == KbName('z')
                results.response(tr)  = 1;
                results.RT(tr)        = t_press - cueOnset;
                results.cueNumber(tr) = cueNumbers(cue_idx);
                fprintf(' | Z | RT=%.0fms\n', results.RT(tr)*1000);
                responded = true;
            elseif kc == KbName('m')
                results.response(tr)  = 2;
                results.RT(tr)        = t_press - cueOnset;
                results.cueNumber(tr) = cueNumbers(cue_idx);
                fprintf(' | M | RT=%.0fms\n', results.RT(tr)*1000);
                responded = true;
            elseif kc == KbName('q')
                fprintf('\nAborted at trial %d\n', tr);
                KbQueueStop(ind);
                KbQueueRelease(ind);
                save(['Data/S' num2str(s) '_StimRecognition.mat'], 'results');
                Screen('CloseAll');
                ShowCursor;
                return
            end
        end
    end

    KbQueueStop(ind);
    KbQueueFlush(ind);
    prevFlip = Screen('Flip', window);   % 清屏准备下一trial
end

%% ---- 结束 ----
DrawFormattedText(window, 'Done! Thank you.', 'center', 'center', [255 255 255]);
Screen('Flip', window);
WaitSecs(2);

%% ---- 保存结果 ----
save(['Data/S' num2str(s) '_StimRecognition.mat'], 'results');
fprintf('\nSaved: Data/S%d_StimRecognition.mat\n', s);
fprintf('Total trials: %d\n', n_cue);

KbQueueRelease(ind);
Screen('CloseAll');
ShowCursor;
end
