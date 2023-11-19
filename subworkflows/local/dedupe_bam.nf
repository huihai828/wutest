//
// Deduplicate BAM file using picard and index it using samtools
//

include { PICARD_MARKDUPLICATES } from '../../modules/nf-core/picard/markduplicates/main'
include { SAMTOOLS_INDEX        } from '../../modules/nf-core/samtools/index/main'

workflow DEDUPE_BAM {

    take:
    ch_bam // channel: [ val(meta), [ bam ] ]

    main:

    ch_versions = Channel.empty()


    PICARD_MARKDUPLICATES (
        ch_bam,
        [[:], []],
        [[:], []]
    )
    ch_versions = ch_versions.mix(PICARD_MARKDUPLICATES.out.versions.first())

    SAMTOOLS_INDEX ( PICARD_MARKDUPLICATES.out.bam )
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions.first())

    emit:
    bam      = PICARD_MARKDUPLICATES.out.bam           // channel: [ val(meta), [ bam ] ]
    bai      = SAMTOOLS_INDEX.out.bai          // channel: [ val(meta), [ bai ] ]
    csi      = SAMTOOLS_INDEX.out.csi          // channel: [ val(meta), [ csi ] ]
    metrics  = PICARD_MARKDUPLICATES.out.metrics        // channel: [ val(meta), [ metrics ] ]


    versions = ch_versions                     // channel: [ versions.yml ]
}

