
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

% 生成S多和H多的序列各100个
% S多：48 shift, 12 hold
% H多：12 shift, 48 hold

n_solutions = 100;
start_pt = 1;

seqs_S = zeros(n_solutions, 61);
for i = 1:n_solutions
    seqs_S(i, :) = GenerateSeqFast_S(start_pt);
end

seqs_H = zeros(n_solutions, 61);
for i = 1:n_solutions
    seqs_H(i, :) = GenerateSeqFast_H(start_pt);
end



function seq = GenerateSeqFast_S(start_pt)
% 48个游程，奇数24个，偶数24个
% 额外12个长度：各6个分配给奇数游程，6个分配给偶数游程
% 这样奇数游程总长=24+6=30，偶数游程总长=24+6=30

n_runs   = 48;
odd_runs  = 24;   % 奇数游程
even_runs = 24;   % 偶数游程
n_extra_each = 6; % 奇/偶各分6个额外

extra_odd  = zeros(1, odd_runs);
extra_odd(randperm(odd_runs, n_extra_each)) = 1;

extra_even = zeros(1, even_runs);
extra_even(randperm(even_runs, n_extra_each)) = 1;

% 交织回48个游程
run_lengths = zeros(1, n_runs);
run_lengths(1:2:end) = 1 + extra_odd;    % 奇数位
run_lengths(2:2:end) = 1 + extra_even;   % 偶数位

first_val = 3 - start_pt;
seq_vals  = zeros(1, 60);
ptr = 1;
for r = 1:n_runs
    if mod(r,2) == 1
        v = first_val;
    else
        v = 3 - first_val;
    end
    seq_vals(ptr : ptr+run_lengths(r)-1) = v;
    ptr = ptr + run_lengths(r);
end
seq = [start_pt, seq_vals];
end


function seq = GenerateSeqFast_H(start_pt)
% 12个游程，奇数6个，偶数6个
% 额外48个长度：各24个分配给奇数游程，24个分配给偶数游程

n_runs    = 12;
odd_runs  = 6;
even_runs = 6;
n_extra_each = 24;  % 奇/偶各分24个额外

% stars-and-bars分别给奇/偶游程
cuts_odd  = sort(randperm(n_extra_each + odd_runs - 1,  odd_runs - 1));
cuts_odd  = [0, cuts_odd,  n_extra_each + odd_runs];
len_odd   = diff(cuts_odd);   % 6个奇数游程长度，总和=30

cuts_even = sort(randperm(n_extra_each + even_runs - 1, even_runs - 1));
cuts_even = [0, cuts_even, n_extra_each + even_runs];
len_even  = diff(cuts_even);  % 6个偶数游程长度，总和=30

run_lengths = zeros(1, n_runs);
run_lengths(1:2:end) = len_odd;
run_lengths(2:2:end) = len_even;

first_val = 3 - start_pt;
seq_vals  = zeros(1, 60);
ptr = 1;
for r = 1:n_runs
    if mod(r,2) == 1
        v = first_val;
    else
        v = 3 - first_val;
    end
    seq_vals(ptr : ptr+run_lengths(r)-1) = v;
    ptr = ptr + run_lengths(r);
end
seq = [start_pt, seq_vals];
end


