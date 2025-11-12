# Viral Abundance Calculation User Guide

## 🎯 Overview

This workflow **automatically calculates** standardized viral abundance metrics (RPM and RPKM) after TaxProfiler completion, requiring no manual intervention.

---

## 🚀 Automatic Calculation (Recommended)

### Usage

```bash
# Short-read data
sbatch submit_short.sh

# Long-read data
sbatch submit_long.sh
```

**Automatically generates**:
```
results_viral_*/abundance/
├── sample_abundance.tsv                  # Individual sample detailed table
├── all_samples_abundance_summary.tsv     # All samples summary
└── top_viruses_summary.tsv               # High abundance viruses (RPM≥10)
```

---

## 📊 Output File Description

### 1. Individual Sample Abundance Table (sample_abundance.tsv)

One file per sample containing all detected viruses and their abundances.

**Example**:
```tsv
Species                    Taxonomy_ID  Assigned_Reads  Fraction  RPM      Genome_Length_bp  RPKM
Shigella phage SfIV       1407493      607            0.0001    100.0    NA                NA
Gihfavirus pelohabitans   2844652      392            0.0001    64.58    NA                NA
Kinglevirus lutadaptatum  2845070      284            0.0001    46.79    NA                NA
```

### 2. Summary Table (all_samples_abundance_summary.tsv)

Complete data from all samples with an additional `Sample` column:

```tsv
Sample    Species                 Taxonomy_ID  Assigned_Reads  Fraction  RPM      ...
sample1   Shigella phage SfIV    1407493      607            0.0001    100.0    ...
sample2   Other virus            12345        450            0.0002    150.0    ...
```

### 3. High Abundance Viruses (top_viruses_summary.tsv)

Contains only viruses with **RPM ≥ 10**, sorted by RPM in descending order.

---

## 🧮 Abundance Metrics Explained

### RPM (Reads Per Million) ⭐ Primary Metric

**Definition**: Number of reads assigned to the virus per million total reads

**Formula**:
```
RPM = (viral reads / total reads) × 1,000,000
```

**Example**:
```
Sample A: total reads = 10M, virus X = 500 reads
RPM = (500 / 10,000,000) × 1,000,000 = 50

Sample B: total reads = 5M, virus X = 250 reads  
RPM = (250 / 5,000,000) × 1,000,000 = 50
```

Despite different absolute read counts, identical RPM → consistent viral abundance

**Applications**:
- ✅ Compare same virus across samples
- ✅ Eliminate sequencing depth differences
- ✅ Most commonly used normalization metric

### RPKM (Reads Per Kilobase Million)

**Definition**: Accounts for both genome length and sequencing depth

**Formula**:
```
RPKM = (viral reads) / (genome length kb × total reads million)
```

**Example**:
```
Virus X (30 kb genome): 3000 reads, total 10M reads
RPKM = 3000 / (30 × 10) = 10

Virus Y (150 kb genome): 3000 reads, total 10M reads
RPKM = 3000 / (150 × 10) = 2
```

**Interpretation**: Despite same read count, virus X has higher actual viral load

**Applications**:
- ✅ Compare viral loads between different viruses
- ✅ Eliminate genome size effects

**Limitations**:
- ⚠️ Requires known genome length
- ⚠️ Unknown viruses show "NA"

---

## 🔍 Data Sources

### Short-read Data

```
Kraken2 classification
    ↓
Bracken statistical correction (if available) ← More accurate
    ↓
Abundance calculation script
    ↓
RPM/RPKM values
```

**If Bracken unavailable**:
```
Kraken2 classification
    ↓
Direct abundance extraction (fallback)
    ↓
RPM/RPKM values (still valid)
```

### Long-read Data

```
Kraken2 classification (accuracy >95%)
    ↓
Direct abundance extraction
    ↓
RPM/RPKM values
```

**No Bracken used** (not needed)

---

## 💡 Usage Scenarios

### Scenario 1: Compare Same Virus Across Samples

**Recommended: Use RPM**

```bash
# Extract RPM for specific virus
grep "SARS-CoV-2" results_viral_short/abundance/all_samples_abundance_summary.tsv | \
  awk '{print $1"\t"$6}' | sort -k2,2nr
```

### Scenario 2: Identify Major Viruses in Sample

**View TOP virus list**

```bash
# View high abundance viruses
cat results_viral_short/abundance/top_viruses_summary.tsv

# Or TOP 20
head -21 results_viral_short/abundance/all_samples_abundance_summary.tsv
```

### Scenario 3: Compare Relative Abundance of Different Viruses

