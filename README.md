# Pipeline - wutest

## Pipeline summary

The 'wutest' pipeline is designed as a test pipeline for the Bioinformatics Pipeline Developer Project. This pipeline adheres to the structure of Nextflow's nf-core. It operates by taking inputs in the form of a samplesheet CSV file, BAM files, and a BED file. The primary tasks it performs include:
1. Generating read counts for the specified regions outlined in the provided BED file, producing output in JSON format.
2. Extracting reads within these regions and converting them into a FASTA file.

The pipeline's workflow and applied tools and scripts can be described as follows:
1. Sort and index BAM file
    - Samtools sort
    - Samtools index
2. QC for orignal BAM files
    - Samtools stats
    - Samtools flagstat
    - Samtools idxstats
3. Preprocessing BAM reads (optional)
    1. Remove duplicates
        - Picard markduplicates
    2. Filter alignments
        - Samtools view
4. QC for preprocessed BAM files
    - Samtools stats
    - Samtools flagstat
    - Samtools idxstats
5. Count reads for the BED regions
    - count_reads_from_bam.py
6. Extract reads in the BED regions
    - Bedtools intersect
    - convert_bam_to_fasta.py

## Installation

The pipeline can be directly downloaded from its Github repository: <https://github.com/huihai828/wutest>, or use Git to download the reposity with following command-line:
```bash
git clone https://github.com/huihai828/wutest.git
```
To get the pipeline executed, it is essential to have Nextflow installed alongside Docker (alternatively Singularity or Conda). Nextflow can resolve the software dependencies (container images or environments) used in the pipelines when running the pipeline for the first time with specific profile (e.g. docker, singularity, conda).

If any issues arise during the execution of the pipeline using Docker containers, you have the option to manually install the required Docker images listed as follows:
```bash
docker pull quay.io/biocontainers/samtools:1.17--h00cdaf9_0
docker pull quay.io/biocontainers/bedtools:2.31.0--hf5e1c6e_2
docker pull quay.io/biocontainers/picard:3.1.0--hdfd78af_0
docker pull quay.io/biocontainers/python:3.8.3
docker pull quay.io/biocontainers/mulled-v2-57736af1eb98c01010848572c9fec9fff6ffaafd:402e865b8f6af2f3e58c6fc8d57127ff0144b2c7-0
```

## Usage

Once you downloaded the pipeline, you can perform test run with following command-lines:
```bash
cd path-to/nf-core-wutest
nextflow run . --outdir results -profile test,docker
```
You can check the output files in folder 'path-to/nf-core-wutest/results', where 'path-to' is where the pipeline was installed. The test use the data located in 'path-to/nf-core-wutest/assets/data'.

To run the pipeline for your BAM files, firstly you need to prepare a samplesheet file in CSV format which looks like as follows:

**samplesheet.csv**:
```
sample,bam_file
sample1,/path-to/sampl1.bam
sample2,/path-to/sampl2.bam
```

### Run pipeline with docker

You can run the pipeline with Docker if you have Docker installed. The command-line is as follows:
```bash
nextflow run path-to/nf-core-nctest --input samplesheet.csv --bed_file test.bed.gz --outdir results -profile docker
```

### Run pipeline with singularity
You can run the pipeline with Singularity if you have Singularity installed. The command-line is as follows:
```bash
nextflow run path-to/nf-core-nctest --input samplesheet.csv --bed_file test.bed.gz --outdir results -profile singularity
```

It is good to set a environmental variable NXF_SINGULARITY_CACHEDIR to store and re-use the images from a central location for future pipeline runs especially when using a computing cluster. The command-line is as follows:
```bash
export NXF_SINGULARITY_CACHEDIR=path-to-singularity-images
```

### Run pipeline with Conda
You can run the pipeline with Conda if you have Conda installed. The command-line is as follows:
```bash
nextflow run path-to/nf-core-nctest --input samplesheet.csv --bed_file test.bed.gz --outdir results -profile conda
```
Note that Conda is considered as last resort by Nextflow since its poorer reproducibility than Docker/Singularity.

### Run pipeline using Gitpod
You can also quickly setup a virtual machine and test the pipeline using Gitpod using your Github account. The steps is as follows:
1. Log on your Github account, then open your Gitpod workspace with link: <https://gitpod.io/workspaces>
2. Click button 'New Workspace' to create a new Workspace with repository link: <https://github.com/huihai828/wutest/tree/master>
3. It will create a virtual machine and open a workspace window, then run test in terminal as follows:
```bash
nextflow run . --outdir results -profile test,docker
```
You will find all the output files in subfolder 'results'.

### Parameters

The pipeline wutest has following parameters:

