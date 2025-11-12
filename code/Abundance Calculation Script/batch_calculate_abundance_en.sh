#!/bin/bash
# Batch calculate viral abundance for all samples (RPM & RPKM)

# Usage instructions
usage() {
    cat << EOF
Usage: bash batch_calculate_abundance_en.sh <results_dir> [output_dir]

Parameters:
    results_dir   TaxProfiler output results directory (e.g. results_viral_short)
    output_dir    Abundance results output directory (default: results_dir/abundance)

Example:
    bash batch_calculate_abundance_en.sh results_viral_short
    bash batch_calculate_abundance_en.sh results_viral_long abundance_output

Output:
    One abundance table file per sample: <sample>_abundance.tsv
    Summary file: all_samples_abundance_summary.tsv

EOF
    exit 1
}

# Check parameters
if [ $# -lt 1 ]; then
    usage
fi

RESULTS_DIR=$1
OUTPUT_DIR=${2:-"${RESULTS_DIR}/abundance"}

# Check if results directory exists
if [ ! -d "$RESULTS_DIR" ]; then
    echo "❌ Error: Results directory does not exist: $RESULTS_DIR"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo "🧬 Batch Calculate Viral Abundance"
echo "=========================================="
echo "Results directory: $RESULTS_DIR"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Find all Bracken output files
BRACKEN_DIR="${RESULTS_DIR}/bracken"
KRAKEN_DIR="${RESULTS_DIR}/kraken2"

if [ ! -d "$KRAKEN_DIR" ]; then
    echo "❌ Error: Kraken2 results directory not found: $KRAKEN_DIR"
    exit 1
fi

# Check if Bracken directory exists and is not empty
if [ ! -d "$BRACKEN_DIR" ] || [ -z "$(find "$BRACKEN_DIR" -name "*.tsv" 2>/dev/null)" ]; then
    echo "⚠️  Warning: Bracken results not found"
    echo ""
    echo "   Bracken may not have run or database is misconfigured."
    echo "   Will calculate abundance directly from Kraken2 results (similar to long-read method)."
    echo ""
    echo "   💡 This will still give you valid abundance values, just without Bracken statistical correction."
    echo ""
    
    # Fallback to long-read script
    if [ -f "batch_calculate_abundance_longread.sh" ]; then
        echo "   Using alternative method: batch_calculate_abundance_longread.sh"
        bash batch_calculate_abundance_longread.sh "$RESULTS_DIR" "$OUTPUT_DIR"
        exit $?
    else
        echo "❌ Error: batch_calculate_abundance_longread.sh not found either"
        echo "   Please ensure abundance calculation scripts are uploaded to the server"
        exit 1
    fi
fi

echo "✅ Found Bracken results, will use standard method for abundance calculation"

# Counters
processed=0
failed=0

# Iterate through all Bracken output files
for bracken_file in ${BRACKEN_DIR}/*_bracken*.tsv; do
    if [ ! -f "$bracken_file" ]; then
        echo "⚠️  Bracken output files not found"
        continue
    fi
    
    # Extract sample name
    sample=$(basename "$bracken_file" | sed 's/_bracken.*\.tsv//')
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Processing sample: $sample"
    
    # Find corresponding Kraken2 report file
    kraken_file="${KRAKEN_DIR}/${sample}.report"
    
    # Try other possible naming formats
    if [ ! -f "$kraken_file" ]; then
        kraken_file="${KRAKEN_DIR}/${sample}_kraken2.report"
    fi
    
    if [ ! -f "$kraken_file" ]; then
        # Try using wildcard to find
        kraken_file=$(find "$KRAKEN_DIR" -name "${sample}*.report" | head -n 1)
    fi
    
    if [ ! -f "$kraken_file" ]; then
        echo "❌ Error: Kraken2 report file not found: $kraken_file"
        ((failed++))
        continue
    fi
    
    # Output file
    output_file="${OUTPUT_DIR}/${sample}_abundance.tsv"
    
    # Run calculation script
    echo "   Bracken: $bracken_file"
    echo "   Kraken:  $kraken_file"
    echo "   Output:  $output_file"
    
    python3 calculate_abundance_en.py \
        --bracken "$bracken_file" \
        --kraken "$kraken_file" \
        --output "$output_file"
    
    if [ $? -eq 0 ]; then
        echo "✅ Complete: $sample"
        ((processed++))
    else
        echo "❌ Failed: $sample"
        ((failed++))
    fi
    
    echo ""
done

echo "=========================================="
echo "📈 Processing Complete"
echo "=========================================="
echo "Successfully processed: $processed samples"
echo "Failed: $failed samples"
echo "Output directory: $OUTPUT_DIR"

# If samples were successfully processed, generate summary table
if [ $processed -gt 0 ]; then
    echo ""
    echo "📋 Generating summary table..."
    
    summary_file="${OUTPUT_DIR}/all_samples_abundance_summary.tsv"
    
    # Create header
    echo -e "Sample\tSpecies\tTaxonomy_ID\tAssigned_Reads\tFraction\tRPM\tGenome_Length_bp\tRPKM" > "$summary_file"
    
    # Merge all sample results
    for abundance_file in ${OUTPUT_DIR}/*_abundance.tsv; do
        if [ -f "$abundance_file" ]; then
            sample=$(basename "$abundance_file" | sed 's/_abundance\.tsv//')
            # Skip header, add sample column
            tail -n +2 "$abundance_file" | awk -v s="$sample" '{print s"\t"$0}' >> "$summary_file"
        fi
    done
    
    echo "✅ Summary table generated: $summary_file"
    
    # Generate TOP virus summary
    top_summary="${OUTPUT_DIR}/top_viruses_summary.tsv"
    echo ""
    echo "📊 Generating TOP virus summary (RPM >= 10)..."
    
    # Use awk to extract viruses with RPM >= 10 and sort
    awk -F'\t' 'NR==1 || $6 >= 10' "$summary_file" | \
        sort -t$'\t' -k6 -nr > "$top_summary"
    
    echo "✅ TOP virus summary: $top_summary"
fi

echo ""
echo "🎉 All tasks complete!"

