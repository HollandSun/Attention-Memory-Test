%%
start_pt = 1;
max_iter = 10000000;
seq = [];
for iter = 1:max_iter
    core = Shuffle([ones(1,30), ones(1,30)*2]);
    s = [start_pt, core];
    if sum(diff(s) ~= 0) == 48
        seq = s;
        break
    end
end


max_iter = 10000000;
n_solutions = 50;
seqs = zeros(n_solutions, 61);
found = 0;

for iter = 1:max_iter
    core = Shuffle([ones(1,30), ones(1,30)*2]);
    s = [start_pt, core];
    if sum(diff(s) ~= 0) == 48
        found = found + 1;
        seqs(found, :) = s;
        if found == n_solutions
            break
        end
    end
end

if found < n_solutions
    seqs = seqs(1:found, :);
end
%%


function seq = GenerateSeqFast1(start_pt)
% 48 changes, 12 holds, 30个1 30个2
% 游程结构：r个游程，change数 = r-1（不含start_pt的转换）
% 加上start_pt到第一个trial的转换，总change数 = 相邻对数

% 48次change意味着：60个位置里有48个位置与前一个不同
% 用游程：设游程长度为 g1,g2,...,gr
% 游程数r，change次数 = r-1+（start_pt是否与第一游程不同）
% hold次数 = sum(gi-1) = 60-r

% 60-r = 12 → r = 48，但还需要处理start_pt
% 若start_pt与第一游程相同：change = r-1 = 47 ✗
% 若start_pt与第一游程不同：change = r   = 48 ✓

% 所以：48个游程，start_pt与第一游程值不同
% 每个游程长度至少1，sum=60，其中12次hold要分配

% 游程值交替：start_pt不同→第一游程是3-start_pt，然后交替
% 48个游程交替，第1游程=3-start_pt，第2=start_pt...

% 需要：1的游程总长=30，2的游程总长=30
% 奇数游程（1,3,5...）值=3-start_pt，偶数游程值=start_pt
% 共48个游程，奇数游程24个，偶数游程24个
% → 3-start_pt的总长=30，start_pt的总长=30 ✓（各24个游程各贡献）

% 只需把12次"额外长度"分配到48个游程里（每个游程基础长度=1）
% 额外长度 = 60-48 = 12，随机分配到48个游程

extra = zeros(1, 48);
positions = randperm(48, 12);   % 随机选12个游程各加1
extra(positions) = 1;
run_lengths = 1 + extra;        % 每个游程长度

% 构造序列
first_val = 3 - start_pt;      % 第一游程的值
seq_vals = zeros(1, 60);
ptr = 1;
for r = 1:48
    val = first_val + mod(r-1,2) * (start_pt - first_val) * 2;
    % 奇数游程=first_val，偶数游程=3-first_val
    % 简化：
    if mod(r,2)==1
        v = first_val;
    else
        v = 3 - first_val;
    end
    seq_vals(ptr:ptr+run_lengths(r)-1) = v;
    ptr = ptr + run_lengths(r);
end

seq = [start_pt, seq_vals];
end


seq = GenerateSeqFast1(1)