| Parameter   | Description |
| ----------- | ----------- |
| --input  \<samplesheet.csv> | Input samplesheet file in CSV format |
| --bed_file \<BED file> | Input BED file |
| --outdir \<directory> | Specify a output directory |
| -profile \<config profile> | Specify a config profile to run the pipeline, which can be docker, singularity and conda |
| --skip_picard \<true/false> | A Boolean option, if set true the pipeline will skip removing the duplicate reads from BAM file with module PICARD_MARKDUPLICATES, default is false |
| --skip_filter \<true/false> | A Boolean option, if set true the pipeline will skip filtering the BAM file with subworkflow FILTER_BAM, default is false |
| --skip_multiqc \<true/false> | A Boolean option, if set true the pipeline will skip the module MULTIQC, default is false |
| --samtools_view_args \<args> | A string of args used by module SAMTOOLS_VIEW, the defualt is '-q 0 -f 2 -F 512' which means only extracting QC-passed reads |
| --save_reference \<true/false> | A Boolean option, if set true the pipeline will save all the intermediate output files apart from end results, default is true |

For example, following command-line will run the pipeline by skipping PICARD_MARKDUPLICATES and filtering out reads with mapping quality larger than 10.
```bash
nextflow run path-to/nf-core-nctest --input samplesheet.csv --bed_file test.bed.gz --outdir results -profile docker --skip_picard true --samtools_view_args "-q 10"
```

## Outputs

If the pipeline runs successfully, it will produce output files in predefined directories under output directory. The output directories and files for test profile are as follows:

| Directory   | Files | Description |
| ----------- | ----------- |----------- |
| bam  | sample1_T1.sorted.bam<br>sample1_T1.sorted.bam.bai<br>sample1_T1.dedupe.bam<br>sample1_T1.dedupe.bam.bai<br>sample1_T1.filtered.bam<br>sample1_T1.filtered.bam.bai<br>sample1_T1.regions.bam<br> | Bam files with suffix '.sorted.bam' are produced by subworkflow SORT_BAM<br>Bam files with suffix '.filtered.bam' are produced by subworkflow FILTER_BAM<br>Bam files with suffix '.dedupe.bam' are produced by subworkflow DEDUPE_BAM<br>Bam files with suffix '.regions.bam' are produced by subworkflow EXTRACT_BAM_READS  |
| bam_stats   | sample1_T1.original.bam.stats<br>sample1_T1.original.bam.flagstat<br>sample1_T1.original.bam.idxstats<br>sample1_T1.cleaned.bam.stats<br>sample1_T1.cleaned.bam.flagstat<br>sample1_T1.cleaned.bam.idxstats | These are QC resutls produced by subworkflow BAM_STATS_SAMTOOLS; files with infix '.original' are for input BAM files, and files with infix '.cleaned' are for preprocessed BAM files. |
| picard_metrics   | sample1_T1.dedupe.MarkDuplicates.metrics.txt | Produced by subworkflow DEDUPE_BAM; a metrics file indicating the numbers of duplicates for both single- and paired-end reads. |
| read_counts   | sample1_T1.readcounts.json | Produced by module COUNT_BAM_READS; a JSON file showing BED region information and corresponding read counts.|
| fasta   | sample1_T1.regions.fasta | Produced by subworkflow EXTRACT_BAM_READS; a FASTA file extracted from BAM file in regions defined in a BED file. |
| multiqc   | multiqc_report.html | MultiQC report HTML file which shows the QC resuls with plots. The related data and plots are in subfolders multiqc_data and multiqc_plots |
| pipeline_info   | execution_report_2023-11-20_15-55-32.html<br>execution_timeline_2023-11-20_15-55-32.html<br>pipeline_dag_2023-11-20_15-55-32.html<br>params_2023-11-20_15-56-39.json<br>execution_trace_2023-11-20_15-55-32.txt<br>software_versions.yml<br>samplesheet.valid.csv | These files showing pipeline runing information produced by Nextflow. |

## Testing

### Testing for Python scripts

The functionality of a Python script can be tested using pytest package.
I did test for script 'count_reads_from_bam.py'. The test script is 'test_count_reads_from_bam.py' in 'bin/tests', and run the test with following command-lines:
```bash
cd path-to/nf-core-nctest/bin/tests
pytest
```
It will get test data from subfolder 'test_data' and perform 5 unit tests.

### Testing pipeline using nf-test

Tool nf-test is able to test all levels of components (modules, subworkflows and whole pipeline) for a pipeline. Firstly we need to install nf-test with following command-line:
 ```bash
curl -fsSL https://code.askimed.com/install/nf-test | bash
```
For demonstration, I did following tests.

**Testing for module SAMTOOLS_VIEW**

The relevant command-lines are as follows:
 ```bash
cd path-to/nf-core-nctest
nf-test generate process modules/nf-core/samtools/view/main.nf
nf-test test tests/modules/nf-core/samtools/view/main.nf.test
```
This test will produce a reference snapshot file 'main.nf.test.snap' for repeated testing.

**Testing for subworkflow FILTER_BAM**

The relevant command-lines are as follows:
 ```bash
cd path-to/nf-core-nctest
nf-test generate workflow subworkflows/local/filter_bam.nf
nf-test test tests/subworkflows/local/filter_bam.nf.test
```
This test will produce a reference snapshot file 'filter_bam.nf.test.snap' for repeated testing.

**Testing for whole pipeline**

This test can check execution correctness and integrity of output files for whole pipeline. The relevant command-lines are as follows:
 ```bash
cd path-to/nf-core-nctest
nf-test generate pipeline main.nf
nf-test test tests/main.nf.test
``` 
