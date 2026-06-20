# VMscatter: A Versatile MIMO Backscatter

[English](#english-readme) | [中文说明](#chinese-readme)

---

<a name="english-readme"></a>

## English Readme

This repository contains the MATLAB proof-of-concept and IEEE 802.11n HT
simulation for **VMscatter**, published at USENIX NSDI 2020:

> Xin Liu, Zicheng Chi, Wei Wang, Yao Yao, and Ting Zhu.
> [VMscatter: A Versatile MIMO Backscatter](https://www.usenix.org/conference/nsdi20/presentation/liu-xin).
> 17th USENIX Symposium on Networked Systems Design and Implementation, 2020.

## Requirements

- MATLAB R2024b
- WLAN Toolbox
- Communications Toolbox
- Signal Processing Toolbox

The release uses the official MathWorks WLAN APIs. It does not include or
modify copies of MathWorks functions.

## Quick start

From the repository root:

```matlab
result = run_quick_demo;
```

This short run checks installation and the complete modulation, channel,
estimation, and decoding path. Its BER sample size is deliberately small and
must not be used as a publication result.

For the full 2--10 dB evaluation:

```matlab
result = run_full_evaluation;
```

To reproduce the paper's high-throughput mode:

```matlab
report = run_high_throughput_evaluation;
```

Generated CSV, MAT, FIG, and PNG files are written to `results/`. That
directory is created locally and is not tracked by Git.

To inspect the decoding principle without the complete HT PHY:

```matlab
cd Proof-of-Concept_Simulation
report = run_poc_simulation;
```

The public PoC entry runs 1,000 codewords by default. The extended regression
suite audits 10,000 codewords.

### Why the proof-of-concept decoder is solvable

The PoC is a **reference-aided similarity-transform identification**
problem. After the ordinary WiFi channel is removed using the all-one tag
state, the effective tag channel is

```text
G(d) = inv(H_R) * D(d) * H_R
D(d) = diag(d_1, ..., d_K)
```

This is not the generic equation `Y = A * X * A`. It is a similarity transform,
equivalently the homogeneous Sylvester/intertwining equation

```text
D(d) * H_R = H_R * G(d)
```

For the 2-tag PoC, the explicit reference is
`D_ref = diag(-1, 1)`. Its distinct eigenvalues identify
the two channel directions. The original Efficient decoder solves this
relation in closed form by fixing one representative of the otherwise
non-unique channel matrix.

The physical `H_R` need not be recovered uniquely. If `C` is any
invertible diagonal matrix, `C * H_R` is an equally valid solution because
`C` commutes with every diagonal tag matrix. This ambiguity cancels during
decoding:

```text
(C * H_R) * G(d) * inv(C * H_R)
    = C * D(d) * inv(C)
    = D(d)
```

Thus the channel can have infinitely many equivalent representations while
the diagonal tag state, and therefore the transmitted bits, remains
recoverable. The main conditions are:

- `H_R` is invertible and reasonably conditioned;
- the reference states distinguish the tag dimensions;
- for `K` tag dimensions, the baseline plus explicit-reference state
  matrix has rank `K`;
- the channel stays approximately constant during reference and data.

Full rank alone is not enough for a single reference operator: the identity
matrix is full rank but its repeated eigenvalues reveal no channel
directions. Distinguishable reference signatures are the key. The
packet-level HT implementation generalizes this principle by estimating
basis operators with joint weighted least squares and applying codebook
maximum-likelihood detection.

Run the public regression suite with:

```matlab
addpath tests
reports = run_all_tests('Full', false); % quick
reports = run_all_tests('Full', true);  % extended noiseless validation
```

## Simulation structure

VMscatter uses the notation `M x K x N`:

- `M`: WiFi transmit antennas/streams;
- `K`: VMscatter tag antennas;
- `N`: receiver antennas.

The release compares:

- **2x2x2**: 2 WiFi transmit streams, 2 tag antennas, 2 receive antennas;
- **2x4x4**: 2 WiFi transmit streams, 4 tag antennas, 4 receive antennas.

Both architectures carry 256 tag bits in 256 HT-Data OFDM symbols per packet:
2x2x2 uses 128 two-bit codewords, while 2x4x4 uses 64 four-bit recursive-STC
codewords. This keeps the data-symbol time and tag information bits equal.
No tag FEC, repeated data bits, favorable-channel selection, or extra
per-bit reflection energy is used.

## Low-BER and high-throughput modes

The receiver follows Eqn. 16 in the paper:

- **LowBER (`T=1`)** jointly detects adjacent coded symbols and then applies
  recursive space-time decoding. It carries one tag bit per OFDM symbol.
- **HighThroughput (`T=0`)** detects each tag time slot independently. The
  prototype holds one tag state for two 4-microsecond HT OFDM symbols, so one
  tag slot lasts 8 microseconds. A 2-tag slot carries two bits; a 4-tag slot
  carries four.

For the documented two-antenna mapping in Fig. 4, information bits `[a b]`
produce tag states

```text
[ exp(j*pi*(a+b)),  exp(j*pi*a) ]
```

For four tag antennas, this simulator applies the same documented mapping to
two independent antenna pairs. This is a bijective 4-bit-to-4-state pairwise
extension; the paper reports the four-antenna throughput result but does not
write a separate four-antenna high-throughput mapping matrix.

With an 8-microsecond tag slot, the ideal raw tag rates are:

| Mode | 2x2x2 | 2x4x4 |
|---|---:|---:|
| HighThroughput | 250 kbps | 500 kbps |

For reference, the corresponding one-tag rate is 125 kbps. Both
high-throughput architectures occupy 256 HT data symbols (128 tag slots) per
packet, so 2x2x2 carries 256 tag bits and 2x4x4 carries 512 tag bits before
errors and reference overhead. Net goodput is reported separately.

## Reference design and channel estimation

During the HT-LTF, the tag uses the all-ones state. Conventional WiFi channel
estimation and equalization therefore provide the baseline operator

```text
G(1) = I
```

For `K` tag antennas, only `K-1` additional states are transmitted. The
design must satisfy

```text
rank([1, d_1, ..., d_{K-1}]) = K
```

The three evaluation profiles are:

| Profile | 2x2x2 explicit reference symbols | 2x4x4 explicit reference symbols |
|---|---:|---:|
| Minimal | 1 | 3 |
| Default (recommended) | 2 | 6 |
| Robust | 4 | 12 |

Repeated observations of each state are combined by weighted joint
least-squares. One reference block is reused by all codewords in the packet,
so its overhead is amortized over the data field.

## Why antenna-domain alignment matters

In IEEE 802.11n HT, cyclic shifts and spatial mapping transform spatial-stream
symbols before transmission. The tag modulates the **physical antenna-domain**
waveform, but the standard receiver initially returns equalized
**spatial-stream-domain** symbols. Directly combining these two coordinate
systems produces an inconsistent VMscatter channel estimate.

The helper functions in `802.11nHT/` extract the transmitted HT-Data tones
after cyclic shift/spatial mapping and apply the same transformation to the
equalized receive streams. VMscatter channel estimation and ML decoding then
operate consistently in the antenna domain.

For every candidate tag codeword, the decoder accumulates a reliability-
weighted Euclidean distance over all 52 HT20 data subcarriers and all coded
OFDM symbols. Reported zero-error points use a 95% confidence upper bound
rather than claiming an exact BER of zero.

## Reproduced reliability result

In the full fixed-seed 2--10 dB run:

- all three reference profiles produced lower 2x4x4 BER at 7 of 9 SNR points;
- Minimal and Default had five consecutive SNR points whose 2x4x4 95%
  confidence upper bound was below the 2x2x2 lower bound, and passed the
  predefined reliability criterion;
- Robust showed the same overall 7-of-9 trend but only two consecutive
  strictly separated confidence intervals, so it did not pass that stricter
  criterion.

Thus the simulation supports a system-level reliability advantage for 2x4x4,
but it does **not** claim that 2x4x4 is statistically better at every SNR
point or for every reference setting.

Error rates are fractions: `1.0 = 100%`, `0.01 = 1%`, and `0.0025 = 0.25%`.

## Repository layout

```text
Proof-of-Concept_Simulation/  simplified decoding mechanism
802.11nHT/                    final packet-level HT simulation
tests/                        public regression tests
Circuit/                      VMscatter hardware design files
run_quick_demo.m              short installation/data-flow check
run_full_evaluation.m         full reference-profile evaluation
run_high_throughput_evaluation.m  paper T=0 throughput evaluation
```

## License

This code is released under the MIT License. See [LICENSE](LICENSE).

## Citation

```bibtex
@inproceedings {vmscatter,
	author = {Xin Liu and Zicheng Chi and Wei Wang and Yao Yao and Ting Zhu},
	title = {{VMscatter}: A Versatile {MIMO} Backscatter },
	booktitle = {17th USENIX Symposium on Networked Systems Design and Implementation (NSDI 20)},
	year = {2020},
	isbn = {978-1-939133-13-7},
	address = {Santa Clara, CA},
	pages = {895--909},
	url = {https://www.usenix.org/conference/nsdi20/presentation/liu-xin},
	publisher = {USENIX Association},
	month = feb
}
```

---

<a name="chinese-readme"></a>

## 中文说明

本仓库包含VMscatter的MATLAB原理仿真和IEEE 802.11n HT完整仿真。论文发表于
USENIX NSDI 2020：

> Xin Liu, Zicheng Chi, Wei Wang, Yao Yao, and Ting Zhu.
> [VMscatter: A Versatile MIMO Backscatter](https://www.usenix.org/conference/nsdi20/presentation/liu-xin).
> 17th USENIX Symposium on Networked Systems Design and Implementation, 2020.

### 环境与运行

需要MATLAB R2024b、WLAN Toolbox、Communications Toolbox和Signal
Processing Toolbox。本代码只调用MathWorks官方WLAN函数，不包含也不修改
MATLAB内部函数副本。

在仓库根目录运行：

```matlab
result = run_quick_demo;
```

这是快速安装和数据流检查，统计量较小，不能作为正式BER结论。正式复现实验：

```matlab
result = run_full_evaluation;
```

正式实验扫描2--10 dB，结果写入本地`results/`。

运行论文中的High-Throughput Mode：

```matlab
report = run_high_throughput_evaluation;
```

原理解码仿真：

```matlab
cd Proof-of-Concept_Simulation
report = run_poc_simulation;
```

公开PoC入口默认运行1,000个codewords；扩展测试套件使用10,000个codewords。

#### PoC为什么可解：参考辅助的相似变换辨识

PoC的核心不是一般形式的 `Y = A * X * A`，而是相似变换问题。利用tag全为
`+1`时的baseline消去普通WiFi信道后，可以得到

```text
G(d) = inv(H_R) * D(d) * H_R
D(d) = diag(d_1, ..., d_K)
```

它也可以写成齐次Sylvester（intertwining）方程：

```text
D(d) * H_R = H_R * G(d)
```

在2-tag PoC中，显式reference为
`D_ref = diag(-1, 1)`。两个不同的特征值可以区分
两条信道方向。原始Efficient解码器没有直接调用特征值分解，而是固定
一组归一化条件，用闭式公式选取一个等价的信道矩阵。

这里最容易被误解、也最关键的一点是：我们不需要唯一恢复真实的
`H_R`。对任意可逆对角矩阵`C`，`C * H_R`都是等价解，因为`C`
与所有对角tag状态矩阵可交换。这个不确定性会在解码时完全抵消：

```text
(C * H_R) * G(d) * inv(C * H_R)
    = C * D(d) * inv(C)
    = D(d)
```

因此，物理信道可以有无穷多个等价表示，但tag的对角状态以及对应bits
仍然可以恢复。成立条件包括：

- `H_R`可逆且条件数不能过差；
- reference states能够区分各个tag维度；
- 对`K`个tag维度，baseline与显式reference组成的状态矩阵必须满秩
  `K`；
- reference和data期间信道近似不变。

需要特别注意：单个reference operator“满秩”本身并不够。例如单位矩阵
虽然满秩，却因为特征值重复而不能暴露信道方向；真正关键的是reference
签名具有足够的可辨识性。packet-level HT实现把同一个原理推广为联合
加权最小二乘的basis-operator估计，再使用码本ML完成判决。

运行公开测试套件：

```matlab
addpath tests
reports = run_all_tests('Full', false); % 快速测试
reports = run_all_tests('Full', true);  % 扩展无噪声验证
```

### 仿真结构

`M x K x N`分别表示WiFi发送天线/stream数、tag天线数和接收天线数。
本代码比较：

- **2x2x2**：2个WiFi发送stream、2根tag天线、2根接收天线；
- **2x4x4**：2个WiFi发送stream、4根tag天线、4根接收天线。

在Low-BER比较中，两种架构每个packet均发送256个tag bits，占用256个
HT-Data OFDM symbols。2x2x2使用128个2-bit codewords；2x4x4使用64个
4-bit recursive-STC codewords。仿真不增加tag FEC、不重复data bits、不增加
每bit反射能量，也不筛选有利信道。

### Low-BER与High-Throughput模式

接收端遵循论文式(16)：

- **LowBER (`T=1`)**：联合相邻coded symbols并进行recursive space-time decoding，
  每个OFDM symbol承载1个tag bit。
- **HighThroughput (`T=0`)**：每个tag time slot独立判决。原型中一个tag state保持
  两个4微秒HT OFDM symbols，因此一个tag slot为8微秒。2-tag slot承载2 bit；
  4-tag slot承载4 bit。

对于论文Figure 4中明确给出的2-tag映射，输入bits `[a b]`映射为

```text
[ exp(j*pi*(a+b)),  exp(j*pi*a) ]
```

对于4根tag天线，代码把同一个2-tag映射分别应用到两组天线对上。这是一个
4-bit到4个tag状态的双射pairwise extension；论文展示了4-tag throughput结果，
但没有单独写出4-tag high-throughput映射矩阵。

8微秒tag slot对应的理想raw tag rate为：

| 模式 | 2x2x2 | 2x4x4 |
|---|---:|---:|
| HighThroughput | 250 kbps | 500 kbps |

作为参考，1-tag速率约为125 kbps。High-Throughput仿真中，222和244均占用
256个HT data symbols，也就是128个tag slots，分别承载256和512个tag bits。
实际net goodput会另外计入reference overhead和误码。

### Reference设计与信道估计

HT-LTF期间tag使用全一状态。常规WiFi信道估计和均衡因此提供baseline operator：

```text
G(1) = I
```

对于`K`根tag天线，只需额外发送`K-1`种状态，并满足

```text
rank([1, d_1, ..., d_{K-1}]) = K
```

三种评估配置为：

| 配置 | 222显式reference symbols | 244显式reference symbols |
|---|---:|---:|
| Minimal | 1 | 3 |
| Default（推荐） | 2 | 6 |
| Robust | 4 | 12 |

相同状态的重复观测通过带可靠度权重的联合最小二乘合并。一个packet只估计一次
reference block，后续大量codewords共享该估计，因此reference开销可以摊薄。

### 为什么必须做antenna-domain对齐

802.11n在发射前会对spatial streams进行cyclic shift和spatial mapping。tag实际
调制的是物理天线域波形，而标准接收机最初输出的是均衡后的spatial-stream域
symbol。若直接混合两种坐标系，VMscatter信道估计将不一致。

`802.11nHT/`中的helper会提取完成cyclic shift/spatial mapping后的HT-Data
子载波，并在接收端对equalized streams执行相同坐标变换。之后，channel
estimation和ML解码统一在antenna domain进行。

对于每个候选tag codeword，解码器会跨全部52个HT20 data subcarriers和全部
coded OFDM symbols累计带可靠度权重的欧氏距离。报告零错误点时使用95%置信
上界，而不是声称真实BER严格等于零。

### 完整仿真结论

在固定随机种子、2--10 dB共9个SNR点的完整仿真中：

- 三种reference配置均有7/9个点满足244 BER低于222；
- Minimal和Default连续5个SNR点的244 BER 95%置信区间上界低于222下界，
  通过预设严格标准；
- Robust也呈现7/9总体趋势，但只有连续2个置信区间严格分离点，因此没有通过
  更严格的连续显著性标准。

严谨结论是：仿真总体支持244具有更好的系统级可靠性，但不声称所有SNR点和
所有reference配置下244都统计显著优于222。

Error rate使用小数表示：`1.0=100%`，`0.01=1%`，`0.0025=0.25%`。

### 仓库结构

```text
Proof-of-Concept_Simulation/  简化原理解码仿真
802.11nHT/                    最终packet-level HT仿真
tests/                        公开回归测试
Circuit/                      VMscatter硬件设计文件
run_quick_demo.m              快速安装/数据流检查
run_full_evaluation.m         完整reference-profile评估
run_high_throughput_evaluation.m  论文T=0 throughput评估
```

### 许可证

本代码采用 MIT License 发布，详见 [LICENSE](LICENSE)。

### 引用

```bibtex
@inproceedings {vmscatter,
	author = {Xin Liu and Zicheng Chi and Wei Wang and Yao Yao and Ting Zhu},
	title = {{VMscatter}: A Versatile {MIMO} Backscatter },
	booktitle = {17th USENIX Symposium on Networked Systems Design and Implementation (NSDI 20)},
	year = {2020},
	isbn = {978-1-939133-13-7},
	address = {Santa Clara, CA},
	pages = {895--909},
	url = {https://www.usenix.org/conference/nsdi20/presentation/liu-xin},
	publisher = {USENIX Association},
	month = feb
}
```
