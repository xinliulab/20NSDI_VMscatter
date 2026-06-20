# VMscatter: A Versatile MIMO Backscatter

[中文说明](README.zh-CN.md)

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

\[
G(\mathbf d)=H_R^{-1}D(\mathbf d)H_R,
\qquad
D(\mathbf d)=\operatorname{diag}(d_1,\ldots,d_K).
\]

This is not the generic equation \(Y=AXA\). It is a similarity transform,
equivalently the homogeneous Sylvester/intertwining equation

\[
D(\mathbf d)H_R=H_RG(\mathbf d).
\]

For the 2-tag PoC, the explicit reference is
\(D_{\rm ref}=\operatorname{diag}(-1,1)\). Its distinct eigenvalues identify
the two channel directions. The original Efficient decoder solves this
relation in closed form by fixing one representative of the otherwise
non-unique channel matrix.

The physical \(H_R\) need not be recovered uniquely. If \(C\) is any
invertible diagonal matrix, \(CH_R\) is an equally valid solution because
\(C\) commutes with every diagonal tag matrix. This ambiguity cancels during
decoding:

\[
(CH_R)G(\mathbf d)(CH_R)^{-1}
=CD(\mathbf d)C^{-1}
=D(\mathbf d).
\]

Thus the channel can have infinitely many equivalent representations while
the diagonal tag state, and therefore the transmitted bits, remains
recoverable. The main conditions are:

- \(H_R\) is invertible and reasonably conditioned;
- the reference states distinguish the tag dimensions;
- for \(K\) tag dimensions, the baseline plus explicit-reference state
  matrix has rank \(K\);
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

\[
\left[e^{j\pi(a+b)}, e^{j\pi a}\right].
\]

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
run_high_throughput_evaluation.m  paper T=0 throughput evaluation
```

## License

This code is released under the MIT License. See [LICENSE](LICENSE).

## Citation

```bibtex
@inproceedings{liu2020vmscatter,
  title     = {VMscatter: A Versatile MIMO Backscatter},
  author    = {Liu, Xin and Chi, Zicheng and Wang, Wei and Yao, Yao and Zhu, Ting},
  booktitle = {17th USENIX Symposium on Networked Systems Design and Implementation (NSDI 20)},
  year      = {2020}
}
```