**Use RPKM (if genome length available)**

```bash
# Filter out RPKM = NA, sort by RPKM
awk -F'\t' '$8 != "NA"' results_viral_short/abundance/all_samples_abundance_summary.tsv | \
  sort -t$'\t' -k8,8nr
```

---

## 🎓 Data Interpretation Guide

### Reasonable Abundance Ranges

**Human clinical samples**:
- High load viruses: RPM > 10,000
- Medium load: RPM 100-10,000
- Low load/latent: RPM < 100

**Environmental/metagenomic samples**:
- Major viruses: RPM 50-500
- Minor viruses: RPM 10-50
- Rare viruses: RPM < 10

### About RPKM Showing NA

**Common in**:
- Environmental phages
- Newly discovered viruses
- Incomplete viruses in database

**Doesn't affect analysis**:
- RPM is sufficient for most studies
- Known human viruses usually have RPKM values

---

## 🔧 Manual Operations (Optional)

### Regenerate TOP Virus List

To change threshold:

```bash
# RPM ≥ 5
awk -F'\t' 'NR==1 || $6 >= 5' results_viral_short/abundance/all_samples_abundance_summary.tsv | \
  sort -t$'\t' -k6,6nr > top_viruses_rpm5.tsv

# RPM ≥ 20
awk -F'\t' 'NR==1 || $6 >= 20' results_viral_short/abundance/all_samples_abundance_summary.tsv | \
  sort -t$'\t' -k6,6nr > top_viruses_rpm20.tsv
```

### Add Custom Viral Genome Lengths

If your viruses show RPKM as NA, you can add genome lengths:

```bash
# Create custom genome length file
cat > my_viral_genomes.tsv << EOF
My_virus_species_1	28000
My_virus_species_2	35000
EOF

# Recalculate (affects RPKM only)
python3 calculate_abundance_longread.py \
  --kraken results/kraken2/sample.report \
  --genome-db my_viral_genomes.tsv \
  --output sample_abundance_updated.tsv
```

---

## 📈 Data Visualization

### Basic Statistics

```bash
# Number of viruses per sample
awk -F'\t' 'NR>1 {count[$1]++} END {for (s in count) print s"\t"count[s]}' \
  results_viral_short/abundance/all_samples_abundance_summary.tsv

# Most common viruses across samples
awk -F'\t' 'NR>1 {rpm[$2]+=$6} END {for (v in rpm) print v"\t"rpm[v]}' \
  results_viral_short/abundance/all_samples_abundance_summary.tsv | \
  sort -t$'\t' -k2,2nr | head -20
```

### R Visualization Example

```r
library(ggplot2)
library(dplyr)

# Load data
data <- read.table("results_viral_short/abundance/all_samples_abundance_summary.tsv", 
                   header=TRUE, sep="\t", quote="")

# TOP 20 viruses bar plot
top20 <- data %>% group_by(Species) %>% 
  summarise(total_rpm = sum(RPM)) %>% 
  arrange(desc(total_rpm)) %>% head(20)

ggplot(top20, aes(x=reorder(Species, total_rpm), y=total_rpm)) +
  geom_bar(stat="identity", fill="steelblue") +
  coord_flip() +
  labs(title="Top 20 Viruses by Total RPM", x="Species", y="Total RPM") +
  theme_minimal()
```

### Python Visualization Example

```python
import pandas as pd
import matplotlib.pyplot as plt

# Load data
df = pd.read_csv("results_viral_short/abundance/all_samples_abundance_summary.tsv", sep="\t")

# TOP 20 viruses
top20 = df.nlargest(20, 'RPM')

plt.figure(figsize=(10, 8))
plt.barh(top20['Species'], top20['RPM'])
plt.xlabel('RPM')
plt.title('Top 20 Viruses by RPM')
plt.tight_layout()
plt.savefig('top_viruses.png', dpi=300)
```

---

## 🎓 Best Practices

### RPM vs RPKM Selection

**Use RPM when**:
- Comparing the same virus across samples
- Sequencing depth varies greatly
- Viral genome length unknown

**Use RPKM when**:
- Comparing relative loads between viruses
- Need to eliminate genome size effects
- Performing quantitative analysis and statistical tests

### Data Filtering Recommendations

**Environmental samples**:
- Filter viruses with RPM < 5 (likely noise)
- Focus on viruses with RPM > 10 (meaningful abundance)

**Clinical samples**:
- Filter RPM < 10
- Focus on viruses with RPM > 100

---

**Need more help?** See README_EN.md or related guide documentation.

