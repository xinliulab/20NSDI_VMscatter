# VMscatter: A Versatile MIMO Backscatter

[中文说明](#中文说明)

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

Generated CSV, MAT, FIG, and PNG files are written to `results/`. That
directory is created locally and is not tracked by Git.

To inspect the decoding principle without the complete HT PHY:

```matlab
cd Proof-of-Concept_Simulation
report = run_poc_simulation;
```

The public PoC entry runs 1,000 codewords by default. The extended regression
suite audits 10,000 codewords.

Run the public regression suite with:

```matlab
addpath tests
reports = run_all_tests('Full', false); % quick
reports = run_all_tests('Full', true);  % extended noiseless validation
```

## Simulation structure

VMscatter uses the notation \(M\times K\times N\):

- \(M\): WiFi transmit antennas/streams;
- \(K\): VMscatter tag antennas;
- \(N\): receiver antennas.

The release compares:

- **2x2x2**: 2 WiFi transmit streams, 2 tag antennas, 2 receive antennas;
- **2x4x4**: 2 WiFi transmit streams, 4 tag antennas, 4 receive antennas.

Both architectures carry 256 tag bits in 256 HT-Data OFDM symbols per packet:
2x2x2 uses 128 two-bit codewords, while 2x4x4 uses 64 four-bit recursive-STC
codewords. This keeps the data-symbol time and tag information bits equal.
No tag FEC, repeated data bits, favorable-channel selection, or extra
per-bit reflection energy is used.

## Reference design and channel estimation

During the HT-LTF, the tag uses the all-ones state. Conventional WiFi channel
estimation and equalization therefore provide the baseline operator

\[
G(\mathbf 1)=I.
\]

For \(K\) tag antennas, only \(K-1\) additional states are transmitted. The
design must satisfy

\[
\operatorname{rank}
\left[\mathbf 1,\mathbf d_1,\ldots,\mathbf d_{K-1}\right]=K.
\]

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
```

## Citation

```bibtex
@inproceedings{liu2020vmscatter,
  title     = {VMscatter: A Versatile MIMO Backscatter},
  author    = {Liu, Xin and Chi, Zicheng and Wang, Wei and Yao, Yao and Zhu, Ting},
  booktitle = {17th USENIX Symposium on Networked Systems Design and Implementation (NSDI 20)},
  year      = {2020}
}
```

---

## 中文说明

本仓库包含VMscatter的MATLAB原理仿真和IEEE 802.11n HT完整仿真。论文发表于
USENIX NSDI 2020，链接见README开头。

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

正式实验扫描2--10 dB，结果写入本地`results/`。原理解码仿真：

```matlab
cd Proof-of-Concept_Simulation
report = run_poc_simulation;
```

公开PoC入口默认运行1,000个codewords；扩展测试套件使用10,000个codewords。

### 222与244的公平比较

\(M\times K\times N\)分别表示WiFi发送天线/stream数、tag天线数和接收天线数。
本代码比较2x2x2与2x4x4。两种架构每个packet均发送256个tag bits，占用256个
HT-Data OFDM symbols；没有增加tag FEC、重复data bits、额外每bit能量或选择
有利信道。

LTF期间的全一tag状态提供\(G(\mathbf1)=I\) baseline。对于\(K\)根tag天线，
只需额外发送\(K-1\)种状态，并保证baseline与这些reference组成的矩阵满秩。

| 配置 | 222显式reference | 244显式reference |
|---|---:|---:|
| Minimal | 1 | 3 |
| Default（推荐） | 2 | 6 |
| Robust | 4 | 12 |

相同状态的重复观测通过带可靠度权重的联合最小二乘合并。一个packet只估计一次
reference block，后续大量codewords共享该估计，因此reference开销可以摊薄。

### 802.11n HT坐标系修复

802.11n在发射前会对spatial streams进行cyclic shift和spatial mapping。tag实际
调制的是物理天线域波形，而标准接收机最初输出的是均衡后的spatial-stream域
symbol。若直接混合两种坐标系，VMscatter信道估计将不一致。

本代码在发射端提取完成cyclic shift/spatial mapping后的HT-Data子载波，并在
接收端对equalized streams执行相同坐标变换。之后，channel estimation和ML
解码统一在antenna domain进行。ML判决跨全部52个HT20 data tones和全部编码
symbols累计带权欧氏距离。

### 完整仿真结论

在固定随机种子、2--10 dB共9个SNR点的完整仿真中，三种reference配置均有
7/9个点满足244 BER低于222。Minimal和Default连续5个点的244 BER 95%置信
区间上界低于222下界，通过预设严格标准；Robust只有连续2个显著点，因此没有
通过该严格标准。

严谨结论是：仿真总体支持244具有更好的系统级可靠性，但不声称所有SNR点和
所有reference配置下244都统计显著优于222。

Error rate使用小数表示：`1.0=100%`，`0.01=1%`，`0.0025=0.25%`。
