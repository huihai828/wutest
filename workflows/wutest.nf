/* github coolman bambed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowNctest.initialise(params, log)


// Check input path parameters to see if they exist
def checkPathParamList = [
    params.input,
    params.bed_file
]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

if (params.input) { ch_input = file(params.input)} else { exit 1, 'Input samplesheet file not specified!' }
if (params.bed_file) { ch_bedfile = file(params.bed_file)} else { exit 1, 'Input BED file not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK       } from '../subworkflows/local/input_check'
include { SORT_BAM          } from '../subworkflows/local/sort_bam'
include { DEDUPE_BAM        } from '../subworkflows/local/dedupe_bam'
include { FILTER_BAM        } from '../subworkflows/local/filter_bam'
include { COUNT_BAM_READS   } from '../modules/local/count_bam_reads'
include { EXTRACT_BAM_READS } from '../subworkflows/local/extract_bam_reads'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                                   } from '../modules/nf-core/fastqc/main'
include { MULTIQC                                  } from '../modules/nf-core/multiqc/main'
include { QUALIMAP_BAMQC                           } from '../modules/nf-core/qualimap/bamqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS              } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { BAM_STATS_SAMTOOLS as BAM_STATS_ORIGINAL } from '../subworkflows/nf-core/bam_stats_samtools/main'
include { BAM_STATS_SAMTOOLS as BAM_STATS_CLEANED  } from '../subworkflows/nf-core/bam_stats_samtools/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow NCTEST {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (ch_input)
    ch_bam = INPUT_CHECK.out.bam
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)


    //
    // SUBWORKFLOW: sort and index input BAM file
    //
    SORT_BAM (
        ch_bam
    )
    ch_bam_sort = SORT_BAM.out.bam
    SORT_BAM.out.bam
    .join(SORT_BAM.out.bai, by: [0], remainder: true)
    .set { ch_sort_bam_bai }
    ch_versions = ch_versions.mix(SORT_BAM.out.versions)


    //
    // SUBWORKFLOW: get BAM stats for original BAM file
    //
    if (!params.skip_picard || !params.skip_filter) {
        BAM_STATS_ORIGINAL (
            ch_sort_bam_bai,
            [[:], []]
        )
        ch_versions = ch_versions.mix(BAM_STATS_ORIGINAL.out.versions)
    }


    //
    // MODULE: remove duplicate reads from BAM file
    //
    if (!params.skip_picard) {
        DEDUPE_BAM (
            SORT_BAM.out.bam
        )
        DEDUPE_BAM.out.bam
        .join(DEDUPE_BAM.out.bai, by: [0], remainder: true)
        .set { ch_sort_bam_bai }
        ch_versions = ch_versions.mix(DEDUPE_BAM.out.versions)
    }


    //
    // SUBWORKFLOW: filter sorted BAM file
    //
    if (!params.skip_filter) {
        FILTER_BAM (
            ch_sort_bam_bai
        )
        FILTER_BAM.out.bam
        .join(FILTER_BAM.out.bai, by: [0], remainder: true)
        .set { ch_sort_bam_bai }
        ch_versions = ch_versions.mix(FILTER_BAM.out.versions)
    }


    //
    // SUBWORKFLOW: get BAM stats after preprocessing
    //
    if (!params.skip_picard || !params.skip_filter) {
        BAM_STATS_CLEANED (
            ch_sort_bam_bai,
            [[:], []]
        )
        ch_versions = ch_versions.mix(BAM_STATS_CLEANED.out.versions)
    }

    //
    // MODULE: count reads from BAM file for regions
    //
    COUNT_BAM_READS (
        ch_sort_bam_bai
        ch_bedfile
    )
    ch_versions = ch_versions.mix(COUNT_BAM_READS.out.versions)


    //
    // SUBWORKFLOW: extract reads from BAM file in regions and convert it as FASTA
    //
    ch_sort_bam_bai.map { meta, bam, bai ->
        return [meta, bam]
    }
    .combine(Channel.fromPath( ch_bedfile))
    .set { ch_sort_bam_bed }
    EXTRACT_BAM_READS (
        ch_sort_bam_bed
    )
    ch_versions = ch_versions.mix(EXTRACT_BAM_READS.out.versions)


    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    if (!params.skip_multiqc) {
        workflow_summary    = WorkflowNctest.paramsSummaryMultiqc(workflow, summary_params)
        ch_workflow_summary = Channel.value(workflow_summary)

        methods_description    = WorkflowNctest.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description, params)
        ch_methods_description = Channel.value(methods_description)

        ch_multiqc_files = Channel.empty()
        ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
        ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
        ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
        //ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))

        ch_multiqc_files = ch_multiqc_files.mix(BAM_STATS_ORIGINAL.out.stats.collect{it[1]}.ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(BAM_STATS_ORIGINAL.out.flagstat.collect{it[1]}.ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(BAM_STATS_ORIGINAL.out.idxstats.collect{it[1]}.ifEmpty([]))
        if (!params.skip_picard) {
            ch_multiqc_files = ch_multiqc_files.mix(DEDUPE_BAM.out.metrics.collect{it[1]}.ifEmpty([]))
        }
        if (!params.skip_picard || !params.skip_filter) {
            ch_multiqc_files = ch_multiqc_files.mix(BAM_STATS_CLEANED.out.stats.collect{it[1]}.ifEmpty([]))
            ch_multiqc_files = ch_multiqc_files.mix(BAM_STATS_CLEANED.out.flagstat.collect{it[1]}.ifEmpty([]))
            ch_multiqc_files = ch_multiqc_files.mix(BAM_STATS_CLEANED.out.idxstats.collect{it[1]}.ifEmpty([]))
        }
        //ch_multiqc_files = ch_multiqc_files.mix(COUNT_BAM_READS.out.json.collect{it[1]}.ifEmpty([]))

        MULTIQC (
            ch_multiqc_files.collect(),
            ch_multiqc_config.toList(),
            ch_multiqc_custom_config.toList(),
            ch_multiqc_logo.toList()
        )
        multiqc_report = MULTIQC.out.report.toList()
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.dump_parameters(workflow, params)
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
