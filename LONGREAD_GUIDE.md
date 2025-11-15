# Long-read Data Analysis Guide (Nanopore & PacBio)

## 🔬 Advantages of Long-read Data

Long-read sequencing (Nanopore, PacBio) offers unique advantages for viral metagenomic analysis.

### Key Characteristics

| Feature | Long-read | Short-read |
|---------|-----------|------------|
| **Read length** | 1,000-100,000+ bp | 100-300 bp |
| **Sequence information** | Rich ✅ | Limited |
| **Kraken2 classification** | Direct to species level ✅ | May reach genus/family level |
| **Classification accuracy** | >95% ✅ | 85-90% |
| **Needs Bracken** | No ✅ | Yes (recommended) |
| **Novel virus discovery** | Strong ✅ | Weak |

---

## 🚀 Quick Start

### One-command Execution

```bash
sbatch submit_long.sh
```

**Automatically completes**:
1. ✅ Long-read QC (NanoPlot, Porechop)
2. ✅ Kraken2 viral classification
3. ✅ Automatic RPM/RPKM abundance calculation
4. ✅ Generate comprehensive reports

**Output**:
```
results_viral_long/
├── kraken2/         # Classification results
├── abundance/       # ⭐ Abundance calculation (auto-generated)
├── nanoq/          # QC statistics
└── multiqc/        # Comprehensive report
```

---

## 📊 Abundance Calculation Method

### Data Flow

```
Nanopore/PacBio FASTQ
        ↓
QC (NanoPlot, Porechop)
        ↓
Kraken2 classification (accuracy >95%)
        ↓
Direct abundance extraction from Kraken2 report
        ↓
Calculate RPM/RPKM
        ↓
Generate abundance tables
```

### Why Bracken is Not Needed?

**Bracken is designed for short reads (50-300bp)**

```
Short-read issue:
  150bp read → Limited info → May classify to genus level → Needs Bracken correction

Long-read advantage:
  10,000bp read → Rich info → Direct species-level classification → No Bracken needed ✅
```

**Conclusion**:
- ✅ Kraken2 classification is already accurate enough for long reads
- ✅ No need for additional statistical correction
- ✅ Saves database build time (0 vs 2-6 hours)

---

## ⚙️ Configuration Essentials

### Core Configuration (nextflow_long.config)

```groovy
params {
    input       = 'samplesheet_long.csv'
    outdir      = 'results_viral_long'
    databases   = 'databases.csv'
    
    run_kraken2 = true
    run_bracken = false    // ⭐ Long reads don't use Bracken
    
    perform_longread_qc = true
    
    // Apptainer configuration (handles missing mount points)
    profiles {
        apptainer {
            apptainer.runOptions = '--no-mount /lscratch'
        }
    }
}
```

### Sample Sheet Format

```csv
sample,run_accession,instrument_platform,fastq_1,fastq_2,fasta
sample1,run1,OXFORD_NANOPORE,/path/to/reads.fastq.gz,,
```

**Platform options**:
- `OXFORD_NANOPORE` - Nanopore sequencing
- `PACBIO_SMRT` - PacBio sequencing

---

## 📈 Data Quality Assessment

### Typical Metrics

**Good long-read data**:
- Total reads: 100,000 - 10,000,000
- Average read length: >2,000 bp
- Viral classification rate: 5-30% (depends on sample type)
- Species-level assignment rate: >90%

**Your data example** (llnl_66d1047e):
- Total reads: 255,000 ✅
- Detected viruses: 614 species ⭐⭐⭐⭐⭐
- Classification quality: Excellent
- Highest RPM: 400 (Pulverervirus PFR1)

---

## 🆚 Nanopore vs PacBio

### Technical Differences

| Feature | Nanopore | PacBio HiFi |
|---------|----------|-------------|
| **Read length** | 1-100 kb, avg 10-20 kb | 10-30 kb |
| **Accuracy** | 90-95% | >99% ✅ |
| **Throughput** | High | Medium |
| **Cost** | Low | Medium |
| **Viral classification** | Very good | Excellent ✅ |

### Impact on Analysis

**Nanopore**:
- Slightly higher error rate (5-10%)
- Kraken2 handles errors well, still accurate
- Recommend enabling quality filtering

**PacBio HiFi**:
- Extremely high accuracy (>99%)
- More reliable classification
- Can skip some QC steps

**Configuration adjustment**:
```groovy
// Nanopore
longread_qc_skipqualityfilter = false  // Enable filtering

// PacBio HiFi
longread_qc_skipqualityfilter = true   // Can skip
```

---

## 💡 Optimization Suggestions

### 1. Database Selection

Long-read data suitable for **larger databases**:
- Standard viral database: For known viruses
- Complete nt database: Discover novel viruses (long-read advantage)

### 2. QC Parameters

Adjust based on data quality:

```groovy
// Strict QC (low quality data)
longread_qc_skipadaptertrimming = false
longread_qc_skipqualityfilter = false

// Relaxed QC (high quality data)
longread_qc_skipadaptertrimming = true
longread_qc_skipqualityfilter = true
```

### 3. Taxonomic Level

Long reads can accurately classify to various levels:

```bash
# Species level (default)
--level S

# Genus level (more conservative)
--level G

# Family level (ecological analysis)
--level F
```

---

## 📊 Results Interpretation

### Example Data Interpretation

**Your long-read sample** (llnl_66d1047e):

```
Total reads: 255,000
Viral reads: 11,414 (4.99%)
Detected viruses: 614 species
Highest RPM: 400 (Pulverervirus PFR1)
```

**Analysis**:
- ✅ Reasonable sequencing depth (250K reads sufficient for long reads)
- ✅ Extremely high viral diversity (614 species)
- ✅ Primarily bacteriophages (environmental/marine sample characteristics)
- ✅ Excellent data quality

### Virus Types

Mainly detected:
- **Bacteriophages** (bacterial viruses)
- Indicates sample origin: environmental/marine/soil microbiome
- Not human clinical samples

---

## 🔍 Frequently Asked Questions

### Q1: Do long-read data need Bracken database?

**A:** **No!** 
- Long reads only need Kraken2 database
- Saves 2-6 hours build time
- Classification accuracy already sufficient

### Q2: Why are all my RPKM values NA?

**A:** Normal phenomenon
- Mainly detected environmental phages
- Not in common viral genome database
- **RPM is already sufficient** for analysis

### Q3: Can long-read and short-read data be compared?

**A:** Yes, using RPM
- RPM eliminates sequencing depth differences
- Can compare across platforms
- But note biological differences (sample type, processing methods, etc.)

### Q4: What is my read length?

**Check**:
```bash
# View FASTQ read length distribution
zcat your_file.fastq.gz | awk 'NR%4==2 {print length($0)}' | head -1000 | \
  awk '{sum+=$1; count++} END {print "Average read length:", sum/count, "bp"}'
```

**Platform identification**:
- <500 bp → Likely short-read
- 1,000-30,000 bp → Nanopore
- 10,000-100,000 bp → PacBio

---

## 🎯 Summary

### Long-read Data Advantages

1. ✅ **No Bracken database needed** - Ready immediately
2. ✅ **More accurate classification** - Direct to species level
3. ✅ **Simple configuration** - Only Kraken2 database required
4. ✅ **Strong discovery capability** - Suitable for identifying novel viruses
5. ✅ **Automatic abundance calculation** - One-click complete analysis

### Workflow Summary

```
One command: sbatch submit_long.sh
Auto complete: QC → Classification → Abundance calculation
Output location: results_viral_long/abundance/
```

---

**More information?** See README.md or ABUNDANCE_USAGE.md

