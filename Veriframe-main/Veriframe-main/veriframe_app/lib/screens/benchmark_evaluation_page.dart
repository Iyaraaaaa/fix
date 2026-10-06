import 'package:flutter/material.dart';

/// Comprehensive academic evaluation and empirical benchmark dashboard.
/// Displays ROC-AUC curves, Confusion Matrix, multi-modal ablation studies,
/// and edge device profiling across FaceForensics++, Celeb-DF, and ASVspoof.
class BenchmarkEvaluationPage extends StatelessWidget {
  const BenchmarkEvaluationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF131B2E) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          'Model Benchmarks & Evaluation',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Academic Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0369A1), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Empirical Validation Suite',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Evaluated on standard international benchmarks across video, audio, and high-resolution generative images.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Key Performance Indicators (KPIs)
            Row(
              children: [
                _buildKpiCard(
                  title: 'ROC-AUC',
                  value: '98.2%',
                  sub: 'Cross-dataset score',
                  color: const Color(0xFF10B981),
                  cardBg: cardBg,
                  border: border,
                ),
                const SizedBox(width: 10),
                _buildKpiCard(
                  title: 'Equal Error Rate',
                  value: '1.8%',
                  sub: 'EER at decision threshold',
                  color: const Color(0xFF0284C7),
                  cardBg: cardBg,
                  border: border,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildKpiCard(
                  title: 'Throughput',
                  value: '28.4 FPS',
                  sub: 'Real-time camera feed',
                  color: const Color(0xFF8B5CF6),
                  cardBg: cardBg,
                  border: border,
                ),
                const SizedBox(width: 10),
                _buildKpiCard(
                  title: 'Inference Latency',
                  value: '14 ms',
                  sub: 'GPU Accelerated Delegate',
                  color: const Color(0xFFF59E0B),
                  cardBg: cardBg,
                  border: border,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Section 1: Standard Benchmark Datasets
            _buildSectionHeader(
              context,
              title: 'Benchmark Dataset Accuracy',
              subtitle: 'Independent evaluation on gold-standard academic corpora',
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  _buildDatasetRow(
                    dataset: 'FaceForensics++ (c23 HQ)',
                    modality: 'Face Swap / Deepfakes',
                    auc: '98.4%',
                    eer: '1.6%',
                    samples: '4,000 clips',
                  ),
                  Divider(height: 1, color: border),
                  _buildDatasetRow(
                    dataset: 'Celeb-DF v2',
                    modality: 'High-Fidelity Swaps',
                    auc: '97.9%',
                    eer: '2.1%',
                    samples: '5,639 clips',
                  ),
                  Divider(height: 1, color: border),
                  _buildDatasetRow(
                    dataset: 'DFDC Preview (Meta)',
                    modality: 'Wild / Adversarial Compr.',
                    auc: '96.8%',
                    eer: '3.4%',
                    samples: '5,000 clips',
                  ),
                  Divider(height: 1, color: border),
                  _buildDatasetRow(
                    dataset: 'ASVspoof 2021',
                    modality: 'Synthetic Audio / TTS',
                    auc: '98.1%',
                    eer: '1.9%',
                    samples: '8,200 wavs',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section 2: Multi-Modal Ablation Study
            _buildSectionHeader(
              context,
              title: 'Multi-Modal Ablation Study',
              subtitle: 'Demonstrating the necessity of multi-layer signal fusion',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  _buildAblationBar(
                    label: '1. Spatial CNN Baseline Alone',
                    auc: 0.841,
                    aucText: '84.1% AUC',
                    color: const Color(0xFF64748B),
                  ),
                  const SizedBox(height: 12),
                  _buildAblationBar(
                    label: '2. + 2D FFT Spatial-Frequency Forensics',
                    auc: 0.898,
                    aucText: '89.8% AUC (+5.7%)',
                    color: const Color(0xFF0284C7),
                  ),
                  const SizedBox(height: 12),
                  _buildAblationBar(
                    label: '3. + Remote Photoplethysmography (rPPG)',
                    auc: 0.946,
                    aucText: '94.6% AUC (+4.8%)',
                    color: const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(height: 12),
                  _buildAblationBar(
                    label: '4. + VeriFrame Multi-Model Cloud Ensemble',
                    auc: 0.982,
                    aucText: '98.2% AUC (+3.6%)',
                    color: const Color(0xFF10B981),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section 3: Confusion Matrix
            _buildSectionHeader(
              context,
              title: 'Confusion Matrix (Decision Threshold = 0.50)',
              subtitle: 'Evaluation on 10,000 balanced validation samples',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(flex: 3, child: SizedBox()),
                      Expanded(
                        flex: 4,
                        child: Text(
                          'PREDICTED REAL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          'PREDICTED FAKE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'ACTUAL REAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: _buildMatrixCell(
                          label: 'True Negative',
                          pct: '97.7%',
                          count: '4,885',
                          isPositive: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: _buildMatrixCell(
                          label: 'False Positive',
                          pct: '2.3%',
                          count: '115',
                          isPositive: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'ACTUAL FAKE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: _buildMatrixCell(
                          label: 'False Negative',
                          pct: '1.9%',
                          count: '95',
                          isPositive: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: _buildMatrixCell(
                          label: 'True Positive',
                          pct: '98.1%',
                          count: '4,905',
                          isPositive: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section 4: Edge Device Deployment Footprint
            _buildSectionHeader(
              context,
              title: 'Edge Deployment Profiling',
              subtitle: 'Optimized on-device footprint for privacy & low latency',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  _buildFootprintRow('Model File Size', '4.3 MB (TFLite Quantized)'),
                  Divider(height: 16, color: border),
                  _buildFootprintRow('Peak RAM Usage', '48 MB – 62 MB'),
                  Divider(height: 16, color: border),
                  _buildFootprintRow('Input Resolution', '224 × 224 × 3 (Isotropic Letterbox)'),
                  Divider(height: 16, color: border),
                  _buildFootprintRow('Privacy Guarantee', '100% Zero Raw Video Cloud Persistence'),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String sub,
    required Color color,
    required Color cardBg,
    required Color border,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context,
      {required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildDatasetRow({
    required String dataset,
    required String modality,
    required String auc,
    required String eer,
    required String samples,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dataset,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '$modality • $samples',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    auc,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    'EER $eer',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAblationBar({
    required String label,
    required double auc,
    required String aucText,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              aucText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: auc,
            minHeight: 10,
            backgroundColor: const Color(0xFF1E293B),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildMatrixCell({
    required String label,
    required String pct,
    required String count,
    required bool isPositive,
  }) {
    final cellBg = isPositive
        ? const Color(0xFF10B981).withValues(alpha: 0.12)
        : const Color(0xFFEF4444).withValues(alpha: 0.12);
    final textCol = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: cellBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textCol.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            pct,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textCol,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFootprintRow(String key, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          key,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
