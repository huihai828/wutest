//
// Check input samplesheet and get bam channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_bam_channel(it) }
        .set { bam }

    emit:
    bam                                     // channel: [ val(meta), [ bam ] ]
    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ meta, [ bam_file ] ]
def create_bam_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id = row.sample

    // add path(s) of the fastq file(s) to the meta map
    def fastq_meta = []
    if (!file(row.bam_file).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Alignement BAM file does not exist!\n${row.bam_file}"
    }

    fastq_meta = [ meta, [ file(row.bam_file) ] ]

    return fastq_meta
}
